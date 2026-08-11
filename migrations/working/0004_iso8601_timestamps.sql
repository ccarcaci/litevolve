-- Normalize any legacy SQLite-style "YYYY-MM-DD HH:MM:SS" timestamps (the format
-- SQLite's own datetime()/CURRENT_TIMESTAMP produce) to strict ISO 8601
-- ("YYYY-MM-DDTHH:MM:SSZ"). Existing seed data is already ISO 8601, so this is a
-- no-op backfill on the example dataset — it only touches rows written before this
-- migration existed.
UPDATE birders     SET joined_at   = REPLACE(joined_at,   ' ', 'T') || 'Z' WHERE joined_at   LIKE '____-__-__ __:__:__';
UPDATE time_slots  SET starts_at   = REPLACE(starts_at,   ' ', 'T') || 'Z' WHERE starts_at   LIKE '____-__-__ __:__:__';
UPDATE time_slots  SET ends_at     = REPLACE(ends_at,     ' ', 'T') || 'Z' WHERE ends_at     LIKE '____-__-__ __:__:__';
UPDATE sightings   SET observed_at = REPLACE(observed_at, ' ', 'T') || 'Z' WHERE observed_at LIKE '____-__-__ __:__:__';
