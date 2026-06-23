// app/api/auth/microsoft/callback/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { createOAuthProvider } from '@infrastructure/auth/OAuthProviderFactory';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { OAuthCallbackHandler } from '@application/handlers/OAuthCallbackHandler';
import { getContainer } from '@infrastructure/container/container';

export async function GET(req: NextRequest) {
  const scheme = process.env.APP_DEEP_LINK_SCHEME || 'futfun';
  const webAppUrl = process.env.WEB_APP_URL;
  const errorUrl = `${scheme}://auth?error=true`;
  const webErrorUrl = webAppUrl ? `${webAppUrl}/#/login?error=auth` : errorUrl;

  const state = req.nextUrl.searchParams.get('state') || '';
  const isWeb = state === 'web';

  try {
    const code = req.nextUrl.searchParams.get('code');

    if (!code) {
      return NextResponse.redirect(isWeb ? webErrorUrl : errorUrl);
    }

    const oauthProvider = createOAuthProvider('microsoft');
    const tokenService = new JwtTokenService();
    const { prisma, notificationService } = getContainer();

    const handler = new OAuthCallbackHandler(oauthProvider, tokenService, prisma, notificationService);
    const result = await handler.handle({ code, provider: 'microsoft', state });

    if (isWeb && webAppUrl) {
      const params = new URLSearchParams({
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        userId: result.user.id,
        email: result.user.email,
        displayName: result.user.displayName,
        role: result.user.role,
      });
      return NextResponse.redirect(`${webAppUrl}/#/auth/callback?${params.toString()}`);
    }

    const deepLink = new URL(`${scheme}://auth`);
    deepLink.searchParams.set('accessToken', result.accessToken);
    deepLink.searchParams.set('refreshToken', result.refreshToken);
    deepLink.searchParams.set('userId', result.user.id);
    deepLink.searchParams.set('email', result.user.email);
    deepLink.searchParams.set('displayName', result.user.displayName);
    deepLink.searchParams.set('role', result.user.role);

    return NextResponse.redirect(deepLink.toString());
  } catch (err) {
    console.error('[Microsoft Callback] OAuth callback failed:', err);
    return NextResponse.redirect(isWeb ? webErrorUrl : errorUrl);
  }
}
