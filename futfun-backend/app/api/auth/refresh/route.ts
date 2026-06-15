import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

const schema = z.object({ refreshToken: z.string() });

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { refreshToken } = schema.parse(body);

    const tokenService = new JwtTokenService();
    const { prisma } = getContainer();

    const payload = tokenService.verifyRefreshToken(refreshToken);
    const stored = await prisma.refreshToken.findUnique({
      where: { userId: payload.userId },
    });

    if (!stored || stored.token !== refreshToken || stored.expiresAt < new Date()) {
      return NextResponse.json(
        { error: { message: 'Invalid refresh token', code: 'INVALID_REFRESH_TOKEN' } },
        { status: 401 }
      );
    }

    const user = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!user) {
      return NextResponse.json(
        { error: { message: 'User not found', code: 'USER_NOT_FOUND' } },
        { status: 404 }
      );
    }

    // Always use current role from DB to reflect any permission changes
    const newPayload: TokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role as TokenPayload['role'],
    };

    const accessToken = tokenService.generateAccessToken(newPayload);
    return NextResponse.json({ accessToken });
  } catch (error) {
    return handleError(error);
  }
}
