import { rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { migrate_db } from "litevolve-bun"

const migrations_path = resolve(import.meta.dirname, "../../migrations/working")
const db_path = join(tmpdir(), "litevolve_example_bun.db")
const latest_version = 3

// ponytail: start from a clean db so the example is re-runnable
rmSync(db_path, { force: true })

const db = migrate_db(migrations_path, db_path, true, latest_version)

const { user_version } = db.query("PRAGMA user_version").get() as { user_version: number }
if (user_version !== latest_version) {
  throw new Error(`expected user_version ${latest_version}, got ${user_version}`)
}

// column added by 0003_add_birder_mentors.sql — proves the last migration really ran
db.query("SELECT mentor_birder_id FROM birders LIMIT 1").get()

console.log(`ok: latest migration ${latest_version} applied to ${db_path}`)
