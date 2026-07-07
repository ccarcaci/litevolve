import Database from "better-sqlite3"
import type { db_adapter } from "litevolve-core"

// ponytail: better-sqlite3 uses prepare() not query(), and exec() not run() for parameterless SQL
export class deno_db_adapter implements db_adapter {
  constructor(private readonly db: InstanceType<typeof Database>) {}

  run(sql: string): void {
    this.db.exec(sql)
  }

  query<T>(sql: string): { get(...params: unknown[]): T | null; run(...params: unknown[]): void } {
    const stmt = this.db.prepare(sql)
    return {
      get: (...params: unknown[]) => (stmt.get(...params) as T | undefined) ?? null,
      run: (...params: unknown[]) => {
        stmt.run(...params)
      },
    }
  }
}
