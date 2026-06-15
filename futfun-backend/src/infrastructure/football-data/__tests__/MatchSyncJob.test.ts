// src/infrastructure/football-data/__tests__/MatchSyncJob.test.ts
import { MatchSyncJob } from '../MatchSyncJob';
import { IFootballDataProvider, ProviderMatch } from '@application/ports/IFootballDataProvider';

jest.mock('node-cron', () => ({
  schedule: jest.fn().mockReturnValue({ stop: jest.fn() }),
}));

function makeMatch(overrides: Partial<ProviderMatch> = {}): ProviderMatch {
  return {
    id: 1,
    homeTeam: { id: 10, name: 'Brazil', shortName: 'BRA', crest: 'https://crest/bra.png' },
    awayTeam: { id: 20, name: 'Germany', shortName: 'GER', crest: 'https://crest/ger.png' },
    utcDate: '2026-06-15T18:00:00Z',
    status: 'SCHEDULED',
    score: { fullTime: { home: null, away: null } },
    stage: 'GROUP_STAGE',
    group: 'Group A',
    matchday: 1,
    ...overrides,
  };
}

function makePrisma() {
  return {
    competition: {
      findMany: jest.fn().mockResolvedValue([{ code: 'WC' }]),
    },
    match: {
      count: jest.fn().mockResolvedValue(0),
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

function makeProvider(matches: ProviderMatch[] = [makeMatch()]): IFootballDataProvider {
  return {
    getCompetitionMatches: jest.fn().mockResolvedValue(matches),
    getMatchById: jest.fn(),
    getLiveMatches: jest.fn(),
    getMatchesByDateRange: jest.fn().mockResolvedValue([]),
  };
}

describe('MatchSyncJob', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('syncMatches', () => {
    test('fetches matches using the configured competition code', async () => {
      const provider = makeProvider();
      const job = new MatchSyncJob(makePrisma() as any, provider);

      await job.syncMatches();

      expect(provider.getCompetitionMatches).toHaveBeenCalledWith('WC');
    });

    test('syncs each enabled competition from the database', async () => {
      const prisma = {
        competition: { findMany: jest.fn().mockResolvedValue([{ code: 'WC' }, { code: 'CLI' }]) },
        match: { count: jest.fn().mockResolvedValue(0), upsert: jest.fn().mockResolvedValue({}) },
      };
      const provider = makeProvider([makeMatch()]);
      const job = new MatchSyncJob(prisma as any, provider);

      await job.syncMatches();

      expect(provider.getCompetitionMatches).toHaveBeenCalledWith('WC');
      expect(provider.getCompetitionMatches).toHaveBeenCalledWith('CLI');
      expect(provider.getCompetitionMatches).toHaveBeenCalledTimes(2);
    });

    test('upserts each match returned by the provider', async () => {
      const matches = [
        makeMatch({ id: 1 }),
        makeMatch({ id: 2, homeTeam: { id: 11, name: 'Argentina', shortName: 'ARG' }, awayTeam: { id: 21, name: 'France', shortName: 'FRA' } }),
      ];
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider(matches));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledTimes(2);
    });

    test('skips matches where homeTeam.id is falsy', async () => {
      const unassigned = makeMatch({ homeTeam: { id: 0, name: 'TBD' } });
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([unassigned]));

      await job.syncMatches();

      expect(prisma.match.upsert).not.toHaveBeenCalled();
    });

    test('skips matches where awayTeam.id is falsy', async () => {
      const unassigned = makeMatch({ awayTeam: { id: 0, name: 'TBD' } });
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([unassigned]));

      await job.syncMatches();

      expect(prisma.match.upsert).not.toHaveBeenCalled();
    });

    test('maps SCHEDULED status correctly', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ status: 'SCHEDULED' })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'SCHEDULED' }) })
      );
    });

    test('maps IN_PLAY status to LIVE', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ status: 'IN_PLAY' })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'LIVE' }) })
      );
    });

    test('maps PAUSED status to LIVE', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ status: 'PAUSED' })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'LIVE' }) })
      );
    });

    test('maps FINISHED status correctly', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(
        prisma as any,
        makeProvider([makeMatch({ status: 'FINISHED', score: { fullTime: { home: 2, away: 1 } } })])
      );

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ create: expect.objectContaining({ status: 'FINISHED' }) })
      );
    });

    test('upserts with externalId as the unique key', async () => {
      const prisma = makePrisma();
      const job = new MatchSyncJob(prisma as any, makeProvider([makeMatch({ id: 999 })]));

      await job.syncMatches();

      expect(prisma.match.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ where: { externalId: 999 } })
      );
    });

    test('catches and logs provider errors without throwing', async () => {
      const brokenProvider: IFootballDataProvider = {
        getCompetitionMatches: jest.fn().mockRejectedValue(new Error('network down')),
        getMatchById: jest.fn(),
        getLiveMatches: jest.fn(),
        getMatchesByDateRange: jest.fn().mockResolvedValue([]),
      };
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
      const job = new MatchSyncJob(makePrisma() as any, brokenProvider);

      await expect(job.syncMatches()).resolves.toBeUndefined();
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });

  describe('start / stop', () => {
    test('calls syncMatches immediately on start', async () => {
      const provider = makeProvider([]);
      const job = new MatchSyncJob(makePrisma() as any, provider);

      job.start();
      // Allow the microtask queue to flush
      await new Promise(resolve => setImmediate(resolve));

      expect(provider.getCompetitionMatches).toHaveBeenCalled();
    });

    test('stop does not throw', () => {
      const job = new MatchSyncJob(makePrisma() as any, makeProvider([]));
      job.start();
      expect(() => job.stop()).not.toThrow();
    });
  });
});
