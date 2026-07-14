#!/bin/bash

# Build the specified framework package
# Usage: ./scripts/ci_build.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "$FRAMEWORK build"
case "$FRAMEWORK" in
  bun)
    bun build runtimes/bun/src/index.ts \
      --bundle --target bun \
      --outdir runtimes/bun/dist/
    ;;
  node)
    # ponytail: tsc emits .d.ts only (emitDeclarationOnly); esbuild bundles src/core into dist/index.js
    esbuild src/index.ts --bundle --platform=node --format=esm --external:node:* --outfile=dist/index.js
    ;;
  deno)
    bun build runtimes/deno/src/index.ts \
      --bundle --target node \
      --external better-sqlite3 \
      --outdir runtimes/deno/dist/
    deno check runtimes/deno/src/index.ts
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "$FRAMEWORK build done"
