import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError, AppError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (
  _req: NextRequest,
  _user: TokenPayload,
  { params }: { params: Promise<{ matchId: string }> }
) => {
  try {
    const { matchId } = await params;
    const { prisma } = getContainer();

    const match = await prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new AppError('Match not found', 'MATCH_NOT_FOUND', 404);

    return NextResponse.json({ match });
  } catch (error) {
    return handleError(error);
  }
});
