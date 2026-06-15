// app/api/auth/callback/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { createOAuthProvider, OAuthProviderName } from '@infrastructure/auth/OAuthProviderFactory';
import { JwtTokenService } from '@infrastructure/auth/JwtTokenService';
import { OAuthCallbackHandler } from '@application/handlers/OAuthCallbackHandler';
import { getContainer } from '@infrastructure/container/container';

const VALID_PROVIDERS: OAuthProviderName[] = ['google', 'microsoft'];

export async function GET(req: NextRequest) {
  const scheme = process.env.APP_DEEP_LINK_SCHEME || 'futfun';
  const webAppUrl = process.env.WEB_APP_URL;
  const errorUrl = `${scheme}://auth?error=true`;
  const webErrorUrl = webAppUrl ? `${webAppUrl}/#/login?error=auth` : errorUrl;

  const state = req.nextUrl.searchParams.get('state') || '';
  const isWeb = state === 'web';

  try {
    const provider = req.nextUrl.searchParams.get('provider');
    const code = req.nextUrl.searchParams.get('code');

    if (!provider || !VALID_PROVIDERS.includes(provider as OAuthProviderName) || !code) {
      return NextResponse.redirect(isWeb ? webErrorUrl : errorUrl);
    }

    const oauthProvider = createOAuthProvider(provider as OAuthProviderName);
    const tokenService = new JwtTokenService();
    const { prisma } = getContainer();

    const handler = new OAuthCallbackHandler(oauthProvider, tokenService, prisma);
    const result = await handler.handle({ code, provider, state });

    // Web: redireciona para rota HTTP que o Flutter web consegue receber.
    // Flutter web usa hash routing por padrão: http://host/#/rota?params
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

    // Mobile: usa deep link (futfun://auth?...)
    const deepLink = new URL(`${scheme}://auth`);
    deepLink.searchParams.set('accessToken', result.accessToken);
    deepLink.searchParams.set('refreshToken', result.refreshToken);
    deepLink.searchParams.set('userId', result.user.id);
    deepLink.searchParams.set('email', result.user.email);
    deepLink.searchParams.set('displayName', result.user.displayName);
    deepLink.searchParams.set('role', result.user.role);
    return NextResponse.redirect(deepLink.toString());
  } catch (err) {
    console.error('[Auth Callback] OAuth callback failed:', err);
    return NextResponse.redirect(isWeb ? webErrorUrl : errorUrl);
  }
}
