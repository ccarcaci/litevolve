import Database from "better-sqlite3"
import { existsSync } from "node:fs"
import { migrate_with_adapter } from "litevolve-core"
import { deno_db_adapter } from "./deno_adapter.js"

export { migration_error } from "litevolve-core"

export const migrate_db = (
  apply_version: number,
  migrations_path: string,
  db_path: string,
  init_seeds = false,
): InstanceType<typeof Database> => {
  const db_exists = existsSync(db_path)
  const db = new Database(db_path)
  db.exec("PRAGMA journal_mode = WAL")
  db.exec("PRAGMA foreign_keys = ON")
  if (!db_exists) console.log(`database created at ${db_path}, user_version initialized to 0`)
  migrate_with_adapter(apply_version, migrations_path, new deno_db_adapter(db), init_seeds)
  return db
}
