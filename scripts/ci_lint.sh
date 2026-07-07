#!/bin/bash

# Run Biome linter across all packages
# Usage: ./scripts/ci_lint.sh

set -e

echo "check linting"
bunx biome check runtimes/
echo "check linting done"
