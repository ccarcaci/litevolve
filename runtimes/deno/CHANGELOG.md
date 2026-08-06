# litevolve-node

## 0.0.2

### Patch Changes

- Fix package identity: the manifest declared `litevolve-bun` with Bun-specific
  `exports` conditions and Bun devDependencies. Now publishes as `litevolve-deno`
  with the `dist/` entry point, correct repository directory, and npm provenance.

  ```

  Basis — committed diff `origin/main...HEAD` and `litevolve-deno@0.0.1..HEAD` for `runtimes/deno` are both **empty**. The only change is the staged `package.json`, so that's what the changeset describes.

  Two things this doesn't cover:

  - `runtimes/deno/CHANGELOG.md` starts with `# litevolve-node` — same copy-paste lineage as the wrong `name`. Changesets appends under the existing header and won't correct it; fix it by hand or the 0.0.2 entry lands under a heading naming a different package.
  - Tag `litevolve-deno@0.0.1` exists while the manifest at that tag said `litevolve-bun`. If `0.0.1` was actually published to npm as `litevolve-deno`, a `patch` → `0.0.2` is right. If it never published (name collided with the real bun package), you want `0.0.1` and this changeset bumps you past it — check `npm view litevolve-deno versions` first.
  ```

## 0.0.1

### Patch Changes

- Add @changesets/cli for release versioning.
- First release of litevolve-node: a versioned SQLite migration runner
  usable as a library (`migrate_db`) or a CLI binary.
