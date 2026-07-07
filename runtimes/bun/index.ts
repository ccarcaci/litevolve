import { DatabaseSync } from "node:sqlite"
import { existsSync } from "node:fs"
import { migrate_with_adapter } from "litevolve-core"
import { node_db_adapter } from "./node_adapter.js"

export { migration_error } from "litevolve-core"

export const migrate_db = (
  apply_version: number,
  migrations_path: string,
  db_path: string,
  init_seeds = false,
): DatabaseSync => {
  const db_exists = existsSync(db_path)
  const db = new DatabaseSync(db_path)
  db.exec("PRAGMA journal_mode = WAL")
  db.exec("PRAGMA foreign_keys = ON")
  if (!db_exists) console.log(`database created at ${db_path}, user_version initialized to 0`)
  migrate_with_adapter(apply_version, migrations_path, new node_db_adapter(db), init_seeds)
  return db
}
