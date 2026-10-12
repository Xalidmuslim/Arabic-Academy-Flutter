#!/usr/bin/env python3
"""Kill security regressions in an isolated tmpfs database and temporary Edge copy."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
ENV = os.environ.copy()
for key in ('DOCKER_HOST', 'DOCKER_CONTEXT', 'DOCKER_TLS', 'DOCKER_TLS_VERIFY', 'DOCKER_CERT_PATH'):
    ENV.pop(key, None)
ENV.setdefault('DENO_DIR', '/tmp/bayna-deno-cache')
DOCKER = ['docker', '--host=unix:///var/run/docker.sock']
NAME = 'bayna-mutation-test-' + uuid.uuid4().hex[:12]

def run(args, **kwargs):
    return subprocess.run(args, env=ENV, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90, **kwargs)

def db(text, database='postgres'):
    return run(DOCKER + ['exec', '-i', NAME, 'psql', '-XqAt', '-U', 'postgres', '-d', database, '-v', 'ON_ERROR_STOP=1'], input=text)

def good(result):
    if result.returncode:
        raise AssertionError(result.stdout[-7000:])
    return result.stdout.strip()

def rejected(result, needle, name):
    if result.returncode == 0 or needle not in result.stdout:
        raise AssertionError('Mutation survived or failed for an unrelated reason: ' + name + '\n' + result.stdout[-7000:])
    print('KILLED:', name, flush=True)

def bootstrap(database):
    mock=(ROOT/'supabase/tests/bootstrap.sql').read_text()
    if database!='postgres': mock='\n'.join(line for line in mock.splitlines() if not line.startswith('create role '))
    good(db(mock, database))
    for migration in sorted((ROOT/'supabase/migrations').glob('*.sql')):
        good(db(migration.read_text(), database))

try:
    good(run(DOCKER + ['run', '-d', '--name', NAME, '--tmpfs', '/var/lib/postgresql/data:rw,size=256m', '-e', 'POSTGRES_PASSWORD=disposable-mutation-test', ENV.get('POSTGRES_IMAGE', 'postgres:17-alpine')]))
    for _ in range(60):
        initialized='PostgreSQL init process complete; ready for start up.' in run(DOCKER+['logs', NAME]).stdout
        if initialized and run(DOCKER + ['exec', NAME, 'pg_isready', '-U', 'postgres']).returncode == 0:
            break
        time.sleep(.25)
    else:
        raise AssertionError('PostgreSQL did not start')
    bootstrap('postgres')
    review = (ROOT/'supabase/tests/review_test.sql').read_text()
    good(db(review))
    print('PASS: SQL mutation baseline', flush=True)
    mutations = [
        ('private.require_notification_delivery(uuid)', lambda s: s.replace("category is null OR enabled IS DISTINCT FROM 'true'::jsonb", "false"), 'category disabled cannot reserve', 'disabled category delivery'),
        ('public.record_event(uuid,text,jsonb)', lambda s: s.replace("p_payload->>'origin'='local_author_learning'", "false"), 'old namespace event cannot bind current account', 'event account affinity'),
        ('public.claim_group_invite(text)', lambda s: s.replace('or i.claimed_at is not null', ''), 'invite claim single use and no paid unlock', 'single-use invite replay'),
        ('public.update_user_preferences(jsonb)', lambda s: s.replace('patch:=private.merge_preferences(s.preferences,patch);', 'patch:=patch;'), 'atomic preferences merge preserves other values', 'atomic preference preservation'),
    ]
    # pg_get_functiondef preserves PL/pgSQL body spelling, except its wrapper.
    for signature, mutate, needle, name in mutations:
        original = good(db("select pg_get_functiondef('"+signature+"'::regprocedure)"))
        changed = mutate(original)
        # Use original body spelling for the predicate (avoid dependence on server pretty-printer).
        if changed == original and name == 'disabled category delivery':
            changed = original.replace("category is null or enabled is distinct from 'true'::jsonb", 'false')
        assert changed != original, 'mutation did not change '+name
        good(db(changed))
        try:
            rejected(db(review), needle, name)
        finally:
            good(db(original))
    # Separate disposable database for genuine two-session upload/deletion races.
    good(db('create database race_mutation'))
    bootstrap('race_mutation')
    original = good(db("select pg_get_functiondef('private.require_active_account()'::regprocedure)", 'race_mutation'))
    good(db(original.replace('for update', ''), 'race_mutation'))
    race_env = ENV.copy()
    race_env['BACKEND_TEST_DATABASE'] = 'race_mutation'
    result = subprocess.run(['python3', str(ROOT/'scripts/test_backend_races.py'), NAME], env=race_env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    rejected(result, 'issued path missing', 'profile lock / actual upload-deletion race')
    good(db('drop database race_mutation'))
finally:
    run(DOCKER + ['rm', '-fv', NAME])

runner = [shutil.which('deno')] if shutil.which('deno') else ['npm', '--cache', '/tmp/bayna-npm-cache', 'exec', '--yes', '--package=deno@2.9.6', '--', 'deno']
with tempfile.TemporaryDirectory(prefix='bayna-edge-mutations-', dir='/tmp') as temp:
    target = Path(temp)/'functions'
    shutil.copytree(ROOT/'supabase/functions', target, ignore=shutil.ignore_patterns('node_modules'))
    # Reuse already-frozen dependencies; no new package tree on the constrained disk.
    modules=ROOT/'supabase/functions/node_modules'
    if modules.exists(): (target/'node_modules').symlink_to(modules, target_is_directory=True)
    args=runner+['test', '--frozen', '--config', str(target/'deno.json'), '--allow-env', '--allow-read']
    test=str(target/'_shared/backend_test.ts')
    good(run(args+[test]))
    print('PASS: Edge mutation baseline (frozen checksums)', flush=True)
    mutations = [
        ('livekit-token/index.ts', 'canPublishData: true', 'canPublishData: false', 'server-scoped LiveKit', 'learner chat data grant'),
        ('_shared/stores.ts', '"SUBSCRIPTION_STATE_CANCELED", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"', '"SUBSCRIPTION_STATE_ACTIVE"', 'Google cancellation', 'future-expiry canceled/grace subscriptions'),
        ('_shared/stores.ts', 'Deno.env.get("DEPLOYMENT_ENVIRONMENT") !== "test"', 'false', 'licensed sandbox', 'production sandbox isolation'),
        ('dispatch-notification/index.ts', 'notification_id: id,', '', 'FCM sender', 'first-send response notification ID'),
        ('dispatch-notification/index.ts', 'notification_id: id,', '', 'notification replay', 'cached replay response notification ID'),
        ('dispatch-notification/index.ts', 'notification_id: id,', '', 'concurrent dispatch', 'concurrent replay response notification ID'),
    ]
    for relative, before, after, pattern, name in mutations:
        file=target/relative
        original=file.read_text()
        # After formatting, the Google state list may be split across lines.
        if name=='future-expiry canceled/grace subscriptions':
            changed=original.replace('"SUBSCRIPTION_STATE_CANCELED"', '"SUBSCRIPTION_STATE_ACTIVE"').replace('"SUBSCRIPTION_STATE_IN_GRACE_PERIOD"', '"SUBSCRIPTION_STATE_ACTIVE"')
        elif name=='first-send response notification ID':
            changed=original.replace('return { ...result, notification_id: id, duplicate: false };', 'return { ...result, duplicate: false };')
        elif name=='concurrent replay response notification ID':
            changed=original.replace('      notification_id: id,\n', '')
        elif name=='cached replay response notification ID':
            # Model a stale preflight server response and omitted defensive response ID.
            changed=original.replace('{ ...previous, notification_id: id, duplicate: true }', '{ state: previous.state, accepted_count: previous.accepted_count, failed_count: previous.failed_count, duplicate: true }')
        else: changed=original.replace(before, after)
        assert changed!=original, 'mutation did not change '+name
        file.write_text(changed)
        try:
            rejected(run(args+['--filter',pattern,test]), '1 failed', name)
        finally:
            file.write_text(original)
print('PASS: all security mutations were detected')
