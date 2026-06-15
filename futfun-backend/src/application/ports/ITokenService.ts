export interface TokenPayload {
  userId: string;
  email: string;
  role: 'PENDING' | 'MEMBER' | 'ADMIN';
  iat?: number;
  exp?: number;
}

export interface ITokenService {
  generateAccessToken(payload: TokenPayload): string;
  generateRefreshToken(payload: TokenPayload): string;
  verifyAccessToken(token: string): TokenPayload;
  verifyRefreshToken(token: string): TokenPayload;
}
