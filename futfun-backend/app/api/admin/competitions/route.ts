import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

const createSchema = z.object({
  code: z.string().min(2).max(10),
  name: z.string().min(2).max(100),
});

export const GET = withAdmin(async (_req: NextRequest) => {
  try {
    const { prisma } = getContainer();
    const competitions = await prisma.competition.findMany({
      orderBy: { createdAt: 'asc' },
    });
    return NextResponse.json({ competitions });
  } catch (error) {
    return handleError(error);
  }
});

export const POST = withAdmin(async (req: NextRequest) => {
  try {
    const body = await req.json();
    const { code, name } = createSchema.parse(body);
    const { prisma } = getContainer();

    const competition = await prisma.competition.create({
      data: { code: code.toUpperCase(), name },
    });
    return NextResponse.json({ competition }, { status: 201 });
  } catch (error) {
    return handleError(error);
  }
});
