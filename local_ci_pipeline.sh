#!/bin/bash
set -e

case "$(uname -s)" in
  Darwin) export RUNNER_OS=macOS ;;
  Linux)  export RUNNER_OS=Linux ;;
  *) echo "error: unsupported OS $(uname -s)"; exit 1 ;;
esac

# -- lint

bun install
scripts/ci_lint.sh

# -- bun

scripts/check_bun_version.sh
scripts/check_updates.sh
scripts/ci_build.sh bun
scripts/ci_types.sh bun
scripts/ci_sec.sh bun
scripts/ci_test.sh bun

# -- node

# npm install
# scripts/check_node_version.sh
# scripts/check_updates_node.sh
# scripts/ci_build.sh node
# scripts/ci_types.sh node
# scripts/ci_sec.sh node
# scripts/ci_test.sh node

# -- deno

# deno install
# scripts/check_deno_version.sh
# scripts/check_updates_deno.sh
# scripts/ci_build.sh deno
# scripts/ci_types.sh deno
# scripts/ci_sec.sh deno
# scripts/ci_test.sh deno

# -- executables smoke checks

scripts/runners_build.sh
for binary in dist/litevolve_*; do
  [ -f "$binary" ] || continue
  scripts/smoke_test.sh "$(basename "$binary")" "$binary" "$PWD/migrations"
done
