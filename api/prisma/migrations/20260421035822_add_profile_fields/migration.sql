-- AlterTable
ALTER TABLE "User" ADD COLUMN     "avatarKey" TEXT,
ADD COLUMN     "preferences" JSONB,
ADD COLUMN     "useGravatar" BOOLEAN NOT NULL DEFAULT false;
