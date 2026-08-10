#!/bin/bash

# Update checks for the bun runtime.
#
# Nothing left to check: every pin this script used to poll is covered by Renovate.
#   .bun-version           -> bun-version manager
#   runtimes/bun/*.json    -> npm manager
#   scripts/Dockerfile     -> dockerfile manager
# Usage: ./scripts/ci_check_updates_bun.sh

set -euo pipefail

echo "runtimes/bun: no update checks beyond Renovate"
