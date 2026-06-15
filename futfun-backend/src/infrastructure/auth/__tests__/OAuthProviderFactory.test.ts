import { createOAuthProvider } from '../OAuthProviderFactory';
import { GoogleOAuthService } from '../GoogleOAuthService';
import { MicrosoftOAuthService } from '../MicrosoftOAuthService';

describe('createOAuthProvider', () => {
  beforeEach(() => {
    process.env.GOOGLE_CLIENT_ID = 'g-client';
    process.env.GOOGLE_CLIENT_SECRET = 'g-secret';
    process.env.APP_BASE_URL = 'http://localhost:4000';
    process.env.MICROSOFT_CLIENT_ID = 'ms-client';
    process.env.MICROSOFT_CLIENT_SECRET = 'ms-secret';
    process.env.MICROSOFT_TENANT_ID = 'common';
  });

  test('returns a GoogleOAuthService instance for "google"', () => {
    const provider = createOAuthProvider('google');
    expect(provider).toBeInstanceOf(GoogleOAuthService);
  });

  test('returns a MicrosoftOAuthService instance for "microsoft"', () => {
    const provider = createOAuthProvider('microsoft');
    expect(provider).toBeInstanceOf(MicrosoftOAuthService);
  });

  test('throws for an unknown provider name', () => {
    expect(() => createOAuthProvider('facebook' as any)).toThrow(
      'Unknown OAuth provider: facebook'
    );
  });
});
