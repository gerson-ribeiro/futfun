import { IFootballDataProvider, ProviderMatch, ProviderMatchWithCompetition } from '@application/ports/IFootballDataProvider';

export class FootballDataOrgAdapter implements IFootballDataProvider {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor() {
    this.baseUrl = process.env.FOOTBALL_DATA_ORG_BASE_URL || 'https://api.football-data.org/v4';
    this.apiKey = process.env.FOOTBALL_DATA_ORG_API_KEY!;
  }

  private async fetchApi(path: string): Promise<any> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      headers: { 'X-Auth-Token': this.apiKey },
    });
    if (!response.ok) {
      throw new Error(`Football API error: ${response.status} ${response.statusText}`);
    }
    return response.json();
  }

  async getCompetitionMatches(code: string, season?: number): Promise<ProviderMatch[]> {
    const seasonParam = season ? `?season=${season}` : '';
    const data = await this.fetchApi(`/competitions/${code}/matches${seasonParam}`);
    return data.matches || [];
  }

  async getMatchById(externalId: number): Promise<ProviderMatch> {
    return this.fetchApi(`/matches/${externalId}`);
  }

  async getLiveMatches(code: string): Promise<ProviderMatch[]> {
    const data = await this.fetchApi(`/competitions/${code}/matches?status=IN_PLAY`);
    return data.matches || [];
  }

  async getMatchesByDateRange(dateFrom: string, dateTo: string, competitionCodes?: string[]): Promise<ProviderMatchWithCompetition[]> {
    const competitionsParam = competitionCodes && competitionCodes.length > 0
      ? `&competitions=${competitionCodes.join(',')}`
      : '';
    const data = await this.fetchApi(`/matches?dateFrom=${dateFrom}&dateTo=${dateTo}${competitionsParam}`);
    return (data.matches || []).filter((m: any) => m.competition?.code) as ProviderMatchWithCompetition[];
  }
}
