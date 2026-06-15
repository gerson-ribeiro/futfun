// app/api/predictions/[matchId]/route.ts
// PUT — update an existing prediction by DB match UUID.
// Used by the "My Predictions" screen when editing a submitted prediction.

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError, AppError } from '@presentation/middleware/errorHandler';
import { PredictionWindow } from '@domain/value-objects/PredictionWindow';
import { TokenPayload } from '@application/ports/ITokenService';

const predictionSchema = z.object({
  predictedHome: z.number().int().min(0),
  predictedAway: z.number().int().min(0),
});

export const PUT = withAuth(async (
  req: NextRequest,
  user: TokenPayload,
  { params }: { params: Promise<{ matchId: string }> },
) => {
  try {
    const { matchId } = await params;
    const body = await req.json();
    const { predictedHome, predictedAway } = predictionSchema.parse(body);

    const { prisma } = getContainer();

    const match = await prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new AppError('Match not found', 'MATCH_NOT_FOUND', 404);

    if (!PredictionWindow.isOpen(match.kickoffTime)) {
      throw new AppError('Predictions are locked after kickoff', 'PREDICTION_LOCKED', 423);
    }

    const existing = await prisma.prediction.findUnique({
      where: { userId_matchId: { userId: user.userId, matchId } },
    });
    if (!existing) throw new AppError('Prediction not found', 'NOT_FOUND', 404);

    const prediction = await prisma.prediction.update({
      where: { userId_matchId: { userId: user.userId, matchId } },
      data: { predictedHome, predictedAway, lockedAt: match.kickoffTime },
    });

    return NextResponse.json({ prediction: { ...prediction, matchExternalId: match.externalId } });
  } catch (error) {
    return handleError(error);
  }
});
