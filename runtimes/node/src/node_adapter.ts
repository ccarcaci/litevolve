import { DatabaseSync } from "node:sqlite"
import type { db_adapter } from "./core/db_adapter"

// ponytail: node:sqlite uses prepare() not query(), and exec() not run() for parameterless SQL
export class node_db_adapter implements db_adapter {
  constructor(private readonly db: DatabaseSync) {}

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
