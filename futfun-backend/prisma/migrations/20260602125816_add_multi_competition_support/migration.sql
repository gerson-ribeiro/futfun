-- AlterTable
ALTER TABLE "matches" ADD COLUMN     "competitionCode" TEXT;

-- CreateTable
CREATE TABLE "competitions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "competitions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_competition_preferences" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "competitionCode" TEXT NOT NULL,
    "hidden" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "user_competition_preferences_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "competitions_code_key" ON "competitions"("code");

-- CreateIndex
CREATE INDEX "user_competition_preferences_userId_idx" ON "user_competition_preferences"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "user_competition_preferences_userId_competitionCode_key" ON "user_competition_preferences"("userId", "competitionCode");

-- CreateIndex
CREATE INDEX "matches_competitionCode_idx" ON "matches"("competitionCode");

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_competitionCode_fkey" FOREIGN KEY ("competitionCode") REFERENCES "competitions"("code") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_competition_preferences" ADD CONSTRAINT "user_competition_preferences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
