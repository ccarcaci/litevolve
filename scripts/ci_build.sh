#!/bin/bash

# Build the specified framework package
# Usage: ./scripts/ci_build.sh <bun|node>

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
    # esbuild bundles src/core into dist/index.js; tsc emits .d.ts only (emitDeclarationOnly in tsconfig)
    esbuild runtimes/node/src/index.ts --bundle --platform=node --format=esm --external:node:* --outfile=runtimes/node/dist/index.js
    esbuild runtimes/node/src/run_litevolve.ts --bundle --platform=node --format=esm --external:node:* --outfile=runtimes/node/dist/run_litevolve.js
    tsc --project runtimes/node/tsconfig.json
    ;;
  *)
    echo "Usage: $0 <bun|node>"
    exit 1
    ;;
esac
echo "$FRAMEWORK build done"
