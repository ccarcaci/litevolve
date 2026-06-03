ALTER TABLE observation_sites ADD COLUMN latitude     REAL NOT NULL DEFAULT 0;
ALTER TABLE observation_sites ADD COLUMN longitude    REAL NOT NULL DEFAULT 0;
ALTER TABLE observation_sites ADD COLUMN habitat_type TEXT NOT NULL DEFAULT 'unknown';
ALTER TABLE observation_sites ADD COLUMN timezone     TEXT;

ALTER TABLE birders ADD COLUMN email            TEXT NOT NULL DEFAULT '';
ALTER TABLE birders ADD COLUMN skill_level      TEXT NOT NULL DEFAULT 'beginner';
ALTER TABLE birders ADD COLUMN favorite_species TEXT;
ALTER TABLE birders ADD COLUMN timezone         TEXT;

ALTER TABLE time_slots ADD COLUMN weather TEXT;

ALTER TABLE sightings ADD COLUMN species_scientific_name TEXT    NOT NULL DEFAULT '';
ALTER TABLE sightings ADD COLUMN individual_count        INTEGER NOT NULL DEFAULT 1;

CREATE TABLE incoming_reports (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  raw_payload TEXT NOT NULL,
  received_at TEXT NOT NULL
);

CREATE TABLE incoming_reports_archive (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  raw_payload TEXT NOT NULL,
  received_at TEXT NOT NULL,
  archived_at TEXT NOT NULL
);
