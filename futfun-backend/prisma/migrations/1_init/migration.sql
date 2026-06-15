-- CreateTable "users"
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "microsoftId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "tenantId" TEXT NOT NULL,
    "passwordHash" TEXT,
    "isPasswordSet" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastLoginAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable "matches"
CREATE TABLE "matches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "externalId" INTEGER NOT NULL,
    "homeTeamId" INTEGER NOT NULL,
    "homeTeamName" TEXT NOT NULL,
    "homeTeamShort" TEXT,
    "homeTeamCrest" TEXT,
    "awayTeamId" INTEGER NOT NULL,
    "awayTeamName" TEXT NOT NULL,
    "awayTeamShort" TEXT,
    "awayTeamCrest" TEXT,
    "kickoffTime" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'SCHEDULED',
    "scoreHome" INTEGER,
    "scoreAway" INTEGER,
    "stage" TEXT NOT NULL,
    "groupName" TEXT,
    "matchday" INTEGER,
    "lastSyncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable "predictions"
CREATE TABLE "predictions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "matchId" UUID NOT NULL,
    "predictedHome" INTEGER NOT NULL,
    "predictedAway" INTEGER NOT NULL,
    "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lockedAt" TIMESTAMP(3) NOT NULL,
    "points" INTEGER,
    "scoredAt" TIMESTAMP(3),

    CONSTRAINT "predictions_pkey" PRIMARY KEY ("id")
);

-- CreateTable "rankings"
CREATE TABLE "rankings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "totalPoints" INTEGER NOT NULL DEFAULT 0,
    "exactScores" INTEGER NOT NULL DEFAULT 0,
    "correctResults" INTEGER NOT NULL DEFAULT 0,
    "matchesPredicted" INTEGER NOT NULL DEFAULT 0,
    "lastCalculatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rankings_pkey" PRIMARY KEY ("id")
);

-- CreateTable "ranking_history"
CREATE TABLE "ranking_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "snapshotKey" TEXT NOT NULL,
    "matchday" INTEGER,
    "roundStage" TEXT NOT NULL,
    "pointsEarned" INTEGER NOT NULL DEFAULT 0,
    "totalPoints" INTEGER NOT NULL DEFAULT 0,
    "exactScores" INTEGER NOT NULL DEFAULT 0,
    "correctResults" INTEGER NOT NULL DEFAULT 0,
    "position" INTEGER NOT NULL,
    "snapshotAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ranking_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_microsoftId_key" ON "users"("microsoftId");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "matches_externalId_key" ON "matches"("externalId");

-- CreateIndex
CREATE INDEX "matches_kickoffTime_idx" ON "matches"("kickoffTime");

-- CreateIndex
CREATE INDEX "matches_status_idx" ON "matches"("status");

-- CreateIndex
CREATE UNIQUE INDEX "predictions_userId_matchId_key" ON "predictions"("userId", "matchId");

-- CreateIndex
CREATE INDEX "predictions_userId_idx" ON "predictions"("userId");

-- CreateIndex
CREATE INDEX "predictions_matchId_idx" ON "predictions"("matchId");

-- CreateIndex
CREATE UNIQUE INDEX "rankings_userId_key" ON "rankings"("userId");

-- CreateIndex
CREATE INDEX "rankings_totalPoints_idx" ON "rankings"("totalPoints");

-- CreateIndex
CREATE UNIQUE INDEX "ranking_history_userId_snapshotKey_key" ON "ranking_history"("userId", "snapshotKey");

-- CreateIndex
CREATE INDEX "ranking_history_userId_snapshotKey_idx" ON "ranking_history"("userId", "snapshotKey");

-- AddForeignKey
ALTER TABLE "predictions" ADD CONSTRAINT "predictions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "predictions" ADD CONSTRAINT "predictions_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rankings" ADD CONSTRAINT "rankings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ranking_history" ADD CONSTRAINT "ranking_history_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
