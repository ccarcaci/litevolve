#!/bin/bash

# Type-check the specified framework package using tsc --noEmit
# Usage: ./scripts/ci_types.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "TypeScript compilation for $FRAMEWORK"
case "$FRAMEWORK" in
  bun)
    bunx tsc --noEmit -p packages/bun/tsconfig.json
    ;;
  node)
    bunx tsc --noEmit -p packages/node/tsconfig.json
    ;;
  deno)
    bunx tsc --noEmit -p packages/deno/tsconfig.json
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "TypeScript compilation for $FRAMEWORK done"
