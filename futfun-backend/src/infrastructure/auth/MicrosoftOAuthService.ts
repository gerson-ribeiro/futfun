import { IOAuthProvider, OAuthTokens, OAuthUserInfo } from '@application/ports/IOAuthProvider';

export class MicrosoftOAuthService implements IOAuthProvider {
  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly tenantId: string;
  private readonly redirectUri: string;

  constructor() {
    this.clientId = process.env.MICROSOFT_CLIENT_ID!;
    this.clientSecret = process.env.MICROSOFT_CLIENT_SECRET!;
    this.tenantId = process.env.MICROSOFT_TENANT_ID || 'common';
    this.redirectUri = `${process.env.APP_BASE_URL}/api/auth/microsoft/callback`;
  }

  getAuthorizationUrl(state: string): string {
    const params = new URLSearchParams({
      client_id: this.clientId,
      response_type: 'code',
      redirect_uri: this.redirectUri,
      scope: 'openid profile email User.Read',
      response_mode: 'query',
      state,
    });
    return `https://login.microsoftonline.com/${this.tenantId}/oauth2/v2.0/authorize?${params.toString()}`;
  }

  async exchangeCodeForTokens(code: string): Promise<OAuthTokens> {
    const body = new URLSearchParams({
      client_id: this.clientId,
      client_secret: this.clientSecret,
      grant_type: 'authorization_code',
      code,
      redirect_uri: this.redirectUri,
      scope: 'openid profile email User.Read',
    });

    const response = await fetch(
      `https://login.microsoftonline.com/${this.tenantId}/oauth2/v2.0/token`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString(),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Microsoft token exchange failed (${response.status}): ${error}`);
    }

    const tokens = await response.json();
    if (!tokens.access_token) throw new Error('No access_token returned from Microsoft');

    return {
      accessToken: tokens.access_token,
      idToken: tokens.id_token || '',
    };
  }

  async getUserInfo(accessToken: string): Promise<OAuthUserInfo> {
    const response = await fetch('https://graph.microsoft.com/v1.0/me', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error(`Failed to fetch Microsoft user info: ${response.status}`);
    const user = await response.json();
    return {
      providerId: user.id,
      email: user.mail || user.userPrincipalName,
      displayName: user.displayName,
    };
  }
}
