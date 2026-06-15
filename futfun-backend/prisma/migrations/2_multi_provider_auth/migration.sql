-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('PENDING', 'MEMBER', 'ADMIN');

-- DropIndex
DROP INDEX "users_microsoftId_key";

-- AlterTable "users": remove old columns, add new columns
ALTER TABLE "users"
  DROP COLUMN IF EXISTS "microsoftId",
  DROP COLUMN IF EXISTS "tenantId",
  DROP COLUMN IF EXISTS "passwordHash",
  DROP COLUMN IF EXISTS "isPasswordSet";

ALTER TABLE "users"
  ADD COLUMN "provider" TEXT NOT NULL DEFAULT 'microsoft',
  ADD COLUMN "providerId" TEXT NOT NULL DEFAULT '',
  ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'PENDING';

-- CreateTable "invites"
CREATE TABLE "invites" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "createdBy" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "invites_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "invites_token_key" ON "invites"("token");

-- CreateIndex
CREATE INDEX "invites_token_idx" ON "invites"("token");

-- CreateIndex
CREATE INDEX "invites_email_idx" ON "invites"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_provider_providerId_key" ON "users"("provider", "providerId");

-- AddForeignKey
ALTER TABLE "invites" ADD CONSTRAINT "invites_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
