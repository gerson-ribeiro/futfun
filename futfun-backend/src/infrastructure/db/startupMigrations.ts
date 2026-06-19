import { PrismaClient } from '@prisma/client';

export async function applyStartupMigrations(prisma: PrismaClient): Promise<void> {
  try {
    await prisma.$executeRaw`
      CREATE TABLE IF NOT EXISTS "device_tokens" (
        "id" UUID NOT NULL DEFAULT gen_random_uuid(),
        "userId" UUID NOT NULL,
        "token" TEXT NOT NULL,
        "platform" TEXT NOT NULL,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
      )
    `;

    await prisma.$executeRaw`
      CREATE UNIQUE INDEX IF NOT EXISTS "device_tokens_token_key" ON "device_tokens"("token")
    `;

    await prisma.$executeRaw`
      CREATE INDEX IF NOT EXISTS "device_tokens_userId_idx" ON "device_tokens"("userId")
    `;

    await prisma.$executeRaw`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE constraint_name = 'device_tokens_userId_fkey'
          AND constraint_type = 'FOREIGN KEY'
        ) THEN
          ALTER TABLE "device_tokens"
            ADD CONSTRAINT "device_tokens_userId_fkey"
            FOREIGN KEY ("userId") REFERENCES "users"("id")
            ON DELETE CASCADE ON UPDATE CASCADE;
        END IF;
      END $$
    `;

    console.log('[startup] device_tokens migration OK');
  } catch (err) {
    console.error('[startup] Migration failed (non-fatal, notifications may be unavailable):', err);
  }
}
