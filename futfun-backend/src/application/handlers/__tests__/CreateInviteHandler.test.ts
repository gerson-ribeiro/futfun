// src/application/handlers/__tests__/CreateInviteHandler.test.ts

import { CreateInviteHandler } from '../CreateInviteHandler';
import { IEmailService } from '@application/ports/IEmailService';

const mockEmailService: IEmailService = {
  sendInvite: jest.fn().mockResolvedValue(undefined),
  sendApprovalNotification: jest.fn().mockResolvedValue(undefined),
};

function makePrisma(userExists = false, invitePending = false) {
  return {
    user: {
      findUnique: jest.fn().mockResolvedValue(
        userExists ? { id: 'u1', email: 'target@example.com', role: 'MEMBER' } : null
      ),
    },
    invite: {
      findFirst: jest.fn().mockResolvedValue(
        invitePending ? { id: 'i1', email: 'target@example.com', usedAt: null } : null
      ),
      create: jest.fn().mockResolvedValue({ id: 'new-invite', token: 'generated-token' }),
    },
  };
}

describe('CreateInviteHandler', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates invite and sends email for valid new recipient', async () => {
    const prisma = makePrisma(false, false);
    const handler = new CreateInviteHandler(prisma as any, mockEmailService);

    await handler.handle({
      email: 'target@example.com',
      createdBy: 'admin-uuid',
      inviterName: 'Gerson',
    });

    expect(prisma.invite.create).toHaveBeenCalled();
    expect(mockEmailService.sendInvite).toHaveBeenCalledWith(
      'target@example.com',
      expect.any(String),
      'Gerson'
    );
  });

  test('throws if user with that email is already a MEMBER or ADMIN', async () => {
    const prisma = makePrisma(true, false);
    const handler = new CreateInviteHandler(prisma as any, mockEmailService);

    await expect(
      handler.handle({ email: 'target@example.com', createdBy: 'admin-uuid', inviterName: 'Gerson' })
    ).rejects.toThrow('already a member');
  });

  test('throws if pending invite already exists for this email', async () => {
    const prisma = makePrisma(false, true);
    const handler = new CreateInviteHandler(prisma as any, mockEmailService);

    await expect(
      handler.handle({ email: 'target@example.com', createdBy: 'admin-uuid', inviterName: 'Gerson' })
    ).rejects.toThrow('pending invite');
  });
});
