import { PrismaClient } from '@prisma/client';
import { PointsCalculationService } from '@application/services/PointsCalculationService';
import { INotificationService } from '@application/ports/INotificationService';

function formatRoundStage(stage: string, matchday: number | null, groupName: string | null): string {
  const label = stage.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  if (groupName) return `${label} · Grupo ${groupName}`;
  if (matchday != null) return `${label} · Rodada ${matchday}`;
  return label;
}

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
    if (match.status !== 'FINISHED') {
      return; // not finished yet — silent, expected
    }
    if (match.scoreHome === null || match.scoreAway === null) {
      console.warn(`[ScorePredictions] Match ${matchId} (${match.homeTeamName} vs ${match.awayTeamName}) is FINISHED but score not available yet — will retry next sync`);
      return;
    }

    const predictions = await this.prisma.prediction.findMany({
      where: { matchId, scoredAt: null },
    });

    if (predictions.length === 0) {
      console.log(`[ScorePredictions] Match ${matchId} (${match.homeTeamName} vs ${match.awayTeamName}) — no unscored predictions, skipping`);
      return;
    }

    console.log(`[ScorePredictions] Scoring ${predictions.length} prediction(s) for match ${matchId} (${match.homeTeamName} ${match.scoreHome}-${match.scoreAway} ${match.awayTeamName})`);

    const now = new Date();
    const pointsEarnedMap = new Map<string, number>();

    for (const prediction of predictions) {
      const points = this.calculator.calculate({
        actualHome: match.scoreHome,
        actualAway: match.scoreAway,
        predictedHome: prediction.predictedHome,
        predictedAway: prediction.predictedAway,
      });

      await this.prisma.prediction.update({
        where: { id: prediction.id },
        data: { points, scoredAt: now },
      });

      const isExact = points === 10;
      const isCorrectResult = points === 5 || points === 7;

      await this.prisma.ranking.upsert({
        where: { userId: prediction.userId },
        create: {
          userId: prediction.userId,
          totalPoints: points,
          exactScores: isExact ? 1 : 0,
          correctResults: isCorrectResult ? 1 : 0,
          matchesPredicted: 1,
          lastCalculatedAt: now,
        },
        update: {
          totalPoints: { increment: points },
          exactScores: { increment: isExact ? 1 : 0 },
          correctResults: { increment: isCorrectResult ? 1 : 0 },
          matchesPredicted: { increment: 1 },
          lastCalculatedAt: now,
        },
      });

      // Upsert per-competition stats
      if (match.competitionCode) {
        await this.prisma.userCompetitionStats.upsert({
          where: { userId_competitionCode: { userId: prediction.userId, competitionCode: match.competitionCode } },
          create: {
            userId: prediction.userId,
            competitionCode: match.competitionCode,
            totalPoints: points,
            exactScores: isExact ? 1 : 0,
            correctResults: isCorrectResult ? 1 : 0,
            matchesPredicted: 1,
            lastCalculatedAt: now,
          },
          update: {
            totalPoints: { increment: points },
            exactScores: { increment: isExact ? 1 : 0 },
            correctResults: { increment: isCorrectResult ? 1 : 0 },
            matchesPredicted: { increment: 1 },
            lastCalculatedAt: now,
          },
        });
      }

      pointsEarnedMap.set(prediction.userId, (pointsEarnedMap.get(prediction.userId) ?? 0) + points);
    }

    // Create a RankingHistory snapshot for each user whose predictions were just scored
    const roundStage = formatRoundStage(match.stage, match.matchday, match.groupName);

    for (const [userId, pointsEarned] of pointsEarnedMap.entries()) {
      // Use per-competition stats for the snapshot when available (preferred),
      // otherwise fall back to the global ranking table.
      let snapshotPoints: number;
      let snapshotExact: number;
      let snapshotCorrect: number;
      let position: number;

      if (match.competitionCode) {
        const compStats = await this.prisma.userCompetitionStats.findUnique({
          where: { userId_competitionCode: { userId, competitionCode: match.competitionCode } },
        });
        if (!compStats) continue;

        snapshotPoints = compStats.totalPoints;
        snapshotExact = compStats.exactScores;
        snapshotCorrect = compStats.correctResults;

        position =
          (await this.prisma.userCompetitionStats.count({
            where: {
              competitionCode: match.competitionCode,
              totalPoints: { gt: compStats.totalPoints },
            },
          })) + 1;
      } else {
        const userRanking = await this.prisma.ranking.findUnique({ where: { userId } });
        if (!userRanking) continue;

        snapshotPoints = userRanking.totalPoints;
        snapshotExact = userRanking.exactScores;
        snapshotCorrect = userRanking.correctResults;

        position =
          (await this.prisma.ranking.count({
            where: { totalPoints: { gt: userRanking.totalPoints } },
          })) + 1;
      }

      await this.prisma.rankingHistory.upsert({
        where: { userId_snapshotKey: { userId, snapshotKey: matchId } },
        create: {
          userId,
          snapshotKey: matchId,
          matchday: match.matchday,
          roundStage,
          pointsEarned,
          totalPoints: snapshotPoints,
          exactScores: snapshotExact,
          correctResults: snapshotCorrect,
          position,
          snapshotAt: now,
          competitionCode: match.competitionCode ?? null,
        },
        update: {},
      });

      console.log(`[ScorePredictions] User ${userId}: +${pointsEarned} pts, competition_total=${snapshotPoints}, position=${position}`);
    }

    // Detect position changes and notify affected users
    const usersWithPositionChange: string[] = [];
    for (const [userId] of pointsEarnedMap.entries()) {
      const current = await this.prisma.rankingHistory.findUnique({
        where: { userId_snapshotKey: { userId, snapshotKey: matchId } },
        select: { position: true },
      });
      const previous = await this.prisma.rankingHistory.findFirst({
        where: {
          userId,
          competitionCode: match.competitionCode ?? null,
          snapshotKey: { not: matchId },
        },
        orderBy: { snapshotAt: 'desc' },
        select: { position: true },
      });
      if (current && previous && current.position !== previous.position) {
        usersWithPositionChange.push(userId);
      }
    }

    if (usersWithPositionChange.length > 0) {
      // Fire-and-forget — notification failure must never block scoring
      this.notificationService
        ?.notifyRankingChanged(usersWithPositionChange)
        .catch((err) => console.error('[ScorePredictions] Notification failed:', err));
    }

    console.log(`[ScorePredictions] Done scoring match ${matchId} — ${pointsEarnedMap.size} user(s) updated`);
  }
}
