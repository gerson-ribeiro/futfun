import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg(process.env.DATABASE_URL!);
const prisma = new PrismaClient({ adapter });

async function main() {
  await prisma.competition.upsert({
    where: { code: 'WC' },
    update: {
      color: '#1A6B3A',
      providerConfig: { 'football-data': 'WC' },
    },
    create: {
      code: 'WC',
      name: 'Copa do Mundo 2026',
      enabled: true,
      color: '#1A6B3A',
      providerConfig: { 'football-data': 'WC' },
    },
  });

  await prisma.competition.upsert({
    where: { code: 'CLI' },
    update: {
      color: '#2E4A8C',
      providerConfig: { thesportsdb: '4562' },
    },
    create: {
      code: 'CLI',
      name: 'Amistosos Internacionais',
      enabled: true,
      color: '#2E4A8C',
      providerConfig: { thesportsdb: '4562' },
    },
  });

  await prisma.match.updateMany({
    where: { competitionCode: null },
    data: { competitionCode: 'WC' },
  });

  console.log('Seed completed.');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
