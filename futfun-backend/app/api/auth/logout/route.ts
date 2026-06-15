// app/api/auth/logout/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';

export const POST = withAuth(async (_req: NextRequest, user) => {
  const { prisma } = getContainer();
  await prisma.refreshToken.deleteMany({ where: { userId: user.userId } });
  return NextResponse.json({ success: true });
});
