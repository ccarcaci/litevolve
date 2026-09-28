**litevolve** is a versioned SQLite migration runner, published as two packages
(`litevolve-bun`, `litevolve-node`) sharing one core. Deno consumers use `litevolve-node`
through `npm:` specifiers — there is no separate Deno package (it was removed).

## The one rule that matters

`runtimes/bun/src/core/` is the **master copy**. `runtimes/node/src/core/` is a
byte-identical copy of it.

Never edit the node copy. Edit bun's, then run `make align_artifacts`.
`scripts/ci_check_align.sh` fails CI on any divergence (it also enforces that `LICENSE` and
`README.md` are copied into both packages).

The CLI entry point is **not** covered: `runtimes/{bun,node}/src/run_litevolve.ts` are kept
identical by hand, differing only in the shebang line. Nothing checks them — edit bun's,
then copy it over (`{ echo '#!/usr/bin/env node'; tail -n +2 runtimes/bun/src/run_litevolve.ts; } > runtimes/node/src/run_litevolve.ts`).

## Layout

| Path                                       | Role                                                                  |
| ------------------------------------------ | --------------------------------------------------------------------- |
| `runtimes/bun/src/core/migrate.ts`         | All migration logic. Exports `migrate_with_adapter`. DB-agnostic.     |
| `runtimes/bun/src/core/db_adapter.ts`      | `db_adapter` / `query_result` types — the seam the core talks through |
| `runtimes/bun/src/core/migration_error.ts` | `migration_error extends Error`                                       |
| `runtimes/bun/src/core/index.ts`           | Barrel re-exporting the core                                          |
| `runtimes/*/src/index.ts`                  | Per-runtime `migrate_db` — opens the DB, sets pragmas, calls the core |
| `runtimes/node/src/node_adapter.ts`        | `node_db_adapter` wrapping `node:sqlite` to fit `db_adapter`          |
| `runtimes/{bun,node}/src/run_litevolve.ts` | CLI entry point — both packages declare a `litevolve` bin             |
| `runtimes/bun/src/migrate.test.ts`         | **The entire test suite.** Bun-only; node has no tests.               |
| `runtimes/{bun,node}/.changeset/`          | Per-package changesets config (no root `.changeset/`)                 |
| `migrations/working/`                      | Runnable ornithology example, 3 versions with up/down/seed            |
| `migrations/broken/`                       | Intentionally-invalid migration (constraint-failure path)             |
| `migrations/invalid_filename/`             | Filenames the discovery regex must reject                             |
| `migrations/trigger/`                      | `CREATE TRIGGER` with a `BEGIN..END` body (statement-splitting case)  |
| `examples/{bun,node,deno}/`                | Consumer examples against the published packages                      |
| `scripts/`                                 | CI shell scripts, the multi-arch binary `Dockerfile` + its `Makefile` |

## SQLite per runtime

- bun: `bun:sqlite` `Database` — already satisfies `db_adapter`, passed to the core directly.
- node: `node:sqlite` `DatabaseSync`, wrapped in `node_db_adapter`.
- Never `better-sqlite3`.

Core code uses `node:fs` (`existsSync`, `readdirSync`, `readFileSync`) — **not** `Bun.file` —
because the same file has to run on both runtimes.

## Conventions

- `snake_case` everywhere: types, functions, variables, class names, files. No camelCase.
- Core throws `migration_error`: `new migration_error(module_path, method, cause_message, original_error?)`.
- The CLI does not throw on bad arguments: `cli_error` writes the message to stdout and
  calls `process.exit`. Argument parsing is `parseArgs` in strict mode (unknown flags,
  missing values and positionals are rejected); `--apply_version` must match `/^\d+$/`.
- Mark deliberate shortcuts with a `ponytail:` comment.

## Migration internals

- Schema version lives in SQLite's `PRAGMA user_version`.
- Seed preference lives in `_db_meta` (key `init_seeds`); sticky, only settable while at v0.
- Each step runs in `BEGIN IMMEDIATE` — a failed seed rolls back its schema change.
- Each statement is run on its own (`bun:sqlite` swallows errors of all but the last
  statement in a multi-statement string). `split_sql_statements` strips `--` line comments
  **first**, then splits on `;`, holding off inside `BEGIN..END` so trigger bodies survive.
  Known gaps (see its `ponytail:` comment): `--`, `;`, `BEGIN`/`END` inside string
  literals, and `CASE..END` inside a trigger body, all break it.

Filename format: `0*[1-9][0-9]*_([a-zA-Z0-9_]+)\.(sql|seed\.sql|down\.sql)`
e.g. `0001_create_initial_schema.sql`, `0042_add_users.down.sql`, `01000_split_log.seed.sql`.
Leading-zero padding optional; version 0 is invalid.

## Commands

| Target                                       | Purpose                                                      |
| -------------------------------------------- | ------------------------------------------------------------ |
| `make help`                                  | List all targets                                             |
| `make install` / `make clean`                | Install bun deps / remove deps, `*.db`, `dist/`              |
| `make ci_checks`                             | Everything CI runs, plus `check_version`                     |
| `make test [name]`                           | Bun tests, optionally filtered by name                       |
| `make test_debug [name]`                     | Same, with `--inspect-wait`                                  |
| `make ci_test`                               | Tests as CI runs them                                        |
| `make check_version`                         | Installed bun vs `.bun-version` — local only                 |
| `make ci_check_align`                        | Verify the core copies match                                 |
| `make ci_check_comparison_stats`             | README comparison stats not stale (`MAX_AGE_DAYS`, default 30) |
| `make update_comparison`                     | Refresh the README comparison table                          |
| `make ci_check_lint` / `make format`         | Biome check / auto-fix                                       |
| `make ci_check_build`                        | Bundle check + `tsc --noEmit`                                |
| `make ci_sec`                                | `bun audit`                                                  |
| `make align_artifacts`                       | Copy bun core → node, and LICENSE/README                     |
| `make migrate DB_PATH=<p> VERSION=<n>`       | Apply migrations up/down                                     |
| `make migrate_seeds DB_PATH=<p> VERSION=<n>` | Fresh DB with seeds                                          |
| `make ci_binary TARGET=bun-darwin-arm64`     | Compile a standalone binary                                  |
| `make yield_version`                         | Generate changesets if missing, bump versions (bun + node)   |
| `make yield_new_version`                     | Tag `<pkg>@<semver>` on a clean `main`                       |
| `make ci_force_create_releases GH_TOKEN=<t>` | Create missing GitHub releases for tags, via Docker          |

`ci_build.sh`, `ci_types.sh`, `ci_sec.sh` and `ci_test.sh` take a runtime argument (`bun`,
`node`) and the root Makefile only wires up the bun ones.

Tooling: Bun for dev, install, test, and binary compilation. Biome for lint/format, config at
`runtimes/bun/biome.json`. The node package is bundled with **esbuild** (`scripts/ci_build.sh`),
not `bun build`.

## Dependency pins

Renovate owns almost everything: `.bun-version` (`bun-version` manager), `.node-version`
(`nodenv`), every `package.json` (`npm`), `scripts/Dockerfile` (`dockerfile`), and the
workflows (`github-actions`, SHA-pinned). Do not add a script that re-checks any of those —
that duplication was removed on purpose.

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

Verify by hand when bumping a runtime: the `IMAGE ?=` pins in the three example Makefiles
(`examples/{bun,node,deno}/Makefile`), the `$schema` URLs in `runtimes/bun/biome.json` and
`runtimes/{bun,node}/.changeset/config.json`, the README version badges, and the unpinned
global `npm install --global esbuild` in `ci.yml` and `publish.yml`.

`examples/deno/` consumes the published `litevolve-node` through an `npm:` specifier (there is
no `litevolve-deno`); its `litevolve-node` pin lives in `examples/deno/deno.json`.
