#!/bin/bash

# Check for outdated dependencies in packages/deno
# Fails if any packages have available updates
# Usage: ./scripts/check_updates_deno.sh

set -e

OUTDATED=$(npm outdated --prefix packages/deno 2>&1) || true

if [ -n "$OUTDATED" ]; then
  echo "$OUTDATED"
  echo ""
  echo "ERROR: outdated dependencies in packages/deno — update package.json and run bun install"
  exit 1
fi

echo "packages/deno: all dependencies up to date"
