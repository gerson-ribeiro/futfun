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

    const history = await prisma.rankingHistory.findMany({
      where: { userId: user.userId, competitionCode },
      orderBy: { snapshotAt: 'asc' },
    });

    return NextResponse.json({ history });
  } catch (error) {
    return handleError(error);
  }
});
