set -e

BUN_CORE_SRC="runtimes/bun/src/core"
NODE_CORE_SRC="runtimes/node/src/core"
DENO_CORE_SRC="runtimes/deno/src/core"

echo "checking core alignment across runtimes..."
diff --brief --recursive $BUN_CORE_SRC $NODE_CORE_SRC || (echo "error: $NODE_CORE_SRC differs from $BUN_CORE_SRC"; exit 1)
diff --brief --recursive $BUN_CORE_SRC $DENO_CORE_SRC || (echo "error: $DENO_CORE_SRC differs from $BUN_CORE_SRC"; exit 1)
echo "all runtime cores are aligned!"

LICENSE_SOURCE="LICENSE"
README_SOURCE="README.md"
BUN_LICENSE_DEST="runtimes/bun/LICENSE"
BUN_README_DEST="runtimes/bun/README.md"
NODE_LICENSE_DEST="runtimes/node/LICENSE"
NODE_README_DEST="runtimes/node/README.md"
DENO_LICENSE_DEST="runtimes/deno/LICENSE"
DENO_README_DEST="runtimes/deno/README.md"
echo "checking README.md and LICENSE alignment..."
diff --brief $LICENSE_SOURCE $BUN_LICENSE_DEST || (echo "error: $LICENSE_SOURCE differs from $BUN_LICENSE_DEST"; exit 1)
diff --brief $README_SOURCE $BUN_README_DEST || (echo "error: $README_SOURCE differs from $BUN_README_DEST"; exit 1)
diff --brief $LICENSE_SOURCE $NODE_LICENSE_DEST || (echo "error: $LICENSE_SOURCE differs from $NODE_LICENSE_DEST"; exit 1)
diff --brief $README_SOURCE $NODE_README_DEST || (echo "error: $README_SOURCE differs from $NODE_README_DEST"; exit 1)
diff --brief $LICENSE_SOURCE $DENO_LICENSE_DEST || (echo "error: $LICENSE_SOURCE differs from $DENO_LICENSE_DEST"; exit 1)
diff --brief $README_SOURCE $DENO_README_DEST || (echo "error: $README_SOURCE differs from $DENO_README_DEST"; exit 1)
echo "LICENSE and README.md are aligned!"
