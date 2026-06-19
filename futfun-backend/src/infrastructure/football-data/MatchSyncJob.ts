import * as cron from 'node-cron';
import { PrismaClient } from '@prisma/client';
import { IFootballDataProvider, ProviderMatch, ProviderMatchWithCompetition } from '@application/ports/IFootballDataProvider';
import { ScorePredictionsHandler } from '@application/handlers/ScorePredictionsHandler';
import { INotificationService } from '@application/ports/INotificationService';

// Maps football-data.org status to our status
function mapStatus(status: string): string {
  if (status === 'IN_PLAY' || status === 'PAUSED') return 'LIVE';
  if (status === 'FINISHED') return 'FINISHED';
  return 'SCHEDULED';
}

// Returns a 7-day window (today ± 3 days) as ISO date strings.
// football-data.org free tier caps date-range queries at 10 days.
function getSevenDayWindow(): { dateFrom: string; dateTo: string } {
  const now = new Date();
  const from = new Date(now);
  from.setUTCDate(now.getUTCDate() - 3);
  from.setUTCHours(0, 0, 0, 0);

  const to = new Date(now);
  to.setUTCDate(now.getUTCDate() + 7);
  to.setUTCHours(23, 59, 59, 999);

  return {
    dateFrom: from.toISOString().split('T')[0],
    dateTo: to.toISOString().split('T')[0],
  };
}

// Returns a 14-day window used by secondary providers (TheSportsDB etc.)
// that don't have the 10-day restriction.
function getTwoWeekWindow(): { dateFrom: string; dateTo: string } {
  const now = new Date();
  const from = new Date(now);
  from.setUTCDate(now.getUTCDate() - 3);
  from.setUTCHours(0, 0, 0, 0);

  const to = new Date(now);
  to.setUTCDate(now.getUTCDate() + 30);
  to.setUTCHours(23, 59, 59, 999);

  return {
    dateFrom: from.toISOString().split('T')[0],
    dateTo: to.toISOString().split('T')[0],
  };
}

export class MatchSyncJob {
  private liveTask: cron.ScheduledTask | null = null;
  private idleTask: cron.ScheduledTask | null = null;
  private secondaryTask: cron.ScheduledTask | null = null;
  private dailyScoringTask: cron.ScheduledTask | null = null;
  private predictionsReminderTask: cron.ScheduledTask | null = null;
  private readonly scorePredictionsHandler: ScorePredictionsHandler;

  constructor(
    private readonly prisma: PrismaClient,
    private readonly provider: IFootballDataProvider,
    /** Optional second provider (e.g. API-Football) for matches absent from the primary provider. */
    private readonly secondaryProvider?: IFootballDataProvider,
    private readonly notificationService?: INotificationService,
  ) {
    this.scorePredictionsHandler = new ScorePredictionsHandler(prisma, notificationService);
  }

  start(): void {
    const liveInterval = parseInt(process.env.LIVE_POLL_INTERVAL_SECONDS || '60', 10);
    const idleInterval = parseInt(process.env.IDLE_POLL_INTERVAL_SECONDS || '600', 10);

    // Live polling: every minute when matches are live
    this.liveTask = cron.schedule(`*/${Math.ceil(liveInterval / 60)} * * * *`, async () => {
      try {
        const hasLive = await this.prisma.match.count({ where: { status: 'LIVE' } });
        if (hasLive > 0) {
          await this.syncMatches();
        }
      } catch (err: any) {
        await this.handleCronError(err, 'live');
      }
    });

    // Idle polling: every 10 minutes always (primary provider only)
    this.idleTask = cron.schedule(`*/${Math.ceil(idleInterval / 60)} * * * *`, async () => {
      try {
        const hasLive = await this.prisma.match.count({ where: { status: 'LIVE' } });
        if (hasLive === 0) {
          await Promise.all([this.syncMatches(), this.syncDateRange()]);
        }
      } catch (err: any) {
        await this.handleCronError(err, 'idle');
      }
    });

    // Secondary provider (API-Football): once per hour to stay within 100 req/day limit.
    if (this.secondaryProvider) {
      this.secondaryTask = cron.schedule('0 * * * *', async () => {
        try {
          await this.syncSecondary();
        } catch (err: any) {
          await this.handleCronError(err, 'secondary');
        }
      });
      console.log('MatchSyncJob secondary (API-Football) cron: every hour');
    }

    // Daily scoring cron: runs at 03:00 UTC (midnight Brazil time, UTC-3).
    // Scores all finished matches that still have unscored predictions.
    this.dailyScoringTask = cron.schedule('0 3 * * *', async () => {
      try {
        await this.scorePendingPredictions();
      } catch (err: any) {
        await this.handleCronError(err, 'daily-scoring');
      }
    });
    console.log('MatchSyncJob daily scoring cron: 03:00 UTC (midnight BRT)');

    // Predictions reminder: 15:00 UTC = 12:00 BRT — notifies users with unpredicted matches today/tomorrow
    if (this.notificationService) {
      this.predictionsReminderTask = cron.schedule('0 15 * * *', async () => {
        try {
          await this.notificationService!.sendPredictionsReminder();
        } catch (err: any) {
          await this.handleCronError(err, 'predictions-reminder');
        }
      });
      console.log('MatchSyncJob predictions reminder cron: 15:00 UTC (12:00 BRT)');
    }

    console.log('MatchSyncJob started');
    // Delay startup syncs by 5s so the event loop settles after server.listen() and
    // avoids TLS handshake ECONNRESET caused by simultaneous Neon cold-start + HTTP fetches.
    setTimeout(() => {
      this.syncMatches().catch(console.error);
      this.syncDateRange().catch(console.error);
      // Also score any pending predictions on startup (catches up from previous downtime).
      this.scorePendingPredictions().catch(console.error);
    }, 5000);
  }

  /** Handles connection errors in cron callbacks — reconnects Prisma so the next tick works. */
  private async handleCronError(err: any, cronName: string): Promise<void> {
    const isConnErr =
      err?.message?.includes('timed out') ||
      err?.message?.includes('timeout') ||
      err?.message?.includes('terminated') ||
      err?.message?.includes('Authentication') ||
      err?.message?.includes('ECONNRESET') ||
      err?.message?.includes('not queryable') ||
      err?.code === 'ECONNRESET';

    if (isConnErr) {
      console.warn(`[MatchSyncJob] [${cronName}] Connection error — reconnecting Prisma: ${err.message}`);
      await this.prisma.$disconnect().catch(() => {});
      await this.prisma.$connect().catch(() => {});
    } else {
      console.error(`[MatchSyncJob] [${cronName}] Unexpected cron error:`, err);
    }
  }

  stop(): void {
    this.liveTask?.stop();
    this.idleTask?.stop();
    this.secondaryTask?.stop();
    this.dailyScoringTask?.stop();
    this.predictionsReminderTask?.stop();
  }

  /** Syncs all enabled competitions + discovers new competitions via date-range scan (primary only). */
  async syncAll(): Promise<void> {
    await Promise.all([this.syncMatches(), this.syncDateRange()]);
  }

  /** Syncs matches for all currently-enabled competitions served by the primary provider. */
  async syncMatches(): Promise<void> {
    try {
      const competitions = await this.prisma.competition.findMany({ where: { enabled: true }, select: { code: true } });
      // Skip secondary-provider codes (FRIENDLIES, AF_*) — those are handled by syncSecondary()
      const primaryCodes = competitions
        .map((c) => c.code)
        .filter((code) => !code.startsWith('AF_') && code !== 'FRIENDLIES');
      for (const code of primaryCodes) {
        await this.syncCompetition(code).catch((err) =>
          console.error(`Competition sync failed for ${code}:`, err),
        );
      }
    } catch (err) {
      console.error('Match sync failed:', err);
    }
  }

  /**
   * Fetches matches from football-data.org for the current 7-day window.
   * Passes enabled competition codes as a filter (required by free tier).
   */
  async syncDateRange(): Promise<void> {
    try {
      const competitions = await this.prisma.competition.findMany({
        where: { enabled: true },
        select: { code: true },
      });
      // Only pass codes that belong to football-data.org (not secondary-provider codes).
      const fdCodes = competitions
        .map((c) => c.code)
        .filter((code) => !code.startsWith('AF_') && code !== 'FRIENDLIES');

      if (fdCodes.length === 0) return;

      const { dateFrom, dateTo } = getSevenDayWindow();
      const matches = await this.provider.getMatchesByDateRange(dateFrom, dateTo, fdCodes);

      // Discover and create any unseen competition codes.
      const codesInBatch = [...new Set(matches.map((m) => m.competition.code))];
      for (const code of codesInBatch) {
        const matchWithCode = matches.find((m) => m.competition.code === code)!;
        await this.prisma.competition.upsert({
          where: { code },
          update: {},
          create: {
            code,
            name: matchWithCode.competition.name,
            enabled: true,
          },
        });
      }

      // Upsert every match that has at least one national-team side (or unknown type).
      for (const match of matches) {
        const isNational =
          !match.homeTeam.type ||
          !match.awayTeam.type ||
          match.homeTeam.type === 'NATIONAL' ||
          match.awayTeam.type === 'NATIONAL';

        if (isNational) {
          await this.upsertMatch(match, match.competition.code);
        }
      }

      console.log(`Date-range sync (${dateFrom} → ${dateTo}): ${matches.length} matches, ${codesInBatch.length} competitions`);
    } catch (err) {
      console.error('Date-range sync failed:', err);
    }
  }

  /**
   * Updates status/scores for secondary-provider matches already in the DB.
   * Does NOT create new matches — those are created on-demand when a user predicts.
   * Also auto-expires stale SCHEDULED matches whose kickoff passed with no data.
   */
  async syncSecondary(): Promise<void> {
    if (!this.secondaryProvider) return;
    try {
      const { dateFrom, dateTo } = getTwoWeekWindow();
      const providerMatches = await this.secondaryProvider.getMatchesByDateRange(dateFrom, dateTo);

      // Build a map of externalId → provider data for fast lookup
      const providerMap = new Map(providerMatches.map((m) => [m.id, m]));

      // Find which secondary-provider matches are already in the DB
      const dbMatches = await this.prisma.match.findMany({
        where: {
          competitionCode: { in: ['FRIENDLIES'] },
          externalId: { in: [...providerMap.keys()] },
        },
        select: { id: true, externalId: true, competitionCode: true },
      });

      let updated = 0;
      for (const dbMatch of dbMatches) {
        const pm = providerMap.get(dbMatch.externalId);
        if (pm) {
          await this.upsertMatch(pm, dbMatch.competitionCode ?? pm.competition.code);
          updated++;
        }
      }

      if (updated > 0) {
        console.log(`[ApiFootball] Secondary sync updated ${updated} predicted match(es) in window`);
      }

      await this.autoExpirePastSecondaryMatches();
    } catch (err: any) {
      const isConnErr =
        err?.code === 'ECONNRESET' ||
        err?.message?.includes('timed out') ||
        err?.message?.includes('Authentication') ||
        err?.message?.includes('terminated');
      if (isConnErr) throw err;
      console.error('[ApiFootball] Secondary sync failed:', err);
    }
  }

  /**
   * Marks SCHEDULED/IN_PLAY secondary-provider matches (FRIENDLIES, AF_*) as FINISHED
   * when their kickoff was more than 2.5 hours ago AND the API returned no data for them
   * this cycle (i.e. they weren't upserted above).
   *
   * This prevents stale "upcoming" cards for past matches when the data provider's
   * free-tier season restriction blocks status updates.
   */
  private async autoExpirePastSecondaryMatches(): Promise<void> {
    try {
      const cutoff = new Date(Date.now() - 150 * 60 * 1000); // 2.5 hours ago

      const stale = await this.prisma.match.findMany({
        where: {
          competitionCode: { in: ['FRIENDLIES'] },
          status: { in: ['SCHEDULED', 'LIVE'] },
          kickoffTime: { lt: cutoff },
        },
        select: { id: true, homeTeamName: true, awayTeamName: true, kickoffTime: true },
      });

      if (stale.length === 0) return;

      console.log(`[ApiFootball] Auto-expiring ${stale.length} past SCHEDULED/LIVE match(es) with no score data.`);

      for (const m of stale) {
        await this.prisma.match.update({
          where: { id: m.id },
          data: { status: 'FINISHED', lastSyncedAt: new Date() },
        });
        console.log(`[ApiFootball] Auto-expired: ${m.homeTeamName} vs ${m.awayTeamName} (kickoff ${m.kickoffTime.toISOString()})`);
      }
    } catch (err) {
      console.error('[ApiFootball] autoExpirePastSecondaryMatches failed:', err);
    }
  }

  /**
   * Finds all FINISHED matches that still have unscored predictions and scores them.
   * Runs daily at midnight BRT and on startup to catch up from any downtime.
   */
  async scorePendingPredictions(): Promise<void> {
    try {
      const matchesWithPending = await this.prisma.match.findMany({
        where: {
          status: 'FINISHED',
          scoreHome: { not: null },
          scoreAway: { not: null },
          predictions: { some: { scoredAt: null } },
        },
        select: { id: true, homeTeamName: true, awayTeamName: true },
      });

      if (matchesWithPending.length === 0) {
        console.log('[DailyScoring] No pending predictions to score.');
        return;
      }

      console.log(`[DailyScoring] Scoring predictions for ${matchesWithPending.length} match(es)...`);
      for (const match of matchesWithPending) {
        await this.scorePredictionsHandler.handle(match.id).catch((err) =>
          console.error(`[DailyScoring] Failed for match ${match.id} (${match.homeTeamName} vs ${match.awayTeamName}):`, err),
        );
      }
      console.log('[DailyScoring] Done.');
    } catch (err) {
      console.error('[DailyScoring] Failed:', err);
    }
  }

  private async syncCompetition(code: string): Promise<void> {
    const matches = await this.provider.getCompetitionMatches(code);
    for (const match of matches) {
      await this.upsertMatch(match, code);
    }
    console.log(`Synced ${matches.length} matches for ${code}`);
  }

  private async upsertMatch(
    match: ProviderMatch | ProviderMatchWithCompetition,
    competitionCode: string,
    attempt = 1,
  ): Promise<void> {
    // Skip knockout matches where teams haven't been assigned yet
    if (!match.homeTeam.id || !match.awayTeam.id) {
      return;
    }
    const status = mapStatus(match.status);
    try {
    const savedMatch = await this.prisma.match.upsert({
      where: { externalId: match.id },
      create: {
        externalId: match.id,
        competitionCode,
        homeTeamId: match.homeTeam.id,
        homeTeamName: match.homeTeam.name,
        homeTeamShort: match.homeTeam.shortName,
        homeTeamCrest: match.homeTeam.crest,
        homeTeamType: match.homeTeam.type ?? null,
        awayTeamId: match.awayTeam.id,
        awayTeamName: match.awayTeam.name,
        awayTeamShort: match.awayTeam.shortName,
        awayTeamCrest: match.awayTeam.crest,
        awayTeamType: match.awayTeam.type ?? null,
        kickoffTime: new Date(match.utcDate),
        status,
        scoreHome: match.score.fullTime.home,
        scoreAway: match.score.fullTime.away,
        stage: match.stage,
        groupName: match.group,
        matchday: match.matchday,
      },
      update: {
        status,
        scoreHome: match.score.fullTime.home,
        scoreAway: match.score.fullTime.away,
        homeTeamType: match.homeTeam.type ?? null,
        awayTeamType: match.awayTeam.type ?? null,
        lastSyncedAt: new Date(),
      },
    });

    if (status === 'FINISHED') {
      await this.scorePredictionsHandler.handle(savedMatch.id).catch((err) =>
        console.error(`[ScorePredictions] Failed for match ${savedMatch.id}:`, err),
      );
    }
    } catch (err: any) {
      // Neon.tech serverless connections can drop; retry once with reconnect.
      const isConnErr =
        err?.code === 'ECONNRESET' ||
        err?.message?.includes('timed out') ||
        err?.message?.includes('Authentication');
      if (isConnErr && attempt === 1) {
        await this.prisma.$disconnect().catch(() => {});
        await this.prisma.$connect().catch(() => {});
        return this.upsertMatch(match, competitionCode, 2);
      }
      throw err;
    }
  }
}
