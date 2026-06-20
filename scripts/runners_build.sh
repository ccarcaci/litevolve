#!/bin/sh
# Build litevolve binaries for the current CI runner.
# Requires: RUNNER_OS=Linux|macOS (set automatically by GitHub Actions)
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

HOST_ARCH=$(uname -m)
if [ "$HOST_ARCH" = "aarch64" ] || [ "$HOST_ARCH" = "arm64" ]; then
  GLIBC_BINARIES="litevolve_linux_arm64"
  DARWIN_BINARIES="litevolve_darwin_arm64"
else
  GLIBC_BINARIES="litevolve_linux_x64 litevolve_linux_x64_modern litevolve_linux_x64_baseline"
  DARWIN_BINARIES="litevolve_darwin_x64 litevolve_darwin_x64_baseline"
fi

case "$RUNNER_OS" in
  Linux)  BINARIES="$GLIBC_BINARIES" ;;
  macOS)  BINARIES="$DARWIN_BINARIES" ;;
  *)
    echo "error: unsupported RUNNER_OS '$RUNNER_OS' (expected Linux or macOS)"
    exit 1
    ;;
esac

for binary in $BINARIES; do
  echo ""
  echo "--- building $binary ---"
  target=$(echo "$binary" | sed 's/litevolve_/bun-/' | tr '_' '-')
  make -C "$ROOT_DIR" ci_binary TARGET="$target"
  mv "$ROOT_DIR/dist/litevolve" "$ROOT_DIR/dist/$binary"
done
