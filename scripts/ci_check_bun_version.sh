#!/bin/bash

# Check that the running Bun version matches .bun-version
# Usage: ./scripts/check_bun_version.sh

set -e

REQUIRED_VERSION=$(cat .bun-version | tr -d '[:space:]')
CURRENT_VERSION=$(bun --version 2>/dev/null || echo "not installed")

if [ "$CURRENT_VERSION" = "not installed" ]; then
  echo "ERROR: Bun is not installed. Required version: $REQUIRED_VERSION"
  echo "Install: curl -fsSL https://bun.sh/install | bash -s bun-v$REQUIRED_VERSION"
  exit 1
fi

if [ "$CURRENT_VERSION" != "$REQUIRED_VERSION" ]; then
  echo "WARNING: Bun version mismatch"
  echo "  Required: $REQUIRED_VERSION"
  echo "  Current:  $CURRENT_VERSION"
  echo ""
  echo "To update to the latest version: bun upgrade"
  echo "To update .bun-version: echo $CURRENT_VERSION > .bun-version"
  exit 1
fi

echo "Bun version OK: $CURRENT_VERSION"
