import { GoogleOAuthService } from '../GoogleOAuthService';

describe('GoogleOAuthService', () => {
  beforeEach(() => {
    process.env.GOOGLE_CLIENT_ID = 'test-google-client-id.apps.googleusercontent.com';
    process.env.GOOGLE_CLIENT_SECRET = 'test-google-secret';
    process.env.APP_BASE_URL = 'http://localhost:4000';
  });

  test('should generate authorization URL with required params', () => {
    const service = new GoogleOAuthService();
    const url = service.getAuthorizationUrl('');
    expect(url).toContain('accounts.google.com/o/oauth2/v2/auth');
    expect(url).toContain('test-google-client-id');
    expect(url).toContain('response_type=code');
    expect(url).toContain('scope=');
    expect(url).toContain('callback%3Fprovider%3Dgoogle');
  });

  test('should include state in authorization URL', () => {
    const service = new GoogleOAuthService();
    const url = service.getAuthorizationUrl('invite:xyz789');
    expect(url).toContain('state=invite%3Axyz789');
  });
});
