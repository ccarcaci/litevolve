import { Database } from "bun:sqlite"
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { randomUUID } from "node:crypto"
import { existsSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import { migrate_db } from "./index"
import { migration_error } from "./core/migration_error"

const MIGRATIONS_ROOT = resolve(import.meta.dir, "../../../migrations")
const MIGRATIONS_PATH = resolve(MIGRATIONS_ROOT, "working")
const BROKEN_MIGRATIONS_PATH = resolve(MIGRATIONS_ROOT, "broken")
const INVALID_FILENAME_MIGRATIONS_PATH = resolve(MIGRATIONS_ROOT, "invalid_filename")
const TRIGGER_MIGRATIONS_PATH = resolve(MIGRATIONS_ROOT, "trigger")

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
    migrate_db(MIGRATIONS_PATH, db_path, false, 1)

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
    migrate_db(MIGRATIONS_PATH, db_path, true, 1)

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
    migrate_db(MIGRATIONS_PATH, db_path, false, 1)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 2)

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
    migrate_db(MIGRATIONS_PATH, db_path, true, 1)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 2) // seeds are still applied since the DB has been initialized with seeds

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
    migrate_db(MIGRATIONS_PATH, db_path, true, 1)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 0)

    //  --  assert
    const db = new Database(db_path)
    expect(table_names(db)).toEqual([])
    expect(db_user_version(db)).toBe(0)
    db.close()
  })

  test("v2_with_init_seeds_down_to_v1_added_columns_and_tables_removed_v1_seed_data_intact", () => {
    //  --  arrange
    migrate_db(MIGRATIONS_PATH, db_path, true, 2)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 1)

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
    migrate_db(MIGRATIONS_PATH, db_path, false, 1)

    //  --  act + assert
    expect(() => migrate_db(MIGRATIONS_PATH, db_path, false, 1)).not.toThrow()

    const db = new Database(db_path)
    expect(table_names(db)).toEqual(V1_TABLES)
    expect(db_user_version(db)).toBe(1)
    db.close()
  })

  test("v0_to_v2_in_one_call_applies_both_up_migrations_user_version_is_2", () => {
    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 2)

    //  --  assert
    const db = new Database(db_path)
    expect(db_user_version(db)).toBe(2)
    expect(column_names(db, "observation_sites")).toEqual(V2_SITES_COLS)
    expect(column_names(db, "birders")).toEqual(V2_BIRDERS_COLS)
    db.close()
  })

  test("omitted_apply_version_migrates_up_to_latest_available_version", () => {
    //  --  act: no apply_version given, working migrations top out at v4
    migrate_db(MIGRATIONS_PATH, db_path, false)

    //  --  assert
    const db = new Database(db_path)
    expect(db_user_version(db)).toBe(4)
    db.close()

    //  --  act: already at latest, calling again with omitted apply_version is a no-op
    expect(() => migrate_db(MIGRATIONS_PATH, db_path, false)).not.toThrow()
    const db2 = new Database(db_path)
    expect(db_user_version(db2)).toBe(4)
    db2.close()
  })

  test("full_rollback_v2_to_v0_applies_both_down_migrations_all_tables_dropped", () => {
    //  --  arrange
    migrate_db(MIGRATIONS_PATH, db_path, false, 2)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 0)

    //  --  assert
    const db = new Database(db_path)
    expect(table_names(db)).toEqual([])
    expect(db_user_version(db)).toBe(0)
    db.close()
  })

  test("failing_migration_wraps_and_surfaces_specific_sqlite_constraint_error", () => {
    //  --  act: the broken migration inserts a row violating a NOT NULL constraint
    let caught: unknown
    try {
      migrate_db(BROKEN_MIGRATIONS_PATH, db_path, false, 1)
    } catch (err) {
      caught = err
    }

    //  --  assert: surfaced as a migration_error wrapping the underlying SQLite error
    expect(caught).toBeInstanceOf(migration_error)
    const err = caught as migration_error

    expect(err.original_error).toBeDefined()
    expect(err.method).toBe("apply_migration")
    expect(err.module_path).toBe("src/core/migrate")
    expect(err.cause).toMatch(/failed to apply [\s\S]*\/migrations\/broken\/0001_not_null_violation.sql/)

    //  --  assert: the wrapped error names the specific constraint type + column,
    //  not a generic failure. SQLite guarantees this message text.
    const original = err.original_error as { message?: string }
    expect(original.message).toContain("NOT NULL constraint failed")
    expect(original.message).toContain("widgets.name")

    //  --  assert: the failed step rolled back — no schema change, still at v0
    const db = new Database(db_path)
    expect(table_names(db)).toEqual([])
    expect(db_user_version(db)).toBe(0)
    db.close()
  })

  test("invalid_migration_filename_aborts_run_no_migrations_apply_no_db_effects", () => {
    //  --  arrange: dir has a valid 0001 migration + a malformed 0003a45_... file
    let caught: unknown
    try {
      //  --  act
      migrate_db(INVALID_FILENAME_MIGRATIONS_PATH, db_path, false, 1)
    } catch (err) {
      caught = err
    }

    //  --  assert: a migration_error is raised
    expect(caught).toBeInstanceOf(migration_error)

    //  --  assert: nothing ran — the valid 0001 migration did not apply, DB is untouched
    const db = new Database(db_path)
    expect(table_names(db)).toEqual([])
    expect(db_user_version(db)).toBe(0)
    db.close()
  })

  test("create_trigger_with_inner_update_where_survives_statement_splitting", () => {
    //  --  arrange: up migration creates a table + an AFTER UPDATE trigger whose
    //  body contains a `;` before its closing END
    migrate_db(TRIGGER_MIGRATIONS_PATH, db_path, false, 1)
    const db = new Database(db_path)
    expect(table_names(db)).toEqual(["widgets"])
    db.query("INSERT INTO widgets (id, name) VALUES ('w1', 'first')").run()

    //  --  act: update a column other than updated_at — the trigger should fire
    db.query("UPDATE widgets SET name = 'second' WHERE id = 'w1'").run()

    //  --  assert: trigger's inner UPDATE ... WHERE ran, updated_at is no longer the default
    const widget = db.query("SELECT updated_at FROM widgets WHERE id = 'w1'").get() as {
      updated_at: string
    } | null
    expect(widget?.updated_at).not.toBe("")
    db.close()

    //  --  act: down migration drops the trigger and table cleanly
    migrate_db(TRIGGER_MIGRATIONS_PATH, db_path, false, 0)
    const db2 = new Database(db_path)
    expect(table_names(db2)).toEqual([])
    db2.close()
  })

  test("throws_when_no_up_migration_files_in_range", () => {
    //  --  arrange
    migrate_db(MIGRATIONS_PATH, db_path, false, 5) // applies up through latest (v4), user_version stays at last applied

    //  --  act + assert
    expect(() => migrate_db(MIGRATIONS_PATH, db_path, false, 6)).toThrow()
  })

  // init_seeds behavior: the flag is only evaluated at version 0; subsequent calls use the stored value

  test("init_seeds_stored_as_true_applies_seeds_on_subsequent_up_regardless_of_flag", () => {
    //  --  arrange: fresh DB with init_seeds=true → stored as true
    migrate_db(MIGRATIONS_PATH, db_path, true, 1)

    //  --  act: migrate v1→v2 with init_seeds omitted (false) — stored true is used
    migrate_db(MIGRATIONS_PATH, db_path, false, 2)

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
    migrate_db(MIGRATIONS_PATH, db_path, false, 1)

    //  --  act: migrate v1→v2 with init_seeds=true — ignored, stored false is used
    migrate_db(MIGRATIONS_PATH, db_path, true, 2)

    //  --  assert: no seed data (schema only, row counts zero)
    const db = new Database(db_path)
    expect(row_count(db, "observation_sites")).toBe(0)
    db.close()
  })

  test("after_rollback_to_v0_init_seeds_flag_is_re_evaluated_on_next_up", () => {
    //  --  arrange: fresh DB with init_seeds=true, then rolled back to v0
    migrate_db(MIGRATIONS_PATH, db_path, true, 1)
    migrate_db(MIGRATIONS_PATH, db_path, false, 0)

    //  --  act: re-migrate from v0 with init_seeds omitted (false) — re-evaluated at v0, stored false
    migrate_db(MIGRATIONS_PATH, db_path, false, 1)

    //  --  assert: no seed data despite previous init_seeds=true run
    const db = new Database(db_path)
    expect(row_count(db, "observation_sites")).toBe(0)
    db.close()
  })

  // --  v3: self-referential FK column + NULL-then-drop down migration

  test("v2_then_v3_up_adds_mentor_birder_id_column_to_birders", () => {
    //  --  arrange
    migrate_db(MIGRATIONS_PATH, db_path, false, 2)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 3)

    //  --  assert
    const db = new Database(db_path)
    expect(column_names(db, "birders")).toEqual(V3_BIRDERS_COLS)
    expect(db_user_version(db)).toBe(3)
    db.close()
  })

  test("v0_to_v3_with_init_seeds_carol_mentor_is_alice", () => {
    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, true, 3)

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
    migrate_db(MIGRATIONS_PATH, db_path, true, 3)

    //  --  act
    migrate_db(MIGRATIONS_PATH, db_path, false, 2)

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
    expect(() => migrate_db(MIGRATIONS_PATH, ":memory:", false, 1)).not.toThrow()
  })

  test("v0_to_v1_with_init_seeds_no_error", () => {
    expect(() => migrate_db(MIGRATIONS_PATH, ":memory:", true, 1)).not.toThrow()
  })

  test("v0_to_v2_up_no_error", () => {
    expect(() => migrate_db(MIGRATIONS_PATH, ":memory:", false, 2)).not.toThrow()
  })

  test("v0_to_v2_with_init_seeds_no_error", () => {
    expect(() => migrate_db(MIGRATIONS_PATH, ":memory:", true, 2)).not.toThrow()
  })

  test("v0_to_v3_up_no_error", () => {
    expect(() => migrate_db(MIGRATIONS_PATH, ":memory:", false, 3)).not.toThrow()
  })

  test("v0_to_v3_with_init_seeds_no_error", () => {
    expect(() => migrate_db(MIGRATIONS_PATH, ":memory:", true, 3)).not.toThrow()
  })
})
