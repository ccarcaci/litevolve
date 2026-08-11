-- Revert strict ISO 8601 ("YYYY-MM-DDTHH:MM:SSZ") back to the legacy
-- space-separated, no-suffix form ("YYYY-MM-DD HH:MM:SS").
UPDATE birders     SET joined_at   = REPLACE(SUBSTR(joined_at,   1, LENGTH(joined_at)   - 1), 'T', ' ') WHERE joined_at   LIKE '____-__-__T__:__:__Z';
UPDATE time_slots  SET starts_at   = REPLACE(SUBSTR(starts_at,   1, LENGTH(starts_at)   - 1), 'T', ' ') WHERE starts_at   LIKE '____-__-__T__:__:__Z';
UPDATE time_slots  SET ends_at     = REPLACE(SUBSTR(ends_at,     1, LENGTH(ends_at)     - 1), 'T', ' ') WHERE ends_at     LIKE '____-__-__T__:__:__Z';
UPDATE sightings   SET observed_at = REPLACE(SUBSTR(observed_at, 1, LENGTH(observed_at) - 1), 'T', ' ') WHERE observed_at LIKE '____-__-__T__:__:__Z';
