import { Database } from "bun:sqlite"
import { existsSync } from "node:fs"
import { migrate_with_adapter } from "litevolve-core"
import type { db_adapter } from "litevolve-core"

export { migration_error } from "litevolve-core"

export const migrate_db = (
  apply_version: number,
  migrations_path: string,
  db_path: string,
  init_seeds = false,
): Database => {
  const db_exists = existsSync(db_path)
  const db = new Database(db_path)
  db.run("PRAGMA journal_mode = WAL")
  db.run("PRAGMA foreign_keys = ON")
  if (!db_exists) console.log(`database created at ${db_path}, user_version initialized to 0`)
  // ponytail: bun:sqlite Database mirrors db_adapter at runtime; typed params differ only at TS level
  migrate_with_adapter(apply_version, migrations_path, db as unknown as db_adapter, init_seeds)
  return db
}
