import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

type HistoryRow = {
  matchId: string;
  kickoffTime: Date;
  stage: string;
  groupName: string | null;
  matchday: number | null;
  pointsEarned: number;
  totalPoints: number;
};

function formatRoundStage(stage: string, matchday: number | null, groupName: string | null): string {
  const label = stage.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  if (groupName) return `${label} · Grupo ${groupName}`;
  if (matchday != null) return `${label} · Rodada ${matchday}`;
  return label;
}

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    const rows = await prisma.$queryRaw<HistoryRow[]>`
      SELECT
        p."matchId",
        m."kickoffTime",
        m.stage,
        m."groupName",
        m.matchday,
        p.points                                                             AS "pointsEarned",
        SUM(p.points) OVER (
          ORDER BY m."kickoffTime"
          ROWS UNBOUNDED PRECEDING
        )::int                                                               AS "totalPoints"
      FROM predictions p
      JOIN matches m ON m.id = p."matchId"
      WHERE p."userId" = ${user.userId}
        AND m."competitionCode" = ${competitionCode}
        AND m.status = 'FINISHED'
        AND p.points IS NOT NULL
      ORDER BY m."kickoffTime" ASC
    `;

    const history = rows.map((row) => ({
      snapshotKey: row.matchId,
      roundStage: formatRoundStage(row.stage, row.matchday, row.groupName),
      pointsEarned: row.pointsEarned,
      totalPoints: row.totalPoints,
      position: 0, // not displayed in the UI; historical position removed with aggregation tables
      snapshotAt: row.kickoffTime.toISOString(),
    }));

    return NextResponse.json({ history });
  } catch (error) {
    return handleError(error);
  }
});
