import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError, AppError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (
  req: NextRequest,
  _user: TokenPayload,
  { params }: { params: Promise<{ userId: string }> },
) => {
  try {
    const { userId } = await params;
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { displayName: true },
    });
    if (!user) throw new AppError('User not found', 'USER_NOT_FOUND', 404);

    const predictions = await prisma.prediction.findMany({
      where: {
        userId,
        match: {
          status: 'FINISHED',
          competitionCode,
        },
      },
      include: {
        match: {
          select: {
            homeTeamName: true,
            homeTeamShort: true,
            awayTeamName: true,
            awayTeamShort: true,
            scoreHome: true,
            scoreAway: true,
            kickoffTime: true,
          },
        },
      },
      orderBy: { match: { kickoffTime: 'desc' } },
    });

    const result = predictions.map((p) => ({
      matchHomeTeam: p.match.homeTeamShort ?? p.match.homeTeamName,
      matchAwayTeam: p.match.awayTeamShort ?? p.match.awayTeamName,
      matchScoreHome: p.match.scoreHome,
      matchScoreAway: p.match.scoreAway,
      kickoffTime: p.match.kickoffTime.toISOString(),
      predictedHome: p.predictedHome,
      predictedAway: p.predictedAway,
      points: p.points,
    }));

    return NextResponse.json({ displayName: user.displayName, predictions: result });
  } catch (error) {
    return handleError(error);
  }
});
