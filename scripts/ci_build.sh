#!/bin/bash

# Build the specified framework package
# Usage: ./scripts/ci_build.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "$FRAMEWORK build"
case "$FRAMEWORK" in
  bun)
    bun build packages/bun/src/index.ts \
      --bundle --target bun \
      --outdir packages/bun/dist/
    ;;
  node)
    # ponytail: tsc --build follows project references (builds core first)
    bunx tsc --build packages/node/tsconfig.json
    ;;
  deno)
    deno check packages/deno/src/index.ts
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "$FRAMEWORK build done"
