import nodemailer from 'nodemailer';
import { IEmailService } from '@application/ports/IEmailService';

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export class SmtpEmailService implements IEmailService {
  private transporter: nodemailer.Transporter;
  private from: string;

  constructor() {
    this.from = process.env.SMTP_FROM ?? `FutFun <${process.env.SMTP_USER}>`;
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST ?? 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT ?? '587', 10),
      secure: process.env.SMTP_SECURE === 'true', // true para porta 465
      auth: {
        user: process.env.SMTP_USER!,
        pass: process.env.SMTP_PASS!,
      },
    });
  }

  async sendInvite(to: string, inviteToken: string, inviterName: string): Promise<void> {
    const webAppUrl = process.env.WEB_APP_URL ?? process.env.APP_BASE_URL;
    const inviteUrl = `${webAppUrl}/#/invite?token=${inviteToken}`;

    await this.transporter.sendMail({
      from: this.from,
      to,
      subject: 'Você foi convidado para o FutFun ⚽',
      html: `
        <h2>Você recebeu um convite!</h2>
        <p>${escapeHtml(inviterName)} te convidou para participar do <strong>FutFun</strong> — o bolão da Copa do Mundo 2026.</p>
        <p>Clique no link abaixo para aceitar o convite (válido por 7 dias):</p>
        <p><a href="${inviteUrl}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Aceitar convite</a></p>
        <p>Ou copie: ${inviteUrl}</p>
      `,
    });
  }

  async sendApprovalNotification(to: string, displayName: string): Promise<void> {
    await this.transporter.sendMail({
      from: this.from,
      to,
      subject: 'Seu acesso ao FutFun foi aprovado! ⚽',
      html: `
        <h2>Bem-vindo(a) ao FutFun, ${escapeHtml(displayName)}!</h2>
        <p>Seu acesso foi <strong>aprovado</strong>. Agora você pode entrar e fazer seus palpites para a Copa do Mundo 2026.</p>
        <p><a href="${process.env.WEB_APP_URL ?? process.env.APP_BASE_URL}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Acessar o FutFun</a></p>
      `,
    });
  }
}
