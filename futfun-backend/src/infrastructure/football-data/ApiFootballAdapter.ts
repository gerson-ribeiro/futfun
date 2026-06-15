// src/infrastructure/football-data/ApiFootballAdapter.ts
//
// Fetches international friendly matches (and other competitions absent from
// football-data.org) via the API-Football v3 service (api-sports.io).
//
// Uses native fetch (Node 18+) — no extra dependency needed.
// Only getMatchesByDateRange is implemented — football-data.org handles
// competition-specific syncs; this adapter fills the gap for friendlies.

import {
  IFootballDataProvider,
  ProviderMatch,
  ProviderMatchWithCompetition,
} from '@application/ports/IFootballDataProvider';

// API-Football league IDs for competitions not covered by football-data.org.
// League 667 = International Friendlies (stored under FRIENDLIES code, same as before)
const FRIENDLY_LEAGUE_IDS = [667];

const BASE_URL = 'https://v3.football.api-sports.io';

function mapStatus(short: string): ProviderMatch['status'] {
  switch (short) {
    case 'FT':
    case 'AET':
    case 'PEN':
      return 'FINISHED';
    case '1H':
    case 'HT':
    case '2H':
    case 'ET':
    case 'BT':
    case 'P':
    case 'LIVE':
      return 'IN_PLAY';
    case 'PST':
      return 'POSTPONED';
    case 'CANC':
    case 'ABD':
      return 'CANCELLED';
    default:
      return 'SCHEDULED';
  }
}

export class ApiFootballAdapter implements IFootballDataProvider {
  private readonly apiKey: string;

  constructor() {
    this.apiKey = process.env.API_FOOTBALL_KEY!;
  }

  private async get<T extends { errors?: any; results?: number }>(
    path: string,
    params: Record<string, string | number>,
  ): Promise<T> {
    const url = new URL(`${BASE_URL}${path}`);
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.set(k, String(v));
    }
    const res = await fetch(url.toString(), {
      headers: { 'x-apisports-key': this.apiKey },
    });
    if (!res.ok) {
      throw new Error(`API-Football ${path} returned ${res.status}`);
    }
    const json = (await res.json()) as T;
    // Log API-level errors (quota exceeded, invalid key, etc.)
    if (json.errors && Object.keys(json.errors).length > 0) {
      console.warn(`[ApiFootball] API errors for ${path}?${url.searchParams}:`, JSON.stringify(json.errors));
    }
    if (json.results === 0) {
      console.log(`[ApiFootball] 0 results for ${path}?${url.searchParams}`);
    }
    return json;
  }

  /** Not needed — football-data.org handles competition-specific syncs. */
  async getCompetitionMatches(_code: string): Promise<ProviderMatch[]> {
    return [];
  }

  /** Not implemented for this adapter. */
  async getMatchById(_externalId: number): Promise<ProviderMatch> {
    throw new Error('ApiFootballAdapter.getMatchById not implemented');
  }

  /** Not needed for this adapter. */
  async getLiveMatches(_code: string): Promise<ProviderMatch[]> {
    return [];
  }

  /**
   * Returns true if an API-Football error object signals a free-plan season restriction.
   * The free plan allows seasons 2022–2024; 2025+ are premium-only.
   */
  private isFreePlanSeasonError(errors: any): boolean {
    if (!errors || typeof errors !== 'object') return false;
    const msg = JSON.stringify(errors).toLowerCase();
    return msg.includes('free plans do not have access to this season');
  }

  /**
   * Fetches all upcoming/recent national-team matches (friendlies + qualifiers)
   * within [dateFrom, dateTo] from API-Football.
   *
   * Free-tier limitation: league 667 only allows seasons 2022–2024.
   * We try the current year first, then walk back until we find an accessible season
   * or reach 2024 (the last confirmed free-tier season).
   */
  async getMatchesByDateRange(
    dateFrom: string,
    dateTo: string,
  ): Promise<ProviderMatchWithCompetition[]> {
    const currentYear = new Date(dateFrom).getFullYear();
    // Last season accessible on the free plan for league 667.
    const FREE_TIER_MIN_SEASON = 2024;
    const results: ProviderMatchWithCompetition[] = [];

    for (const leagueId of FRIENDLY_LEAGUE_IDS) {
      try {
        let data: { response: any[]; results?: number; errors?: any } | null = null;

        // Walk back from currentYear to FREE_TIER_MIN_SEASON, stopping at the first
        // season that is not blocked by the free-plan restriction.
        for (let season = currentYear; season >= FREE_TIER_MIN_SEASON; season--) {
          const candidate = await this.get<{ response: any[]; results?: number; errors?: any }>('/fixtures', {
            league: leagueId,
            season,
            from: dateFrom,
            to: dateTo,
          });

          if (this.isFreePlanSeasonError(candidate.errors)) {
            console.log(`[ApiFootball] league=${leagueId} season=${season} blocked by free plan — trying season=${season - 1}`);
            continue;
          }

          data = candidate;
          if ((data.results ?? data.response?.length ?? 0) > 0) break;
          // Season accessible but 0 results — fall back to previous year in case
          // fixtures for this date window are filed under an older season.
          if (season > FREE_TIER_MIN_SEASON) {
            console.log(`[ApiFootball] league=${leagueId} season=${season} returned 0 — retrying with season=${season - 1}`);
          }
        }

        if (!data) break;

        for (const f of data.response ?? []) {
          const fixture = f.fixture;
          const league  = f.league;
          const teams   = f.teams;
          const goals   = f.goals;
          const score   = f.score?.fulltime;

          if (!fixture?.id || !teams?.home?.id || !teams?.away?.id) continue;

          results.push({
            id: fixture.id,
            utcDate: fixture.date,
            status: mapStatus(fixture.status?.short ?? 'NS'),
            stage: league.round ?? 'Regular Season',
            group: undefined,
            matchday: undefined,
            homeTeam: {
              id: teams.home.id,
              name: teams.home.name,
              shortName: teams.home.name,
              crest: teams.home.logo,
              type: 'NATIONAL',
            },
            awayTeam: {
              id: teams.away.id,
              name: teams.away.name,
              shortName: teams.away.name,
              crest: teams.away.logo,
              type: 'NATIONAL',
            },
            score: {
              fullTime: {
                home: score?.home ?? goals?.home ?? null,
                away: score?.away ?? goals?.away ?? null,
              },
            },
            competition: {
              code: 'FRIENDLIES',
              name: 'International Friendlies',
            },
          });
        }
      } catch (err) {
        console.error(`[ApiFootball] Failed to fetch league ${leagueId}:`, err);
      }
    }

    return results;
  }
}
