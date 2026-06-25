import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

/**
 * POST /api/admin/competitions/[code]/rescore
 *
 * Recalcula os pontos de todos os palpites de partidas encerradas do campeonato.
 * 1. Reseta scoredAt / points em todas as predictions do campeonato
 * 2. Roda scorePendingPredictions para recomputar tudo
 *
 * O ranking é atualizado automaticamente via view — sem tabelas de agregação.
 */
export const POST = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { code } = await context.params;
    const { prisma, matchSyncJob } = getContainer();

    const competition = await prisma.competition.findUnique({ where: { code } });
    if (!competition) {
      return NextResponse.json({ error: 'Campeonato não encontrado' }, { status: 404 });
    }

    const matches = await prisma.match.findMany({
      where: { competitionCode: code, status: 'FINISHED' },
      select: { id: true },
    });
    const matchIds = matches.map((m) => m.id);

    const reset = await prisma.prediction.updateMany({
      where: { matchId: { in: matchIds } },
      data: { scoredAt: null, points: null },
    });

    // Re-score in background — response returns immediately
    matchSyncJob.scorePendingPredictions().catch((err: Error) =>
      console.error('[Rescore] scorePendingPredictions failed:', err),
    );

    return NextResponse.json({
      message: `Ranking de "${competition.name}" sendo recalculado`,
      reset: { predictions: reset.count },
    });
  } catch (error) {
    return handleError(error);
  }
});
