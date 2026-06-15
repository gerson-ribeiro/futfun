export class PointsCalculationService {
  calculate(params: {
    actualHome: number | null;
    actualAway: number | null;
    predictedHome: number;
    predictedAway: number;
  }): number {
    const { actualHome, actualAway, predictedHome, predictedAway } = params;

    if (actualHome === null || actualAway === undefined || actualAway === null || actualHome === undefined) {
      return 0;
    }

    // Exact score
    if (actualHome === predictedHome && actualAway === predictedAway) {
      return 10;
    }

    const actualResult = Math.sign(actualHome - actualAway); // -1, 0, 1
    const predictedResult = Math.sign(predictedHome - predictedAway);

    const correctResult = actualResult === predictedResult;

    if (!correctResult) {
      return 0;
    }

    // Correct result — check if one score matches
    const oneScoreCorrect = actualHome === predictedHome || actualAway === predictedAway;

    return oneScoreCorrect ? 7 : 5;
  }
}
