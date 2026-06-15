import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const patchSchema = z.object({
  hidden: z.boolean(),
});

export const PATCH = withAuth(async (req: NextRequest, user: TokenPayload, context: any) => {
  try {
    const { code } = context.params;
    const body = await req.json();
    const { hidden } = patchSchema.parse(body);
    const { prisma } = getContainer();

    const preference = await prisma.userCompetitionPreference.upsert({
      where: { userId_competitionCode: { userId: user.userId, competitionCode: code } },
      create: { userId: user.userId, competitionCode: code, hidden },
      update: { hidden },
    });
    return NextResponse.json({ preference });
  } catch (error) {
    return handleError(error);
  }
});
