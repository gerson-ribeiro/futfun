// src/infrastructure/container/container.ts

import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { FootballDataOrgAdapter } from '@infrastructure/football-data/FootballDataOrgAdapter';
import { TheSportsDbAdapter } from '@infrastructure/football-data/TheSportsDbAdapter';
import { MatchSyncJob } from '@infrastructure/football-data/MatchSyncJob';
import { ResendEmailService } from '@infrastructure/email/ResendEmailService';
import { SmtpEmailService } from '@infrastructure/email/SmtpEmailService';
import { IEmailService } from '@application/ports/IEmailService';

function createEmailService(): IEmailService {
  if (process.env.SMTP_USER && process.env.SMTP_PASS) {
    console.log('[Email] Using SMTP service');
    return new SmtpEmailService();
  }
  console.log('[Email] Using Resend service');
  return new ResendEmailService();
}

export interface IContainer {
  prisma: PrismaClient;
  matchSyncJob: MatchSyncJob;
  emailService: IEmailService;
  footballProvider: FootballDataOrgAdapter;
  secondaryProvider: TheSportsDbAdapter;
}

let container: IContainer | null = null;

export function initializeContainer(): IContainer {
  if (container) return container;

  // Explicit pg.Pool tuned for Neon.tech serverless.
  // connect_timeout=45 (in URL) covers Neon cold-start auth (~20-30s) plus margin.
  // connectionTimeoutMillis caps how long Pool.connect() waits for a slot.
  // idleTimeoutMillis closes idle connections before Neon's 5-min idle cutoff.
  const rawUrl = process.env.DATABASE_URL!;
  // Remove any existing connect_timeout so we can replace it with 45.
  const urlWithoutTimeout = rawUrl.replace(/[&?]connect_timeout=\d+/, '');
  const dbUrl = `${urlWithoutTimeout}${urlWithoutTimeout.includes('?') ? '&' : '?'}connect_timeout=45`;
  const pool = new Pool({
    connectionString: dbUrl,
    max: 3,
    idleTimeoutMillis: 20000,
    connectionTimeoutMillis: 50000,
  });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const footballProvider = new FootballDataOrgAdapter();
  // TheSportsDB handles international friendlies (free, no key required).
  // Uses eventsround for bulk data + team-specific lookups to bypass the 50-event cap.
  const secondaryProvider = new TheSportsDbAdapter();
  console.log('[Container] Secondary provider: TheSportsDbAdapter (international friendlies)');
  const matchSyncJob = new MatchSyncJob(prisma, footballProvider, secondaryProvider);
  const emailService = createEmailService();

  container = { prisma, matchSyncJob, emailService, footballProvider, secondaryProvider };
  return container;
}

export function getContainer(): IContainer {
  if (!container) initializeContainer();
  return container!;
}
