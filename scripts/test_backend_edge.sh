#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DENO_DIR="${DENO_DIR:-/tmp/bayna-deno-cache}"
if command -v deno >/dev/null; then runner=(deno); else runner=(npm --cache /tmp/bayna-npm-cache exec --yes --package=deno@2.9.6 -- deno); fi
"${runner[@]}" check --frozen --config supabase/functions/deno.json supabase/functions/*/index.ts
"${runner[@]}" test --frozen --config supabase/functions/deno.json --allow-env --allow-read supabase/functions/_shared/backend_test.ts
