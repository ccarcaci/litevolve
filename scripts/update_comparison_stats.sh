#!/bin/bash

# Fetch GitHub stats (stars, open issues, latest release, latest commit on the
# default branch) for the tools listed in the README's ## comparison table, and
# rewrite that table's stat rows in place. Checkmarks go on: fewest open issues,
# most recent release, most recent commit.
# "Latest release" falls back to the npm registry for tools with no GitHub Release
# object (litevolve, sqlite-auto-migrator both only tag/publish to npm).
# Requires: curl, jq. Set GITHUB_TOKEN to raise the unauthenticated 60 req/hour cap.
# Usage: ./scripts/update_comparison_stats.sh
#
# ponytail: plain indexed arrays, not `declare -A` — macOS ships bash 3.2, which
# has no associative arrays, and this repo runs on macOS by convention.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO_ROOT/README.md"

# same left-to-right order as the README table columns
NAMES=(litevolve sqlite-auto-migrator deno-nessie drizzle-orm)
SLUGS=(ccarcaci/litevolve SanderGi/sqlite-auto-migrator halvardssm/deno-nessie drizzle-team/drizzle-orm)
# comma-separated npm package names, used as the "latest release" fallback when a
# tool has no GitHub Release object; empty entry means no fallback (GitHub only)
NPM_PKGS=("litevolve-bun,litevolve-node,litevolve-deno" "sqlite-auto-migrator" "" "")

# ponytail: no array for the optional auth header — bash 3.2 (macOS default) treats
# an empty array under `set -u` as unbound, so branch on a plain string instead.
#
# Checks the HTTP status explicitly instead of `curl -f`: a rate-limited 403 from
# api.github.com over HTTP/2 makes curl's own error handling misfire as exit 56
# (CURLE_RECV_ERROR) instead of a clean fail-on-error exit, so we read the status
# ourselves and hard-exit with a readable message instead of a bare curl crash.
gh_api() {
  local endpoint="$1" status body_file headers_file body reset reset_human
  body_file=$(mktemp)
  headers_file=$(mktemp)

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    status=$(curl -s -o "$body_file" -D "$headers_file" -w '%{http_code}' \
      -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/$endpoint")
  else
    status=$(curl -s -o "$body_file" -D "$headers_file" -w '%{http_code}' \
      -H "Accept: application/vnd.github+json" "https://api.github.com/$endpoint")
  fi
  body=$(cat "$body_file")

  if [ "$status" = "403" ] && grep -qi "rate limit" "$body_file"; then
    reset=$(grep -i '^x-ratelimit-reset:' "$headers_file" | tail -n1 | tr -d '\r' | awk '{print $2}')
    reset_human=$(date -u -r "$reset" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
      || date -u -d "@$reset" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$reset (unix epoch)")
    rm -f "$body_file" "$headers_file"
    echo "error: GitHub API rate limit exceeded (0 requests remaining)" >&2
    echo "resets at $reset_human" >&2
    echo "fix: export GITHUB_TOKEN=<token> and re-run (raises the cap from 60/hr to 5000/hr)" >&2
    exit 1
  fi

  rm -f "$body_file" "$headers_file"
  [ "${status:0:1}" = "2" ] || return 1
  printf '%s' "$body"
}

# npm_latest_date "pkg1,pkg2,..." -> latest publish date (YYYY-MM-DD) across those
# packages' dist-tags.latest version, or "n/a" if none resolve
npm_latest_date() {
  local best="" pkg json v t
  IFS=',' read -ra pkgs <<<"$1"
  for pkg in "${pkgs[@]}"; do
    json=$(curl -sf "https://registry.npmjs.org/$pkg") || continue
    v=$(jq -r '.["dist-tags"].latest // empty' <<<"$json")
    [ -z "$v" ] && continue
    t=$(jq -r --arg v "$v" '.time[$v] // empty' <<<"$json" | cut -d T -f1)
    [ -z "$t" ] && continue
    if [ -z "$best" ] || [[ "$t" > "$best" ]]; then best="$t"; fi
  done
  echo "${best:-n/a}"
}

STARS=() ISSUES=() RELEASE=() COMMIT=()

for i in "${!NAMES[@]}"; do
  slug="${SLUGS[$i]}"
  repo_json=$(gh_api "repos/$slug")

  STARS[$i]=$(jq -r '.stargazers_count' <<<"$repo_json")
  # ponytail: GitHub's open_issues_count includes PRs; a true issues-only count needs
  # a second, paginated call. Good enough for a README comparison, split out if it matters.
  ISSUES[$i]=$(jq -r '.open_issues_count' <<<"$repo_json")

  default_branch=$(jq -r '.default_branch' <<<"$repo_json")
  COMMIT[$i]=$(gh_api "repos/$slug/commits?sha=$default_branch&per_page=1" \
    | jq -r '.[0].commit.committer.date | split("T")[0]')

  release_json=$(gh_api "repos/$slug/releases/latest" || echo '{}')
  RELEASE[$i]=$(jq -r '.published_at // "n/a"' <<<"$release_json" | cut -d T -f1)
  if [ "${RELEASE[$i]}" = "n/a" ] && [ -n "${NPM_PKGS[$i]}" ]; then
    RELEASE[$i]=$(npm_latest_date "${NPM_PKGS[$i]}")
  fi
done

# lowest issue count / most recent release / most recent commit win a checkmark
# (string comparison is fine: dates are ISO 8601)
best_min() { printf '%s\n' "$@" | sort -n | head -n1; }
# "n/a" (no GitHub release) never wins "most recent" -- exclude it before sorting
best_date() { printf '%s\n' "$@" | grep -v '^n/a$' | sort | tail -n1; }

MIN_ISSUES=$(best_min "${ISSUES[@]}")
MAX_RELEASE=$(best_date "${RELEASE[@]}")
MAX_COMMIT=$(best_date "${COMMIT[@]}")

mark() { # mark <value> <best> -> "value" or "✅ value" if value == best (never for n/a)
  if [ "$1" != "n/a" ] && [ "$1" = "$2" ]; then echo "✅ $1"; else echo "$1"; fi
}

row() { # row <label> <4 cells>
  printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "$5"
}

STARS_ROW=$(row "Stars" "${STARS[0]}" "${STARS[1]}" "${STARS[2]}" "${STARS[3]}")
# litevolve's 1 open issue is Renovate's permanent "Dependency Dashboard" tracking
# issue, not a real one -- treat it as tied for lowest and label it as such
LITEVOLVE_ISSUES_CELL="${ISSUES[0]}"
if [ "${ISSUES[0]}" = "1" ]; then
  LITEVOLVE_ISSUES_CELL="✅ 1 (Renovate dashboard)"
else
  LITEVOLVE_ISSUES_CELL=$(mark "${ISSUES[0]}" "$MIN_ISSUES")
fi

ISSUES_ROW=$(row "Open issues" \
  "$LITEVOLVE_ISSUES_CELL" "$(mark "${ISSUES[1]}" "$MIN_ISSUES")" \
  "$(mark "${ISSUES[2]}" "$MIN_ISSUES")" "$(mark "${ISSUES[3]}" "$MIN_ISSUES")")
RELEASE_ROW=$(row "Latest release" \
  "$(mark "${RELEASE[0]}" "$MAX_RELEASE")" "$(mark "${RELEASE[1]}" "$MAX_RELEASE")" \
  "$(mark "${RELEASE[2]}" "$MAX_RELEASE")" "$(mark "${RELEASE[3]}" "$MAX_RELEASE")")
COMMIT_ROW=$(row "Latest commit" \
  "$(mark "${COMMIT[0]}" "$MAX_COMMIT")" "$(mark "${COMMIT[1]}" "$MAX_COMMIT")" \
  "$(mark "${COMMIT[2]}" "$MAX_COMMIT")" "$(mark "${COMMIT[3]}" "$MAX_COMMIT")")

TODAY=$(date -u +%Y-%m-%d)

# rewrite each "| <label> | ..." row in place by label, and the "last fetched" line;
# every other line passes through unchanged
awk -v stars="$STARS_ROW" -v issues="$ISSUES_ROW" -v release="$RELEASE_ROW" \
    -v commit="$COMMIT_ROW" -v today="$TODAY" '
  /^\| Stars \|/ { print stars; next }
  /^\| Open issues \|/ { print issues; next }
  /^\| Latest release \|/ { print release; next }
  /^\| Latest commit \|/ { print commit; next }
  /^_(GitHub|Comparison) stats last fetched:/ { print "_Comparison stats last fetched: " today "_"; next }
  { print }
' "$README" > "$README.tmp"
mv "$README.tmp" "$README"

echo "README.md comparison table updated ($TODAY)"
