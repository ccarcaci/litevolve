import { migrate_with_adapter } from "./core"
import { existsSync } from "node:fs"
import { Database } from "bun:sqlite"

export const migrate_db = (
  migrations_path: string,
  db_path: string,
  init_seeds: boolean,
  apply_version?: number,
): Database => {
  const db_exists = existsSync(db_path)
  const db = new Database(db_path)
  db.run("PRAGMA journal_mode = WAL")
  db.run("PRAGMA foreign_keys = ON")
  if (!db_exists) {
    console.log(`database created at ${db_path}, user_version initialized to 0`)
  }
  migrate_with_adapter(migrations_path, db, init_seeds, apply_version)
  return db
}
