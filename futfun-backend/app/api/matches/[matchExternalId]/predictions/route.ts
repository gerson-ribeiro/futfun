import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError, AppError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (
  _req: NextRequest,
  user: TokenPayload,
  { params }: { params: Promise<{ matchExternalId: string }> },
) => {
  try {
    const { matchExternalId } = await params;
    const externalId = parseInt(matchExternalId, 10);
    if (isNaN(externalId)) {
      return NextResponse.json({ error: 'Invalid matchExternalId' }, { status: 400 });
    }

    const { prisma } = getContainer();

    const match = await prisma.match.findUnique({ where: { externalId } });
    if (!match) throw new AppError('Match not found', 'MATCH_NOT_FOUND', 404);

    const predictions = await prisma.prediction.findMany({
      where: { matchId: match.id },
      include: { user: { select: { id: true, displayName: true } } },
    });

    const isFinished = match.status === 'FINISHED';

    const result = predictions
      .map((p) => ({
        displayName: p.user.displayName,
        predictedHome: p.predictedHome,
        predictedAway: p.predictedAway,
        points: p.points,
        isCurrentUser: p.userId === user.userId,
      }))
      .sort((a, b) => {
        if (isFinished) {
          const ptsDiff = (b.points ?? -1) - (a.points ?? -1);
          if (ptsDiff !== 0) return ptsDiff;
        }
        return a.displayName.localeCompare(b.displayName);
      });

    return NextResponse.json({ predictions: result, matchStatus: match.status });
  } catch (error) {
    return handleError(error);
  }
});
