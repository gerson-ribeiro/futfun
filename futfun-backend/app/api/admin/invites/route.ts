// app/api/admin/invites/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { CreateInviteHandler } from '@application/handlers/CreateInviteHandler';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({ email: z.string().email() });

export const POST = withAdmin(async (req: NextRequest, user: TokenPayload) => {
  try {
    const body = await req.json();
    const { email } = schema.parse(body);

    const { prisma, emailService } = getContainer();
    const handler = new CreateInviteHandler(prisma, emailService);

    const adminUser = await prisma.user.findUnique({
      where: { id: user.userId },
      select: { displayName: true },
    });

    const result = await handler.handle({
      email,
      createdBy: user.userId,
      inviterName: adminUser?.displayName || 'Admin',
    });

    const webAppUrl = process.env.WEB_APP_URL ?? process.env.APP_BASE_URL ?? '';
    const inviteUrl = `${webAppUrl}/#/invite?token=${result.inviteToken}`;

    return NextResponse.json(
      { inviteId: result.inviteId, inviteUrl, emailSent: result.emailSent },
      { status: 201 }
    );
  } catch (error) {
    return handleError(error);
  }
});

export const GET = withAdmin(async (_req: NextRequest) => {
  try {
    const { prisma } = getContainer();
    const invites = await prisma.invite.findMany({
      select: {
        id: true,
        email: true,
        expiresAt: true,
        usedAt: true,
        createdAt: true,
        creator: { select: { displayName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return NextResponse.json({ invites });
  } catch (error) {
    return handleError(error);
  }
});
