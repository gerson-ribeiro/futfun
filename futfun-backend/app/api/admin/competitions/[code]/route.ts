import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

const patchSchema = z.object({
  enabled: z.boolean(),
});

export const PATCH = withAdmin(async (req: NextRequest, _user: any, context: any) => {
  try {
    const { code } = context.params;
    const body = await req.json();
    const { enabled } = patchSchema.parse(body);
    const { prisma } = getContainer();

    const competition = await prisma.competition.update({
      where: { code },
      data: { enabled },
    });
    return NextResponse.json({ competition });
  } catch (error) {
    return handleError(error);
  }
});
