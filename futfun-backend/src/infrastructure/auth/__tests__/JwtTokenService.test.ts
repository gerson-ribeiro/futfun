import { JwtTokenService } from '../JwtTokenService';

describe('JwtTokenService', () => {
  beforeEach(() => {
    process.env.JWT_SECRET = 'test-secret-must-be-at-least-32-chars-long';
    process.env.JWT_ACCESS_EXPIRES_IN = '15m';
    process.env.JWT_REFRESH_EXPIRES_IN = '7d';
  });

  test('should generate and verify access token with role', () => {
    const service = new JwtTokenService();
    const payload = { userId: 'user-123', email: 'test@example.com', role: 'MEMBER' as const };
    const token = service.generateAccessToken(payload);
    const verified = service.verifyAccessToken(token);
    expect(verified.userId).toBe('user-123');
    expect(verified.email).toBe('test@example.com');
    expect(verified.role).toBe('MEMBER');
  });

  test('should generate and verify refresh token with role', () => {
    const service = new JwtTokenService();
    const payload = { userId: 'user-123', email: 'test@example.com', role: 'ADMIN' as const };
    const token = service.generateRefreshToken(payload);
    const verified = service.verifyRefreshToken(token);
    expect(verified.userId).toBe('user-123');
    expect(verified.role).toBe('ADMIN');
  });

  test('should throw for invalid access token', () => {
    const service = new JwtTokenService();
    expect(() => service.verifyAccessToken('invalid-token')).toThrow();
  });
});
