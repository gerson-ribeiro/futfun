import { PredictionWindow } from '../PredictionWindow';

describe('PredictionWindow', () => {
  describe('isOpen', () => {
    test('returns true when kickoff is in the future', () => {
      const future = new Date(Date.now() + 60_000);
      expect(PredictionWindow.isOpen(future)).toBe(true);
    });

    test('returns false when kickoff is in the past', () => {
      const past = new Date(Date.now() - 1_000);
      expect(PredictionWindow.isOpen(past)).toBe(false);
    });

    test('returns false when kickoff is right now (already started)', () => {
      const now = new Date(Date.now() - 1);
      expect(PredictionWindow.isOpen(now)).toBe(false);
    });
  });

  describe('assertOpen', () => {
    test('does not throw when kickoff is in the future', () => {
      const future = new Date(Date.now() + 60_000);
      expect(() => PredictionWindow.assertOpen(future)).not.toThrow();
    });

    test('throws PREDICTION_LOCKED when kickoff has passed', () => {
      const past = new Date(Date.now() - 1_000);
      expect(() => PredictionWindow.assertOpen(past)).toThrow('PREDICTION_LOCKED');
    });

    test('throws the exact message text', () => {
      const past = new Date(Date.now() - 1_000);
      expect(() => PredictionWindow.assertOpen(past)).toThrow(
        'PREDICTION_LOCKED: Match has already started'
      );
    });
  });
});
