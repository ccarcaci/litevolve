#!/bin/bash

# Update checks for the node runtime.
#
# Nothing left to check: every pin this script used to poll is covered by Renovate.
#   .node-version          -> nodenv manager
#   runtimes/node/*.json   -> npm manager
# Usage: ./scripts/ci_check_updates_node.sh

set -euo pipefail

echo "runtimes/node: no update checks beyond Renovate"
