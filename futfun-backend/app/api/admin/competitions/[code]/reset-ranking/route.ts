import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const POST = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { code } = context.params;
    const { prisma } = getContainer();

    const competition = await prisma.competition.findUnique({ where: { code } });
    if (!competition) {
      return NextResponse.json({ error: 'Campeonato não encontrado' }, { status: 404 });
    }

    const [deletedStats, deletedHistory] = await prisma.$transaction([
      prisma.userCompetitionStats.deleteMany({ where: { competitionCode: code } }),
      prisma.rankingHistory.deleteMany({ where: { competitionCode: code } }),
    ]);

    return NextResponse.json({
      message: `Ranking de "${competition.name}" reiniciado com sucesso`,
      deleted: {
        stats: deletedStats.count,
        history: deletedHistory.count,
      },
    });
  } catch (error) {
    return handleError(error);
  }
});
