DROP TABLE IF EXISTS incoming_reports_archive;
DROP TABLE IF EXISTS incoming_reports;

ALTER TABLE sightings DROP COLUMN individual_count;
ALTER TABLE sightings DROP COLUMN species_scientific_name;

ALTER TABLE time_slots DROP COLUMN weather;

ALTER TABLE birders DROP COLUMN timezone;
ALTER TABLE birders DROP COLUMN favorite_species;
ALTER TABLE birders DROP COLUMN skill_level;
ALTER TABLE birders DROP COLUMN email;

ALTER TABLE observation_sites DROP COLUMN timezone;
ALTER TABLE observation_sites DROP COLUMN habitat_type;
ALTER TABLE observation_sites DROP COLUMN longitude;
ALTER TABLE observation_sites DROP COLUMN latitude;
