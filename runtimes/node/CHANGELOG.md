# litevolve-node

## 0.2.0

### Minor Changes

- `migrate_db` and `migrate_with_adapter` now take `apply_version` as an optional trailing argument instead of a required first argument, defaulting to the highest-numbered migration file in `migrations_path` when omitted. The CLI's `--apply_version` flag is likewise now optional. README updated for both the library and CLI usage sections.

  Basis: `litevolve-node@0.1.0..HEAD` touches only `src/core/migrate.ts`, `src/index.ts` and `README.md`, all from commit `9d20e44`. Both exported functions changed parameter order and made `apply_version` optional, which breaks existing call sites — bumped as `minor` per this project's 0.x convention (breaking changes bump minor, non-breaking fixes bump patch; matches the 0.0.5→0.1.0 precedent).

## 0.1.0

### Minor Changes

- Declare a `litevolve` `bin` entry point backed by a new `src/run_litevolve.ts` CLI (parses `--apply_version`, `--db_path`, `--migrations_path`, `--init_seeds` and calls `migrate_db`), so `npx litevolve-node ...` runs migrations without cloning the repo. README updated to document it.

  ​``
Basis: `litevolve-node@0.0.5..HEAD` touches `runtimes/node/package.json` (`bin` field), the new `runtimes/node/src/run_litevolve.ts`, and `runtimes/node/README.md` — all in scope for the bin addition.
​``

  ```

  Reasoning: `litevolve-node@0.0.5` is the latest node tag; the only commit since (`3208d06`) touching `runtimes/node/` adds the `bin` field, the CLI script, and the README section for it — a new public capability, so `minor` (matches semver convention; all prior node changesets were `patch` bug/infra fixes, this is the first feature).
  ```

## 0.0.5

### Patch Changes

- Update the `Makefile`'s `shell` target to a floating `node:slim` image instead of the pinned `node:$(NODE_VERSION)-alpine`, and expand the README with the local-only `check_version` step, the `.deno-version` update-check exception, and the `engines`-is-a-floor policy.

## 0.0.4

### Patch Changes

- Skip files without a `.sql`, `.seed.sql` or `.down.sql` extension when reading the migrations directory, instead of throwing on them. Stray files such as `.DS_Store`, `.gitkeep` or editor swap files no longer abort a migration run; filenames that do end in a SQL extension but break the naming spec still throw as before.

  ```

  Basis: `23bd77a..HEAD` (last release bump) touches only `src/core/migrate.ts` (`EXTENSION_REGEX` pre-filter in `read_migration_files`) plus the `@types/node` 26.1.2→26.2.0 devDependency bump — left out, dev-only, no consumer impact.
  ```

## 0.0.3

### Patch Changes

- Correct the module path reported in `migration_error` from `src/db_migrations/migrate` to `src/core/migrate`, and exclude `node_modules` and `dist` from the TypeScript build.

  ```

  Diff vs `main` is only those two files: 3 error-message strings in `src/core/migrate.ts` and the `exclude` in `tsconfig.json`. Both patch-level, no API change.
  ```

## 0.0.2

### Patch Changes

- Republish with npm provenance attestation from the automated release workflow.

  ```

  Two flaws in `make yield_version` this exposes:

  1. **The guard can never be false.** `claude --print ... > $(NODE_CHANGESET_DIR)/curr_changeset.md` creates the file unconditionally, so `ls $(NODE_CHANGESET_DIR)/*.md | grep -qv README.md` always matches. "no changeset, skipping" is dead code. Fix: `-s` test instead — `if [ -s $(NODE_CHANGESET_DIR)/curr_changeset.md ]; then` — and have this prompt emit nothing when there's no diff.
  2. **My stdout becomes the file verbatim.** Everything above — including this explanation — would land in `curr_changeset.md` if you piped it. The prompt needs to say "output only the changeset markdown, nothing else, empty output if no changes."
  ```

## 0.0.1

### Patch Changes

- Add @changesets/cli for release versioning.
- First release of litevolve-node: a versioned SQLite migration runner
  usable as a library (`migrate_db`) or a CLI binary.
