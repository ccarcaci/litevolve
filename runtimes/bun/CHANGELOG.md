# litevolve-bun

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
