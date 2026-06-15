-- Backfill user_competition_stats from all existing scored predictions,
-- grouped by user and competition. Uses ON CONFLICT to safely re-run.
INSERT INTO "user_competition_stats" (
  "id",
  "userId",
  "competitionCode",
  "totalPoints",
  "exactScores",
  "correctResults",
  "matchesPredicted",
  "lastCalculatedAt"
)
SELECT
  gen_random_uuid(),
  p."userId",
  m."competitionCode",
  SUM(COALESCE(p.points, 0)),
  SUM(CASE WHEN p.points = 10 THEN 1 ELSE 0 END),
  SUM(CASE WHEN p.points IN (5, 7) THEN 1 ELSE 0 END),
  COUNT(*),
  NOW()
FROM predictions p
JOIN matches m ON p."matchId" = m.id
WHERE p."scoredAt" IS NOT NULL
  AND m."competitionCode" IS NOT NULL
GROUP BY p."userId", m."competitionCode"
ON CONFLICT ("userId", "competitionCode") DO UPDATE
  SET
    "totalPoints"      = EXCLUDED."totalPoints",
    "exactScores"      = EXCLUDED."exactScores",
    "correctResults"   = EXCLUDED."correctResults",
    "matchesPredicted" = EXCLUDED."matchesPredicted",
    "lastCalculatedAt" = EXCLUDED."lastCalculatedAt";

-- Stamp competitionCode on existing ranking_history rows that still have NULL,
-- matching via the snapshotKey which stores the match UUID.
UPDATE "ranking_history" rh
SET "competitionCode" = m."competitionCode"
FROM matches m
WHERE rh."snapshotKey" = m.id::text
  AND rh."competitionCode" IS NULL
  AND m."competitionCode" IS NOT NULL;

-- Recalculate ranking_history.totalPoints to be the per-competition running
-- total (sum of pointsEarned ordered by snapshotAt within the same competition).
-- This replaces the previously stored global total with the correct scoped value.
WITH running AS (
  SELECT
    rh.id,
    SUM(rh."pointsEarned") OVER (
      PARTITION BY rh."userId", rh."competitionCode"
      ORDER BY rh."snapshotAt" ASC, rh.id ASC
    ) AS new_total
  FROM "ranking_history" rh
  WHERE rh."competitionCode" IS NOT NULL
)
UPDATE "ranking_history" rh
SET "totalPoints" = running.new_total
FROM running
WHERE rh.id = running.id;
