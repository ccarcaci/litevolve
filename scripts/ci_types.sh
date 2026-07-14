#!/bin/bash

# Type-check the specified framework package using tsc --noEmit
# Usage: ./scripts/ci_types.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "TypeScript compilation for $FRAMEWORK"
case "$FRAMEWORK" in
  bun)
    bunx tsc --noEmit --project runtimes/bun/tsconfig.json
    ;;
  node)
    tsc --noEmit --project runtimes/node/tsconfig.json
    ;;
  deno)
    tsc --noEmit --project runtimes/deno/tsconfig.json
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "TypeScript compilation for $FRAMEWORK done"
