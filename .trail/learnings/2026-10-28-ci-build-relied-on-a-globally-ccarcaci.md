---
title: CI build relied on a globally installed TypeScript that newer runner images no longer ship
author: Ccarcaci
date: 2026-10-28
standing: true
id: l-f6dde124
scope: repo
status: active
src: init-sessions
touches:
  - scripts/ci_build.sh
  - runtimes/node/tsconfig.json
---

## Watch out
- The CI runner label moved from Ubuntu 24.04 to 26.04, and the build step failed with command not found because the new image has no global TypeScript. The old image hid the missing dependency.
- In the code: scripts/ci_build.sh:21 calls bare `tsc --project runtimes/node/tsconfig.json`. Use the project-local binary (runtimes/node/node_modules/.bin/tsc, or via bunx/npx) or install typescript explicitly in the workflow instead of relying on the runner image.

_From past Claude sessions here, Oct 23._
