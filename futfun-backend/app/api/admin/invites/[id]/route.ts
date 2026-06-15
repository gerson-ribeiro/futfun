// app/api/admin/invites/[id]/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const DELETE = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { id } = context.params;
    const { prisma } = getContainer();

    const invite = await prisma.invite.findUnique({ where: { id } });
    if (!invite) {
      return NextResponse.json(
        { error: { message: 'Invite not found', code: 'INVITE_NOT_FOUND' } },
        { status: 404 }
      );
    }
    if (invite.usedAt) {
      return NextResponse.json(
        { error: { message: 'Cannot cancel an already used invite', code: 'INVITE_ALREADY_USED' } },
        { status: 400 }
      );
    }

    await prisma.invite.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (error) {
    return handleError(error);
  }
});
