// app/api/auth/microsoft/login/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { MicrosoftOAuthService } from '@infrastructure/auth/MicrosoftOAuthService';
import { handleError } from '@presentation/middleware/errorHandler';

export async function GET(req: NextRequest) {
  try {
    const state = req.nextUrl.searchParams.get('state') || '';
    const service = new MicrosoftOAuthService();
    const authUrl = service.getAuthorizationUrl(state);
    return NextResponse.json({ authUrl });
  } catch (error) {
    return handleError(error);
  }
}
