-- Migration: add SOFTWARE category type + software-specific Device fields

ALTER TYPE "CategoryType" ADD VALUE IF NOT EXISTS 'SOFTWARE';

ALTER TABLE "Device"
  ADD COLUMN IF NOT EXISTS "platform" TEXT,
  ADD COLUMN IF NOT EXISTS "licenceKey" TEXT,
  ADD COLUMN IF NOT EXISTS "requiresDongle" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "downloadUrl" TEXT,
  ADD COLUMN IF NOT EXISTS "localPath" TEXT,
  ADD COLUMN IF NOT EXISTS "hasOriginalManuals" BOOLEAN NOT NULL DEFAULT false;
