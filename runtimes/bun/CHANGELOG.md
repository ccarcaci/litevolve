# litevolve-bun

## 0.2.0

### Minor Changes

- `migrate_db` and `migrate_with_adapter` now take `apply_version` as an optional trailing argument instead of a required leading one, defaulting to the highest-numbered "up" migration file in `migrations_path` when omitted (`read_latest_version`, new in `core/migrate.ts`). The CLI's `--apply_version` flag is likewise now optional — omit it to migrate up to the latest available migration. README updated for both the library snippet and the CLI usage section.

  Basis: `litevolve-bun@0.1.0..HEAD` touches only `runtimes/bun/src/core/migrate.ts`, `runtimes/bun/src/index.ts`, `runtimes/bun/src/run_litevolve.ts`, `runtimes/bun/README.md`, and the test file, all from the single commit in range (`9d20e44`).

  `minor`: reordering `migrate_db`'s parameters (`apply_version` moved from 1st to 4th) breaks any existing positional call site — a breaking change bumped as `minor` per this project's 0.x convention, consistent with the 0.0.5→0.1.0 precedent.

## 0.1.0

### Minor Changes

- Declare a `litevolve` `bin` entry point (`./src/run_litevolve.ts`, now with a `#!/usr/bin/env bun` shebang), so `bunx litevolve-bun ...` runs migrations without cloning the repo. README updated: drops the "no package declares a `bin`" caveat and documents `bunx`/`npx` usage alongside the existing clone/compiled-binary paths.

  ​```Basis:`litevolve-bun@0.0.5..HEAD`touches only`runtimes/bun/package.json` (`bin`field),`runtimes/bun/src/run_litevolve.ts`(shebang), and`runtimes/bun/README.md` (docs) — all in scope for the bin addition, matching the single commit in range (`3208d06`).

  `minor`, not `patch`: this is a new public capability (a runnable CLI entry point), not a bug fix — consistent with the `litevolve-node` changeset for the same commit.
  ​```

## 0.0.5

### Patch Changes

- Loosen the published `engines.bun` floor from an exact pin (`1.3.14`) to `>=1.3`, so consumers on any 1.3.x (or later) Bun aren't blocked by a version they don't have. Also pin the `@types/bun` devDependency to an exact version instead of `^1.3.14`, and update the README's Bun/Deno badges and docs to match: badges now show `>=` floors instead of exact pins, the `scripts/` layout note mentions the local-only `check_bun_version.sh`, and `contributing_guidelines` documents `make check_version`, the `.deno-version` Renovate exception, and the `engines`-is-a-floor policy.

## 0.0.4

### Patch Changes

- Skip non-migration files when reading the migrations directory. Previously any file in `migrations_path` that didn't match the filename spec threw a `migration_error`, so a stray `README.md` or `.DS_Store` broke `migrate_db`. Entries are now filtered by extension first, and only files that look like migrations are validated against the filename spec.

  ```

  Scope note: `origin/main == HEAD == e731ced`, so there is no branch diff. The only unreleased bun change since the 0.0.3 bump (`23bd77a`) is `e731ced`, which is what the changeset covers.

  Two flaws in the change itself, not in the changeset:

  - `EXTENSION_REGEX = /(sql|seed\.sql|down\.sql)$/` isn't anchored on the dot, so `notasql` or `mysql` still passes the filter and then throws on `FILENAME_REGEX` — the reported bug is only half fixed. `/\.(sql)$/` covers all three cases.
  - The alternation is dead weight regardless: `seed.sql` and `down.sql` both end in `sql`, so the whole regex collapses to `/sql$/`. And `.filter((f) => { const match = f.match(...); return match !== null })` is `.filter((f) => EXTENSION_REGEX.test(f))`.

  Also: `migrations/working/this_file_is_not_a_migration` was added as the fixture but no test asserts on it — the regression isn't actually covered.
  ```

## 0.0.3

### Patch Changes

- Ship the package straight from TypeScript source: `exports` and `types` now point at `src/index.ts`, `dist` is dropped from `files`, and tests are excluded from the published tarball. Also remove the stale root `index.ts` (dead `node:sqlite` copy of `migrate_db`), correct the module path reported in `migration_error` from `src/db_migrations/migrate` to `src/core/migrate`, and add `node` to `tsconfig` types.

  ```

  Left out of the note: `bun.lock` churn and the `@types/bun` pin → `^1.3.14` (devDep, not consumer-facing).

  One flaw worth flagging: dropping `dist` from `exports` means anything other than Bun resolving `litevolve-bun` now gets raw TS. That's fine if Bun-only is the contract, but it's a consumer-visible packaging change — arguably `minor`, not `patch`, if anyone was relying on the `default` → `./dist/index.js` condition at 0.0.2.
  ```

## 0.0.2

### Patch Changes

- Republish with npm provenance attestation from the automated release workflow.

  ```

  Note `publishConfig.provenance: true` is already committed in `runtimes/bun/package.json`, so provenance is a property of *how* `publish.yml` runs, not of the package contents — it's still not a code change.

  Same two `make yield_version` flaws the node run surfaced still apply: the `ls | grep -qv README.md` guard can never be false because the redirect creates the file unconditionally (use `[ -s ... ]`), and this explanation would land verbatim in the file if piped (prompt must demand changeset markdown only, empty on no-diff).
  ```

## 0.0.1

### Patch Changes

- Add @changesets/cli for release versioning.
- First release of litevolve-bun: a versioned SQLite migration runner
  usable as a library (`migrate_db`) or a CLI binary.
