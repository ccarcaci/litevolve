#!/bin/bash

# Security audit for the specified framework package
# Usage: ./scripts/ci_sec.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "$FRAMEWORK security auditing"
cd runtimes/$FRAMEWORK
case "$FRAMEWORK" in
  bun)
    bun audit
    ;;
  node)
    npm audit
    ;;
  deno)
    echo "deno auditing not implemented yet"
    exit 1
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "$FRAMEWORK security auditing done"
