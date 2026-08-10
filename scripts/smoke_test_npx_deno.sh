#!/bin/sh
# Smoke-test the published litevolve-deno CLI via `npx`, against migrations/working.
# Usage: ./scripts/smoke_test_npx_deno.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
MIGRATIONS_PATH="$ROOT_DIR/migrations/working"
DB=/tmp/litevolve_smoke_npx_deno_$$.db

echo "testing npx litevolve-deno..."
npx --yes litevolve-deno \
    --apply_version=3 \
    --db_path="$DB" \
    --migrations_path="$MIGRATIONS_PATH" \
    --init_seeds

rm -f "$DB"
echo "npx litevolve-deno: ok"
