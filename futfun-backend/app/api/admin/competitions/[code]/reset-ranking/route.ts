import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';

/**
 * @deprecated Use POST /api/admin/competitions/[code]/rescore instead.
 * The aggregation tables (user_competition_stats, ranking_history) were removed.
 * Rankings are now computed live from the predictions table via a SQL view.
 */
export const POST = withAdmin(async (_req: NextRequest, _user: any, context: any) => {
  const { code } = await context.params;
  return NextResponse.json(
    {
      error:
        'Este endpoint foi removido. Use POST /api/admin/competitions/' +
        code +
        '/rescore para recalcular o ranking.',
    },
    { status: 410 },
  );
});
