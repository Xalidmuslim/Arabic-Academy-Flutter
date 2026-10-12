#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# No host port or persistent volume. All test data are disposable.
docker_cmd=(env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH docker --host=unix:///var/run/docker.sock)
container="bayna-db-test-${RANDOM}-$$"
cleanup() { "${docker_cmd[@]}" rm -fv "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
"${docker_cmd[@]}" run -d --name "$container" --tmpfs /var/lib/postgresql/data:rw,size=256m -e POSTGRES_PASSWORD=disposable-backend-test "${POSTGRES_IMAGE:-postgres:16-alpine}" >/dev/null
ready=false
for _ in {1..60}; do
 if [[ $("${docker_cmd[@]}" logs "$container" 2>&1) == *"PostgreSQL init process complete; ready for start up."* ]] && "${docker_cmd[@]}" exec "$container" pg_isready -U postgres >/dev/null 2>&1; then ready=true; break; fi
 sleep 1
done
if [[ "$ready" != true ]]; then "${docker_cmd[@]}" logs "$container"; exit 1; fi
run_sql() { "${docker_cmd[@]}" exec -i "$container" psql -X -U postgres -v ON_ERROR_STOP=1 < "$1"; }
run_sql supabase/tests/bootstrap.sql
for migration in supabase/migrations/*.sql; do echo "Applying $migration"; run_sql "$migration"; done
shopt -s nullglob
tests=(supabase/tests/*_test.sql)
if (( ${#tests[@]} == 0 )); then echo "No SQL tests found" >&2; exit 1; fi
for test in "${tests[@]}"; do echo "Running $test"; run_sql "$test"; done
python3 scripts/test_backend_races.py "$container"
echo 'Backend migrations and security assertions passed.'
