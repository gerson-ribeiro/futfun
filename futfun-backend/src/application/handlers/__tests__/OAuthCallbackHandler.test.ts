// src/application/handlers/__tests__/OAuthCallbackHandler.test.ts

import { OAuthCallbackHandler } from '../OAuthCallbackHandler';
import { IOAuthProvider } from '@application/ports/IOAuthProvider';
import { ITokenService, TokenPayload } from '@application/ports/ITokenService';
import { INotificationService } from '@application/ports/INotificationService';

const mockProvider: IOAuthProvider = {
  getAuthorizationUrl: jest.fn(),
  exchangeCodeForTokens: jest.fn().mockResolvedValue({
    accessToken: 'provider-access-token',
    idToken: 'provider-id-token',
  }),
  getUserInfo: jest.fn().mockResolvedValue({
    providerId: 'google-sub-123',
    email: 'user@example.com',
    displayName: 'Test User',
  }),
};

const mockTokenService: ITokenService = {
  generateAccessToken: jest.fn().mockReturnValue('access-jwt'),
  generateRefreshToken: jest.fn().mockReturnValue('refresh-jwt'),
  verifyAccessToken: jest.fn(),
  verifyRefreshToken: jest.fn(),
};

const mockNotificationService: INotificationService = {
  notifyRankingChanged: jest.fn().mockResolvedValue(undefined),
  sendPredictionsReminder: jest.fn().mockResolvedValue(undefined),
  notifyAdminsOfPendingUser: jest.fn().mockResolvedValue(undefined),
};

function makePrisma(overrides: Partial<ReturnType<typeof makeDefaultPrisma>> = {}) {
  return { ...makeDefaultPrisma(), ...overrides };
}

function makeDefaultPrisma() {
  return {
    user: {
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({
        id: 'user-uuid',
        email: 'user@example.com',
        displayName: 'Test User',
        role: 'PENDING',
      }),
      update: jest.fn().mockResolvedValue({
        id: 'user-uuid',
        email: 'user@example.com',
        displayName: 'Test User',
        role: 'MEMBER',
      }),
    },
    invite: {
      findFirst: jest.fn().mockResolvedValue(null),
      update: jest.fn().mockResolvedValue({}),
    },
    refreshToken: {
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

describe('OAuthCallbackHandler', () => {
  beforeEach(() => {
    process.env.ADMIN_SEED_EMAIL = 'admin@example.com';
    jest.clearAllMocks();
  });

  test('creates new PENDING user when no invite and not admin email', async () => {
    const prisma = makePrisma();
    const handler = new OAuthCallbackHandler(
      mockProvider,
      mockTokenService,
      prisma as any,
      mockNotificationService
    );

    const result = await handler.handle({ code: 'auth-code', provider: 'google', state: '' });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: 'PENDING', provider: 'google' }),
      })
    );
    expect(result.user.role).toBe('PENDING');
    expect(result.accessToken).toBe('access-jwt');
  });

  test('creates new ADMIN user when email matches ADMIN_SEED_EMAIL', async () => {
    const adminProvider: IOAuthProvider = {
      ...mockProvider,
      getUserInfo: jest.fn().mockResolvedValue({
        providerId: 'google-sub-admin',
        email: 'admin@example.com',
        displayName: 'Admin User',
      }),
    };
    const prisma = makePrisma({
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'admin-uuid',
          email: 'admin@example.com',
          displayName: 'Admin User',
          role: 'ADMIN',
        }),
        update: jest.fn(),
      },
    });
    const handler = new OAuthCallbackHandler(
      adminProvider,
      mockTokenService,
      prisma as any,
      mockNotificationService
    );

    const result = await handler.handle({ code: 'auth-code', provider: 'google', state: '' });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: 'ADMIN' }),
      })
    );
    expect(result.user.role).toBe('ADMIN');
  });

  test('creates new MEMBER user when valid invite token in state', async () => {
    const futureDate = new Date(Date.now() + 86400000);
    const prisma = makePrisma({
      invite: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'invite-uuid',
          email: 'user@example.com',
          token: 'valid-token',
          expiresAt: futureDate,
          usedAt: null,
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'user-uuid',
          email: 'user@example.com',
          displayName: 'Test User',
          role: 'MEMBER',
        }),
        update: jest.fn(),
      },
    });
    const handler = new OAuthCallbackHandler(
      mockProvider,
      mockTokenService,
      prisma as any,
      mockNotificationService
    );

    const result = await handler.handle({
      code: 'auth-code',
      provider: 'google',
      state: 'invite:valid-token',
    });

    expect(prisma.user.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ role: 'MEMBER' }),
      })
    );
    expect(prisma.invite.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'invite-uuid' } })
    );
    expect(result.user.role).toBe('MEMBER');
  });

  test('updates lastLoginAt for existing user and returns current role', async () => {
    const existingUser = {
      id: 'existing-uuid',
      email: 'user@example.com',
      displayName: 'Existing User',
      role: 'MEMBER',
    };
    const prisma = makePrisma({
      user: {
        findFirst: jest.fn().mockResolvedValue(existingUser),
        update: jest.fn().mockResolvedValue(existingUser),
        create: jest.fn(),
      },
    });
    const handler = new OAuthCallbackHandler(
      mockProvider,
      mockTokenService,
      prisma as any,
      mockNotificationService
    );

    const result = await handler.handle({ code: 'auth-code', provider: 'google', state: '' });

    expect(prisma.user.create).not.toHaveBeenCalled();
    expect(prisma.user.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'existing-uuid' } })
    );
    expect(result.user.role).toBe('MEMBER');
  });
});
