// src/application/handlers/CreateInviteHandler.ts

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import { IEmailService } from '@application/ports/IEmailService';

export interface CreateInviteInput {
  email: string;
  createdBy: string;
  inviterName: string;
}

export class CreateInviteHandler {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly emailService: IEmailService
  ) {}

  async handle(input: CreateInviteInput): Promise<{ inviteId: string; inviteToken: string; emailSent: boolean }> {
    const { email, createdBy, inviterName } = input;

    const existingUser = await this.prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      throw new Error(`User ${email} is already a member`);
    }

    const existingInvite = await this.prisma.invite.findFirst({
      where: { email, usedAt: null, expiresAt: { gt: new Date() } },
    });
    if (existingInvite) {
      throw new Error(`There is already a pending invite for ${email}`);
    }

    const token = randomUUID();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const invite = await this.prisma.invite.create({
      data: { email, token, expiresAt, createdBy },
    });

    let emailSent = false;
    try {
      await this.emailService.sendInvite(email, token, inviterName);
      emailSent = true;
    } catch (err) {
      console.error('[Invite] Email sending failed (invite still created):', err);
    }

    return { inviteId: invite.id, inviteToken: token, emailSent };
  }
}
