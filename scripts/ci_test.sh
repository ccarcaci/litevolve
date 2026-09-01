#!/bin/bash

# Run tests for the specified framework
# Usage: ./scripts/ci_test.sh <bun|node>

set -e

FRAMEWORK="$1"

echo "executing $FRAMEWORK tests"
case "$FRAMEWORK" in
  bun)
    # execute the main test suite for unit tests, written for Bun specifically
    bun test --isolate --parallel=4 runtimes/bun/
    ;;
  node)
    # execute node-specific tests
    node --test runtimes/node/**/*.test.ts
    ;;
  *)
    echo "Usage: $0 <bun|node>"
    exit 1
    ;;
esac
echo "$FRAMEWORK tests done"
