# litevolve-deno

## 0.2.1

### Patch Changes

- - fix(migrate): allow digits in migration filenames and preserve trigger bodies when splitting SQL statements
  - fix(cli): default apply_version to latest and fix migrate_db argument order
  - chore(release): bump bun, node, and deno packages to 0.2.0 with apply_version changelog entries
  - refactor(migrate): make apply_version optional, default to latest available migration
  - chore(release): bump bun, node, and deno packages to 0.1.0 with bin entry point changelogs
  - docs: document CLI bin entry points and add npx/bunx smoke tests
  - ci: drop redundant bun build step from publish and prune deno package files
  - renovate/ Update dependency @types/node to v26.2.0
  - chore(release): version bun, deno, and node packages to 0.0.5
  - chore(deps): pin exact devDependency versions and move deno's @types/node to devDependencies
  - ci(deno): re-enable deno CI job and rename deno.json to package.json
  - chore(ci): switch to lockfile-only installs and let Renovate own version pins
  - chore(release): bump runtime packages to 0.0.4
  - fix(migrate): skip non-migration files when reading migrations directory
  - `chore(release): bump runtime packages to 0.0.3`
  - build(deno): build with `deno compile`, add deno.lock, and use alpine shell image
  - fix(deno): use node:sqlite via node adapter instead of bun:sqlite and drop better-sqlite3 adapter
  - chore: correct core module paths, tsconfig types, and bun packaging; drop stale deno and local CI files
  - docs(readme): rewrite runtime READMEs for per-package npm publishing and current release process
  - chore(release): split publish into tag-driven per-package workflow with deno support

## 0.2.0

### Minor Changes

- `migrate_db` and `migrate_with_adapter` now take `apply_version` as an optional trailing argument instead of a required leading one, defaulting to the highest-numbered "up" migration file in `migrations_path` when omitted (`read_latest_version`, new in `core/migrate.ts`). The CLI's `--apply_version` flag is likewise now optional — omit it to migrate up to the latest available migration. README updated for both the library snippet and the CLI usage section.

  Basis: `litevolve-deno@0.0.1` is stale (deno CI, and therefore its tag/publish step, is disabled — see CLAUDE.md — so it never advanced past 0.0.1 even though `package.json`/`CHANGELOG.md` are already at 0.1.0). Diffing from the literal tag would re-bundle the already-released 0.0.3, 0.0.4, 0.0.5, and 0.1.0 changesets into this one. Used `9756702` instead — the commit `litevolve-bun@0.1.0` and `litevolve-node@0.1.0` both point to, i.e. deno's true last-released state — which isolates exactly one commit in range (`9d20e44`), touching `src/core/migrate.ts`, `src/index.ts`, `src/run_litevolve.ts`, and `README.md`.

  `minor`: reordering `migrate_db`'s parameters (`apply_version` moved from 1st to last) breaks any existing positional call site — a breaking change bumped as `minor` per this project's 0.x convention, consistent with the 0.0.5→0.1.0 precedent.

## 0.1.0

### Minor Changes

- Declare a `litevolve` `bin` entry point (`./dist/run_litevolve.js`, now with a `#!/usr/bin/env node` shebang) and drop `src` from the published `files` list so only `dist` ships. README documents `npx litevolve-deno ...` alongside the `bunx`/`npx` examples for the other two packages; the existing "on hold, do not use" warning for `litevolve-deno` is unchanged.

## 0.0.5

### Patch Changes

- Move `@types/node` out of `dependencies` into `devDependencies`, pinned to an exact version (`26.2.0`) instead of a `^` range. It was published as a runtime dependency, so every consumer of `litevolve-deno` also installed `@types/node` even though nothing in the published `dist`/`src` needs it at runtime.

  Also sync the README: the Bun and Deno version badges now show `>=` floors instead of exact pins, the `scripts/` layout note mentions the local-only `check_bun_version.sh`, and `contributing_guidelines` documents the Renovate `.deno-version` exception and the `engines`-is-a-floor policy.

## 0.0.4

### Patch Changes

- Skip files without a SQL extension when reading the migrations directory. Previously every entry in `migrations_path` was validated against the filename spec and anything else threw a `migration_error`, so a stray `README.md` or `.DS_Store` aborted `migrate_db`. Entries are now filtered by extension first; filenames that do end in `.sql` but break the naming spec still throw as before.

  ```

  Basis: `origin/main == HEAD == e731ced`, so there is no branch diff. `23bd77a..HEAD` (the 0.0.3 release bump) touches exactly one deno file — `src/core/migrate.ts` — which is `e731ced`. Nothing else to describe.

  Three things worth pushing back on, none of them about the changeset:

  - `EXTENSION_REGEX = /(sql|seed\.sql|down\.sql)$/` is unanchored on the dot, so `mysql` or `notasql` still passes the filter and throws — the reported bug is half fixed. The alternation is also dead: all three branches end in `sql`, so it collapses to `/\.sql$/`. Same defect I flagged on the bun changeset; it's identical code in all three runtimes.
  - The deno runtime has **zero tests** (`src/migrate.test.ts` was deleted in 0.0.3 with no `Deno.test` replacement), so this fix ships unverified here even though bun/node could cover it.
  - `runtimes/deno/CHANGELOG.md` 0.0.3 has a raw conversational blob pasted into it — "Three flaws worth pushing back on… Want me to write the file?" — inside a stray fenced block. That's published to npm as the release notes. Worth fixing before the next release.

  Say the word and I'll write the file and/or clean the CHANGELOG.
  ```

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
