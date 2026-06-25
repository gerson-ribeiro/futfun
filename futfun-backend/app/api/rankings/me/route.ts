import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

type RankingRow = {
  userId: string;
  displayName: string;
  matchesPredicted: number;
  totalPoints: number;
  exactScores: number;
  correctResults: number;
};

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    // Reuse the same query as /rankings — sort to determine position.
    const rows = await prisma.$queryRaw<RankingRow[]>`
      SELECT
        u.id                                      AS "userId",
        u."displayName",
        COALESCE(r."matchesPredicted", 0)::int    AS "matchesPredicted",
        COALESCE(r."totalPoints",      0)::int    AS "totalPoints",
        COALESCE(r."exactScores",      0)::int    AS "exactScores",
        COALESCE(r."correctResults",   0)::int    AS "correctResults"
      FROM users u
      LEFT JOIN "user_competition_ranking" r
        ON r."userId" = u.id AND r."competitionCode" = ${competitionCode}
      WHERE u.role IN ('MEMBER', 'ADMIN')
      ORDER BY
        COALESCE(r."totalPoints",      0) DESC,
        COALESCE(r."exactScores",      0) DESC,
        COALESCE(r."correctResults",   0) DESC,
        COALESCE(r."matchesPredicted", 0) ASC
    `;

    const positionIndex = rows.findIndex((r) => r.userId === user.userId);
    if (positionIndex === -1) {
      return NextResponse.json({ ranking: null });
    }

    return NextResponse.json({
      ranking: {
        position: positionIndex + 1,
        ...rows[positionIndex],
      },
    });
  } catch (error) {
    return handleError(error);
  }
});
