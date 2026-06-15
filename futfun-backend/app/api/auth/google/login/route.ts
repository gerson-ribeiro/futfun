// app/api/auth/google/login/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { GoogleOAuthService } from '@infrastructure/auth/GoogleOAuthService';
import { handleError } from '@presentation/middleware/errorHandler';

export async function GET(req: NextRequest) {
  try {
    const state = req.nextUrl.searchParams.get('state') || '';
    const service = new GoogleOAuthService();
    const authUrl = service.getAuthorizationUrl(state);
    return NextResponse.json({ authUrl });
  } catch (error) {
    return handleError(error);
  }
}
