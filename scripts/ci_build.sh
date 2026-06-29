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
    # ponytail: tsc emits .d.ts only (emitDeclarationOnly); bun build bundles litevolve-core into JS
    bunx tsc --build packages/node/tsconfig.json
    bun build packages/node/src/index.ts \
      --bundle --target node \
      --outdir packages/node/dist/
    ;;
  deno)
    bun build packages/deno/src/index.ts \
      --bundle --target node \
      --external better-sqlite3 \
      --outdir packages/deno/dist/
    bunx tsc --build packages/deno/tsconfig.json
    deno check packages/deno/src/index.ts
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "$FRAMEWORK build done"
