---
title: Floating the CI runner OS label causes surprise breakage when GitHub changes the default image
author: Ccarcaci
date: 2026-10-28
standing: true
id: l-1e1d72e6
scope: repo
status: active
src: init-sessions
touches:
  - ".github/workflows/ci.yml"
---

## Watch out
- The job uses the latest Ubuntu label, so GitHub's migration to a new OS version silently changed the tooling available and broke an unchanged build.
- In the code: `.github/workflows/ci.yml:61` has `runs-on: ubuntu-latest`. When CI fails with a missing tool and no code changes, compare the runner image name and version in the logs first. Consider pinning to ubuntu-24.04 or declaring all tools explicitly.

_From past Claude sessions here, Oct 23._
