#!/bin/bash

# Check Node version matches .node-version and is the latest available 22.x LTS
# Usage: ./scripts/check_node_version.sh

set -e

PINNED=$(cat .node-version | tr -d '[:space:]')
CURRENT=$(node --version 2>/dev/null | sed 's/^v//' || echo "not installed")

if [ "$CURRENT" = "not installed" ]; then
  echo "ERROR: Node is not installed. Required version: $PINNED"
  exit 1
fi

if [ "$CURRENT" != "$PINNED" ]; then
  echo "ERROR: Node version mismatch"
  echo "  Required: $PINNED"
  echo "  Current:  $CURRENT"
  echo "To update .node-version: echo $CURRENT > .node-version"
  exit 1
fi

echo "Node version installed: $CURRENT"

LATEST=$(curl -sf https://nodejs.org/dist/index.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
jod = [x for x in data if isinstance(x.get('lts'), str) and x['lts'] == 'Jod']
print(jod[0]['version'].lstrip('v') if jod else '')
" 2>/dev/null || true)

if [ -z "$LATEST" ]; then
  echo "WARNING: Could not fetch latest Node 22 LTS version from nodejs.org"
  exit 0
fi

if [ "$PINNED" != "$LATEST" ]; then
  echo "ERROR: Node $PINNED is pinned but $LATEST is the latest Node 22 LTS"
  echo "Update .node-version: echo $LATEST > .node-version"
  exit 1
fi

echo "Node version OK: $CURRENT (latest 22 LTS)"
