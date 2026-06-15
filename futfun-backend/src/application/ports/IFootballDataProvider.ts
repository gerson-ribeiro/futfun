export interface ProviderTeam {
  id: number;
  name: string;
  shortName?: string;
  crest?: string;
  type?: 'NATIONAL' | 'CLUB';
}

export interface ProviderScore {
  home: number | null;
  away: number | null;
}

export interface ProviderMatch {
  id: number;
  homeTeam: ProviderTeam;
  awayTeam: ProviderTeam;
  utcDate: string;
  status: 'SCHEDULED' | 'TIMED' | 'IN_PLAY' | 'PAUSED' | 'FINISHED' | 'CANCELLED' | 'POSTPONED';
  score: {
    fullTime: ProviderScore;
  };
  stage: string;
  group?: string;
  matchday?: number;
}

export interface ProviderMatchWithCompetition extends ProviderMatch {
  competition: {
    code: string;
    name: string;
  };
}

export interface IFootballDataProvider {
  getCompetitionMatches(code: string, season?: number): Promise<ProviderMatch[]>;
  getMatchById(externalId: number): Promise<ProviderMatch>;
  getLiveMatches(code: string): Promise<ProviderMatch[]>;
  /** Returns matches within the given date range, optionally filtered by competition codes. */
  getMatchesByDateRange(dateFrom: string, dateTo: string, competitionCodes?: string[]): Promise<ProviderMatchWithCompetition[]>;
}
