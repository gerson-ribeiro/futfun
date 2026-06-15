// app/api/admin/invites/[id]/resend/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { randomUUID } from 'crypto';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const POST = withAdmin(async (_req: NextRequest, user: TokenPayload, context: any) => {
  try {
    const { id } = context.params;
    const { prisma, emailService } = getContainer();

    const invite = await prisma.invite.findUnique({ where: { id } });
    if (!invite) {
      return NextResponse.json(
        { error: { message: 'Invite not found', code: 'INVITE_NOT_FOUND' } },
        { status: 404 }
      );
    }
    if (invite.usedAt) {
      return NextResponse.json(
        { error: { message: 'Cannot resend an already used invite', code: 'INVITE_ALREADY_USED' } },
        { status: 400 }
      );
    }

    const newToken = randomUUID();
    const newExpiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await prisma.invite.update({
      where: { id },
      data: { token: newToken, expiresAt: newExpiresAt },
    });

    const adminUser = await prisma.user.findUnique({
      where: { id: user.userId },
      select: { displayName: true },
    });

    let emailSent = false;
    try {
      await emailService.sendInvite(invite.email, newToken, adminUser?.displayName || 'Admin');
      emailSent = true;
    } catch (err) {
      console.error('[Invite] Resend email failed (invite token still updated):', err);
    }

    const webAppUrl = process.env.WEB_APP_URL ?? process.env.APP_BASE_URL ?? '';
    const inviteUrl = `${webAppUrl}/#/invite?token=${newToken}`;

    return NextResponse.json({ success: true, inviteUrl, emailSent });
  } catch (error) {
    return handleError(error);
  }
});
