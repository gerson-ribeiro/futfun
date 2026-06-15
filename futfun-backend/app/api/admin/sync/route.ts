import { NextRequest, NextResponse } from 'next/server';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';

export const POST = withAdmin(async (_req: NextRequest) => {
  try {
    const { matchSyncJob } = getContainer();
    // Run in the background — don't await so the HTTP response returns quickly.
    matchSyncJob.syncAll().catch(console.error);
    return NextResponse.json({ message: 'Sync triggered' });
  } catch (error) {
    return handleError(error);
  }
});
