import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

/**
 * POST /api/admin/competitions/[code]/rescore
 *
 * Full ranking recalculation for a competition:
 * 1. Deletes userCompetitionStats and rankingHistory for the competition
 * 2. Resets scoredAt / points on all predictions for that competition's matches
 * 3. Immediately runs scorePendingPredictions to rebuild everything from match scores
 *
 * Use this when the ranking is out of sync with actual predictions.
 */
export const POST = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { code } = context.params;
    const { prisma, matchSyncJob } = getContainer();

    const competition = await prisma.competition.findUnique({ where: { code } });
    if (!competition) {
      return NextResponse.json({ error: 'Campeonato não encontrado' }, { status: 404 });
    }

    // 1. Find all match IDs for this competition
    const matches = await prisma.match.findMany({
      where: { competitionCode: code, status: 'FINISHED' },
      select: { id: true },
    });
    const matchIds = matches.map((m) => m.id);

    // 2. Reset stats and history, and un-score all predictions in one transaction
    const [deletedStats, deletedHistory, resetPredictions] = await prisma.$transaction([
      prisma.userCompetitionStats.deleteMany({ where: { competitionCode: code } }),
      prisma.rankingHistory.deleteMany({ where: { competitionCode: code } }),
      prisma.prediction.updateMany({
        where: { matchId: { in: matchIds } },
        data: { scoredAt: null, points: null },
      }),
    ]);

    // 3. Re-score all predictions for FINISHED matches with scores available
    // Run in background — response returns before scoring completes
    matchSyncJob.scorePendingPredictions().catch((err: Error) =>
      console.error('[Rescore] scorePendingPredictions failed:', err),
    );

    return NextResponse.json({
      message: `Ranking de "${competition.name}" sendo recalculado`,
      reset: {
        stats: deletedStats.count,
        history: deletedHistory.count,
        predictions: resetPredictions.count,
      },
    });
  } catch (error) {
    return handleError(error);
  }
});
