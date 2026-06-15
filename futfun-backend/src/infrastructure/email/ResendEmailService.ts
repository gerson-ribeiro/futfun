import { Resend } from 'resend';
import { IEmailService } from '@application/ports/IEmailService';

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const isDev = process.env.NODE_ENV !== 'production';

export class ResendEmailService implements IEmailService {
  private resend: Resend;

  constructor() {
    this.resend = new Resend(process.env.RESEND_API_KEY!);
  }

  async sendInvite(to: string, inviteToken: string, inviterName: string): Promise<void> {
    const webAppUrl = process.env.WEB_APP_URL ?? process.env.APP_BASE_URL;
    const inviteUrl = `${webAppUrl}/#/invite?token=${inviteToken}`;

    if (isDev) {
      console.log(`\n[DEV] Invite email not sent (no verified domain). Use this link:\n  → ${inviteUrl}\n`);
      return;
    }

    const { error } = await this.resend.emails.send({
      from: 'FutFun <onboarding@resend.dev>',
      to: [to],
      subject: 'Você foi convidado para o FutFun ⚽',
      html: `
        <h2>Você recebeu um convite!</h2>
        <p>${escapeHtml(inviterName)} te convidou para participar do <strong>FutFun</strong> — o bolão da Copa do Mundo 2026.</p>
        <p>Clique no link abaixo para aceitar o convite (válido por 7 dias):</p>
        <p><a href="${inviteUrl}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Aceitar convite</a></p>
        <p>Ou copie: ${inviteUrl}</p>
      `,
    });
    if (error) throw new Error(error.message);
  }

  async sendApprovalNotification(to: string, displayName: string): Promise<void> {
    if (isDev) {
      console.log(`\n[DEV] Approval email not sent (no verified domain). User "${displayName}" approved.\n`);
      return;
    }

    const { error } = await this.resend.emails.send({
      from: 'FutFun <onboarding@resend.dev>',
      to: [to],
      subject: 'Seu acesso ao FutFun foi aprovado! ⚽',
      html: `
        <h2>Bem-vindo(a) ao FutFun, ${escapeHtml(displayName)}!</h2>
        <p>Seu acesso foi <strong>aprovado</strong>. Agora você pode entrar e fazer seus palpites para a Copa do Mundo 2026.</p>
        <p><a href="${process.env.WEB_APP_URL ?? process.env.APP_BASE_URL}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Acessar o FutFun</a></p>
      `,
    });
    if (error) throw new Error(error.message);
  }
}
