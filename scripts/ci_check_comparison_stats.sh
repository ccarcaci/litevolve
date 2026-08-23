#!/bin/bash

# Check that the README's ## comparison table stats aren't stale, without hitting
# any network. A hard byte-for-byte re-fetch-and-diff (like ci_check_align.sh does
# for the core copies) isn't the right model here: star/issue counts on other
# people's repos drift constantly, so that would fail on almost every CI run for
# reasons nobody on this repo caused. Instead this just checks the age of the
# "_Comparison stats last fetched: <date>_" line against MAX_AGE_DAYS.
# Usage: ./scripts/ci_check_comparison_stats.sh
#        MAX_AGE_DAYS=7 ./scripts/ci_check_comparison_stats.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO_ROOT/README.md"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-30}"

FETCHED_DATE=$(grep -o '_Comparison stats last fetched: [0-9-]*_' "$README" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' || true)

if [ -z "$FETCHED_DATE" ]; then
  echo "error: no '_Comparison stats last fetched: <date>_' line found in README.md"
  echo "fix: run ./scripts/update_comparison_stats.sh (or 'make update_comparison')"
  exit 1
fi

# GNU date (Linux CI) vs BSD date (macOS dev) parse ISO dates differently
FETCHED_EPOCH=$(date -u -d "$FETCHED_DATE" +%s 2>/dev/null \
  || date -j -u -f "%Y-%m-%d" "$FETCHED_DATE" +%s 2>/dev/null || true)

if [ -z "$FETCHED_EPOCH" ]; then
  echo "error: could not parse fetched date '$FETCHED_DATE' from README.md"
  exit 1
fi

NOW_EPOCH=$(date -u +%s)
AGE_DAYS=$(( (NOW_EPOCH - FETCHED_EPOCH) / 86400 ))

if [ "$AGE_DAYS" -lt 0 ]; then
  echo "error: comparison stats fetched date ($FETCHED_DATE) is in the future"
  exit 1
fi

if [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]; then
  echo "error: comparison stats are $AGE_DAYS days old (fetched $FETCHED_DATE), max is $MAX_AGE_DAYS"
  echo "fix: run ./scripts/update_comparison_stats.sh (or 'make update_comparison')"
  exit 1
fi

echo "comparison stats OK: fetched $FETCHED_DATE ($AGE_DAYS/$MAX_AGE_DAYS days old)"
