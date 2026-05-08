-- CreateEnum
CREATE TYPE "MediaType" AS ENUM ('IMAGE', 'VIDEO');

-- AlterTable
ALTER TABLE "Device" ALTER COLUMN "functionalStatus" SET DEFAULT 'UNKNOWN';

-- AlterTable
ALTER TABLE "Image" ADD COLUMN     "duration" INTEGER,
ADD COLUMN     "mediaType" "MediaType" NOT NULL DEFAULT 'IMAGE';

-- AlterTable
ALTER TABLE "ShowcaseJourney" ALTER COLUMN "publishedAt" SET DATA TYPE TIMESTAMP(3);
