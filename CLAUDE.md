
Default to using Bun instead of Node.js.

- Use `bun <file>` instead of `node <file>` or `ts-node <file>`
- Use `bun test` instead of `jest` or `vitest`
- Use `bun build <file.html|file.ts|file.css>` instead of `webpack` or `esbuild`
- Use `bun install` instead of `npm install` or `yarn install` or `pnpm install`
- Use `bun run <script>` instead of `npm run <script>` or `yarn run <script>` or `pnpm run <script>`
- Use `bunx <package> <command>` instead of `npx <package> <command>`
- Bun automatically loads .env, so don't use dotenv.

## APIs

- `bun:sqlite` for SQLite. Don't use `better-sqlite3`.
- Prefer `Bun.file` over `node:fs`'s readFile/writeFile

## Testing

Use `bun test` to run tests. Tests live in `src/` alongside source files (e.g. `src/migrate.test.ts`).

Run tests: `make ci_test` (parallel, isolated) or `make test_debug` (with debugger).

## Project

**litevolve** is a versioned SQLite migration runner usable as a library (`migrate_db`) or a CLI binary.

### Source layout

| File                     | Role                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------ |
| `src/migrate.ts`         | Core logic: file discovery, `migrate_up`, `migrate_down`, `migrate_db` (public API) |
| `src/run_litevolve.ts`   | CLI entry point — parses flags and calls `migrate_db`                                |
| `src/migration_error.ts` | `migration_error` class (extends `Error`)                                            |
| `src/index.ts`           | Library entry point — re-exports `migrate_db` and `migration_error`                  |
| `src/migrate.test.ts`    | All tests                                                                            |
| `migrations/`            | Example ornithology DB (3 versions, up/down/seed files)                              |

### Naming conventions

All identifiers use `snake_case` (types, functions, variables, files). No camelCase.

### Error handling

Use `migration_error` from `src/migration_error.ts` for all thrown errors. Constructor: `new migration_error(module_path, method, cause_message, original_error?)`.

### Migration internals

- Schema version tracked via SQLite `PRAGMA user_version`.
- Seed preference tracked in `_db_meta` table (key `init_seeds`); sticky after DB is at v0.
- Each step runs inside `BEGIN IMMEDIATE` transaction — seed failure rolls back the schema change.
- Statements split on `;` before comment stripping — avoid `;` inside SQL comments in migration files.

### Migration filename format

```
0+[1-9][0-9]*_([a-zA-Z_]+)\.(sql|seed\.sql|down\.sql)
```

Examples: `0001_create_initial_schema.sql`, `0042_add_users.down.sql`, `01000_split_log.seed.sql`.

### Key Makefile targets

| Target                                          | Purpose                         |
| ----------------------------------------------- | ------------------------------- |
| `make ci_test`                                  | Run tests (parallel, isolated)  |
| `make ci_lint`                                  | Biome linter                    |
| `make ci_check_build`                           | Compile check + `tsc --noEmit`  |
| `make ci_sec`                                   | Security audit (prod deps)      |
| `make format`                                   | Auto-fix formatting and linting |
| `make migrate DB_PATH=<p> VERSION=<n>`          | Apply migrations up/down        |
| `make migrate_seeds DB_PATH=<p> VERSION=<n>`    | Migrate fresh DB with seeds     |
| `make ci_binary TARGET=<bun-darwin-arm64\|…>`   | Compile standalone binary       |

### Linter

Biome (`bunx biome`). Config lives in `biome.json` if present. Run `make format` to auto-fix.
