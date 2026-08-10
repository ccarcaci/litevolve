#!/bin/bash

# Check .deno-version against the latest Deno release.
# Renovate has no manager matching .deno-version, so this check is the only thing
# keeping that pin current. Everything else in runtimes/deno (package.json,
# deno.json, deno.lock) is covered by Renovate's npm + deno managers.
# Usage: ./scripts/ci_check_updates_deno.sh

set -euo pipefail

PINNED=$(tr -d '[:space:]' < .deno-version)

# same endpoint the official installer resolves "latest" with (https://deno.land/install.sh)
LATEST=$(curl -sf https://dl.deno.land/release-latest.txt | tr -d '[:space:]' | sed 's/^v//' || true)

if [ -z "$LATEST" ]; then
  echo "WARNING: could not fetch the latest Deno release from dl.deno.land"
  exit 0
fi

if [ "$PINNED" != "$LATEST" ]; then
  echo "ERROR: .deno-version pins $PINNED but $LATEST is the latest Deno release"
  echo "Update: echo $LATEST > .deno-version"
  exit 1
fi

echo ".deno-version OK: $PINNED (latest)"
