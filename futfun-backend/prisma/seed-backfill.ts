// prisma/seed-backfill.ts
// Run once after deploy to populate user_competition_stats from existing scored predictions.
// Safe to run multiple times (uses upsert).

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg(process.env.DATABASE_URL!);
const prisma = new PrismaClient({ adapter });

async function main() {
  const scored = await prisma.prediction.findMany({
    where: { points: { not: null } },
    include: { match: { select: { competitionCode: true } } },
  });

  const statsMap = new Map<
    string,
    { totalPoints: number; exactScores: number; correctResults: number; matchesPredicted: number }
  >();

  for (const p of scored) {
    const code = p.match.competitionCode;
    if (!code || p.points === null) continue;

    const key = `${p.userId}::${code}`;
    const s = statsMap.get(key) ?? { totalPoints: 0, exactScores: 0, correctResults: 0, matchesPredicted: 0 };
    s.totalPoints += p.points;
    s.exactScores += p.points === 10 ? 1 : 0;
    // correctResults = correct result but NOT exact score (matches Ranking table logic)
    s.correctResults += (p.points === 5 || p.points === 7) ? 1 : 0;
    s.matchesPredicted += 1;
    statsMap.set(key, s);
  }

  let count = 0;
  for (const [key, stats] of statsMap.entries()) {
    const [userId, competitionCode] = key.split('::');
    await prisma.userCompetitionStats.upsert({
      where: { userId_competitionCode: { userId, competitionCode } },
      create: { userId, competitionCode, ...stats, lastCalculatedAt: new Date() },
      update: { ...stats, lastCalculatedAt: new Date() },
    });
    count++;
  }

  console.log(`Backfill complete: ${count} user_competition_stats rows upserted from ${scored.length} scored predictions.`);
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
