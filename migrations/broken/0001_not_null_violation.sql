-- Intentionally invalid migration used only by migrate.test.ts.
-- The INSERT omits the NOT NULL column `name`, so SQLite rejects it and the
-- whole migration transaction rolls back. Kept in a `broken/` subdirectory so it
-- is NOT picked up by the main v1..v3 sequence (readdirSync does not recurse).
CREATE TABLE widgets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

INSERT INTO widgets (id) VALUES ('w1');
