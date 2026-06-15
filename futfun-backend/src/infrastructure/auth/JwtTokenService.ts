import jwt from 'jsonwebtoken';
import { ITokenService, TokenPayload } from '@application/ports/ITokenService';

export class JwtTokenService implements ITokenService {
  private readonly secret: string;
  private readonly accessExpires: string;
  private readonly refreshExpires: string;

  constructor() {
    this.secret = process.env.JWT_SECRET!;
    this.accessExpires = process.env.JWT_ACCESS_EXPIRES_IN || '15m';
    this.refreshExpires = process.env.JWT_REFRESH_EXPIRES_IN || '7d';
  }

  private createToken(payload: TokenPayload, expiresIn: string): string {
    return jwt.sign(
      { userId: payload.userId, email: payload.email, role: payload.role },
      this.secret,
      { expiresIn: expiresIn as jwt.SignOptions['expiresIn'] }
    );
  }

  generateAccessToken(payload: TokenPayload): string {
    return this.createToken(payload, this.accessExpires);
  }

  generateRefreshToken(payload: TokenPayload): string {
    return this.createToken(payload, this.refreshExpires);
  }

  verifyAccessToken(token: string): TokenPayload {
    return jwt.verify(token, this.secret) as TokenPayload;
  }

  verifyRefreshToken(token: string): TokenPayload {
    return jwt.verify(token, this.secret) as TokenPayload;
  }
}
