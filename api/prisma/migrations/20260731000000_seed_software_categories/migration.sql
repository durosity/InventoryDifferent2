-- Migration: seed the Macintosh Garden-style software category taxonomy
-- (Games + genres, Software/Applications + app categories), all flagged
-- showSoftwareFields = true so they show up correctly in the Software tab
-- and the Add Software category picker.
--
-- This looks up "Games" and "Software" by name (case-insensitive) rather than
-- by id, since those may already exist with different ids (or not exist at
-- all) in any given database. Existing categories are reused and flagged;
-- nothing here overwrites an existing category's other fields. Category
-- names are globally unique, so if a conflicting name already exists for an
-- unrelated purpose, that existing row wins and the duplicate is skipped.

DO $$
DECLARE
  games_id INTEGER;
  software_id INTEGER;
  child_name TEXT;
  games_children TEXT[] := ARRAY[
    'Action','Adventure','Arcade','Board Game','Books & Multimedia','Card & Casino','Casual',
    'Creative','Defunct','Early Childhood Educational','Flight Simulation','FPS',
    'Game Compilations','Game Editors & Tools','Hidden Object','Interactive Fiction','Pinball',
    'Puzzle','Racing','RPG','Simulation','Source Code','Sports','Strategy','Trivia',
    'Visual Novels','Word Games','World Builder'
  ];
  software_children TEXT[] := ARRAY[
    '3D Rendering & CAD','Antivirus','Audio Plugins','Business & Productivity','Clip Art',
    'Compression & Archiving','Contextual Menu Modules','Control Panels & Extensions',
    'Customization & Themes','Database','Demoscene','Development Tools',
    'Drivers & Hardware Support','Emulators','Encryption & Security','Finance','Fonts',
    'Health & Fitness','HyperCard','Icons','Imaging & Burning','Internet & Communications',
    'Lifestyle','Mac Info & Literature','Medical','Music & Sound','Novelties & Fun',
    'Operating Systems','Plug-ins','Reference','Science & Math','Screen Savers',
    'Software Compilations','Spreadsheet','Travel','Utilities','Video',
    'Visual Arts & Graphics','Web Extensions','Widgets','Word Processing & Publishing'
  ];
  i INTEGER;
BEGIN
  -- Find or create the two top-level categories, and make sure they're flagged
  SELECT id INTO games_id FROM "Category" WHERE lower(name) = 'games';
  IF games_id IS NULL THEN
    INSERT INTO "Category" (name, type, "sortOrder", "showSoftwareFields")
    VALUES ('Games', 'SOFTWARE', 0, true)
    RETURNING id INTO games_id;
  ELSE
    UPDATE "Category" SET "showSoftwareFields" = true WHERE id = games_id;
  END IF;

  SELECT id INTO software_id FROM "Category" WHERE lower(name) = 'software';
  IF software_id IS NULL THEN
    INSERT INTO "Category" (name, type, "sortOrder", "showSoftwareFields")
    VALUES ('Software', 'SOFTWARE', 0, true)
    RETURNING id INTO software_id;
  ELSE
    UPDATE "Category" SET "showSoftwareFields" = true WHERE id = software_id;
  END IF;

  -- Games genres
  FOR i IN 1..array_length(games_children, 1) LOOP
    child_name := games_children[i];
    IF NOT EXISTS (SELECT 1 FROM "Category" WHERE lower(name) = lower(child_name)) THEN
      INSERT INTO "Category" (name, type, "sortOrder", "showSoftwareFields", "parentId")
      VALUES (child_name, 'SOFTWARE', i, true, games_id);
    END IF;
  END LOOP;

  -- Application categories
  FOR i IN 1..array_length(software_children, 1) LOOP
    child_name := software_children[i];
    IF NOT EXISTS (SELECT 1 FROM "Category" WHERE lower(name) = lower(child_name)) THEN
      INSERT INTO "Category" (name, type, "sortOrder", "showSoftwareFields", "parentId")
      VALUES (child_name, 'SOFTWARE', i, true, software_id);
    END IF;
  END LOOP;
END $$;
