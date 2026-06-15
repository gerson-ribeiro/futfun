export interface OAuthTokens {
  accessToken: string;
  idToken: string;
}

export interface OAuthUserInfo {
  providerId: string;
  email: string;
  displayName: string;
}

export interface IOAuthProvider {
  getAuthorizationUrl(state: string): string;
  exchangeCodeForTokens(code: string): Promise<OAuthTokens>;
  getUserInfo(accessToken: string): Promise<OAuthUserInfo>;
}
