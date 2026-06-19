// app/api/admin/users/[id]/role/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { ResendEmailService } from '@infrastructure/email/ResendEmailService';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({ role: z.enum(['PENDING', 'MEMBER', 'ADMIN']) });

export const PATCH = withAdmin(async (req: NextRequest, _user: TokenPayload, context: any) => {
  try {
    const { id } = context.params;
    const body = await req.json();
    const { role } = schema.parse(body);

    const { prisma } = getContainer();

    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) {
      return NextResponse.json(
        { error: { message: 'User not found', code: 'USER_NOT_FOUND' } },
        { status: 404 }
      );
    }

    const wasPromotedToMember = target.role === 'PENDING' && role === 'MEMBER';

    const updated = await prisma.user.update({
      where: { id },
      data: { role },
      select: {
        id: true,
        email: true,
        displayName: true,
        role: true,
        provider: true,
        createdAt: true,
        lastLoginAt: true,
      },
    });

    if (wasPromotedToMember) {
      const emailService = new ResendEmailService();
      // Fire-and-forget: email failure must not roll back an already-committed approval
      emailService.sendApprovalNotification(updated.email, updated.displayName)
        .catch(err => console.error('[approval] Failed to send approval email:', err));
    }

    return NextResponse.json({ user: updated });
  } catch (error) {
    return handleError(error);
  }
});
