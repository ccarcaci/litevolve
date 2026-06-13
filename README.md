# litevolve

Versioned SQLite migrations for Bun, Node, and Deno — usable as a library or a CLI.

[![CI](https://github.com/ccarcaci/litevolve/actions/workflows/ci.yml/badge.svg)](https://github.com/ccarcaci/litevolve/actions/workflows/ci.yml)
<!-- [![npm version](https://img.shields.io/npm/v/litevolve.svg)](https://www.npmjs.com/package/litevolve) -->
<!-- [![npm downloads](https://img.shields.io/npm/dm/litevolve.svg)](https://www.npmjs.com/package/litevolve) -->
<!-- [![JSR](https://jsr.io/badges/@litevolve/litevolve)](https://jsr.io/@litevolve/litevolve) -->
<!-- [![Homebrew installs](https://img.shields.io/homebrew/installs/dm/litevolve.svg)](https://formulae.brew.sh/formula/litevolve) -->
<!-- [![Bundle size](https://img.shields.io/bundlephobia/minzip/litevolve.svg)](https://bundlephobia.com/package/litevolve) -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE.md)
[![Bun](https://img.shields.io/badge/Bun-%3E%3D1.0-black?logo=bun)](https://bun.sh)
[![Node](https://img.shields.io/badge/Node-%3E%3D20-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Deno](https://img.shields.io/badge/Deno-%3E%3D1.40-000?logo=deno)](https://deno.land)

---

## what_it_does

`litevolve` reads a directory of numbered SQL files (`{version}_name.sql`, `{version}_name.down.sql`, optional `{version}_name.seed.sql`) and applies them up or down against a SQLite database to reach a target schema version. Each step runs in a single `BEGIN IMMEDIATE` transaction so a failed seed rolls back its schema change too. The current schema version is tracked in SQLite's native `PRAGMA user_version`; a sticky `init_seeds` flag is recorded in an internal `_db_meta` table so seed behavior stays consistent across subsequent upgrades.

## install

```sh
# Bun
bun add litevolve

# npm / pnpm / yarn
npm install litevolve
pnpm add litevolve
yarn add litevolve

# Deno (JSR)
deno add jsr:@litevolve/litevolve

# Homebrew (CLI only)
brew install litevolve
```

## library_usage

```ts
import { migrate_db } from "litevolve"

// Apply migrations up (or down) to reach version 2.
// Returns the open Bun Database handle.
const db = migrate_db(
  2,                    // apply_version: target schema version
  "./migrations",       // migrations_path: directory holding the .sql files
  "./data/birds.db",    // db_path: SQLite file (or ":memory:")
  true,                 // init_seeds: only honored on a fresh DB at v0
)
```

The signature lives at `src/migrate.ts:172` and the error type at `src/migration_error.ts:1`.

## CLI_usage

The CLI takes the same four inputs as named flags:

```sh
litevolve \
  --apply_version=2 \
  --db_path=./data/birds.db \
  --migrations_path=./migrations \
  --init_seeds
```

Runtime-equivalent invocations:

```sh
bunx litevolve --apply_version=2 --db_path=./data/birds.db --migrations_path=./migrations
npx  litevolve --apply_version=2 --db_path=./data/birds.db --migrations_path=./migrations
deno run --allow-read --allow-write npm:litevolve \
  --apply_version=2 --db_path=./data/birds.db --migrations_path=./migrations
```

## migration_file_conventions

Files in the migrations directory are validated by a strict regex:

```
0+[1-9][0-9]*_([a-z]|[A-Z]|_)+\.(sql|seed\.sql|down\.sql)
```

Breakdown:

- `0+` — at least one leading zero (the zero-padding).
- `[1-9][0-9]*` — the numeric version: a non-zero leading digit followed by any digits.
- `_` — separator.
- `([a-z]|[A-Z]|_)+` — a `[a-zA-Z_]+` description.
- `\.(sql|seed\.sql|down\.sql)` — one of three extensions.

| Extension      | Direction          | When applied                         |
| -------------- | ------------------ | ------------------------------------ |
| `.sql`         | up                 | when current_version < N ≤ target    |
| `.down.sql`    | down               | when target < N ≤ current_version    |
| `.seed.sql`    | up + init_seeds    | optional, same transaction as `.sql` |

Files that do not match the regex are silently skipped — keep auxiliary files (notes, fixtures, sub-directories) out of the migrations directory or they won't be picked up.

**Sort order is numeric after stripping leading zeros**, not lexicographic. `0999_x.sql` sorts before `01000_y.sql` because `parseInt("0999")` is `999` and `parseInt("01000")` is `1000`. This means the padding width can change across migrations without breaking the order: `0001_…`, `0042_…`, `0999_…`, `01000_…` all sort correctly together.

Valid examples: `0001_create_initial_schema.sql`, `0042_add_users_language_column.down.sql`, `01000_split_audit_log.seed.sql`.
Invalid: `1_foo.sql` (no leading zero), `0000_foo.sql` (no non-zero digit), `0001-foo.sql` (hyphen not allowed), `0001_foo.txt` (wrong extension).

Notes about the parser (see `src/migrate.ts:48`):

- Statements are split on `;`. **Avoid `;` inside string literals or SQL comments** — the splitter runs before comment stripping, so a semicolon in a comment becomes a statement terminator.
- Line comments `-- …` are stripped after the split.
- Down migrations never apply seeds. Each `.down.sql` is responsible for its own data cleanup before dropping columns or tables.

## `init_seeds`_semantics

`init_seeds` is **sticky**: it is only honored when the database is at version 0 (fresh or fully rolled back). The chosen value is recorded in `_db_meta` and reused for every subsequent up-migration on the same database. Passing `--init_seeds` to a partially-migrated DB is silently ignored — this guarantees that a database either *consistently* has its seed rows or *consistently* does not. See the behavior contract in `src/migrate.test.ts` (the `init_seeds_*` tests).

## example_ornithology_database

The `migrations/` directory in this repository ships a runnable three-version example modelling a bird-observation system:

- **v1** (`0001_create_initial_schema.sql`) — minimal core, four tables:
  - `observation_sites (id, name)`
  - `birders (id, name, joined_at)`
  - `time_slots (id, site_id, starts_at, ends_at, reserved)`
  - `sightings (id, birder_id, site_id, species_common_name, observed_at, status)`

  Optional seed populates 3 sites, 8 birders (Alice Johnson, Bob Smith, …), 32 two-hour observation windows, and 3 sightings (`pending` / `verified` / `rejected`).
- **v2** (`0002_expand_schema.sql`) — adds richer metadata via `ALTER TABLE ADD COLUMN` and creates two intake tables:
  - `observation_sites` gains `latitude`, `longitude`, `habitat_type`, `timezone`.
  - `birders` gains `email`, `skill_level`, `favorite_species`, `timezone`.
  - `time_slots` gains `weather`.
  - `sightings` gains `species_scientific_name`, `individual_count`.
  - New tables `incoming_reports (id, source, raw_payload, received_at)` and `incoming_reports_archive (…, archived_at)`.

  Optional seed back-fills coordinates, skill levels, scientific names, weather notes, and sets `timezone = 'America/New_York'` for Central Park, Alice, and Bob.
- **v3** (`0003_add_birder_mentors.sql`) — adds `mentor_birder_id TEXT REFERENCES birders(id)` to `birders` (a self-referential FK). Optional seed marks Alice as the mentor of Carol/Dan/Eve and Bob as the mentor of Frank/Grace.

  The down migration demonstrates the **NULL-before-drop pattern** for foreign-key removal:

  ```sql
  -- 0003_add_birder_mentors.down.sql
  UPDATE birders SET mentor_birder_id = NULL;
  ALTER TABLE birders DROP COLUMN mentor_birder_id;
  ```

  Clearing the FK values first is the right habit even when `DROP COLUMN` would also strip the inline `REFERENCES` constraint — it's the pattern you must use when removing a FK constraint *while keeping the column*, since SQLite has no `ALTER TABLE DROP CONSTRAINT` and the alternative is a `CREATE TABLE … / INSERT SELECT / DROP / RENAME` table-rebuild that would otherwise copy stale references into the new table.

Drive it from the Makefile:

```sh
make migrate_seeds DB_PATH=./birds.db VERSION=2
sqlite3 ./birds.db "SELECT name, timezone FROM observation_sites;"
```

## contributing_guidelines

Refer to [Makefile](./Makefile) for a comprehensive list of available helping commands.

- OSX is recommended for development
  - if you have any experience contributing to this library under Linux please share your setup
- Makefile approach is opinionated (sorry)
- Use any editor but don't push any related configuration of it, keep it in your machine
  - I currently use [Helix editor](https://helix-editor.com/)

## license

[MIT](./LICENSE.md)
