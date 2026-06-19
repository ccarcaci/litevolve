import { parseArgs } from "node:util"
import { migrate_db } from "./index"
import { migration_error } from "./index"

type migration_configs_type = {
  init_seeds: boolean
  apply_version: number
  db_path: string
  migrations_path: string
}

const parse_cli_args = (): migration_configs_type => {
  const { values } = parseArgs({
    args: process.argv.slice(2),
    options: {
      init_seeds: { type: "boolean" },
      apply_version: { type: "string" },
      db_path: { type: "string" },
      migrations_path: { type: "string" },
    },
    strict: false,
  })

  const missing: string[] = []

  const required = (key: string): string => {
    const value = values[key]
    if (!value) {
      missing.push(`--${key}`)
      return ""
    }
    if (typeof value !== "string") return ""
    return value
  }

  const configs: migration_configs_type = {
    init_seeds: (values.init_seeds as boolean | undefined) ?? false,
    apply_version: parseInt(required("apply_version"), 10),
    db_path: required("db_path"),
    migrations_path: required("migrations_path"),
  }

  if (missing.length > 0) {
    throw new migration_error(
      "src/db_migrations/run_migration",
      "parse_cli_args",
      `missing required CLI args: ${missing.join(", ")}`,
    )
  }

  return configs
}

//  --

const configs = parse_cli_args()
migrate_db(configs.apply_version, configs.migrations_path, configs.db_path, configs.init_seeds)
