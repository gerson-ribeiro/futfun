// app/api/admin/users/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const GET = withAdmin(async (_req: NextRequest) => {
  try {
    const { prisma } = getContainer();
    const users = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        displayName: true,
        provider: true,
        role: true,
        createdAt: true,
        lastLoginAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });
    return NextResponse.json({ users });
  } catch (error) {
    return handleError(error);
  }
});
