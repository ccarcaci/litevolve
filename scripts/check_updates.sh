#!/bin/bash

# Check for dependency updates and new Bun version
# Usage: ./scripts/check_updates.sh [--changelog]
#
# --changelog  Show changelog links and release notes for outdated packages

set -e

SHOW_CHANGELOG=false
if [ "$1" = "--changelog" ]; then
  SHOW_CHANGELOG=true
fi

BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
RESET="\033[0m"

# --- Bun version check ---
echo -e "${BOLD}Checking Bun version...${RESET}"
CURRENT_BUN=$(bun --version 2>/dev/null || echo "not installed")
LATEST_BUN=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^bun-v//')

if [ -z "$LATEST_BUN" ]; then
  echo "  Could not fetch latest Bun version from GitHub"
elif [ "$CURRENT_BUN" = "$LATEST_BUN" ]; then
  echo -e "  Bun: ${GREEN}${CURRENT_BUN} (up to date)${RESET}"
else
  echo -e "  Bun: ${YELLOW}${CURRENT_BUN} -> ${LATEST_BUN} (update available)${RESET}"
  echo "  Update: bun upgrade --version ${LATEST_BUN}"
  echo "  Then:   echo ${LATEST_BUN} > .bun-version"
  if [ "$SHOW_CHANGELOG" = true ]; then
    echo ""
    echo -e "  ${CYAN}Release notes:${RESET}"
    RELEASE_BODY=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep -o '"body": ".*"' | head -1 | cut -d'"' -f4 | head -c 500)
    if [ -n "$RELEASE_BODY" ]; then
      echo "$RELEASE_BODY" | sed 's/\\r\\n/\n/g' | sed 's/\\n/\n/g' | head -20 | sed 's/^/    /'
      echo "    ..."
    fi
    echo -e "  ${CYAN}Full changelog: https://github.com/oven-sh/bun/releases/latest${RESET}"
  fi
fi

echo ""

# --- Dockerfile base image check ---
echo -e "${BOLD}Checking Dockerfile base image...${RESET}"
DOCKERFILE="local_infra/Dockerfile"
if [ -f "$DOCKERFILE" ]; then
  PINNED_TAG=$(grep -oE 'oven/bun:[^[:space:]]+' "$DOCKERFILE" | head -1 | cut -d: -f2 || true)
  PINNED_MINOR=$(echo "$PINNED_TAG" | grep -oE '^[0-9]+\.[0-9]+' || true)
  if [ -z "$PINNED_MINOR" ]; then
    echo "  Could not parse version from Dockerfile base image: ${PINNED_TAG:-unknown}"
  elif [ -z "$LATEST_BUN" ]; then
    echo "  Could not check (Bun latest version unavailable)"
  else
    LATEST_MINOR=$(echo "$LATEST_BUN" | grep -oE '^[0-9]+\.[0-9]+' || true)
    if [ "$PINNED_MINOR" = "$LATEST_MINOR" ]; then
      echo -e "  oven/bun Dockerfile: ${GREEN}${PINNED_TAG} (major.minor up to date, latest is ${LATEST_BUN})${RESET}"
    else
      echo -e "  oven/bun Dockerfile: ${YELLOW}${PINNED_TAG} -> ${LATEST_MINOR:-unknown}-debian (latest Bun: ${LATEST_BUN})${RESET}"
      echo "  Update Dockerfile:  FROM oven/bun:${LATEST_MINOR}-debian"
    fi
  fi
else
  echo "  Dockerfile not found at ${DOCKERFILE} (skipping)"
fi

echo ""

# --- Dependency updates check ---
echo -e "${BOLD}Checking dependency updates...${RESET}"

OUTDATED_OUTPUT=$(bun outdated 2>&1) || true

if echo "$OUTDATED_OUTPUT" | grep -q "All dependencies are up to date"; then
  echo -e "  ${GREEN}All dependencies are up to date${RESET}"
  exit 0
fi

if [ -z "$OUTDATED_OUTPUT" ]; then
  echo -e "  ${GREEN}All dependencies are up to date${RESET}"
  exit 0
fi

echo "$OUTDATED_OUTPUT"

if [ "$SHOW_CHANGELOG" = false ]; then
  echo ""
  echo "Run 'make updates-changelog' to see changelogs for outdated packages"
  exit 0
fi

# --- Fetch changelogs for outdated packages ---
echo ""
echo -e "${BOLD}Fetching changelogs...${RESET}"

# Parse outdated packages from bun outdated table output
# Lines look like: | @anthropic-ai/sdk    | 0.39.0  | 0.39.0  | 0.78.0 |
# or:              | @biomejs/biome (dev) | 1.9.4   | 1.9.4   | 2.4.4  |
PACKAGES=$(echo "$OUTDATED_OUTPUT" | grep -E '^\| [@a-z]' | awk -F'|' '{gsub(/^ +| +$| \(dev\)/, "", $2); print $2}' || true)

if [ -z "$PACKAGES" ]; then
  exit 0
fi

# Map package names to GitHub repos
get_github_repo() {
  local pkg="$1"
  case "$pkg" in
    "@anthropic-ai/sdk") echo "anthropics/anthropic-sdk-typescript" ;;
    "grammy")            echo "grammyjs/grammY" ;;
    "hono")              echo "honojs/hono" ;;
    "openai")            echo "openai/openai-node" ;;
    "@biomejs/biome")    echo "biomejs/biome" ;;
    "@types/bun")        echo "oven-sh/bun" ;;
    "jest")              echo "jestjs/jest" ;;
    "@jest/globals")     echo "jestjs/jest" ;;
    "ts-jest")           echo "kulshekhar/ts-jest" ;;
    "typescript")        echo "microsoft/TypeScript" ;;
    *)                   echo "" ;;
  esac
}

for pkg in $PACKAGES; do
  repo=$(get_github_repo "$pkg")
  if [ -z "$repo" ]; then
    echo -e "\n  ${CYAN}${pkg}${RESET}: changelog URL unknown"
    continue
  fi

  echo -e "\n  ${CYAN}${pkg}${RESET} — https://github.com/${repo}/releases"

  RELEASE_BODY=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep -o '"body": ".*"' | head -1 | cut -d'"' -f4 | head -c 800)
  if [ -n "$RELEASE_BODY" ]; then
    echo "$RELEASE_BODY" | sed 's/\\r\\n/\n/g' | sed 's/\\n/\n/g' | head -15 | sed 's/^/    /'
    echo "    ..."
  fi
done

echo ""
