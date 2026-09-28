#!/usr/bin/env bun
import { parseArgs } from "node:util"
import { migrate_db } from "./index"

type migration_configs_type = {
  init_seeds: boolean
  db_path: string
  migrations_path: string
  apply_version?: number
}

const usage = `Usage: litevolve --db_path=<path> --migrations_path=<dir> [options]

Required:
  --db_path=<path>          SQLite database file (created if missing)
  --migrations_path=<dir>   Directory containing migration files

Options:
  --apply_version=<n>       Target schema version, up or down (default: highest migration found)
  --init_seeds              Apply seed files; only settable on a fresh (v0) database
  --help                    Show this help
`

const cli_error = (cause_message: string) => {
  process.stdout.write(cause_message)
  process.exit(0)
}

const read_cli_values = () => {
  try {
    return parseArgs({
      args: process.argv.slice(2),
      options: {
        init_seeds: { type: "boolean" },
        apply_version: { type: "string" },
        db_path: { type: "string" },
        migrations_path: { type: "string" },
        help: { type: "boolean" },
      },
    }).values
  } catch (error) {
    // unknown flag, missing flag value, or stray positional argument
    cli_error((error as Error).message)
    return {}
  }
}

const parse_cli_args = (): migration_configs_type => {
  const values = read_cli_values()

  if (values.help) {
    process.stdout.write(usage)
    process.exit(0)
  }

  const missing = (["db_path", "migrations_path"] as const)
    .filter((key) => !values[key])
    .map((key) => `--${key}`)
  if (missing.length > 0) {
    cli_error(`missing required CLI args: ${missing.join(", ")}`)
  }

  const apply_version_raw = values.apply_version
  if (apply_version_raw !== undefined && !/^\d+$/.test(apply_version_raw)) {
    cli_error(`--apply_version must be a non-negative integer, got "${apply_version_raw}"`)
  }

  return {
    init_seeds: values.init_seeds ?? false,
    db_path: values.db_path as string,
    migrations_path: values.migrations_path as string,
    apply_version: apply_version_raw === undefined ? undefined : Number(apply_version_raw),
  }
}

//  --

const configs = parse_cli_args()
migrate_db(configs.migrations_path, configs.db_path, configs.init_seeds, configs.apply_version)
