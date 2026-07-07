#!/bin/bash

# Check for outdated dependencies in runtimes/deno
# Fails if any packages have available updates
# Usage: ./scripts/check_updates_deno.sh

set -e

OUTDATED=$(npm outdated --prefix runtimes/deno 2>&1) || true

if [ -n "$OUTDATED" ]; then
  echo "$OUTDATED"
  echo ""
  echo "ERROR: outdated dependencies in runtimes/deno — update package.json and run bun install"
  exit 1
fi

echo "runtimes/deno: all dependencies up to date"
