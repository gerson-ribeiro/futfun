// src/infrastructure/football-data/TheSportsDbAdapter.ts
//
// Fetches international friendly matches from TheSportsDB (free, no key needed).
// League 4562 = "International Friendlies"
//
// Strategy (avoids the eventsseason null issue and eventsround 50-event cap):
//  1. Call eventspastleague to get the most recently finished event's round number
//  2. Fetch that round and the next round via eventsround (covers the 2-week window)
//  3. Call eventsnextleague for the first upcoming event (catches round overflow)
//  4. Call eventsnext for Brazil (id=134496) — guarantees Brazil matches always appear
//  5. Filter all collected events to [dateFrom, dateTo] and deduplicate

import {
  IFootballDataProvider,
  ProviderMatch,
  ProviderMatchWithCompetition,
} from '@application/ports/IFootballDataProvider';

const BASE_URL = 'https://www.thesportsdb.com/api/v1/json/3';
const LEAGUE_ID = '4562'; // International Friendlies (national teams)
const COMPETITION_CODE = 'CLI'; // matches the 'CLI' competition row in the DB (Amistosos Internacionais)
const COMPETITION_NAME = 'Amistosos Internacionais';

// TheSportsDB IDs for national teams whose matches we always want to catch,
// even when they fall in the overflow beyond eventsround's 50-event cap.
const PRIORITY_TEAM_IDS = [
  '134496', // Brazil
];

function mapStatus(strStatus: string): ProviderMatch['status'] {
  const s = (strStatus ?? '').toLowerCase();
  if (s === 'match finished' || s === 'ft' || s === 'aet' || s === 'pen') return 'FINISHED';
  if (['1h', '2h', 'ht', 'et', 'bt', 'live', 'in progress', 'p'].includes(s)) return 'IN_PLAY';
  if (s === 'postponed') return 'POSTPONED';
  if (s === 'cancelled' || s === 'canceled' || s === 'canc') return 'CANCELLED';
  return 'SCHEDULED';
}

/**
 * Normalize TheSportsDB timestamp to a valid ISO 8601 UTC string.
 * Handles two formats the API returns:
 *  - "2026-06-10T01:00:00+00:00"  — already valid, kept as-is
 *  - "2026-06-10 01:00:00"        — space separator, no tz → treated as UTC
 */
function normalizeTimestamp(ts: string): string {
  const withT = ts.replace(' ', 'T');
  if (!withT.includes('+') && !withT.endsWith('Z')) {
    return withT + 'Z';
  }
  return withT;
}

function parseEvent(e: any): ProviderMatchWithCompetition | null {
  if (!e?.idEvent || !e?.idHomeTeam || !e?.idAwayTeam) return null;

  // Skip youth / women categories to focus on senior national team matches
  const name: string = (e.strEvent ?? '') + ' ' + (e.strHomeTeam ?? '') + ' ' + (e.strAwayTeam ?? '');
  if (/\bU\d{2}\b/i.test(name) || /women|féminin|femenino/i.test(name)) return null;

  const rawTs: string | undefined = e.strTimestamp ?? (e.dateEvent && e.strTime
    ? `${e.dateEvent}T${e.strTime}Z`
    : e.dateEvent ? `${e.dateEvent}T12:00:00Z` : undefined);
  if (!rawTs) return null;
  const kickoffStr = normalizeTimestamp(rawTs);

  return {
    id: parseInt(e.idEvent, 10),
    utcDate: kickoffStr,
    status: mapStatus(e.strStatus ?? ''),
    stage: e.strRound ?? 'Regular Season',
    group: undefined,
    matchday: undefined,
    homeTeam: {
      id: parseInt(e.idHomeTeam, 10),
      name: e.strHomeTeam,
      shortName: e.strHomeTeam,
      crest: e.strHomeTeamBadge ?? undefined,
      type: 'NATIONAL',
    },
    awayTeam: {
      id: parseInt(e.idAwayTeam, 10),
      name: e.strAwayTeam,
      shortName: e.strAwayTeam,
      crest: e.strAwayTeamBadge ?? undefined,
      type: 'NATIONAL',
    },
    score: {
      fullTime: {
        home: e.intHomeScore !== null && e.intHomeScore !== '' ? parseInt(e.intHomeScore, 10) : null,
        away: e.intAwayScore !== null && e.intAwayScore !== '' ? parseInt(e.intAwayScore, 10) : null,
      },
    },
    competition: {
      code: COMPETITION_CODE,
      name: COMPETITION_NAME,
    },
  };
}

export class TheSportsDbAdapter implements IFootballDataProvider {

  private async fetchJson(path: string, timeoutMs = 30000): Promise<any> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(`${BASE_URL}${path}`, { signal: controller.signal });
      if (!res.ok) throw new Error(`TheSportsDB ${path} returned ${res.status}`);
      return res.json();
    } finally {
      clearTimeout(timer);
    }
  }

  async getCompetitionMatches(_code: string): Promise<ProviderMatch[]> { return []; }
  async getMatchById(_id: number): Promise<ProviderMatch> { throw new Error('not implemented'); }
  async getLiveMatches(_code: string): Promise<ProviderMatch[]> { return []; }

  /**
   * Returns upcoming + recent international friendlies in [dateFrom, dateTo].
   *
   * TheSportsDB free tier notes:
   * - eventsround returns max 50 events per round; large rounds overflow
   * - eventsnextleague / eventspastleague return max 1 event each (free tier cap)
   * - eventsseason returns null for recent seasons on the free tier
   */
  async getMatchesByDateRange(
    dateFrom: string,
    dateTo: string,
  ): Promise<ProviderMatchWithCompetition[]> {
    const from = new Date(dateFrom);
    const to = new Date(dateTo);
    to.setUTCHours(23, 59, 59, 999);

    const season = new Date(dateFrom).getFullYear().toString();
    const rawEvents: any[] = [];

    // 1. Get the last-finished event to determine the current round number
    let currentRound = 17; // default fallback for June 2026 WC prep window
    try {
      const pastData = await this.fetchJson(`/eventspastleague.php?id=${LEAGUE_ID}`);
      const lastEvent = (pastData?.events ?? [])[0];
      if (lastEvent?.intRound) {
        currentRound = parseInt(lastEvent.intRound, 10);
      }
    } catch (err) {
      console.warn('[TheSportsDB] Could not determine current round, using default:', currentRound);
    }

    // 2. Fetch the current round and next 2 rounds (covers ~3 weeks)
    for (let r = currentRound; r <= currentRound + 2; r++) {
      try {
        const data = await this.fetchJson(`/eventsround.php?id=${LEAGUE_ID}&r=${r}&s=${season}`);
        rawEvents.push(...(data?.events ?? []));
      } catch (err) {
        console.warn(`[TheSportsDB] Failed to fetch round ${r}:`, err);
      }
    }

    // 3. eventsnextleague — catches the first upcoming event that may overflow the round cap
    try {
      const nextData = await this.fetchJson(`/eventsnextleague.php?id=${LEAGUE_ID}`);
      rawEvents.push(...(nextData?.events ?? []));
    } catch (err) {
      console.warn('[TheSportsDB] eventsnextleague failed:', err);
    }

    // 4. Priority team next-events — ensures Brazil (and other key teams) matches
    // appear even when they fall past the 50-event round cap
    for (const teamId of PRIORITY_TEAM_IDS) {
      try {
        const data = await this.fetchJson(`/eventsnext.php?id=${teamId}`);
        rawEvents.push(...(data?.events ?? []));
      } catch (err) {
        console.warn(`[TheSportsDB] eventsnext for team ${teamId} failed:`, err);
      }
    }

    // 5. Deduplicate and filter by date window
    const results: ProviderMatchWithCompetition[] = [];
    const seen = new Set<number>();

    for (const e of rawEvents) {
      const match = parseEvent(e);
      if (!match || seen.has(match.id)) continue;
      seen.add(match.id);

      const kickoff = new Date(match.utcDate);
      if (kickoff >= from && kickoff <= to) {
        results.push(match);
      }
    }

    console.log(`[TheSportsDB] round=${currentRound}–${currentRound + 2}, season=${season}: ${results.length} matches in window`);
    return results;
  }
}
