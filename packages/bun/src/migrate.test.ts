import { Database } from "bun:sqlite"
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { randomUUID } from "node:crypto"
import { existsSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { migrate_db } from "./index"

const MIGRATIONS_PATH = resolve(import.meta.dir, "../../../migrations")

const SITE_ID = "48740B1B-0AA2-48DD-9EEE-C14B6AC3258C" // Central Park Bird Sanctuary
const ALICE_ID = "D5F7BA6A-19C2-42F3-8080-17F098BB807D" // Alice Johnson
const BOB_ID = "507259D3-B912-4DBE-9D87-D5F06741B021" // Bob Smith
const CAROL_ID = "A1111111-1111-4111-8111-111111111111" // Carol Davis (mentored by Alice in v3 seed)

type pragma_table_info_row_type = {
  cid: number
  name: string
  type: string
  notnull: number
  dflt_value: string | null
  pk: number
}

// Excludes _db_meta — it is a migrate.ts-internal tracking table, not a migration artifact.
const table_names = (db: Database): string[] =>
  (
    db
      .query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name != '_db_meta' ORDER BY name",
      )
      .all() as {
      name: string
    }[]
  ).map((r) => r.name)

const column_names = (db: Database, table: string): string[] =>
  (db.query(`PRAGMA table_info(${table})`).all() as pragma_table_info_row_type[]).map((r) => r.name)

const db_user_version = (db: Database): number =>
  (db.query("PRAGMA user_version").get() as { user_version: number }).user_version

const row_count = (db: Database, table: string): number =>
  (db.query(`SELECT COUNT(*) as n FROM ${table}`).get() as { n: number }).n

const V1_TABLES = ["birders", "observation_sites", "sightings", "time_slots"]
const V2_TABLES = [
  "birders",
  "incoming_reports",
  "incoming_reports_archive",
  "observation_sites",
  "sightings",
  "time_slots",
]
const V1_SITES_COLS = ["id", "name"]
const V1_BIRDERS_COLS = ["id", "name", "joined_at"]
const V2_SITES_COLS = ["id", "name", "latitude", "longitude", "habitat_type", "timezone"]
const V2_BIRDERS_COLS = [
  "id",
  "name",
  "joined_at",
  "email",
  "skill_level",
  "favorite_species",
  "timezone",
]
const V3_BIRDERS_COLS = [...V2_BIRDERS_COLS, "mentor_birder_id"]

// --

describe("migrate_db_file_based_database", () => {
  let db_path: string

  beforeEach(() => {
    db_path = join(tmpdir(), `litevolve_migrate_${randomUUID()}.db`)
  })

  afterEach(() => {
    for (const ext of ["", "-wal", "-shm"]) {
      const p = `${db_path}${ext}`
      if (existsSync(p)) rmSync(p)
    }
  })

  test("v1_up_creates_all_tables_with_correct_columns_and_user_version_1", () => {
    //  --  act
    migrate_db(1, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(table_names(db)).toEqual(V1_TABLES)
    expect(column_names(db, "observation_sites")).toEqual(V1_SITES_COLS)
    expect(column_names(db, "birders")).toEqual(V1_BIRDERS_COLS)
    expect(column_names(db, "time_slots")).toContain("reserved")
    expect(column_names(db, "sightings")).toContain("status")
    expect(db_user_version(db)).toBe(1)
    db.close()
  })

  test("v1_up_with_init_seeds_inserts_all_seed_rows", () => {
    //  --  act
    migrate_db(1, MIGRATIONS_PATH, db_path, true)

    //  --  assert
    const db = new Database(db_path)
    expect(row_count(db, "observation_sites")).toBe(3)
    expect(row_count(db, "birders")).toBe(8)
    expect(row_count(db, "time_slots")).toBe(32)
    expect(row_count(db, "sightings")).toBe(3)
    db.close()
  })

  test("v1_then_v2_up_expands_schema_and_adds_intake_tables_and_timezone", () => {
    //  --  arrange
    migrate_db(1, MIGRATIONS_PATH, db_path)

    //  --  act
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(table_names(db)).toEqual(V2_TABLES)
    expect(column_names(db, "observation_sites")).toEqual(V2_SITES_COLS)
    expect(column_names(db, "birders")).toEqual(V2_BIRDERS_COLS)
    expect(column_names(db, "time_slots")).toContain("weather")
    expect(column_names(db, "sightings")).toContain("species_scientific_name")
    expect(column_names(db, "sightings")).toContain("individual_count")
    expect(db_user_version(db)).toBe(2)
    db.close()
  })

  test("v1_then_v2_with_init_seeds_timezone_values_set_on_seeded_rows", () => {
    //  --  arrange
    migrate_db(1, MIGRATIONS_PATH, db_path, true)

    //  --  act
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    const site = db.query("SELECT timezone FROM observation_sites WHERE id = ?").get(SITE_ID) as {
      timezone: string
    } | null
    expect(site?.timezone).toBe("America/New_York") // Central Park Bird Sanctuary

    const alice = db.query("SELECT timezone FROM birders WHERE id = ?").get(ALICE_ID) as {
      timezone: string
    } | null
    expect(alice?.timezone).toBe("America/New_York")

    const bob = db.query("SELECT timezone FROM birders WHERE id = ?").get(BOB_ID) as {
      timezone: string
    } | null
    expect(bob?.timezone).toBe("America/New_York")
    db.close()
  })

  test("v1_with_init_seeds_down_to_v0_all_tables_dropped_user_version_is_0", () => {
    //  --  arrange
    migrate_db(1, MIGRATIONS_PATH, db_path, true)

    //  --  act
    migrate_db(0, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(table_names(db)).toEqual([])
    expect(db_user_version(db)).toBe(0)
    db.close()
  })

  test("v2_with_init_seeds_down_to_v1_added_columns_and_tables_removed_v1_seed_data_intact", () => {
    //  --  arrange
    migrate_db(2, MIGRATIONS_PATH, db_path, true)

    //  --  act
    migrate_db(1, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(db_user_version(db)).toBe(1)
    expect(table_names(db)).toEqual(V1_TABLES)
    expect(column_names(db, "observation_sites")).toEqual(V1_SITES_COLS)
    expect(column_names(db, "birders")).toEqual(V1_BIRDERS_COLS)
    expect(row_count(db, "observation_sites")).toBe(3)
    expect(row_count(db, "birders")).toBe(8)
    expect(row_count(db, "sightings")).toBe(3)
    db.close()
  })

  test("already_at_target_version_no_op_no_error_state_unchanged", () => {
    //  --  arrange
    migrate_db(1, MIGRATIONS_PATH, db_path)

    //  --  act + assert
    expect(() => migrate_db(1, MIGRATIONS_PATH, db_path)).not.toThrow()

    const db = new Database(db_path)
    expect(table_names(db)).toEqual(V1_TABLES)
    expect(db_user_version(db)).toBe(1)
    db.close()
  })

  test("v0_to_v2_in_one_call_applies_both_up_migrations_user_version_is_2", () => {
    //  --  act
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(db_user_version(db)).toBe(2)
    expect(column_names(db, "observation_sites")).toEqual(V2_SITES_COLS)
    expect(column_names(db, "birders")).toEqual(V2_BIRDERS_COLS)
    db.close()
  })

  test("full_rollback_v2_to_v0_applies_both_down_migrations_all_tables_dropped", () => {
    //  --  arrange
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  act
    migrate_db(0, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(table_names(db)).toEqual([])
    expect(db_user_version(db)).toBe(0)
    db.close()
  })

  test("throws_when_no_up_migration_files_in_range", () => {
    //  --  arrange
    migrate_db(4, MIGRATIONS_PATH, db_path) // applies up through latest (v3), user_version stays at last applied

    //  --  act + assert
    expect(() => migrate_db(5, MIGRATIONS_PATH, db_path)).toThrow()
  })

  // init_seeds behavior: the flag is only evaluated at version 0; subsequent calls use the stored value

  test("init_seeds_stored_as_true_applies_seeds_on_subsequent_up_regardless_of_flag", () => {
    //  --  arrange: fresh DB with init_seeds=true → stored as true
    migrate_db(1, MIGRATIONS_PATH, db_path, true)

    //  --  act: migrate v1→v2 with init_seeds omitted (false) — stored true is used
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  assert: v2 seeds were applied (timezone values set, not the default 'UTC')
    const db = new Database(db_path)
    const alice = db.query("SELECT timezone FROM birders WHERE id = ?").get(ALICE_ID) as {
      timezone: string
    } | null
    expect(alice?.timezone).toBe("America/New_York")
    db.close()
  })

  test("init_seeds_stored_as_false_blocks_seeds_on_subsequent_up_regardless_of_flag", () => {
    //  --  arrange: fresh DB with init_seeds omitted (false) → stored as false
    migrate_db(1, MIGRATIONS_PATH, db_path)

    //  --  act: migrate v1→v2 with init_seeds=true — ignored, stored false is used
    migrate_db(2, MIGRATIONS_PATH, db_path, true)

    //  --  assert: no seed data (schema only, row counts zero)
    const db = new Database(db_path)
    expect(row_count(db, "observation_sites")).toBe(0)
    db.close()
  })

  test("after_rollback_to_v0_init_seeds_flag_is_re_evaluated_on_next_up", () => {
    //  --  arrange: fresh DB with init_seeds=true, then rolled back to v0
    migrate_db(1, MIGRATIONS_PATH, db_path, true)
    migrate_db(0, MIGRATIONS_PATH, db_path)

    //  --  act: re-migrate from v0 with init_seeds omitted (false) — re-evaluated at v0, stored false
    migrate_db(1, MIGRATIONS_PATH, db_path)

    //  --  assert: no seed data despite previous init_seeds=true run
    const db = new Database(db_path)
    expect(row_count(db, "observation_sites")).toBe(0)
    db.close()
  })

  // --  v3: self-referential FK column + NULL-then-drop down migration

  test("v2_then_v3_up_adds_mentor_birder_id_column_to_birders", () => {
    //  --  arrange
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  act
    migrate_db(3, MIGRATIONS_PATH, db_path)

    //  --  assert
    const db = new Database(db_path)
    expect(column_names(db, "birders")).toEqual(V3_BIRDERS_COLS)
    expect(db_user_version(db)).toBe(3)
    db.close()
  })

  test("v0_to_v3_with_init_seeds_carol_mentor_is_alice", () => {
    //  --  act
    migrate_db(3, MIGRATIONS_PATH, db_path, true)

    //  --  assert
    const db = new Database(db_path)
    const carol = db.query("SELECT mentor_birder_id FROM birders WHERE id = ?").get(CAROL_ID) as {
      mentor_birder_id: string | null
    } | null
    expect(carol?.mentor_birder_id).toBe(ALICE_ID)
    db.close()
  })

  test("v3_down_to_v2_drops_mentor_birder_id_column_after_nulling_fk_values", () => {
    //  --  arrange: full v3 with seeded mentor relationships
    migrate_db(3, MIGRATIONS_PATH, db_path, true)

    //  --  act
    migrate_db(2, MIGRATIONS_PATH, db_path)

    //  --  assert: column is gone, birder rows preserved
    const db = new Database(db_path)
    expect(db_user_version(db)).toBe(2)
    expect(column_names(db, "birders")).toEqual(V2_BIRDERS_COLS)
    expect(row_count(db, "birders")).toBe(8)
    db.close()
  })
})

// --

describe("migrate_db_in_memory_database", () => {
  // :memory: opens a fresh isolated connection per call — state cannot be inspected after
  // migrate_db returns because the internal Database handle is not exposed. These tests
  // verify that each migration path executes without errors.

  test("v0_to_v1_up_no_error", () => {
    expect(() => migrate_db(1, MIGRATIONS_PATH, ":memory:")).not.toThrow()
  })

  test("v0_to_v1_with_init_seeds_no_error", () => {
    expect(() => migrate_db(1, MIGRATIONS_PATH, ":memory:", true)).not.toThrow()
  })

  test("v0_to_v2_up_no_error", () => {
    expect(() => migrate_db(2, MIGRATIONS_PATH, ":memory:")).not.toThrow()
  })

  test("v0_to_v2_with_init_seeds_no_error", () => {
    expect(() => migrate_db(2, MIGRATIONS_PATH, ":memory:", true)).not.toThrow()
  })

  test("v0_to_v3_up_no_error", () => {
    expect(() => migrate_db(3, MIGRATIONS_PATH, ":memory:")).not.toThrow()
  })

  test("v0_to_v3_with_init_seeds_no_error", () => {
    expect(() => migrate_db(3, MIGRATIONS_PATH, ":memory:", true)).not.toThrow()
  })
})
