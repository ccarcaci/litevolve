# litevolve-deno

## 0.0.3

### Patch Changes

- Make the package actually run on Deno. `migrate_db` now opens the database with `node:sqlite`'s `DatabaseSync` through the shared `node_db_adapter` instead of importing `bun:sqlite`, and the `better-sqlite3`-backed `deno_db_adapter` is deleted along with the dependency. `engines` now declares `deno >=2.9` instead of `bun 1.3.14`, and `tsconfig` types switch from `bun` to `node`.

  Also remove the stale root `index.ts` (dead copy of `migrate_db` that referenced an unimported `migrate_with_adapter`), and correct the module path reported in `migration_error` from `src/db_migrations/migrate` to `src/core/migrate`.

  ```

  Left out as non-consumer-facing: `deno.lock` replacing `bun.lock`/`package-lock.json`, `biome.json` removal, the `Makefile` shell target moving to `alpine:edge`, and the added `@types/node`/`typescript`/`@changesets/cli` dev tooling.

  Three flaws worth pushing back on:

  - **`patch` vs `minor`:** `migrate_db`'s return type changed from `bun:sqlite`'s `Database` to `DatabaseSync` — normally minor. I chose `patch` because 0.0.2 imported `bun:sqlite` and declared `engines.bun`, so no Deno consumer could ever have depended on the old type. If `litevolve-deno@0.0.2` is actually installed anywhere, bump this to `minor`.
  - **The Deno runtime now has zero tests.** `src/migrate.test.ts` (419 lines) was deleted with no `Deno.test` replacement. The bun and node runtimes keep theirs. This changeset ships an untested backend swap.
  - **`scripts/ci_build.sh` looks broken for deno:** the command became `deno compile ... --bundle --target node --external better-sqlite3 --outdir`, but those are `bun build` flags and `deno compile` emits a standalone executable, not `dist/index.js` — which is what `package.json` `exports` points at. I could not fetch the Deno CLI docs to confirm (WebFetch permission denied), so treat this as unverified — but check it before releasing, since a broken build means an empty/absent `dist`. `deno bundle` is likely what you want.

  Want me to write the file?
  ```

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
