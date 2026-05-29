-- Migration: storage/OS multi-value + PRAM battery restructure
-- 1. Create DeviceStorage and DeviceOS tables
-- 2. Migrate existing storage/operatingSystem strings into new tables
-- 3. Add pramBatteryInstalled + pramBatteryExpiryDate, migrate from isPramBatteryRemoved
-- 4. Drop storage, operatingSystem, isPramBatteryRemoved from Device
-- 5. Update WishlistItem: isPramBatteryRemoved -> pramBatteryInstalled + pramBatteryExpiryDate

-- ============================================================
-- Create new tables
-- ============================================================

CREATE TABLE "DeviceStorage" (
  "id"        SERIAL PRIMARY KEY,
  "deviceId"  INTEGER NOT NULL REFERENCES "Device"("id") ON DELETE CASCADE,
  "value"     TEXT NOT NULL,
  "sortOrder" INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE "DeviceOS" (
  "id"        SERIAL PRIMARY KEY,
  "deviceId"  INTEGER NOT NULL REFERENCES "Device"("id") ON DELETE CASCADE,
  "value"     TEXT NOT NULL,
  "sortOrder" INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- Migrate Device.storage -> DeviceStorage rows
-- Split on ' + ' separator
-- ============================================================

DO $$
DECLARE
  rec RECORD;
  parts TEXT[];
  part TEXT;
  idx INT;
BEGIN
  FOR rec IN SELECT id, storage FROM "Device" WHERE storage IS NOT NULL AND storage <> '' LOOP
    parts := string_to_array(rec.storage, ' + ');
    idx := 0;
    FOREACH part IN ARRAY parts LOOP
      part := TRIM(part);
      IF part <> '' THEN
        INSERT INTO "DeviceStorage" ("deviceId", "value", "sortOrder") VALUES (rec.id, part, idx);
        idx := idx + 1;
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- Migrate Device.operatingSystem -> DeviceOS rows
-- ============================================================

INSERT INTO "DeviceOS" ("deviceId", "value", "sortOrder")
SELECT id, TRIM("operatingSystem"), 0
FROM "Device"
WHERE "operatingSystem" IS NOT NULL AND TRIM("operatingSystem") <> '';

-- ============================================================
-- Add pramBatteryInstalled + pramBatteryExpiryDate to Device
-- Migrate: pramBatteryInstalled = NOT isPramBatteryRemoved
-- ============================================================

ALTER TABLE "Device"
  ADD COLUMN "pramBatteryInstalled"  BOOLEAN,
  ADD COLUMN "pramBatteryExpiryDate" TIMESTAMP(3);

UPDATE "Device"
SET "pramBatteryInstalled" = NOT COALESCE("isPramBatteryRemoved", false)
WHERE "isPramBatteryRemoved" IS NOT NULL;

-- ============================================================
-- Drop old columns from Device
-- ============================================================

ALTER TABLE "Device"
  DROP COLUMN "storage",
  DROP COLUMN "operatingSystem",
  DROP COLUMN "isPramBatteryRemoved";

-- ============================================================
-- Update WishlistItem: isPramBatteryRemoved -> pramBatteryInstalled + pramBatteryExpiryDate
-- ============================================================

ALTER TABLE "WishlistItem"
  ADD COLUMN "pramBatteryInstalled"  BOOLEAN,
  ADD COLUMN "pramBatteryExpiryDate" TIMESTAMP(3);

UPDATE "WishlistItem"
SET "pramBatteryInstalled" = NOT COALESCE("isPramBatteryRemoved", false)
WHERE "isPramBatteryRemoved" IS NOT NULL;

ALTER TABLE "WishlistItem"
  DROP COLUMN "isPramBatteryRemoved";
