UPDATE observation_sites SET latitude =  40.7829, longitude =  -73.9654, habitat_type = 'urban_park', timezone = 'America/New_York' WHERE id = '48740B1B-0AA2-48DD-9EEE-C14B6AC3258C';
UPDATE observation_sites SET latitude =  38.9351, longitude =  -74.9060, habitat_type = 'coastal'                                  WHERE id = 'E1A2B3C4-D5F6-4789-ABCD-EF1234567890';
UPDATE observation_sites SET latitude =  38.0723, longitude = -122.8819, habitat_type = 'coastal'                                  WHERE id = 'F0E1D2C3-B4A5-4978-9876-543210FEDCBA';

UPDATE birders SET email = 'alice.johnson@birders.example', skill_level = 'expert',        favorite_species = 'Northern Cardinal', timezone = 'America/New_York' WHERE id = 'D5F7BA6A-19C2-42F3-8080-17F098BB807D';
UPDATE birders SET email = 'bob.smith@birders.example',     skill_level = 'intermediate',  favorite_species = 'American Robin',    timezone = 'America/New_York' WHERE id = '507259D3-B912-4DBE-9D87-D5F06741B021';
UPDATE birders SET email = 'carol.davis@birders.example',   skill_level = 'beginner',      favorite_species = 'House Sparrow'      WHERE id = 'A1111111-1111-4111-8111-111111111111';
UPDATE birders SET email = 'dan.lee@birders.example',       skill_level = 'intermediate',  favorite_species = 'Mallard'            WHERE id = 'A2222222-2222-4222-8222-222222222222';
UPDATE birders SET email = 'eve.martinez@birders.example',  skill_level = 'expert',        favorite_species = 'Red-tailed Hawk'    WHERE id = 'A3333333-3333-4333-8333-333333333333';
UPDATE birders SET email = 'frank.patel@birders.example',   skill_level = 'beginner',      favorite_species = 'Mourning Dove'      WHERE id = 'A4444444-4444-4444-8444-444444444444';
UPDATE birders SET email = 'grace.kim@birders.example',     skill_level = 'ornithologist', favorite_species = 'Snowy Owl'          WHERE id = 'A5555555-5555-4555-8555-555555555555';
UPDATE birders SET email = 'henry.wright@birders.example',  skill_level = 'intermediate',  favorite_species = 'Blue Jay'           WHERE id = 'A6666666-6666-4666-8666-666666666666';

UPDATE time_slots SET weather = 'clear'         WHERE id IN ('TS-01', 'TS-04', 'TS-06', 'TS-08', 'TS-12', 'TS-13', 'TS-14', 'TS-16', 'TS-18', 'TS-19', 'TS-21', 'TS-22', 'TS-24', 'TS-26', 'TS-28', 'TS-29', 'TS-32');
UPDATE time_slots SET weather = 'partly_cloudy' WHERE id IN ('TS-02', 'TS-07', 'TS-15', 'TS-20', 'TS-27', 'TS-30');
UPDATE time_slots SET weather = 'overcast'      WHERE id IN ('TS-03', 'TS-11', 'TS-23', 'TS-31');
UPDATE time_slots SET weather = 'foggy'         WHERE id IN ('TS-05', 'TS-17', 'TS-25');
UPDATE time_slots SET weather = 'rainy'         WHERE id IN ('TS-09', 'TS-10');

UPDATE sightings SET species_scientific_name = 'Cardinalis cardinalis', individual_count = 2 WHERE id = 'SG-01';
UPDATE sightings SET species_scientific_name = 'Turdus migratorius',    individual_count = 5 WHERE id = 'SG-02';
UPDATE sightings SET species_scientific_name = 'Vireo olivaceus',       individual_count = 1 WHERE id = 'SG-03';
