import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  try {
    const { token } = await params;
    const { prisma } = getContainer();
    const invite = await prisma.invite.findFirst({
      where: {
        token,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true, email: true, expiresAt: true },
    });

    if (!invite) {
      return NextResponse.json(
        { error: { message: 'Invite not found, expired, or already used', code: 'INVALID_INVITE' } },
        { status: 404 }
      );
    }

    return NextResponse.json({ valid: true, email: invite.email, expiresAt: invite.expiresAt });
  } catch (error) {
    return handleError(error);
  }
}
