import { PrismaClient } from '@prisma/client';
import { FcmService } from './FcmService';
import { INotificationService } from '@application/ports/INotificationService';

export class NotificationService implements INotificationService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly fcm: FcmService,
  ) {}

  async notifyRankingChanged(userIds: string[]): Promise<void> {
    if (userIds.length === 0 || !this.fcm.isAvailable()) return;
    try {
      const rows = await this.prisma.deviceToken.findMany({
        where: { userId: { in: userIds } },
        select: { token: true },
      });
      const tokens = rows.map((r) => r.token);
      if (tokens.length === 0) return;

      const { invalidTokens } = await this.fcm.sendMulticast(
        tokens,
        'Ranking atualizado 🏆',
        'Sua posição mudou. Veja como você está!',
        { type: 'ranking' },
      );
      await this.cleanInvalidTokens(invalidTokens);
      console.log(`[NotificationService] Ranking notification sent to ${tokens.length} token(s)`);
    } catch (err) {
      console.error('[NotificationService] notifyRankingChanged failed:', err);
    }
  }

  async sendPredictionsReminder(): Promise<void> {
    if (!this.fcm.isAvailable()) return;
    try {
      const now = new Date();
      // End of tomorrow: midnight UTC at the end of the next calendar day
      const endOfTomorrow = new Date(now);
      endOfTomorrow.setUTCDate(now.getUTCDate() + 2);
      endOfTomorrow.setUTCHours(0, 0, 0, 0);

      // Matches today and tomorrow still open for prediction (kickoff in the future)
      const upcomingMatches = await this.prisma.match.findMany({
        where: {
          status: 'SCHEDULED',
          kickoffTime: { gt: now, lt: endOfTomorrow },
        },
        select: { id: true },
      });

      if (upcomingMatches.length === 0) {
        console.log('[NotificationService] No upcoming matches today/tomorrow — skipping reminder');
        return;
      }

      const matchIds = upcomingMatches.map((m) => m.id);

      // Users who have at least one upcoming match without a prediction
      const usersWithTokens = await this.prisma.user.findMany({
        where: {
          role: { in: ['MEMBER', 'ADMIN'] },
          deviceTokens: { some: {} },
        },
        select: {
          id: true,
          deviceTokens: { select: { token: true } },
          predictions: {
            where: { matchId: { in: matchIds } },
            select: { matchId: true },
          },
        },
      });

      const predictedMatchCountByUser = new Map<string, number>();
      for (const user of usersWithTokens) {
        predictedMatchCountByUser.set(user.id, user.predictions.length);
      }

      const tokens = usersWithTokens
        .filter((u) => (predictedMatchCountByUser.get(u.id) ?? 0) < matchIds.length)
        .flatMap((u) => u.deviceTokens.map((t) => t.token));

      if (tokens.length === 0) {
        console.log('[NotificationService] All users have predictions for today/tomorrow — skipping reminder');
        return;
      }

      const { invalidTokens } = await this.fcm.sendMulticast(
        tokens,
        'Palpites disponíveis ⚽',
        'Tem jogos hoje ou amanhã sem palpite. Não perca!',
        { type: 'predictions' },
      );
      await this.cleanInvalidTokens(invalidTokens);
      console.log(`[NotificationService] Predictions reminder sent to ${tokens.length} token(s)`);
    } catch (err) {
      console.error('[NotificationService] sendPredictionsReminder failed:', err);
    }
  }

  async notifyAdminsOfPendingUser(user: { id: string; displayName: string; email: string }): Promise<void> {
    if (!this.fcm.isAvailable()) return;
    try {
      const rows = await this.prisma.deviceToken.findMany({
        where: { user: { role: 'ADMIN' } },
        select: { token: true },
      });
      if (rows.length === 0) return;

      const tokens = rows.map((r) => r.token);
      const { invalidTokens } = await this.fcm.sendMulticast(
        tokens,
        'Novo usuário aguardando aprovação',
        `${user.displayName} (${user.email}) quer entrar no bolão`,
        { type: 'pending_user', userId: user.id },
      );
      await this.cleanInvalidTokens(invalidTokens);
      console.log(`[NotificationService] Admin notification sent for pending user ${user.email}`);
    } catch (err) {
      console.error('[NotificationService] notifyAdminsOfPendingUser failed:', err);
    }
  }

  private async cleanInvalidTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;
    await this.prisma.deviceToken.deleteMany({ where: { token: { in: tokens } } });
    console.log(`[NotificationService] Cleaned ${tokens.length} invalid token(s)`);
  }
}
