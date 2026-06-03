ALTER TABLE birders ADD COLUMN mentor_birder_id TEXT REFERENCES birders(id);
