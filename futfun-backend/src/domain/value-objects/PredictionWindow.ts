export class PredictionWindow {
  /**
   * Predictions are open as long as the match hasn't kicked off yet.
   * No advance restriction — users can predict any scheduled future match.
   * This avoids UTC-vs-local timezone issues (e.g. 21:00 BRT = 00:00 UTC next day)
   * and ensures WC group-stage games are predictable from schedule release.
   */
  static isOpen(kickoffTime: Date): boolean {
    return new Date() < kickoffTime;
  }

  static assertOpen(kickoffTime: Date): void {
    if (!PredictionWindow.isOpen(kickoffTime)) {
      throw new Error('PREDICTION_LOCKED: Match has already started');
    }
  }
}
