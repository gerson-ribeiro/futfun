import { PointsCalculationService } from '../PointsCalculationService';

describe('PointsCalculationService', () => {
  let service: PointsCalculationService;

  beforeEach(() => {
    service = new PointsCalculationService();
  });

  it('should return 10 for an exact score match', () => {
    expect(
      service.calculate({ actualHome: 2, actualAway: 1, predictedHome: 2, predictedAway: 1 })
    ).toBe(10);
  });

  it('should return 10 for an exact score match (draw)', () => {
    expect(
      service.calculate({ actualHome: 0, actualAway: 0, predictedHome: 0, predictedAway: 0 })
    ).toBe(10);
  });

  it('should return 7 for correct result with home score correct', () => {
    // Home win: actual 3-1, predicted 3-0 (home score matches, away doesn't)
    expect(
      service.calculate({ actualHome: 3, actualAway: 1, predictedHome: 3, predictedAway: 0 })
    ).toBe(7);
  });

  it('should return 7 for correct result with away score correct', () => {
    // Home win: actual 3-1, predicted 2-1 (away score matches, home doesn't)
    expect(
      service.calculate({ actualHome: 3, actualAway: 1, predictedHome: 2, predictedAway: 1 })
    ).toBe(7);
  });

  it('should return 7 for correct result (draw) with home score correct', () => {
    // Draw: actual 2-2, predicted 2-3 (home score matches, away doesn't — but predicted away win, not draw)
    // Actually need a draw prediction: actual 1-1, predicted 1-3 would be predicted away win, not draw
    // For draw result + correct result: predicted must also be draw
    // actual 2-2, predicted 2-0: both draws? No, 2-0 is a home win.
    // Draw result: actual 1-1. Predicted draw with home score: predicted 1-2? No that's away win.
    // predicted 1-0 is home win. predicted 0-0 is draw, no score match.
    // actual 2-2, predicted 2-2 is exact (10). actual 1-1, predicted 1-0 = wrong result.
    // For draw + one score correct: actual 2-2, predicted 2-3 — predicted is away win, wrong result.
    // actual 1-1, predicted 1-4 — predicted is away win, wrong result.
    // Correct: actual 2-2, predicted 2-1 — 2===2 home match, result: both draws? Math.sign(2-2)=0, Math.sign(2-1)=1 → not a draw prediction, so wrong result.
    // So to get draw + one score correct: both must be draw AND one score must match.
    // actual 3-3, predicted 3-1: Math.sign(3-3)=0, Math.sign(3-1)=1 → wrong result.
    // This is impossible unless predicted is also a draw with one matching score.
    // actual 2-2, predicted 2-2 = exact (10). actual 1-1, predicted 1-1 = exact (10).
    // actual 3-3, predicted 3-3 = exact (10). actual 2-2, predicted 1-1 = both draws, no score match → 5.
    // actual 3-3, predicted 3-1: Math.sign(3-1)=1, wrong result.
    // Conclusion: for a draw, to have "correct result + one score correct" without exact score,
    // we need e.g. actual 2-2, predicted 2-0 → Math.sign(2-2)=0, Math.sign(2-0)=1 → wrong result.
    // It's actually impossible for a draw to have "correct result + one score correct" without exact score
    // because if both teams scored the same amount and one score matches, both match (exact score).
    // So this test case is inherently impossible — skip it and test a home win instead.
    // actual 3-1, predicted 3-0 with correct result + home score: covered above.
    // Test: away win with away score correct
    expect(
      service.calculate({ actualHome: 0, actualAway: 2, predictedHome: 1, predictedAway: 2 })
    ).toBe(7);
  });

  it('should return 5 for only correct result (draw)', () => {
    // Both draw, but different scores
    expect(
      service.calculate({ actualHome: 2, actualAway: 2, predictedHome: 1, predictedAway: 1 })
    ).toBe(5);
  });

  it('should return 5 for only correct result (home win)', () => {
    // Both home wins, no score matches
    expect(
      service.calculate({ actualHome: 3, actualAway: 0, predictedHome: 2, predictedAway: 1 })
    ).toBe(5);
  });

  it('should return 0 for wrong result (predicted home win, actual draw)', () => {
    expect(
      service.calculate({ actualHome: 1, actualAway: 1, predictedHome: 2, predictedAway: 1 })
    ).toBe(0);
  });

  it('should return 0 for wrong result (away win vs home win)', () => {
    expect(
      service.calculate({ actualHome: 0, actualAway: 2, predictedHome: 2, predictedAway: 0 })
    ).toBe(0);
  });

  it('should return 0 when actualHome is null (no score yet)', () => {
    expect(
      service.calculate({ actualHome: null, actualAway: 1, predictedHome: 1, predictedAway: 1 })
    ).toBe(0);
  });

  it('should return 0 when actualAway is null (no score yet)', () => {
    expect(
      service.calculate({ actualHome: 1, actualAway: null, predictedHome: 1, predictedAway: 1 })
    ).toBe(0);
  });

  it('should return 0 when both scores are null', () => {
    expect(
      service.calculate({ actualHome: null, actualAway: null, predictedHome: 0, predictedAway: 0 })
    ).toBe(0);
  });
});
