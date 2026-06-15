// src/application/handlers/__tests__/ScorePredictionsHandler.test.ts
import { ScorePredictionsHandler } from '../ScorePredictionsHandler';

function makePrisma(opts: {
  competitionCode?: string | null;
  points?: number;
} = {}) {
  const { competitionCode = 'WC', points = 10 } = opts;

  const rankingRow = { userId: 'user-1', totalPoints: points, exactScores: points === 10 ? 1 : 0, correctResults: points >= 5 ? 1 : 0, matchesPredicted: 1 };

  return {
    match: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'match-1',
        status: 'FINISHED',
        scoreHome: 2,
        scoreAway: 1,
        stage: 'GROUP_STAGE',
        matchday: 1,
        groupName: 'A',
        homeTeamName: 'Brasil',
        awayTeamName: 'Argentina',
        competitionCode,
      }),
    },
    prediction: {
      findMany: jest.fn().mockResolvedValue([
        { id: 'pred-1', userId: 'user-1', matchId: 'match-1', predictedHome: 2, predictedAway: 1, scoredAt: null },
      ]),
      update: jest.fn().mockResolvedValue({}),
    },
    ranking: {
      upsert: jest.fn().mockResolvedValue({}),
      findUnique: jest.fn().mockResolvedValue(rankingRow),
      count: jest.fn().mockResolvedValue(0),
    },
    rankingHistory: {
      upsert: jest.fn().mockResolvedValue({}),
    },
    userCompetitionStats: {
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

describe('ScorePredictionsHandler', () => {
  beforeEach(() => jest.clearAllMocks());

  test('upserts userCompetitionStats when match has competitionCode', async () => {
    const prisma = makePrisma({ competitionCode: 'WC', points: 10 });
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle('match-1');

    expect(prisma.userCompetitionStats.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId_competitionCode: { userId: 'user-1', competitionCode: 'WC' } },
      }),
    );
  });

  test('skips userCompetitionStats when match has no competitionCode', async () => {
    const prisma = makePrisma({ competitionCode: null });
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle('match-1');

    expect(prisma.userCompetitionStats.upsert).not.toHaveBeenCalled();
  });

  test('saves competitionCode in rankingHistory snapshot', async () => {
    const prisma = makePrisma({ competitionCode: 'WC' });
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle('match-1');

    expect(prisma.rankingHistory.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ competitionCode: 'WC' }),
      }),
    );
  });
});
