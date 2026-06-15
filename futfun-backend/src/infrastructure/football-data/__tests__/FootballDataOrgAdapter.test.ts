// src/infrastructure/football-data/__tests__/FootballDataOrgAdapter.test.ts
import { FootballDataOrgAdapter } from '../FootballDataOrgAdapter';

const mockFetch = jest.fn();

beforeAll(() => {
  global.fetch = mockFetch;
});

function mockOkResponse(body: unknown) {
  return mockFetch.mockResolvedValueOnce({
    ok: true,
    json: jest.fn().mockResolvedValue(body),
  });
}

function mockErrorResponse(status: number, statusText: string) {
  return mockFetch.mockResolvedValueOnce({ ok: false, status, statusText });
}

describe('FootballDataOrgAdapter', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.FOOTBALL_DATA_ORG_BASE_URL = 'https://api.football-data.org/v4';
    process.env.FOOTBALL_DATA_ORG_API_KEY = 'test-api-key';
  });

  describe('getCompetitionMatches', () => {
    test('calls correct URL without season param', async () => {
      mockOkResponse({ matches: [] });
      const adapter = new FootballDataOrgAdapter();
      await adapter.getCompetitionMatches('WC');

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/competitions/WC/matches',
        expect.objectContaining({ headers: { 'X-Auth-Token': 'test-api-key' } })
      );
    });

    test('appends season query param when provided', async () => {
      mockOkResponse({ matches: [] });
      const adapter = new FootballDataOrgAdapter();
      await adapter.getCompetitionMatches('WC', 2026);

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/competitions/WC/matches?season=2026',
        expect.anything()
      );
    });

    test('returns matches array from API response', async () => {
      const fakeMatch = { id: 1, homeTeam: { id: 10 }, awayTeam: { id: 20 } };
      mockOkResponse({ matches: [fakeMatch] });
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getCompetitionMatches('WC');

      expect(result).toEqual([fakeMatch]);
    });

    test('returns empty array when API response has no matches key', async () => {
      mockOkResponse({});
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getCompetitionMatches('WC');

      expect(result).toEqual([]);
    });

    test('throws when API response is not OK', async () => {
      mockErrorResponse(429, 'Too Many Requests');
      const adapter = new FootballDataOrgAdapter();

      await expect(adapter.getCompetitionMatches('WC')).rejects.toThrow(
        'Football API error: 429 Too Many Requests'
      );
    });
  });

  describe('getMatchById', () => {
    test('calls correct URL for match ID', async () => {
      const fakeMatch = { id: 42 };
      mockOkResponse(fakeMatch);
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getMatchById(42);

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/matches/42',
        expect.anything()
      );
      expect(result).toEqual(fakeMatch);
    });
  });

  describe('getLiveMatches', () => {
    test('calls URL with status=IN_PLAY filter', async () => {
      mockOkResponse({ matches: [] });
      const adapter = new FootballDataOrgAdapter();
      await adapter.getLiveMatches('WC');

      expect(mockFetch).toHaveBeenCalledWith(
        'https://api.football-data.org/v4/competitions/WC/matches?status=IN_PLAY',
        expect.anything()
      );
    });

    test('returns matches array', async () => {
      const liveMatch = { id: 99 };
      mockOkResponse({ matches: [liveMatch] });
      const adapter = new FootballDataOrgAdapter();
      const result = await adapter.getLiveMatches('WC');

      expect(result).toEqual([liveMatch]);
    });
  });
});
