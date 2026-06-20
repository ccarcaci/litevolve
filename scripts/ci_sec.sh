#!/bin/bash

# Security audit for the specified framework package
# Usage: ./scripts/ci_sec.sh <bun|node|deno>

set -e

FRAMEWORK="$1"

echo "$FRAMEWORK security auditing"
case "$FRAMEWORK" in
  bun|node|deno)
    (cd "packages/$FRAMEWORK" && bun audit)
    ;;
  *)
    echo "Usage: $0 <bun|node|deno>"
    exit 1
    ;;
esac
echo "$FRAMEWORK security auditing done"
