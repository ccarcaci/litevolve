#!/bin/bash

# Run tests for the specified framework
# Usage: ./scripts/ci_test.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "executing $FRAMEWORK tests"
case "$FRAMEWORK" in
  bun)
    bun test --isolate --parallel=4 packages/core/src/ packages/bun/src/
    ;;
  node)
    node --test packages/node/src/
    ;;
  deno)
    deno test --allow-read --allow-write packages/deno/src/
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "$FRAMEWORK tests done"
