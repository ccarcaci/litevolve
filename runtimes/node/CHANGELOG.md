# litevolve-node

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
