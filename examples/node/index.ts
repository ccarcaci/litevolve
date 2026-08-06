import { rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { migrate_db } from "litevolve-node"

const migrations_path = resolve(import.meta.dirname, "../../migrations/working")
const db_path = join(tmpdir(), "litevolve_example_node.db")
const latest_version = 3

// ponytail: start from a clean db so the example is re-runnable
rmSync(db_path, { force: true })

// db is typed as node:sqlite's DatabaseSync via litevolve-node/dist/index.d.ts
const db = migrate_db(latest_version, migrations_path, db_path, true)

const row = db.prepare("PRAGMA user_version").get() as { user_version: number } | undefined
if (row?.user_version !== latest_version) {
  throw new Error(`expected user_version ${latest_version}, got ${row?.user_version}`)
}

// column added by 0003_add_birder_mentors.sql — proves the last migration really ran
db.prepare("SELECT mentor_birder_id FROM birders LIMIT 1").get()

console.log(`ok: latest migration ${latest_version} applied to ${db_path}`)

// never called — if litevolve-node's types stopped resolving, migrate_db would widen to `any`,
// the directive below would become unused and `tsc --noEmit` would fail
export const _types_resolve = () => {
  // @ts-expect-error apply_version is a number, not a string
  migrate_db("3", migrations_path, db_path)
}
