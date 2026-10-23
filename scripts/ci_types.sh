#!/bin/bash

# Type-check the specified framework package using tsc --noEmit
# Usage: ./scripts/ci_types.sh <bun|node>

set -e

FRAMEWORK="$1"
TSC_NODE_BIN="./runtimes/node/node_modules/.bin/tsc"

echo "TypeScript compilation for $FRAMEWORK"
case "$FRAMEWORK" in
  bun)
    bun x tsc --noEmit --project runtimes/bun/tsconfig.json
    ;;
  node)
    $TSC_NODE_BIN --noEmit --project runtimes/node/tsconfig.json
    ;;
  *)
    echo "Usage: $0 <bun|node>"
    exit 1
    ;;
esac
echo "TypeScript compilation for $FRAMEWORK done"
