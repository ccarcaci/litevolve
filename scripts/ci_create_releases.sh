#!/bin/sh

# Create a GitHub release for every commit that carries one or more
# "litevolve-{bun,node,deno}@<version>" tags but has no release yet. Multiple
# package tags can land on the same commit (e.g. a bun+node release together)
# - those are folded into a single release, anchored on one of the tags and
# titled with every tag at that commit. Idempotent: an existing release is
# left untouched, so this is safe to run on every tag push and to re-run by
# hand to backfill releases missing from history.
#
# POSIX sh on purpose, no bash-only features (declare -A, mapfile): this runs
# both on macOS's stock bash (3.2, no associative arrays) and inside the
# serversideup/github-cli Docker image (Alpine ash, no bash at all).
#
# Usage: ./scripts/ci_create_releases.sh
# Requires: gh authenticated (GH_TOKEN), full tag history (fetch-depth: 0, fetch-tags: true)

set -eu

TAG_PATTERN='^litevolve-(bun|node|deno)@'

tags="$(git for-each-ref --format='%(refname:short)' refs/tags | grep -E "$TAG_PATTERN" || true)"

if [ -z "$tags" ]; then
  echo "no tags matching $TAG_PATTERN found"
  exit 0
fi

# sha<TAB>tag, one row per matching tag
sha_tag_rows="$(printf '%s\n' "$tags" | while IFS= read -r tag; do
  printf '%s\t%s\n' "$(git rev-list -n1 "$tag")" "$tag"
done)"

# unique commit shas, oldest first - so "previous release" means "the
# previous commit in this list", regardless of which package(s) tagged it
ordered_shas="$(printf '%s\n' "$sha_tag_rows" | cut -f1 | sort -u | while IFS= read -r sha; do
  printf '%s %s\n' "$(git log -1 --format=%ct "$sha")" "$sha"
done | sort -n | cut -d' ' -f2)"

previous_sha=""
for sha in $ordered_shas; do
  tags_for_sha="$(printf '%s\n' "$sha_tag_rows" | awk -F'\t' -v s="$sha" '$1==s{print $2}' | sort -u)"
  anchor_tag="$(printf '%s\n' "$tags_for_sha" | head -n1)"
  all_tags="$(printf '%s\n' "$tags_for_sha" | tr '\n' ' ' | sed 's/ *$//')"

  if gh release view "$anchor_tag" >/dev/null 2>&1; then
    echo "$anchor_tag: release already exists, skipping"
    previous_sha="$sha"
    continue
  fi

  short_sha="$(git rev-parse --short "$sha")"
  commit_date="$(git log -1 --format=%cs "$sha")"
  title="$commit_date $all_tags $short_sha"

  if [ -n "$previous_sha" ]; then
    notes="$(git log --format='- %s' "$previous_sha..$sha")"
  else
    notes="$(git log --format='- %s' "$sha")"
  fi

  echo "creating release: $title"
  gh release create "$anchor_tag" --title "$title" --notes "$notes"

  previous_sha="$sha"
done
