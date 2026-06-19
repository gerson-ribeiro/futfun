import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({
  token: z.string().min(1),
  platform: z.enum(['android', 'web']),
});

export const POST = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const body = await req.json();
    const { token, platform } = schema.parse(body);
    const { prisma } = getContainer();

    await prisma.deviceToken.upsert({
      where: { token },
      create: { userId: user.userId, token, platform },
      update: { userId: user.userId, platform },
    });

    return NextResponse.json({ ok: true }, { status: 201 });
  } catch (error) {
    return handleError(error);
  }
});

export const DELETE = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const body = await req.json();
    const { token } = z.object({ token: z.string().min(1) }).parse(body);
    const { prisma } = getContainer();

    await prisma.deviceToken.deleteMany({
      where: { userId: user.userId, token },
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return handleError(error);
  }
});
