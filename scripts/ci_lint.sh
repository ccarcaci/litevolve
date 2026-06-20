#!/bin/bash

# Run Biome linter across all packages
# Usage: ./scripts/ci_lint.sh

set -e

echo "check linting"
bunx biome check packages/
echo "check linting done"
