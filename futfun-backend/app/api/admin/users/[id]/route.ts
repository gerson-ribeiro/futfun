// app/api/admin/users/[id]/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const DELETE = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  try {
    const { id } = context.params;
    const { prisma } = getContainer();

    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) {
      return NextResponse.json(
        { error: { message: 'User not found', code: 'USER_NOT_FOUND' } },
        { status: 404 }
      );
    }

    await prisma.user.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (error) {
    return handleError(error);
  }
});
