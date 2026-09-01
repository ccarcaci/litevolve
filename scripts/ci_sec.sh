#!/bin/bash

# Security audit for the specified framework package
# Usage: ./scripts/ci_sec.sh <bun|node>

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
  *)
    echo "Usage: $0 <bun|node>"
    exit 1
    ;;
esac
echo "$FRAMEWORK security auditing done"
