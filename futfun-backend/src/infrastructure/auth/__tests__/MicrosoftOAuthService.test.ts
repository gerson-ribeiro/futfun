import { MicrosoftOAuthService } from '../MicrosoftOAuthService';

describe('MicrosoftOAuthService', () => {
  beforeEach(() => {
    process.env.MICROSOFT_CLIENT_ID = 'test-client-id';
    process.env.MICROSOFT_TENANT_ID = 'common';
    process.env.MICROSOFT_CLIENT_SECRET = 'test-secret';
    process.env.APP_BASE_URL = 'http://localhost:4000';
  });

  test('should generate authorization URL with required params', () => {
    const service = new MicrosoftOAuthService();
    const url = service.getAuthorizationUrl('');
    expect(url).toContain('login.microsoftonline.com');
    expect(url).toContain('test-client-id');
    expect(url).toContain('response_type=code');
    expect(url).toContain('microsoft%2Fcallback'); // dedicated route, no query string
  });

  test('should include state in authorization URL', () => {
    const service = new MicrosoftOAuthService();
    const url = service.getAuthorizationUrl('invite:abc123');
    expect(url).toContain('state=invite%3Aabc123');
  });
});
