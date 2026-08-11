-- Regression fixture for migrate.test.ts: a CREATE TRIGGER body contains a `;`
-- before its closing END, which a naive `split(";")` breaks apart (see
-- split_sql_statements in src/core/migrate.ts). Kept in a `trigger/`
-- subdirectory so it is NOT picked up by the main working/ v1..v4 sequence
-- (readdirSync does not recurse).
CREATE TABLE widgets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT ''
);

CREATE TRIGGER widgets_updated_at
AFTER UPDATE ON widgets
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE widgets
  SET updated_at = strftime('%Y-%m-%dT%H:%M:%f+00:00', 'now')
  WHERE id = NEW.id;
END;
