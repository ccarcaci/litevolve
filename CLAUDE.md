**litevolve** is a versioned SQLite migration runner, published as two packages
(`litevolve-bun`, `litevolve-node`) sharing one core. Deno consumers use `litevolve-node`
through `npm:` specifiers — there is no separate Deno package (it was removed).

## The one rule that matters

`runtimes/bun/src/core/` is the **master copy**. `runtimes/node/src/core/` is a
byte-identical copy of it.

Never edit the node copy. Edit bun's, then run `make align_artifacts`.
`scripts/ci_check_align.sh` fails CI on any divergence (it also enforces that `LICENSE` and
`README.md` are copied into both packages).

## Layout

| Path                                | Role                                                                        |
| ----------------------------------- | --------------------------------------------------------------------------- |
| `runtimes/bun/src/core/migrate.ts`  | All migration logic. Exports `migrate_with_adapter`. DB-agnostic.           |
| `runtimes/bun/src/core/db_adapter.ts` | `db_adapter` / `query_result` types — the seam the core talks through      |
| `runtimes/bun/src/core/migration_error.ts` | `migration_error extends Error`                                      |
| `runtimes/*/src/index.ts`           | Per-runtime `migrate_db` — opens the DB, sets pragmas, calls the core       |
| `runtimes/node/src/node_adapter.ts` | `node_db_adapter` wrapping `node:sqlite` to fit `db_adapter`                |
| `runtimes/{bun,node}/src/run_litevolve.ts` | CLI entry point — both packages declare a `litevolve` bin             |
| `runtimes/bun/src/migrate.test.ts`  | **The entire test suite.** Bun-only; node has no tests.                     |
| `migrations/working/`               | Runnable ornithology example, 3 versions with up/down/seed                  |
| `migrations/broken/`                | Intentionally-invalid migration (constraint-failure path)                   |
| `migrations/invalid_filename/`      | Filenames the discovery regex must reject                                   |
| `scripts/`                          | All CI shell scripts + the multi-arch binary `Dockerfile`                   |

## SQLite per runtime

- bun: `bun:sqlite` `Database` — already satisfies `db_adapter`, passed to the core directly.
- node: `node:sqlite` `DatabaseSync`, wrapped in `node_db_adapter`.
- Never `better-sqlite3`.

Core code uses `node:fs` (`existsSync`, `readdirSync`, `readFileSync`) — **not** `Bun.file` —
because the same file has to run on both runtimes.

## Conventions

- `snake_case` everywhere: types, functions, variables, class names, files. No camelCase.
- Throw `migration_error`: `new migration_error(module_path, method, cause_message, original_error?)`.
- Mark deliberate shortcuts with a `ponytail:` comment.

## Migration internals

- Schema version lives in SQLite's `PRAGMA user_version`.
- Seed preference lives in `_db_meta` (key `init_seeds`); sticky, only settable while at v0.
- Each step runs in `BEGIN IMMEDIATE` — a failed seed rolls back its schema change.
- Statements split on `;` *before* comment stripping — never put `;` inside a SQL comment.

Filename format: `0*[1-9][0-9]*_([a-zA-Z0-9_]+)\.(sql|seed\.sql|down\.sql)`
e.g. `0001_create_initial_schema.sql`, `0042_add_users.down.sql`, `01000_split_log.seed.sql`.
Leading-zero padding optional; version 0 is invalid.

## Commands

| Target                                       | Purpose                                        |
| -------------------------------------------- | ---------------------------------------------- |
| `make ci_checks`                             | Everything CI runs, plus `check_version`       |
| `make test [name]`                           | Bun tests, optionally filtered by name         |
| `make test_debug [name]`                     | Same, with `--inspect-wait`                    |
| `make ci_test`                               | Tests as CI runs them (isolated, parallel)     |
| `make check_version`                         | Installed bun vs `.bun-version` — local only   |
| `make ci_check_align`                        | Verify the core copies match                   |
| `make ci_check_updates`                      | Version pins Renovate does not cover           |
| `make ci_check_lint` / `make format`         | Biome check / auto-fix                         |
| `make ci_check_build`                        | Bundle check + `tsc --noEmit`                  |
| `make ci_sec`                                | `bun audit`                                    |
| `make align_artifacts`                       | Copy bun core → node, and LICENSE/README        |
| `make migrate DB_PATH=<p> VERSION=<n>`       | Apply migrations up/down                       |
| `make migrate_seeds DB_PATH=<p> VERSION=<n>` | Fresh DB with seeds                            |
| `make ci_binary TARGET=bun-darwin-arm64`     | Compile a standalone binary                    |

`ci_build.sh`, `ci_types.sh`, `ci_sec.sh` and `ci_test.sh` take a runtime argument (`bun`,
`node`) and the root Makefile only wires up the bun ones.

Tooling: Bun for dev, install, test, and binary compilation. Biome for lint/format, config at
`runtimes/bun/biome.json`. The node package is bundled with **esbuild** (`scripts/ci_build.sh`),
not `bun build`.

## Dependency pins

Renovate owns almost everything: `.bun-version` (`bun-version` manager), `.node-version`
(`nodenv`), every `package.json` (`npm`), `scripts/Dockerfile` (`dockerfile`), and both
workflows (`github-actions`, SHA-pinned). Do not add a script that re-checks any of those —
that duplication was removed on purpose.

`.deno-version` is a leftover: it recorded the Deno release used to sanity-check the runtime
under Deno, checked by `scripts/ci_check_updates_deno.sh` / `make ci_check_updates`. All of
that was removed with the Deno package. Nothing reads or checks the file now — bump it by
hand or delete it.

### `engines` are floors, on purpose

`engines` in the two published runtimes is the **minimum runtime a consumer needs**, not the
toolchain this repo builds with. It is deliberately *not* tied to `.bun-version` /
`.node-version`, which track latest. Bumping a floor drops support for released consumers, so
it happens by hand, only when a breaking change actually raises the minimum — never
automatically.

Do not add a check or a Renovate rule that syncs `engines` to a version file. Renovate could
not do it anyway: its npm manager extracts only `node`, `yarn`, `npm`, `pnpm` and `vscode` from
`engines` and marks anything else `unknown-engines`, so `engines.bun` is invisible to it, and
Renovate has no way to express "field A equals file B" (`postUpgradeTasks` could, but it is
self-hosted-only).

### Still checked by nothing

Verify by hand when bumping a runtime: the `IMAGE ?=` pins in the two example Makefiles
(`examples/{bun,node}/Makefile`), the `$schema` URLs in `biome.json` and
`.changeset/config.json`, the README version badges, and the unpinned global
`npm install --global esbuild` in both workflows.
