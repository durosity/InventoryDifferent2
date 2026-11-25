-- Migration: restructure categories under two top-level groupings,
-- "Hardware" and "Software", each with the existing categories as
-- sub-categories (and, for Software, as sub-sub-categories under
-- "Games"/"Applications").
--
-- Looks everything up by name rather than hardcoded ids, so it's safe to run
-- against a database where these categories have different ids, or don't
-- exist yet. Idempotent: safe to re-run.

DO $$
DECLARE
  hardware_id INTEGER;
  software_id INTEGER;
  games_id INTEGER;
  applications_id INTEGER;
  cat RECORD;
  next_sort INTEGER := 0;
BEGIN
  -- Top-level "Hardware"
  SELECT id INTO hardware_id FROM "Category" WHERE lower(name) = 'hardware';
  IF hardware_id IS NULL THEN
    INSERT INTO "Category" (name, type, "sortOrder", "showSoftwareFields")
    VALUES ('Hardware', 'OTHER', 0, false)
    RETURNING id INTO hardware_id;
  END IF;

  -- The existing "Software" category has been acting as the "Applications"
  -- bucket (parent of Utilities, Operating Systems, etc). Rename it to make
  -- room for a new top-level "Software" that wraps both it and "Games".
  SELECT id INTO applications_id FROM "Category" WHERE lower(name) = 'software';
  IF applications_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "Category" WHERE lower(name) = 'applications') THEN
    UPDATE "Category" SET name = 'Applications' WHERE id = applications_id;
  ELSE
    SELECT id INTO applications_id FROM "Category" WHERE lower(name) = 'applications';
  END IF;

  -- New top-level "Software"
  SELECT id INTO software_id FROM "Category" WHERE lower(name) = 'software' AND "parentId" IS NULL;
  IF software_id IS NULL THEN
    INSERT INTO "Category" (name, type, "sortOrder", "showSoftwareFields")
    VALUES ('Software', 'SOFTWARE', 1, true)
    RETURNING id INTO software_id;
  END IF;

  -- "Games" and "Applications" become children of the new "Software"
  SELECT id INTO games_id FROM "Category" WHERE lower(name) = 'games';
  IF games_id IS NOT NULL THEN
    UPDATE "Category" SET "parentId" = software_id WHERE id = games_id;
  END IF;
  IF applications_id IS NOT NULL THEN
    UPDATE "Category" SET "parentId" = software_id WHERE id = applications_id;
  END IF;

  -- Every other previously-top-level, non-software category becomes a child
  -- of "Hardware" (preserving relative order via sortOrder)
  FOR cat IN
    SELECT id FROM "Category"
    WHERE "parentId" IS NULL
      AND "showSoftwareFields" = false
      AND id != hardware_id
    ORDER BY "sortOrder", name
  LOOP
    UPDATE "Category" SET "parentId" = hardware_id, "sortOrder" = next_sort WHERE id = cat.id;
    next_sort := next_sort + 1;
  END LOOP;
END $$;
