#!/bin/sh
# Smoke-test the published litevolve-node CLI via `npx`, against migrations/working.
# Usage: ./scripts/smoke_test_npx_node.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
MIGRATIONS_PATH="$ROOT_DIR/migrations/working"
DB=/tmp/litevolve_smoke_npx_node_$$.db

echo "testing npx litevolve-node..."
npx --yes litevolve-node \
    --apply_version=3 \
    --db_path="$DB" \
    --migrations_path="$MIGRATIONS_PATH" \
    --init_seeds

rm -f "$DB"
echo "npx litevolve-node: ok"
