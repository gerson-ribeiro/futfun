// app/api/predictions/route.ts

import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError, AppError } from '@presentation/middleware/errorHandler';
import { PredictionWindow } from '@domain/value-objects/PredictionWindow';
import { TokenPayload } from '@application/ports/ITokenService';

// GET — returns predictions for the authenticated user, optionally filtered by competitionCode
export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const { searchParams } = req.nextUrl;
    const competitionCode = searchParams.get('competitionCode');

    const { prisma } = getContainer();
    const predictions = await prisma.prediction.findMany({
      where: {
        userId: user.userId,
        ...(competitionCode ? { match: { competitionCode } } : {}),
      },
      include: { match: true },
      orderBy: { match: { kickoffTime: 'asc' } },
    });
    // Include matchExternalId so Flutter can link predictions to upcoming-matches data
    return NextResponse.json({
      predictions: predictions.map((p) => ({
        ...p,
        matchExternalId: p.match.externalId,
      })),
    });
  } catch (error) {
    return handleError(error);
  }
});

// Schema for the match data sent by the client when creating a prediction
const matchDataSchema = z.object({
  externalId: z.number().int().positive(),
  competitionCode: z.string().min(1),
  competitionName: z.string().min(1),
  homeTeamId: z.number().int().positive(),
  homeTeamName: z.string().min(1),
  homeTeamShort: z.string().nullable().optional(),
  homeTeamCrest: z.string().nullable().optional(),
  homeTeamType: z.string().nullable().optional(),
  awayTeamId: z.number().int().positive(),
  awayTeamName: z.string().min(1),
  awayTeamShort: z.string().nullable().optional(),
  awayTeamCrest: z.string().nullable().optional(),
  awayTeamType: z.string().nullable().optional(),
  kickoffTime: z.string().min(1),
  stage: z.string().min(1),
  groupName: z.string().nullable().optional(),
  matchday: z.number().int().positive().nullable().optional(),
});

const createPredictionSchema = z.object({
  match: matchDataSchema,
  predictedHome: z.number().int().min(0),
  predictedAway: z.number().int().min(0),
});

// POST — upsert match from client data then upsert prediction.
// This is the primary create/update path for the match list screen.
// The match is only written to DB here, on first prediction.
export const POST = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const body = await req.json();
    const { match: matchData, predictedHome, predictedAway } = createPredictionSchema.parse(body);

    const { prisma } = getContainer();

    // 1. Ensure competition row exists
    await prisma.competition.upsert({
      where: { code: matchData.competitionCode },
      create: { code: matchData.competitionCode, name: matchData.competitionName, enabled: true },
      update: {},
    });

    // 2. Upsert match — create on first prediction, preserve status/scores on subsequent calls
    const kickoffTime = new Date(matchData.kickoffTime);
    const dbMatch = await prisma.match.upsert({
      where: { externalId: matchData.externalId },
      create: {
        externalId: matchData.externalId,
        competitionCode: matchData.competitionCode,
        homeTeamId: matchData.homeTeamId,
        homeTeamName: matchData.homeTeamName,
        homeTeamShort: matchData.homeTeamShort ?? null,
        homeTeamCrest: matchData.homeTeamCrest ?? null,
        homeTeamType: matchData.homeTeamType ?? null,
        awayTeamId: matchData.awayTeamId,
        awayTeamName: matchData.awayTeamName,
        awayTeamShort: matchData.awayTeamShort ?? null,
        awayTeamCrest: matchData.awayTeamCrest ?? null,
        awayTeamType: matchData.awayTeamType ?? null,
        kickoffTime,
        status: 'SCHEDULED',
        stage: matchData.stage,
        groupName: matchData.groupName ?? null,
        matchday: matchData.matchday ?? null,
      },
      update: {
        // Only refresh display fields; status/scores managed by sync job
        homeTeamCrest: matchData.homeTeamCrest ?? null,
        awayTeamCrest: matchData.awayTeamCrest ?? null,
        homeTeamShort: matchData.homeTeamShort ?? null,
        awayTeamShort: matchData.awayTeamShort ?? null,
      },
    });

    // 3. Domain validation: prediction window must be open
    if (!PredictionWindow.isOpen(dbMatch.kickoffTime)) {
      throw new AppError('Predictions are locked after kickoff', 'PREDICTION_LOCKED', 423);
    }

    // 4. Upsert prediction (handles both create and update)
    const prediction = await prisma.prediction.upsert({
      where: { userId_matchId: { userId: user.userId, matchId: dbMatch.id } },
      create: {
        userId: user.userId,
        matchId: dbMatch.id,
        predictedHome,
        predictedAway,
        lockedAt: dbMatch.kickoffTime,
      },
      update: {
        predictedHome,
        predictedAway,
        lockedAt: dbMatch.kickoffTime,
      },
    });

    return NextResponse.json(
      { prediction: { ...prediction, matchExternalId: dbMatch.externalId } },
      { status: 201 },
    );
  } catch (error) {
    return handleError(error);
  }
});
