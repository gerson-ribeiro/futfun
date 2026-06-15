import { OAuth2Client } from 'google-auth-library';
import { IOAuthProvider, OAuthTokens, OAuthUserInfo } from '@application/ports/IOAuthProvider';

export class GoogleOAuthService implements IOAuthProvider {
  private client: OAuth2Client;
  private redirectUri: string;

  constructor() {
    this.redirectUri = `${process.env.APP_BASE_URL}/api/auth/callback?provider=google`;
    this.client = new OAuth2Client(
      process.env.GOOGLE_CLIENT_ID!,
      process.env.GOOGLE_CLIENT_SECRET!,
      this.redirectUri
    );
  }

  getAuthorizationUrl(state: string): string {
    return this.client.generateAuthUrl({
      access_type: 'offline',
      scope: ['openid', 'profile', 'email'],
      state,
    });
  }

  async exchangeCodeForTokens(code: string): Promise<OAuthTokens> {
    const { tokens } = await this.client.getToken(code);
    if (!tokens.access_token) throw new Error('No access token returned from Google');
    if (!tokens.id_token) throw new Error('No ID token returned from Google');
    return {
      accessToken: tokens.access_token,
      idToken: tokens.id_token,
    };
  }

  async getUserInfo(accessToken: string): Promise<OAuthUserInfo> {
    const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error(`Failed to fetch Google user info: ${response.status}`);
    const user = await response.json();
    return {
      providerId: user.sub,
      email: user.email,
      displayName: user.name,
    };
  }
}
