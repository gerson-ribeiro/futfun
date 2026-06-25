-- Drop the three aggregation tables that were replaced by a live SQL view.
-- Rankings are now computed on-the-fly from the predictions table, eliminating
-- double-counting and race-condition bugs.

DROP TABLE IF EXISTS "user_competition_stats" CASCADE;
DROP TABLE IF EXISTS "ranking_history" CASCADE;
DROP TABLE IF EXISTS "rankings" CASCADE;

-- View that computes ranking stats live from the predictions + matches tables.
-- Always consistent: updating prediction.points is immediately reflected here.
CREATE OR REPLACE VIEW "user_competition_ranking" AS
SELECT
  p."userId",
  m."competitionCode",
  COUNT(*)::int                                                 AS "matchesPredicted",
  COALESCE(SUM(p.points), 0)::int                               AS "totalPoints",
  COUNT(*) FILTER (WHERE p.points = 10)::int                    AS "exactScores",
  COUNT(*) FILTER (WHERE p.points = 5 OR p.points = 7)::int     AS "correctResults"
FROM predictions p
JOIN matches m ON m.id = p."matchId"
WHERE m.status = 'FINISHED'
  AND p.points IS NOT NULL
GROUP BY p."userId", m."competitionCode";
