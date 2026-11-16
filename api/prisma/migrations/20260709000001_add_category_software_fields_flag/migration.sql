-- Migration: add showSoftwareFields flag to Category (decouples the software-style
-- form fields from CategoryType, so any category — Software, Games, etc. — can
-- opt in via a checkbox in the admin UI)

ALTER TABLE "Category"
  ADD COLUMN IF NOT EXISTS "showSoftwareFields" BOOLEAN NOT NULL DEFAULT false;

-- Backfill: turn the flag on for any category that was already using the
-- SOFTWARE CategoryType, so existing data doesn't lose the behaviour it had
UPDATE "Category" SET "showSoftwareFields" = true WHERE "type" = 'SOFTWARE';
