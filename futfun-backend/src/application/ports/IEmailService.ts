export interface IEmailService {
  sendInvite(to: string, inviteToken: string, inviterName: string): Promise<void>;
  sendApprovalNotification(to: string, displayName: string): Promise<void>;
}
