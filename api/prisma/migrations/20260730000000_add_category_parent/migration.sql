-- Migration: add parentId self-relation to Category, enabling sub-categories
-- (e.g. "Games" > "Puzzle", "Applications" > "Utilities")

ALTER TABLE "Category"
  ADD COLUMN IF NOT EXISTS "parentId" INTEGER;

ALTER TABLE "Category"
  ADD CONSTRAINT "Category_parentId_fkey"
  FOREIGN KEY ("parentId") REFERENCES "Category"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
