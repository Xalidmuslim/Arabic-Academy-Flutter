#!/usr/bin/env python3
"""Exercise generated catalog SQL against real migrations in disposable Postgres.

Uses only the explicitly synthetic unit-test manifest, never publisher content.
No host port, persistent volume, or owner credentials are used.
"""
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from scripts.catalog_import import build_plan, render_sql
from scripts.tests.test_catalog_import import lesson, sample


def main():
    environment = {key: value for key, value in os.environ.items() if key not in
                   {"DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"}}
    docker = ["docker", "--host=unix:///var/run/docker.sock"]
    container = "bayna-catalog-test-" + uuid.uuid4().hex[:12]

    def run(*args):
        return subprocess.run([*docker, *args], env=environment, capture_output=True, text=True)

    def sql(text, expected_success=True):
        result = subprocess.run([*docker, "exec", "-i", container, "psql", "-h", "127.0.0.1",
                                 "-X", "-q", "-t", "-A", "-U", "postgres", "-v", "ON_ERROR_STOP=1"],
                                input=text, env=environment, capture_output=True, text=True)
        if expected_success and result.returncode:
            raise RuntimeError(result.stderr)
        if not expected_success and result.returncode == 0:
            raise AssertionError("Forbidden or duplicate catalog SQL was accepted")
        return result.stdout.strip()

    try:
        result = run("run", "-d", "--name", container, "--tmpfs", "/var/lib/postgresql/data:rw,size=256m",
                     "-e", "POSTGRES_PASSWORD=disposable-catalog-test",
                     os.environ.get("POSTGRES_IMAGE", "postgres:16-alpine"))
        if result.returncode:
            raise RuntimeError(result.stderr)
        # TCP readiness excludes the image's temporary socket-only init server.
        for _ in range(60):
            if run("exec", container, "pg_isready", "-h", "127.0.0.1", "-U", "postgres").returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("PostgreSQL did not become ready")
        sql((ROOT / "supabase/tests/bootstrap.sql").read_text(encoding="utf-8"))
        for migration in sorted((ROOT / "supabase/migrations").glob("*.sql")):
            sql(migration.read_text(encoding="utf-8"))
        manifest = sample()
        lesson(manifest)["title"] = "Owner's lesson'); DROP TABLE public.courses; --"
        plan = build_plan(manifest)
        transaction = render_sql(plan)
        course_id = plan["rows"]["courses"][0]["id"]
        lesson_id = plan["rows"]["lessons"][0]["id"]
        book_id = plan["rows"]["books"][0]["id"]
        block_id = plan["rows"]["blocks"][0]["id"]
        count = f"SELECT count(*) FROM public.courses WHERE id='{course_id}';"
        sql("SET ROLE anon;\n" + transaction, expected_success=False)
        assert sql(count) == "0", "Denied import changed data"
        sql(transaction)
        assert sql(f"SELECT body->>'ar' FROM public.lesson_blocks WHERE id='{block_id}';") == "كِتَابٌ"
        assert sql(f"SELECT source_locator->>'page_start' FROM public.lessons WHERE id='{lesson_id}';") == "2"
        assert sql(f"SELECT source_locator->>'pdf_sha256' FROM public.books WHERE id='{book_id}';") == "ab" * 32
        assert sql(f"SELECT source_policy::jsonb->>'manifest_sha256' FROM public.courses WHERE id='{course_id}';") == plan["manifest_sha256"]
        assert sql(f"SELECT title FROM public.lessons WHERE id='{lesson_id}';") == lesson(manifest)["title"]
        sql(transaction, expected_success=False)
        assert sql(count) == "1", "Duplicate import changed data"
        print("Catalog SQL passed: real migrations/permissions, vowels, provenance, quoting, duplicate rollback. Synthetic fixture only.")
    finally:
        run("rm", "-fv", container)


if __name__ == "__main__":
    main()
