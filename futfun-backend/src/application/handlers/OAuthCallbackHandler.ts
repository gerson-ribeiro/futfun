// src/application/handlers/OAuthCallbackHandler.ts

import { PrismaClient } from '@prisma/client';
import { IOAuthProvider } from '@application/ports/IOAuthProvider';
import { ITokenService, TokenPayload } from '@application/ports/ITokenService';
import { INotificationService } from '@application/ports/INotificationService';

export interface CallbackInput {
  code: string;
  provider: string;
  state: string;
}

export interface CallbackResult {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string; displayName: string; role: 'PENDING' | 'MEMBER' | 'ADMIN' };
}

function parseInviteToken(state: string): string | null {
  if (state.startsWith('invite:')) return state.slice(7);
  return null;
}

export class OAuthCallbackHandler {
  constructor(
    private readonly oauthProvider: IOAuthProvider,
    private readonly tokenService: ITokenService,
    private readonly prisma: PrismaClient,
    private readonly notificationService: INotificationService
  ) {}

  async handle(input: CallbackInput): Promise<CallbackResult> {
    const { code, provider, state } = input;

    const tokens = await this.oauthProvider.exchangeCodeForTokens(code);
    const userInfo = await this.oauthProvider.getUserInfo(tokens.accessToken);

    const inviteToken = parseInviteToken(state);

    let user = await this.prisma.user.findFirst({
      where: { provider, providerId: userInfo.providerId },
    });

    if (!user) {
      let role: 'PENDING' | 'MEMBER' | 'ADMIN' = 'PENDING';

      if (userInfo.email === process.env.ADMIN_SEED_EMAIL) {
        role = 'ADMIN';
      } else if (inviteToken) {
        const invite = await this.prisma.invite.findFirst({
          where: {
            token: inviteToken,
            usedAt: null,
            expiresAt: { gt: new Date() },
          },
        });
        if (invite) {
          role = 'MEMBER';
          await this.prisma.invite.update({
            where: { id: invite.id },
            data: { usedAt: new Date() },
          });
        }
      }

      user = await this.prisma.user.create({
        data: {
          provider,
          providerId: userInfo.providerId,
          email: userInfo.email,
          displayName: userInfo.displayName,
          role,
        },
      });

      if (role === 'PENDING') {
        this.notificationService.notifyAdminsOfPendingUser(user).catch((err) =>
          console.error('[OAuthCallback] Failed to notify admins:', err)
        );
      }
    } else {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() },
      });
    }

    const payload: TokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role as TokenPayload['role'],
    };

    const accessToken = this.tokenService.generateAccessToken(payload);
    const refreshToken = this.tokenService.generateRefreshToken(payload);
    const expiresAt = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000);
    
    // Cleanup expired tokens for this user
    await this.prisma.refreshToken.deleteMany({
      where: {
        OR: [
          { userId: user.id, expiresAt: { lt: new Date() } },
          { token: refreshToken }
        ]
      }
    });

    await this.prisma.refreshToken.create({
      data: { userId: user.id, token: refreshToken, expiresAt },
    });

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email, displayName: user.displayName, role: user.role },
    };
  }
}
