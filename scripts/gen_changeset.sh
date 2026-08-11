#!/bin/bash

# Print changeset file content for <runtime>: a "patch" bump whose body is the
# commit messages touching runtimes/<runtime> since the latest <pkg>@<version> tag
# (all commits if the package has no tag yet, i.e. first release).
# Usage: ./scripts/gen_changeset.sh <bun|node|deno>

set -e

RUNTIME="$1"
PKG_NAME=$(node -p "require('./runtimes/$RUNTIME/package.json').name")

LATEST_TAG=$(git tag --list "$PKG_NAME@*" --sort=-v:refname | head -n1)
RANGE="HEAD"
[ -n "$LATEST_TAG" ] && RANGE="$LATEST_TAG..HEAD"

echo "---"
echo "\"$PKG_NAME\": patch"
echo "---"
echo
git log "$RANGE" --pretty=format:"- %s" -- "runtimes/$RUNTIME"
echo
