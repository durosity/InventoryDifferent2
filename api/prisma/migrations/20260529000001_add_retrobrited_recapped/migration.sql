-- Migration: add isRetroBrited and isRecapped boolean flags to Device

ALTER TABLE "Device"
  ADD COLUMN IF NOT EXISTS "isRetroBrited" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "isRecapped"    BOOLEAN NOT NULL DEFAULT false;
