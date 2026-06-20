#!/bin/bash

# Check for outdated dependencies in packages/node
# Fails if any packages have available updates
# Usage: ./scripts/check_updates_node.sh

set -e

OUTDATED=$(npm outdated --prefix packages/node 2>&1) || true

if [ -n "$OUTDATED" ]; then
  echo "$OUTDATED"
  echo ""
  echo "ERROR: outdated dependencies in packages/node — update package.json and run bun install"
  exit 1
fi

echo "packages/node: all dependencies up to date"
