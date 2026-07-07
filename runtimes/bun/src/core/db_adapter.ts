export type query_result<T> = {
  get(...params: unknown[]): T | null
  run(...params: unknown[]): void
}

export type db_adapter = {
  run(sql: string): void
  query<T>(sql: string): query_result<T>
}
