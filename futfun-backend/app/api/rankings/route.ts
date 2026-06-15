import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, _user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    // Busca todos os usuários elegíveis (MEMBER e ADMIN) com suas stats para esta liga
    const users = await prisma.user.findMany({
      where: { role: { in: ['MEMBER', 'ADMIN'] } },
      select: {
        id: true,
        displayName: true,
        competitionStats: {
          where: { competitionCode },
        },
      },
    });

    // Constrói entradas com 0s para quem não tem stats
    const entries = users.map((user) => {
      const stats = user.competitionStats[0];
      return {
        userId: user.id,
        displayName: user.displayName,
        totalPoints: stats?.totalPoints ?? 0,
        exactScores: stats?.exactScores ?? 0,
        correctResults: stats?.correctResults ?? 0,
        matchesPredicted: stats?.matchesPredicted ?? 0,
      };
    });

    // Ordena pelas regras de desempate
    entries.sort((a, b) => {
      if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
      if (b.exactScores !== a.exactScores) return b.exactScores - a.exactScores;
      if (b.correctResults !== a.correctResults) return b.correctResults - a.correctResults;
      return a.matchesPredicted - b.matchesPredicted;
    });

    const rankings = entries.map((entry, index) => ({
      position: index + 1,
      ...entry,
    }));

    return NextResponse.json({ rankings });
  } catch (error) {
    return handleError(error);
  }
});
