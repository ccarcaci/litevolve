-- this is a test comment with semicolons; to prove
-- that; they won't affect migrations

CREATE TABLE observation_sites (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE birders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  joined_at TEXT NOT NULL
);

CREATE TABLE time_slots (
  id TEXT PRIMARY KEY,
  site_id TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  reserved INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (site_id) REFERENCES observation_sites(id)
);

-- here; too

CREATE TABLE sightings (
  id TEXT PRIMARY KEY,
  birder_id TEXT NOT NULL,
  site_id TEXT NOT NULL,
  species_common_name TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  status TEXT NOT NULL,
  FOREIGN KEY (birder_id) REFERENCES birders(id),
  FOREIGN KEY (site_id) REFERENCES observation_sites(id)
);
