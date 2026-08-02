-- Clear FK data first so no stale references survive the schema change.
-- The DROP COLUMN below also removes the inline REFERENCES constraint declared in
-- the up migration. The explicit NULL step is the pattern to follow when removing
-- the constraint via table-rebuild rather than DROP COLUMN, since SQLite has no
-- ALTER TABLE DROP CONSTRAINT and a rebuild copies values verbatim into the new
-- table unless they have first been cleared.
UPDATE birders SET mentor_birder_id = NULL;

ALTER TABLE birders DROP COLUMN mentor_birder_id;
