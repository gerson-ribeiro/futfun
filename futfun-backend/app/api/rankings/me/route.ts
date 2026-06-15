import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    // Mesma lógica do /rankings para determinar a posição real do usuário
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

    const entries = users.map((u) => {
      const stats = u.competitionStats[0];
      return {
        userId: u.id,
        displayName: u.displayName,
        totalPoints: stats?.totalPoints ?? 0,
        exactScores: stats?.exactScores ?? 0,
        correctResults: stats?.correctResults ?? 0,
        matchesPredicted: stats?.matchesPredicted ?? 0,
      };
    });

    entries.sort((a, b) => {
      if (b.totalPoints !== a.totalPoints) return b.totalPoints - a.totalPoints;
      if (b.exactScores !== a.exactScores) return b.exactScores - a.exactScores;
      if (b.correctResults !== a.correctResults) return b.correctResults - a.correctResults;
      return a.matchesPredicted - b.matchesPredicted;
    });

    const positionIndex = entries.findIndex((e) => e.userId === user.userId);

    if (positionIndex === -1) {
      return NextResponse.json({ ranking: null });
    }

    const entry = entries[positionIndex];
    return NextResponse.json({
      ranking: {
        position: positionIndex + 1,
        ...entry,
      },
    });
  } catch (error) {
    return handleError(error);
  }
});
