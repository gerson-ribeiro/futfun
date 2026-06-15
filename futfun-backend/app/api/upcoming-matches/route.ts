// app/api/upcoming-matches/route.ts
//
// Returns upcoming matches from both providers without writing to the DB.
// Provider data is cached per daysAhead value for 5 minutes.
// hasPrediction is injected per-request (user-specific, never cached).

import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { ProviderMatchWithCompetition } from '@application/ports/IFootballDataProvider';
import { TokenPayload } from '@application/ports/ITokenService';

// Provider data only — shared across users, safe to cache
interface CachedMatch {
  id: string;
  externalId: number;
  competitionCode: string;
  competitionName: string;
  homeTeamId: number;
  homeTeamName: string;
  homeTeamShort: string | null;
  homeTeamCrest: string | null;
  homeTeamType: string | null;
  awayTeamId: number;
  awayTeamName: string;
  awayTeamShort: string | null;
  awayTeamCrest: string | null;
  awayTeamType: string | null;
  kickoffTime: string;
  status: string;
  scoreHome: number | null;
  scoreAway: number | null;
  stage: string;
  groupName: string | null;
  matchday: number | null;
}

// Sent to client — adds per-user hasPrediction flag
interface UpcomingMatch extends CachedMatch {
  hasPrediction: boolean;
}

// Cache keyed by daysAhead; stores provider data only (no user-specific fields)
const matchCache = new Map<number, { data: CachedMatch[]; ts: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000;

// dateFrom = today 00:00 UTC; dateTo = today + daysAhead days 23:59 UTC
function getMatchWindow(daysAhead: number) {
  const now = new Date();
  const from = new Date(now);
  from.setUTCHours(0, 0, 0, 0);
  const to = new Date(now);
  to.setUTCDate(now.getUTCDate() + daysAhead);
  to.setUTCHours(23, 59, 59, 999);
  return {
    dateFrom: from.toISOString().split('T')[0],
    dateTo: to.toISOString().split('T')[0],
  };
}

function toCachedMatch(m: ProviderMatchWithCompetition): CachedMatch {
  return {
    id: m.id.toString(),
    externalId: m.id,
    competitionCode: m.competition.code,
    competitionName: m.competition.name,
    homeTeamId: m.homeTeam.id,
    homeTeamName: m.homeTeam.name,
    homeTeamShort: m.homeTeam.shortName ?? null,
    homeTeamCrest: m.homeTeam.crest ?? null,
    homeTeamType: m.homeTeam.type ?? null,
    awayTeamId: m.awayTeam.id,
    awayTeamName: m.awayTeam.name,
    awayTeamShort: m.awayTeam.shortName ?? null,
    awayTeamCrest: m.awayTeam.crest ?? null,
    awayTeamType: m.awayTeam.type ?? null,
    kickoffTime: m.utcDate.includes('T') ? m.utcDate : `${m.utcDate}T00:00:00Z`,
    status: m.status,
    scoreHome: m.score.fullTime.home ?? null,
    scoreAway: m.score.fullTime.away ?? null,
    stage: m.stage,
    groupName: m.group ?? null,
    matchday: m.matchday ?? null,
  };
}

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const { searchParams } = req.nextUrl;
    const competitionCode = searchParams.get('competitionCode');
    const daysAhead = Math.max(1, parseInt(searchParams.get('daysAhead') ?? '7', 10) || 7);

    const { prisma, footballProvider, secondaryProvider } = getContainer();
    const now = Date.now();
    const cached = matchCache.get(daysAhead);

    let providerMatches: CachedMatch[];

    if (cached && now - cached.ts <= CACHE_TTL_MS) {
      providerMatches = cached.data;
    } else {
      const { dateFrom, dateTo } = getMatchWindow(daysAhead);

      // Primary provider: enabled competitions (excludes secondary-provider codes)
      // 'AF_*' = API-Football codes; 'FRIENDLIES' / 'CLI' = TheSportsDB codes
      let primaryMatches: ProviderMatchWithCompetition[] = [];
      try {
        const competitions = await prisma.competition.findMany({
          where: { enabled: true },
          select: { code: true },
        });
        const fdCodes = competitions
          .map((c) => c.code)
          .filter((code) => !code.startsWith('AF_') && code !== 'FRIENDLIES' && code !== 'CLI');

        if (fdCodes.length > 0) {
          primaryMatches = await footballProvider.getMatchesByDateRange(dateFrom, dateTo, fdCodes);
        }
      } catch (err) {
        console.warn('[UpcomingMatches] Primary provider failed:', err);
      }

      // Secondary provider: TheSportsDB (international friendlies)
      let secondaryMatches: ProviderMatchWithCompetition[] = [];
      try {
        secondaryMatches = await secondaryProvider.getMatchesByDateRange(dateFrom, dateTo);
      } catch (err) {
        console.warn('[UpcomingMatches] Secondary provider failed:', err);
      }

      // Merge, deduplicate by externalId, sort by kickoff
      const seen = new Set<number>();
      const all: CachedMatch[] = [];
      for (const m of [...primaryMatches, ...secondaryMatches]) {
        if (!m.homeTeam?.id || !m.awayTeam?.id) continue;
        if (seen.has(m.id)) continue;
        seen.add(m.id);
        all.push(toCachedMatch(m));
      }
      all.sort((a, b) => new Date(a.kickoffTime).getTime() - new Date(b.kickoffTime).getTime());

      matchCache.set(daysAhead, { data: all, ts: now });
      console.log(`[UpcomingMatches] Cache refreshed for daysAhead=${daysAhead}: ${all.length} matches`);
      providerMatches = all;
    }

    // Apply competition filter before user query to reduce lookup set
    const filtered = competitionCode
      ? providerMatches.filter((m) => m.competitionCode === competitionCode)
      : providerMatches;

    // One DB query: find which of these matches the user has already predicted
    const externalIds = filtered.map((m) => m.externalId);
    const predictedRows = externalIds.length > 0
      ? await prisma.prediction.findMany({
          where: {
            userId: user.userId,
            match: { externalId: { in: externalIds } },
          },
          select: { match: { select: { externalId: true } } },
        })
      : [];
    const predictedSet = new Set(predictedRows.map((r) => r.match.externalId));

    const matches: UpcomingMatch[] = filtered.map((m) => ({
      ...m,
      hasPrediction: predictedSet.has(m.externalId),
    }));

    return NextResponse.json({ matches });
  } catch (error) {
    return handleError(error);
  }
});
