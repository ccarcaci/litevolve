import { existsSync, readdirSync, readFileSync } from "node:fs"
import { resolve } from "node:path"
import type { db_adapter } from "./db_adapter"
import { migration_error } from "./migration_error"

type migration_file_type = {
  version: number
  file_path: string
}

const read_current_version = (db: db_adapter): number =>
  (db.query("PRAGMA user_version").get() as { user_version: number }).user_version

// Enforced filename format:
//   0+[1-9][0-9]*_([a-z]|[A-Z]|_)+.(sql|seed.sql|down.sql)
// At least one leading 0 acts as zero-padding, followed by a non-zero leading digit and
// any digits, an underscore, a [a-zA-Z_]+ description, and one of three extensions.
// Sort order strips the leading 0+ via parseInt, so 0999 sorts before 01000 numerically.
const FILENAME_REGEX = /^(0+[1-9][0-9]*)_[a-zA-Z_]+\.(sql|seed\.sql|down\.sql)$/

const read_migration_files = (
  direction: "up" | "down",
  migrations_path: string,
): migration_file_type[] =>
  readdirSync(migrations_path).flatMap((f) => {
    const match = f.match(FILENAME_REGEX)
    if (!match) return []
    const extension = match[2] // "sql" | "seed.sql" | "down.sql"
    if (direction === "up" && extension !== "sql") return []
    if (direction === "down" && extension !== "down.sql") return []
    if (!match[1]) return []
    const version = parseInt(match[1], 10)
    if (version <= 0) return []
    return [{ version, file_path: resolve(migrations_path, f) }]
  })

// Derives the optional seed file path from an up migration file path.
// Example: 0042_add_users_language_column.sql → 0042_add_users_language_column.seed.sql
// Returns null if the seed file does not exist.
const find_seed_path = (file_path: string): string | null => {
  const seed_path = file_path.replace(/\.sql$/, ".seed.sql")
  return existsSync(seed_path) ? seed_path : null
}

// Splits a SQL file into individual statements and runs each one via db.run().
// Handles multi-statement DDL files (CREATE TABLE, CREATE INDEX, etc.).
// IMPORTANT: splits on ";" first — semicolons inside SQL comment text are also
// treated as statement terminators, so avoid them in migration comment text.
const run_sql_statements = (db: db_adapter, sql: string): void => {
  sql
    .replace(/--[^\n]*/g, "").trim() // /--[^\n]*/g strips each "-- … end-of-line" comment; trim removes residual whitespace
    .split(";") // statement terminator; semicolons in comment text also split here
    .filter((s) => s.length > 0) // discard empty chunks from trailing ";" or comment-only segments
    .forEach((s) => {
      db.run(s)
    })
}

// Applies a single migration step inside one IMMEDIATE transaction.
// If seed_path is provided its statements run in the same transaction,
// so a seed failure rolls back the schema change too.
const apply_migration = (
  next_version: number,
  file_path: string,
  db: db_adapter,
  seed_path?: string,
): void => {
  const sql = readFileSync(file_path, "utf-8")
  const seed_sql = seed_path ? readFileSync(seed_path, "utf-8") : null

  db.run("BEGIN IMMEDIATE")
  try {
    run_sql_statements(db, sql)
    if (seed_sql) run_sql_statements(db, seed_sql)
    db.run(`PRAGMA user_version = ${next_version}`)
    db.run("COMMIT")
  } catch (err) {
    db.run("ROLLBACK")
    throw new migration_error(
      "src/db_migrations/migrate",
      "apply_migration",
      `failed to apply ${file_path}`,
      err,
    )
  }
}

// _db_meta stores migration-level state across process restarts.
// It is managed directly by migrate.ts and is not part of any migration file.
const ensure_meta_table = (db: db_adapter): void => {
  db.run("CREATE TABLE IF NOT EXISTS _db_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
}

const read_init_seeds = (db: db_adapter): boolean => {
  const row = db
    .query<{ value: string }>("SELECT value FROM _db_meta WHERE key = ?")
    .get("init_seeds")
  return row?.value === "true"
}

const write_init_seeds = (db: db_adapter, value: boolean): void => {
  db
    .query("INSERT OR REPLACE INTO _db_meta (key, value) VALUES ('init_seeds', ?)")
    .run(value ? "true" : "false")
}

//  --

const migrate_up = (
  current_version: number,
  apply_version: number,
  migrations_path: string,
  db: db_adapter,
): void => {
  const apply_seeds = read_init_seeds(db)

  if (current_version >= 1) {
    console.log(
      `seeds will${apply_seeds ? "" : " not"} be applied because the database has${apply_seeds ? "" : " not"} been initialized with seeds, --init_seeds param value is ignored, db has already been initialized`,
    )
  }

  const migrations = read_migration_files("up", migrations_path)
    .filter((m) => m.version > current_version && m.version <= apply_version)
    .sort((a, b) => a.version - b.version)

  if (migrations.length === 0) {
    throw new migration_error(
      "src/db_migrations/migrate",
      "migrate_up",
      `no up migration files found between version ${current_version} and ${apply_version}`,
    )
  }

  for (const m of migrations) {
    const seed_path = apply_seeds ? find_seed_path(m.file_path) : undefined
    console.log(`↑ applying ${m.file_path}${seed_path ? ` + ${seed_path}` : ""}`)
    apply_migration(m.version, m.file_path, db, seed_path ?? undefined)
    console.log(`  user_version → ${m.version}`)
  }
}

const migrate_down = (
  current_version: number,
  apply_version: number,
  migrations_path: string,
  db: db_adapter,
): void => {
  const migrations = read_migration_files("down", migrations_path)
    .filter((m) => m.version <= current_version && m.version > apply_version)
    .sort((a, b) => b.version - a.version) // descending: undo latest first

  if (migrations.length === 0) {
    throw new migration_error(
      "src/db_migrations/migrate",
      "migrate_down",
      `no down migration files found between version ${current_version} and ${apply_version}`,
    )
  }

  for (const m of migrations) {
    const next_version = m.version - 1
    // Seed files are never applied when going down. Each *.down.sql is responsible
    // for its own data consistency (e.g. DELETE rows before dropping a column).
    console.log(`↓ applying ${m.file_path}`)
    apply_migration(next_version, m.file_path, db)
    console.log(`  user_version → ${next_version}`)
  }
}

//  --

export const migrate_with_adapter = (
  apply_version: number,
  migrations_path: string,
  db: db_adapter,
  init_seeds = false,
): void => {
  ensure_meta_table(db)
  const current_version = read_current_version(db)
  console.log(
    `current user_version=${current_version}  target=${apply_version}  init_seeds=${init_seeds}`,
  )

  if (current_version === apply_version) {
    console.log("already at target version, nothing to do")
    return
  }

  // init_seeds is only evaluated when the DB is at version 0 (fresh or rolled-back).
  // For already-migrated DBs the CLI flag is ignored and the stored value is used instead,
  // so a seed decision made at DB creation stays consistent across all subsequent upgrades.
  if (current_version === 0) write_init_seeds(db, init_seeds)

  if (apply_version > current_version) {
    migrate_up(current_version, apply_version, migrations_path, db)
  } else {
    migrate_down(current_version, apply_version, migrations_path, db)
  }

  console.log(`migration complete: user_version=${apply_version}`)
}
