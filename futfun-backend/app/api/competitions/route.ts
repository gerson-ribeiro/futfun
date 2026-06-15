import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (_req: NextRequest, user: TokenPayload) => {
  try {
    const { prisma } = getContainer();

    const [competitions, preferences, statsGroups] = await Promise.all([
      prisma.competition.findMany({
        where: { enabled: true },
        orderBy: { createdAt: 'asc' },
      }),
      prisma.userCompetitionPreference.findMany({
        where: { userId: user.userId },
        select: { competitionCode: true, hidden: true },
      }),
      prisma.userCompetitionStats.groupBy({
        by: ['competitionCode'],
        where: { totalPoints: { gt: 0 } },
        _count: { userId: true },
      }),
    ]);

    const hiddenSet = new Set(
      preferences.filter((p) => p.hidden).map((p) => p.competitionCode),
    );
    const codesWithData = new Set(statsGroups.map((s) => s.competitionCode));

    const result = competitions.map((c) => ({
      ...c,
      hidden: hiddenSet.has(c.code),
      hasRankingData: codesWithData.has(c.code),
    }));

    return NextResponse.json({ competitions: result });
  } catch (error) {
    return handleError(error);
  }
});
