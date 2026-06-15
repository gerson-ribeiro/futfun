-- AlterTable
ALTER TABLE "competitions" ADD COLUMN     "color" TEXT,
ADD COLUMN     "providerConfig" JSONB;

-- AlterTable
ALTER TABLE "ranking_history" ADD COLUMN     "competitionCode" TEXT;

-- CreateTable
CREATE TABLE "user_competition_stats" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "competitionCode" TEXT NOT NULL,
    "totalPoints" INTEGER NOT NULL DEFAULT 0,
    "exactScores" INTEGER NOT NULL DEFAULT 0,
    "correctResults" INTEGER NOT NULL DEFAULT 0,
    "matchesPredicted" INTEGER NOT NULL DEFAULT 0,
    "lastCalculatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_competition_stats_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_competition_stats_competitionCode_totalPoints_idx" ON "user_competition_stats"("competitionCode", "totalPoints");

-- CreateIndex
CREATE UNIQUE INDEX "user_competition_stats_userId_competitionCode_key" ON "user_competition_stats"("userId", "competitionCode");

-- CreateIndex
CREATE INDEX "ranking_history_userId_competitionCode_idx" ON "ranking_history"("userId", "competitionCode");

-- AddForeignKey
ALTER TABLE "user_competition_stats" ADD CONSTRAINT "user_competition_stats_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_competition_stats" ADD CONSTRAINT "user_competition_stats_competitionCode_fkey" FOREIGN KEY ("competitionCode") REFERENCES "competitions"("code") ON DELETE CASCADE ON UPDATE CASCADE;
