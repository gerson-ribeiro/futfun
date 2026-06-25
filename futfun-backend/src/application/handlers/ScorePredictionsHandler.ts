import { PrismaClient } from '@prisma/client';
import { PointsCalculationService } from '@application/services/PointsCalculationService';
import { INotificationService } from '@application/ports/INotificationService';

export class ScorePredictionsHandler {
  private readonly calculator = new PointsCalculationService();

  constructor(
    private readonly prisma: PrismaClient,
    private readonly notificationService?: INotificationService,
  ) {}

  async handle(matchId: string): Promise<void> {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });

    if (!match) {
      console.warn(`[ScorePredictions] Match not found: ${matchId}`);
      return;
    }
    if (match.status !== 'FINISHED') return;
    if (match.scoreHome === null || match.scoreAway === null) {
      console.warn(`[ScorePredictions] Match ${matchId} (${match.homeTeamName} vs ${match.awayTeamName}) is FINISHED but score not available yet`);
      return;
    }

    const now = new Date();

    // Atomically claim all unscored predictions. The second concurrent call
    // finds 0 rows (already claimed) and returns early — no double-scoring.
    // Also re-claims predictions where the process crashed after claiming but
    // before writing points (scoredAt set, points still null).
    const claimed = await this.prisma.prediction.updateMany({
      where: {
        matchId,
        OR: [{ scoredAt: null }, { points: null }],
      },
      data: { scoredAt: now },
    });

    if (claimed.count === 0) {
      console.log(`[ScorePredictions] ${match.homeTeamName} vs ${match.awayTeamName} — already scored or no predictions`);
      return;
    }

    const predictions = await this.prisma.prediction.findMany({
      where: { matchId, scoredAt: now },
    });

    console.log(`[ScorePredictions] Scoring ${predictions.length} prediction(s) for ${match.homeTeamName} ${match.scoreHome}-${match.scoreAway} ${match.awayTeamName}`);

    for (const prediction of predictions) {
      const points = this.calculator.calculate({
        actualHome: match.scoreHome,
        actualAway: match.scoreAway,
        predictedHome: prediction.predictedHome,
        predictedAway: prediction.predictedAway,
      });

      await this.prisma.prediction.update({
        where: { id: prediction.id },
        data: { points },
      });
    }

    console.log(`[ScorePredictions] Done — ${predictions.length} prediction(s) scored`);

    if (this.notificationService && predictions.length > 0) {
      const userIds = [...new Set(predictions.map((p) => p.userId))];
      this.notificationService.notifyRankingChanged(userIds).catch((err) =>
        console.error('[ScorePredictions] Notification failed:', err),
      );
    }
  }
}
