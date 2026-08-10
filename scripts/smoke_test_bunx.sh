#!/bin/sh
# Smoke-test the published litevolve-bun CLI via `bunx`, against migrations/working.
# Usage: ./scripts/smoke_test_bunx.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
MIGRATIONS_PATH="$ROOT_DIR/migrations/working"
DB=/tmp/litevolve_smoke_bunx_$$.db

echo "testing bunx litevolve-bun..."
bunx litevolve-bun \
    --apply_version=3 \
    --db_path="$DB" \
    --migrations_path="$MIGRATIONS_PATH" \
    --init_seeds

rm -f "$DB"
echo "bunx litevolve-bun: ok"
