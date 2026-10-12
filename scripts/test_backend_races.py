#!/usr/bin/env python3
"""Real competing PostgreSQL sessions; no sleep-based race assumptions."""
import json
import os
import queue
import subprocess
import sys
import threading
import time

container = sys.argv[1]
docker_env = os.environ.copy()
for key in ('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH'):
    docker_env.pop(key, None)
base = ['docker','--host=unix:///var/run/docker.sock','exec','-i']

def command(app):
    return base + ['-e', 'PGAPPNAME='+app,container,'psql','-XqAt','-U','postgres','-d',os.environ.get('BACKEND_TEST_DATABASE','postgres'),'-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose']

def sql(statement):
    return subprocess.check_output(command('backend-race-control')+['-c',statement],env=docker_env,text=True,timeout=15).strip()

def start(app, statement):
    return subprocess.Popen(command(app)+['-c',statement],env=docker_env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)

class Session:
    def __init__(self,app):
        self.p=subprocess.Popen(command(app),env=docker_env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
        self.lines=queue.Queue()
        def read():
            for line in self.p.stdout:self.lines.put(line.strip())
        threading.Thread(target=read,daemon=True).start()
    def send(self,s):self.p.stdin.write(s+'\n');self.p.stdin.flush()
    def until(self,marker):
        rows=[]
        while True:
            line=self.lines.get(timeout=10)
            if line==marker:return rows
            rows.append(line)
    def close(self):
        if self.p.poll() is None:self.send('commit;\n\\q')
        self.p.wait(timeout=10)
        assert self.p.returncode==0,self.p.stderr.read()

def blocked(app):
    return sql("select exists(select 1 from pg_stat_activity where application_name='"+app+"' and cardinality(pg_blocking_pids(pid))>0)")=='t'

def await_block(app,process):
    end=time.monotonic()+8
    while time.monotonic()<end:
        if blocked(app):return
        assert process.poll() is None,'actor finished without reaching expected lock: '+app
        time.sleep(.03)
    raise AssertionError('actor did not block: '+app)

def auth(uid):
    return "begin;set local request.jwt.claim.sub='"+uid+"';set local role authenticated;"

def result(process):
    out,err=process.communicate(timeout=12)
    return process.returncode,out,err

def last_json(out):
    return json.loads([line for line in out.splitlines() if line.startswith('{')][-1])

A='50000000-0000-0000-0000-000000000001'
B='50000000-0000-0000-0000-000000000002'
sql("insert into auth.users(id) values('"+A+"'),('"+B+"');create function private.test_upload_barrier() returns trigger language plpgsql as $$begin if new.owner_id='"+A+"'::uuid then perform pg_advisory_xact_lock(801122);end if;return new;end$$;create trigger test_upload_barrier before insert on public.media for each row execute function private.test_upload_barrier();")
failures=[]
# Upload reaches insertion after its active check. Deletion must wait for its profile lock.
gate=Session('backend-race-gate')
try:
    gate.send('begin;select pg_advisory_xact_lock(801122);\n\\echo GATE_READY')
    gate.until('GATE_READY')
    upload=start('backend-race-upload-first',auth(A)+"select public.prepare_media_upload(null,'audio/mp4',3,false);commit;")
    await_block('backend-race-upload-first',upload)
    deletion=start('backend-race-delete-second',auth(A)+"select public.request_account_deletion(true);commit;")
    deadline=time.monotonic()+3
    while deletion.poll() is None and not blocked('backend-race-delete-second') and time.monotonic()<deadline:time.sleep(.03)
    gate.close()
    urc,uout,uerr=result(upload);drc,dout,derr=result(deletion)
    assert urc==0 and drc==0,(uerr,derr)
    path=last_json(uout)['object_path'];plan=last_json(dout)
    if path not in [o['object_path'] for o in plan['objects']]:failures.append('upload-first: issued path missing from confirmed deletion plan')
    sql("set role service_role;select public.purge_account_data('"+A+"');")
    retained=json.loads(sql("select objects from private.account_media_cleanup_jobs where user_id='"+A+"'"))
    if path not in [o['object_path'] for o in retained]:failures.append('upload-first: cleanup locator missing after purge')
finally:
    if gate.p.poll() is None:gate.close()
# Deletion owns profile before upload starts. Upload must recheck active status after waiting.
deleter=Session('backend-race-delete-first')
try:
    deleter.send(auth(B)+"select public.request_account_deletion(true);\n\\echo DELETE_READY")
    deleter.until('DELETE_READY')
    upload=start('backend-race-upload-second',auth(B)+"select public.prepare_media_upload(null,'audio/mp4',3,false);commit;")
    await_block('backend-race-upload-second',upload)
    deleter.close()
    rc,out,err=result(upload)
    if rc==0 or '42501' not in err or 'account_unavailable' not in err:failures.append('deletion-first: prepared upload succeeded after confirmed deletion')
    if sql("select count(*) from public.media where owner_id='"+B+"'")!='0':failures.append('deletion-first: unexpected media registration')
finally:
    if deleter.p.poll() is None:deleter.close()
# Concurrent preference patches must compose after the first transaction commits.
C='50000000-0000-0000-0000-000000000003'
sql("insert into auth.users(id) values('"+C+"');")
writer=Session('backend-race-preferences-first')
try:
    writer.send(auth(C)+"select public.update_user_preferences('{\"preferences\":{\"unknown\":{\"first\":1},\"notification_categories\":{\"lesson\":false}}}');\n\\echo PREF_READY")
    writer.until('PREF_READY')
    second=start('backend-race-preferences-second',auth(C)+"select public.update_user_preferences('{\"preferences\":{\"unknown\":{\"second\":2},\"notification_categories\":{\"assignment\":false}}}');commit;")
    await_block('backend-race-preferences-second',second)
    writer.close()
    rc,out,err=result(second)
    assert rc==0,err
    kept=json.loads(sql("select preferences from public.user_settings where user_id='"+C+"'"))
    if kept != {'unknown':{'first':1,'second':2},'notification_categories':{'lesson':False,'assignment':False}}:failures.append('concurrent preferences: unrelated patches lost')
finally:
    if writer.p.poll() is None:writer.close()
if failures:
    for failure in failures:print('FAIL:',failure,file=sys.stderr)
    sys.exit(1)
print('PASS: real sessions: upload-first, deletion-first, concurrent preference merge; cleanup locator retained after purge')
