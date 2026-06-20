-- Migration: split cpu -> cpuType + cpuSpeed
--            split graphics -> graphicsChip + screenSize + displayType + displayVariant + nativeResolution
-- Applies to Device, WishlistItem, and Template tables
--
-- Fixes applied vs previous draft:
--   1. Built-in 640x480 (no inch marker) no longer gets screenSize = '640'
--   2. Sony Trinitron entries now get displayType = 'CRT'
--   3. LED-backlit Retina entries keep displayVariant = 'LED-backlit' (applied after Retina)
--   4. Text: mode entries excluded from nativeResolution

-- ============================================================
-- Device table
-- ============================================================
ALTER TABLE "Device"
  ADD COLUMN "cpuType"          TEXT,
  ADD COLUMN "cpuSpeed"         TEXT,
  ADD COLUMN "graphicsChip"     TEXT,
  ADD COLUMN "screenSize"       TEXT,
  ADD COLUMN "displayType"      TEXT,
  ADD COLUMN "displayVariant"   TEXT,
  ADD COLUMN "nativeResolution" TEXT;

-- CPU: split on ' @ '
UPDATE "Device" SET
  "cpuType" = TRIM(SPLIT_PART(cpu, ' @ ', 1)),
  "cpuSpeed" = TRIM(SPLIT_PART(cpu, ' @ ', 2))
WHERE cpu IS NOT NULL AND cpu LIKE '% @ %';

UPDATE "Device" SET "cpuType" = TRIM(cpu)
WHERE cpu IS NOT NULL AND cpu NOT LIKE '% @ %';

-- screenSize: Built-in entries with inch marker (e.g. "Built-in 9.5" Active Matrix...")
-- Must have a " after the number to be a screen size, not a resolution
UPDATE "Device" SET
  "screenSize" = TRIM(SUBSTRING(graphics FROM E'^Built-in ([0-9][0-9./]*")'))
WHERE graphics IS NOT NULL AND graphics LIKE 'Built-in %' AND graphics ~ E'^Built-in [0-9][0-9.]*"';

-- screenSize: standalone monitor entries (e.g. "17" LCD, 1024x768")
UPDATE "Device" SET
  "screenSize" = TRIM(SUBSTRING(graphics FROM E'^([0-9][0-9./]*"[/0-9."]*)'))
WHERE graphics IS NOT NULL AND "screenSize" IS NULL AND graphics ~ E'^[0-9][0-9.]*"';

-- nativeResolution: handle x and × (with optional spaces), skip Text: entries
UPDATE "Device" SET
  "nativeResolution" = REGEXP_REPLACE(
    TRIM(SUBSTRING(graphics FROM E'([0-9]{3,}\\s*[x\u00d7]\\s*[0-9]{3,})')),
    E'\\s+', '', 'g'
  )
WHERE graphics IS NOT NULL
  AND graphics NOT LIKE 'Text:%'
  AND graphics ~ E'[0-9]{3,}\\s*[x\u00d7]\\s*[0-9]{3,}';

-- displayType: LCD first (includes LED-backlit LCD)
UPDATE "Device" SET "displayType" = 'LCD'
WHERE graphics IS NOT NULL AND (graphics LIKE '%LCD%' OR graphics LIKE '%LED-backlit%');

-- CRT (includes Sony Trinitron which is a CRT)
UPDATE "Device" SET "displayType" = 'CRT'
WHERE graphics IS NOT NULL AND "displayType" IS NULL
  AND (graphics LIKE '%CRT%' OR graphics LIKE '%Trinitron%');

-- Monochrome (only if not already set)
UPDATE "Device" SET "displayType" = 'Monochrome'
WHERE graphics IS NOT NULL AND "displayType" IS NULL AND graphics LIKE '%monochrome%';

-- displayVariant: order matters — LED-backlit applied after Retina so it wins for "LED-backlit Retina"
UPDATE "Device" SET "displayVariant" = 'Active Matrix'
WHERE graphics IS NOT NULL AND graphics LIKE '%Active Matrix%';

UPDATE "Device" SET "displayVariant" = 'Passive Matrix'
WHERE graphics IS NOT NULL AND graphics LIKE '%Passive Matrix%';

UPDATE "Device" SET "displayVariant" = 'Sony Trinitron'
WHERE graphics IS NOT NULL AND graphics LIKE '%Sony Trinitron%';

UPDATE "Device" SET "displayVariant" = 'Diamondtron'
WHERE graphics IS NOT NULL AND graphics LIKE '%Diamondtron%';

UPDATE "Device" SET "displayVariant" = 'Retina'
WHERE graphics IS NOT NULL AND graphics LIKE '%Retina%';

-- LED-backlit applied last so it wins over Retina for "LED-backlit LCD, NNNx NNN Retina"
UPDATE "Device" SET "displayVariant" = 'LED-backlit'
WHERE graphics IS NOT NULL AND graphics LIKE '%LED-backlit%';

-- graphicsChip: discrete GPU entries — no inch markers, no CRT/LCD/monochrome/× chars, no Text:
UPDATE "Device" SET "graphicsChip" = TRIM(graphics)
WHERE graphics IS NOT NULL
  AND graphics NOT LIKE 'Text:%'
  AND graphics NOT LIKE '%monochrome%'
  AND graphics NOT LIKE '% CRT%'
  AND graphics NOT LIKE '% LCD%'
  AND graphics NOT LIKE E'%\u00d7%'
  AND graphics NOT LIKE E'%"%'
  AND graphics NOT LIKE 'Built-in %';

-- graphicsChip: known catch-all built-in video strings (no display spec)
UPDATE "Device" SET "graphicsChip" = TRIM(graphics)
WHERE graphics IS NOT NULL AND graphics IN (
  'Built-in video',
  'Built-in video + AV capabilities',
  'Built-in video + optional Apple or third-party video card',
  'Integrated video',
  'Optional Apple or third-party video card',
  'PCI video card',
  'IMS Twin Turbo PCI video card'
);

ALTER TABLE "Device" DROP COLUMN "cpu", DROP COLUMN "graphics";

-- ============================================================
-- WishlistItem table
-- ============================================================
ALTER TABLE "WishlistItem"
  ADD COLUMN "cpuType"          TEXT,
  ADD COLUMN "cpuSpeed"         TEXT,
  ADD COLUMN "graphicsChip"     TEXT,
  ADD COLUMN "screenSize"       TEXT,
  ADD COLUMN "displayType"      TEXT,
  ADD COLUMN "displayVariant"   TEXT,
  ADD COLUMN "nativeResolution" TEXT;

UPDATE "WishlistItem" SET
  "cpuType" = TRIM(SPLIT_PART(cpu, ' @ ', 1)),
  "cpuSpeed" = TRIM(SPLIT_PART(cpu, ' @ ', 2))
WHERE cpu IS NOT NULL AND cpu LIKE '% @ %';

UPDATE "WishlistItem" SET "cpuType" = TRIM(cpu)
WHERE cpu IS NOT NULL AND cpu NOT LIKE '% @ %';

UPDATE "WishlistItem" SET
  "screenSize" = TRIM(SUBSTRING(graphics FROM E'^Built-in ([0-9][0-9./]*")'))
WHERE graphics IS NOT NULL AND graphics LIKE 'Built-in %' AND graphics ~ E'^Built-in [0-9][0-9.]*"';

UPDATE "WishlistItem" SET
  "screenSize" = TRIM(SUBSTRING(graphics FROM E'^([0-9][0-9./]*"[/0-9."]*)'))
WHERE graphics IS NOT NULL AND "screenSize" IS NULL AND graphics ~ E'^[0-9][0-9.]*"';

UPDATE "WishlistItem" SET
  "nativeResolution" = REGEXP_REPLACE(
    TRIM(SUBSTRING(graphics FROM E'([0-9]{3,}\\s*[x\u00d7]\\s*[0-9]{3,})')),
    E'\\s+', '', 'g'
  )
WHERE graphics IS NOT NULL
  AND graphics NOT LIKE 'Text:%'
  AND graphics ~ E'[0-9]{3,}\\s*[x\u00d7]\\s*[0-9]{3,}';

UPDATE "WishlistItem" SET "displayType" = 'LCD'
WHERE graphics IS NOT NULL AND (graphics LIKE '%LCD%' OR graphics LIKE '%LED-backlit%');

UPDATE "WishlistItem" SET "displayType" = 'CRT'
WHERE graphics IS NOT NULL AND "displayType" IS NULL
  AND (graphics LIKE '%CRT%' OR graphics LIKE '%Trinitron%');

UPDATE "WishlistItem" SET "displayType" = 'Monochrome'
WHERE graphics IS NOT NULL AND "displayType" IS NULL AND graphics LIKE '%monochrome%';

UPDATE "WishlistItem" SET "displayVariant" = 'Active Matrix'
WHERE graphics IS NOT NULL AND graphics LIKE '%Active Matrix%';

UPDATE "WishlistItem" SET "displayVariant" = 'Passive Matrix'
WHERE graphics IS NOT NULL AND graphics LIKE '%Passive Matrix%';

UPDATE "WishlistItem" SET "displayVariant" = 'Sony Trinitron'
WHERE graphics IS NOT NULL AND graphics LIKE '%Sony Trinitron%';

UPDATE "WishlistItem" SET "displayVariant" = 'Diamondtron'
WHERE graphics IS NOT NULL AND graphics LIKE '%Diamondtron%';

UPDATE "WishlistItem" SET "displayVariant" = 'Retina'
WHERE graphics IS NOT NULL AND graphics LIKE '%Retina%';

UPDATE "WishlistItem" SET "displayVariant" = 'LED-backlit'
WHERE graphics IS NOT NULL AND graphics LIKE '%LED-backlit%';

UPDATE "WishlistItem" SET "graphicsChip" = TRIM(graphics)
WHERE graphics IS NOT NULL
  AND graphics NOT LIKE 'Text:%'
  AND graphics NOT LIKE '%monochrome%'
  AND graphics NOT LIKE '% CRT%'
  AND graphics NOT LIKE '% LCD%'
  AND graphics NOT LIKE E'%\u00d7%'
  AND graphics NOT LIKE E'%"%'
  AND graphics NOT LIKE 'Built-in %';

UPDATE "WishlistItem" SET "graphicsChip" = TRIM(graphics)
WHERE graphics IS NOT NULL AND graphics IN (
  'Built-in video',
  'Built-in video + AV capabilities',
  'Built-in video + optional Apple or third-party video card',
  'Integrated video',
  'Optional Apple or third-party video card',
  'PCI video card',
  'IMS Twin Turbo PCI video card'
);

ALTER TABLE "WishlistItem" DROP COLUMN "cpu", DROP COLUMN "graphics";

-- ============================================================
-- Template table
-- ============================================================
ALTER TABLE "Template"
  ADD COLUMN "cpuType"          TEXT,
  ADD COLUMN "cpuSpeed"         TEXT,
  ADD COLUMN "graphicsChip"     TEXT,
  ADD COLUMN "screenSize"       TEXT,
  ADD COLUMN "displayType"      TEXT,
  ADD COLUMN "displayVariant"   TEXT,
  ADD COLUMN "nativeResolution" TEXT;

UPDATE "Template" SET
  "cpuType" = TRIM(SPLIT_PART(cpu, ' @ ', 1)),
  "cpuSpeed" = TRIM(SPLIT_PART(cpu, ' @ ', 2))
WHERE cpu IS NOT NULL AND cpu LIKE '% @ %';

UPDATE "Template" SET "cpuType" = TRIM(cpu)
WHERE cpu IS NOT NULL AND cpu NOT LIKE '% @ %';

UPDATE "Template" SET
  "screenSize" = TRIM(SUBSTRING(graphics FROM E'^Built-in ([0-9][0-9./]*")'))
WHERE graphics IS NOT NULL AND graphics LIKE 'Built-in %' AND graphics ~ E'^Built-in [0-9][0-9.]*"';

UPDATE "Template" SET
  "screenSize" = TRIM(SUBSTRING(graphics FROM E'^([0-9][0-9./]*"[/0-9."]*)'))
WHERE graphics IS NOT NULL AND "screenSize" IS NULL AND graphics ~ E'^[0-9][0-9.]*"';

UPDATE "Template" SET
  "nativeResolution" = REGEXP_REPLACE(
    TRIM(SUBSTRING(graphics FROM E'([0-9]{3,}\\s*[x\u00d7]\\s*[0-9]{3,})')),
    E'\\s+', '', 'g'
  )
WHERE graphics IS NOT NULL
  AND graphics NOT LIKE 'Text:%'
  AND graphics ~ E'[0-9]{3,}\\s*[x\u00d7]\\s*[0-9]{3,}';

UPDATE "Template" SET "displayType" = 'LCD'
WHERE graphics IS NOT NULL AND (graphics LIKE '%LCD%' OR graphics LIKE '%LED-backlit%');

UPDATE "Template" SET "displayType" = 'CRT'
WHERE graphics IS NOT NULL AND "displayType" IS NULL
  AND (graphics LIKE '%CRT%' OR graphics LIKE '%Trinitron%');

UPDATE "Template" SET "displayType" = 'Monochrome'
WHERE graphics IS NOT NULL AND "displayType" IS NULL AND graphics LIKE '%monochrome%';

UPDATE "Template" SET "displayVariant" = 'Active Matrix'
WHERE graphics IS NOT NULL AND graphics LIKE '%Active Matrix%';

UPDATE "Template" SET "displayVariant" = 'Passive Matrix'
WHERE graphics IS NOT NULL AND graphics LIKE '%Passive Matrix%';

UPDATE "Template" SET "displayVariant" = 'Sony Trinitron'
WHERE graphics IS NOT NULL AND graphics LIKE '%Sony Trinitron%';

UPDATE "Template" SET "displayVariant" = 'Diamondtron'
WHERE graphics IS NOT NULL AND graphics LIKE '%Diamondtron%';

UPDATE "Template" SET "displayVariant" = 'Retina'
WHERE graphics IS NOT NULL AND graphics LIKE '%Retina%';

UPDATE "Template" SET "displayVariant" = 'LED-backlit'
WHERE graphics IS NOT NULL AND graphics LIKE '%LED-backlit%';

UPDATE "Template" SET "graphicsChip" = TRIM(graphics)
WHERE graphics IS NOT NULL
  AND graphics NOT LIKE 'Text:%'
  AND graphics NOT LIKE '%monochrome%'
  AND graphics NOT LIKE '% CRT%'
  AND graphics NOT LIKE '% LCD%'
  AND graphics NOT LIKE E'%\u00d7%'
  AND graphics NOT LIKE E'%"%'
  AND graphics NOT LIKE 'Built-in %';

UPDATE "Template" SET "graphicsChip" = TRIM(graphics)
WHERE graphics IS NOT NULL AND graphics IN (
  'Built-in video',
  'Built-in video + AV capabilities',
  'Built-in video + optional Apple or third-party video card',
  'Integrated video',
  'Optional Apple or third-party video card',
  'PCI video card',
  'IMS Twin Turbo PCI video card'
);

ALTER TABLE "Template" DROP COLUMN "cpu", DROP COLUMN "graphics";
