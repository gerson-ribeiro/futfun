import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const { prisma } = getContainer();
    const { searchParams } = req.nextUrl;

    const stage = searchParams.get('stage');
    const status = searchParams.get('status');
    const matchday = searchParams.get('matchday');
    const competitionCode = searchParams.get('competitionCode');
    const dateFrom = searchParams.get('dateFrom');
    const dateTo = searchParams.get('dateTo');
    const nationalTeamsOnly = searchParams.get('nationalTeamsOnly') === 'true';

    // Build conditions as an array to avoid key conflicts when merging AND/OR clauses
    const conditions: object[] = [];

    if (stage) conditions.push({ stage });
    if (status) conditions.push({ status });
    if (matchday) conditions.push({ matchday: parseInt(matchday, 10) });

    if (dateFrom || dateTo) {
      const kickoffFilter: Record<string, Date> = {};
      if (dateFrom) kickoffFilter.gte = new Date(dateFrom);
      if (dateTo) kickoffFilter.lte = new Date(dateTo);
      conditions.push({ kickoffTime: kickoffFilter });
    }

    // National teams filter: exclude known club teams; null type = not yet classified = show match
    if (nationalTeamsOnly) {
      conditions.push({ OR: [{ homeTeamType: 'NATIONAL' }, { homeTeamType: null }] });
      conditions.push({ OR: [{ awayTeamType: 'NATIONAL' }, { awayTeamType: null }] });
    }

    if (competitionCode) {
      conditions.push({ competitionCode });
    } else {
      const [enabledCompetitions, hiddenPrefs] = await Promise.all([
        prisma.competition.findMany({ where: { enabled: true }, select: { code: true } }),
        prisma.userCompetitionPreference.findMany({
          where: { userId: user.userId, hidden: true },
          select: { competitionCode: true },
        }),
      ]);

      const hiddenCodes = new Set(hiddenPrefs.map((p: { competitionCode: string }) => p.competitionCode));
      const visibleCodes = enabledCompetitions
        .map((c: { code: string }) => c.code)
        .filter((code: string) => !hiddenCodes.has(code));

      conditions.push({
        OR: [
          { competitionCode: { in: visibleCodes } },
          { competitionCode: null },
        ],
      });
    }

    const matches = await prisma.match.findMany({
      where: conditions.length > 0 ? { AND: conditions } : {},
      orderBy: { kickoffTime: 'asc' },
      take: 200,
    });

    return NextResponse.json({ matches });
  } catch (error) {
    return handleError(error);
  }
});
