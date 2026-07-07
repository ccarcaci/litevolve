#!/bin/bash

# Check Deno version matches .deno-version and is the latest available 2.x
# Usage: ./scripts/check_deno_version.sh

set -e

PINNED=$(cat .deno-version | tr -d '[:space:]')
CURRENT=$(deno --version 2>/dev/null | grep '^deno ' | awk '{print $2}' || echo "not installed")

if [ "$CURRENT" = "not installed" ]; then
  echo "ERROR: Deno is not installed. Required version: $PINNED"
  exit 1
fi

if [ "$CURRENT" != "$PINNED" ]; then
  echo "ERROR: Deno version mismatch"
  echo "  Required: $PINNED"
  echo "  Current:  $CURRENT"
  echo "To update .deno-version: echo $CURRENT > .deno-version"
  exit 1
fi

echo "Deno version installed: $CURRENT"

LATEST=$(curl -sf https://api.github.com/repos/denoland/deno/releases/latest | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//' || true)

if [ -z "$LATEST" ]; then
  echo "WARNING: Could not fetch latest Deno version from GitHub"
  exit 0
fi

if [ "$PINNED" != "$LATEST" ]; then
  echo "ERROR: Deno $PINNED is pinned but $LATEST is available"
  echo "Update .deno-version: echo $LATEST > .deno-version"
  exit 1
fi

echo "Deno version OK: $CURRENT (latest)"
