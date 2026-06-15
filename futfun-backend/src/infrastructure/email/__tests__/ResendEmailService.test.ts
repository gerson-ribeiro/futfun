jest.mock('resend', () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: {
      send: jest.fn().mockResolvedValue({ data: { id: 'email-id' }, error: null }),
    },
  })),
}));

import { ResendEmailService } from '../ResendEmailService';

describe('ResendEmailService', () => {
  beforeEach(() => {
    process.env.RESEND_API_KEY = 're_test_key';
    process.env.APP_BASE_URL = 'https://app.futfun.com';
    jest.clearAllMocks();
  });

  test('sendInvite should call Resend with correct recipient and subject', async () => {
    const service = new ResendEmailService();
    const { Resend } = require('resend');
    const mockInstance = Resend.mock.results[0].value;

    await service.sendInvite('user@example.com', 'token-abc', 'Gerson');

    expect(mockInstance.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: ['user@example.com'],
        subject: expect.stringContaining('FutFun'),
        html: expect.stringContaining('token-abc'),
      })
    );
  });

  test('sendApprovalNotification should call Resend with correct recipient', async () => {
    const service = new ResendEmailService();
    const { Resend } = require('resend');
    const mockInstance = Resend.mock.results[0].value;

    await service.sendApprovalNotification('user@example.com', 'João Silva');

    expect(mockInstance.emails.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: ['user@example.com'],
        subject: expect.stringContaining('aprovado'),
        html: expect.stringContaining('João Silva'),
      })
    );
  });

  test('should throw when Resend returns an error', async () => {
    const { Resend } = require('resend');
    Resend.mockImplementation(() => ({
      emails: {
        send: jest.fn().mockResolvedValue({ data: null, error: { message: 'API error' } }),
      },
    }));

    const service = new ResendEmailService();
    await expect(service.sendInvite('user@example.com', 'token', 'Admin')).rejects.toThrow('API error');
  });
});
