import { migrate_with_adapter } from "./core"
import { existsSync } from "node:fs"
import { Database } from "bun:sqlite"

export const migrate_db = (
  apply_version: number,
  migrations_path: string,
  db_path: string,
  init_seeds = false,
): Database => {
  const db_exists = existsSync(db_path)
  const db = new Database(db_path)
  db.exec("PRAGMA journal_mode = WAL")
  db.exec("PRAGMA foreign_keys = ON")
  if (!db_exists) console.log(`database created at ${db_path}, user_version initialized to 0`)
  migrate_with_adapter(apply_version, migrations_path, db, init_seeds)
  return db
}
