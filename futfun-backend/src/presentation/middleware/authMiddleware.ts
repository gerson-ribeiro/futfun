// src/presentation/middleware/authMiddleware.ts

import { NextRequest, NextResponse } from 'next/server';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { TokenPayload } from '@application/ports/ITokenService';

export function withAuth(
  handler: (req: NextRequest, user: TokenPayload, context?: any) => Promise<NextResponse>
) {
  return async (req: NextRequest, context?: any): Promise<NextResponse> => {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: { message: 'Missing or invalid Authorization header', code: 'UNAUTHORIZED' } },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    const tokenService = new JwtTokenService();

    try {
      const user = tokenService.verifyAccessToken(token);
      return handler(req, user, context);
    } catch {
      return NextResponse.json(
        { error: { message: 'Invalid or expired token', code: 'TOKEN_EXPIRED' } },
        { status: 401 }
      );
    }
  };
}

export function withAdmin(
  handler: (req: NextRequest, user: TokenPayload, context?: any) => Promise<NextResponse>
) {
  return withAuth(async (req, user, context) => {
    if (user.role !== 'ADMIN') {
      return NextResponse.json(
        { error: { message: 'Forbidden', code: 'FORBIDDEN' } },
        { status: 403 }
      );
    }
    return handler(req, user, context);
  });
}
