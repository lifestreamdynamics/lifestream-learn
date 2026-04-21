-- AlterTable
ALTER TABLE "Video" ADD COLUMN "defaultCaptionLanguage" TEXT;

-- CreateTable
CREATE TABLE "VideoCaption" (
    "id" UUID NOT NULL,
    "videoId" UUID NOT NULL,
    "language" TEXT NOT NULL,
    "vttKey" TEXT NOT NULL,
    "bytes" INTEGER NOT NULL,
    "uploadedBy" UUID NOT NULL,
    "uploadedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VideoCaption_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "VideoCaption_videoId_language_key" ON "VideoCaption"("videoId", "language");

-- CreateIndex
CREATE INDEX "VideoCaption_videoId_idx" ON "VideoCaption"("videoId");

-- AddForeignKey
ALTER TABLE "VideoCaption" ADD CONSTRAINT "VideoCaption_videoId_fkey" FOREIGN KEY ("videoId") REFERENCES "Video"("id") ON DELETE CASCADE ON UPDATE CASCADE;
