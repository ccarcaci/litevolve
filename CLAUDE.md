**litevolve** is a versioned SQLite migration runner, published as three packages
(`litevolve-bun`, `litevolve-node`, `litevolve-deno`) sharing one core.

## The one rule that matters

`runtimes/bun/src/core/` is the **master copy**. `runtimes/node/src/core/` and
`runtimes/deno/src/core/` are byte-identical copies of it.

Never edit the node or deno copies. Edit bun's, then run `make align_artifacts`.
`scripts/ci_check_align.sh` fails CI on any divergence (it also enforces that `LICENSE` and
`README.md` are copied into all three packages).

## Layout

| Path                                | Role                                                                        |
| ----------------------------------- | --------------------------------------------------------------------------- |
| `runtimes/bun/src/core/migrate.ts`  | All migration logic. Exports `migrate_with_adapter`. DB-agnostic.           |
| `runtimes/bun/src/core/db_adapter.ts` | `db_adapter` / `query_result` types — the seam the core talks through      |
| `runtimes/bun/src/core/migration_error.ts` | `migration_error extends Error`                                      |
| `runtimes/*/src/index.ts`           | Per-runtime `migrate_db` — opens the DB, sets pragmas, calls the core       |
| `runtimes/{node,deno}/src/node_adapter.ts` | `node_db_adapter` wrapping `node:sqlite` to fit `db_adapter`         |
| `runtimes/{bun,deno}/src/run_litevolve.ts` | CLI entry point (node ships as a library only)                       |
| `runtimes/bun/src/migrate.test.ts`  | **The entire test suite.** Bun-only; node/deno have no tests.               |
| `migrations/working/`               | Runnable ornithology example, 3 versions with up/down/seed                  |
| `migrations/broken/`                | Intentionally-invalid migration (constraint-failure path)                   |
| `migrations/invalid_filename/`      | Filenames the discovery regex must reject                                   |
| `scripts/`                          | All CI shell scripts + the multi-arch binary `Dockerfile`                   |

## SQLite per runtime

- bun: `bun:sqlite` `Database` — already satisfies `db_adapter`, passed to the core directly.
- node and deno: `node:sqlite` `DatabaseSync`, wrapped in `node_db_adapter`.
- Never `better-sqlite3`.

Core code uses `node:fs` (`existsSync`, `readdirSync`, `readFileSync`) — **not** `Bun.file` —
because the same file has to run on all three runtimes.

## Conventions

- `snake_case` everywhere: types, functions, variables, class names, files. No camelCase.
- Throw `migration_error`: `new migration_error(module_path, method, cause_message, original_error?)`.
- Mark deliberate shortcuts with a `ponytail:` comment.

## Migration internals

- Schema version lives in SQLite's `PRAGMA user_version`.
- Seed preference lives in `_db_meta` (key `init_seeds`); sticky, only settable while at v0.
- Each step runs in `BEGIN IMMEDIATE` — a failed seed rolls back its schema change.
- Statements split on `;` *before* comment stripping — never put `;` inside a SQL comment.

Filename format: `0*[1-9][0-9]*_([a-zA-Z_]+)\.(sql|seed\.sql|down\.sql)`
e.g. `0001_create_initial_schema.sql`, `0042_add_users.down.sql`, `01000_split_log.seed.sql`.
Leading-zero padding optional; version 0 is invalid.

## Commands

| Target                                       | Purpose                                        |
| -------------------------------------------- | ---------------------------------------------- |
| `make ci_checks`                             | Everything CI runs, in order                   |
| `make test [name]`                           | Bun tests, optionally filtered by name         |
| `make test_debug [name]`                     | Same, with `--inspect-wait`                    |
| `make ci_test`                               | Tests as CI runs them (isolated, parallel)     |
| `make ci_check_align`                        | Verify the core copies match                   |
| `make ci_check_lint` / `make format`         | Biome check / auto-fix                         |
| `make ci_check_build`                        | Bundle check + `tsc --noEmit`                  |
| `make ci_sec`                                | `bun audit`                                    |
| `make align_artifacts`                       | Copy bun core → node + deno, and LICENSE/README |
| `make migrate DB_PATH=<p> VERSION=<n>`       | Apply migrations up/down                       |
| `make migrate_seeds DB_PATH=<p> VERSION=<n>` | Fresh DB with seeds                            |
| `make ci_binary TARGET=bun-darwin-arm64`     | Compile a standalone binary                    |

The `scripts/ci_*.sh` scripts take a runtime argument (`bun`, `node`, `deno`); the root
Makefile only wires up the bun ones. Deno CI is currently disabled (`if: false` in
`.github/workflows/ci.yml`), so deno changes are unverified by CI.

Tooling: Bun for dev, install, test, and binary compilation. Biome for lint/format, config at
`runtimes/bun/biome.json`. The node package is bundled with **esbuild** (`scripts/ci_build.sh`),
not `bun build`.

## Dependency pins

`DEPENDENCY_PINS.md` inventories every hardcoded third-party version and which ones Renovate
does not cover. Consult it before bumping a runtime version — several pins are duplicated
across `.bun-version`, `engines`, Dockerfiles, example Makefiles, and README badges.
