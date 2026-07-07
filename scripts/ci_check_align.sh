set -e

BUN_CORE_SRC="runtimes/bun/src/core"
NODE_CORE_SRC="runtimes/node/src/core"
DENO_CORE_SRC="runtimes/deno/src/core"

echo "checking core alignment across runtimes..."
diff --brief --recursive $BUN_CORE_SRC $NODE_CORE_SRC || (echo "error: $NODE_CORE_SRC differs from $BUN_CORE_SRC"; exit 1)
diff --brief --recursive $BUN_CORE_SRC $DENO_CORE_SRC || (echo "error: $DENO_CORE_SRC differs from $BUN_CORE_SRC"; exit 1)
echo "all runtime cores are aligned!"
