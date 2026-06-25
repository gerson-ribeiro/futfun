import { PrismaClient } from '@prisma/client';

export async function applyStartupMigrations(prisma: PrismaClient): Promise<void> {
  try {
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS "device_tokens" (
        "id" UUID NOT NULL DEFAULT gen_random_uuid(),
        "userId" UUID NOT NULL,
        "token" TEXT NOT NULL,
        "platform" TEXT NOT NULL,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
      )
    `;

    await prisma.$executeRaw`
      CREATE UNIQUE INDEX IF NOT EXISTS "device_tokens_token_key" ON "device_tokens"("token")
    `;

    await prisma.$executeRaw`
      CREATE INDEX IF NOT EXISTS "device_tokens_userId_idx" ON "device_tokens"("userId")
    `;

    await prisma.$executeRaw`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE constraint_name = 'device_tokens_userId_fkey'
          AND constraint_type = 'FOREIGN KEY'
        ) THEN
          ALTER TABLE "device_tokens"
            ADD CONSTRAINT "device_tokens_userId_fkey"
            FOREIGN KEY ("userId") REFERENCES "users"("id")
            ON DELETE CASCADE ON UPDATE CASCADE;
        END IF;
      END $$
    `;

    console.log('[startup] device_tokens migration OK');
  } catch (err) {
    console.error('[startup] Migration failed (non-fatal, notifications may be unavailable):', err);
  }

  try {
    await prisma.$executeRaw`DROP TABLE IF EXISTS "user_competition_stats" CASCADE`;
    await prisma.$executeRaw`DROP TABLE IF EXISTS "ranking_history" CASCADE`;
    await prisma.$executeRaw`DROP TABLE IF EXISTS "rankings" CASCADE`;

    await prisma.$executeRaw`
      CREATE OR REPLACE VIEW "user_competition_ranking" AS
      SELECT
        p."userId",
        m."competitionCode",
        COUNT(*)::int                                                   AS "matchesPredicted",
        COALESCE(SUM(p.points), 0)::int                                 AS "totalPoints",
        COUNT(*) FILTER (WHERE p.points = 10)::int                      AS "exactScores",
        COUNT(*) FILTER (WHERE p.points = 5 OR p.points = 7)::int       AS "correctResults"
      FROM predictions p
      JOIN matches m ON m.id = p."matchId"
      WHERE m.status = 'FINISHED'
        AND p.points IS NOT NULL
      GROUP BY p."userId", m."competitionCode"
    `;

    console.log('[startup] ranking view migration OK');
  } catch (err) {
    console.error('[startup] Ranking view migration failed:', err);
  }
}
