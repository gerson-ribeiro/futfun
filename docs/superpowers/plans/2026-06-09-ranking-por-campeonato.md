# Ranking por Campeonato + Campeonatos Configuráveis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separar o ranking por campeonato, adicionar tema visual dinâmico por campeonato no app Flutter, e tornar os campeonatos totalmente configuráveis via admin sem código.

**Architecture:** Três fases independentes. Fase 1 (backend) e Fase 2 (frontend) são críticas para a Copa do Mundo (12/06). A Fase 3 (provider config) refatora os adapters para eliminar hardcoding. Backend usa nova tabela `user_competition_stats` (stats materializadas por competição) — O(1) no query de ranking. Frontend usa `activeCompetitionNotifierProvider` (Riverpod) com persistência em SecureStorage como estado global.

**Tech Stack:** TypeScript/Prisma/Next.js 15 (backend), Dart/Flutter/Riverpod (frontend), PostgreSQL/Neon.tech, Jest (testes backend)

**Spec:** `docs/superpowers/specs/2026-06-09-ranking-por-campeonato-design.md`

---

## ⚠️ ORDEM DE DEPLOY

Fase 1 (backend) deve ser deployada **antes** de Fase 2 (frontend). As fases 1 e 2 juntas são suficientes para a Copa. Fase 3 pode ser feita depois.

---

## FASE 1 — Backend: Ranking por Campeonato

### Task B1: Schema Prisma — UserCompetitionStats + campos novos

**Files:**
- Modify: `futfun-backend/prisma/schema.prisma`

- [ ] **Passo 1.1: Adicionar campos a `Competition`**

Em `schema.prisma`, adicionar após `enabled Boolean @default(true)`:
```prisma
model Competition {
  id             String                 @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  code           String                 @unique
  name           String
  enabled        Boolean                @default(true)
  color          String?
  providerConfig Json?
  createdAt      DateTime               @default(now())
  matches        Match[]
  competitionStats UserCompetitionStats[]

  @@map("competitions")
}
```

- [ ] **Passo 1.2: Adicionar `competitionCode` a `RankingHistory`**

Em `schema.prisma`, o modelo `RankingHistory` passa a ser:
```prisma
model RankingHistory {
  id              String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  userId          String   @db.Uuid
  snapshotKey     String
  matchday        Int?
  roundStage      String
  pointsEarned    Int      @default(0)
  totalPoints     Int      @default(0)
  exactScores     Int      @default(0)
  correctResults  Int      @default(0)
  position        Int
  competitionCode String?
  snapshotAt      DateTime @default(now())
  user            User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, snapshotKey])
  @@index([userId, snapshotKey])
  @@index([userId, competitionCode])
  @@map("ranking_history")
}
```

- [ ] **Passo 1.3: Criar modelo `UserCompetitionStats`**

Adicionar após o modelo `Ranking` em `schema.prisma`:
```prisma
model UserCompetitionStats {
  id               String      @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  userId           String      @db.Uuid
  competitionCode  String
  totalPoints      Int         @default(0)
  exactScores      Int         @default(0)
  correctResults   Int         @default(0)
  matchesPredicted Int         @default(0)
  lastCalculatedAt DateTime    @default(now())
  user             User        @relation(fields: [userId], references: [id], onDelete: Cascade)
  competition      Competition @relation(fields: [competitionCode], references: [code], onDelete: Cascade)

  @@unique([userId, competitionCode])
  @@index([competitionCode, totalPoints])
  @@map("user_competition_stats")
}
```

- [ ] **Passo 1.4: Adicionar relações ao modelo `User`**

No modelo `User`, adicionar após `ranking Ranking?`:
```prisma
  competitionStats UserCompetitionStats[]
```

- [ ] **Passo 1.5: Rodar a migração**

```bash
cd futfun-backend
npx prisma migrate dev --name add_competition_stats
```
Saída esperada: `✔ Generated Prisma Client` + confirmação de migração criada.

- [ ] **Passo 1.6: Verificar que o cliente gerou os novos tipos**

```bash
npx prisma generate
```
Saída esperada: `✔ Generated Prisma Client`.

- [ ] **Passo 1.7: Commit**

```bash
git add prisma/schema.prisma prisma/migrations/
git commit -m "feat: add UserCompetitionStats model, competition color/providerConfig, RankingHistory.competitionCode"
```

---

### Task B2: ScorePredictionsHandler — upsert UserCompetitionStats

**Files:**
- Modify: `futfun-backend/src/application/handlers/ScorePredictionsHandler.ts`
- Create: `futfun-backend/src/application/handlers/__tests__/ScorePredictionsHandler.test.ts`

- [ ] **Passo 2.1: Escrever o teste que falha**

Criar `src/application/handlers/__tests__/ScorePredictionsHandler.test.ts`:
```typescript
// src/application/handlers/__tests__/ScorePredictionsHandler.test.ts
import { ScorePredictionsHandler } from '../ScorePredictionsHandler';

function makePrisma(opts: {
  competitionCode?: string | null;
  points?: number;
} = {}) {
  const { competitionCode = 'WC', points = 10 } = opts;

  const rankingRow = { userId: 'user-1', totalPoints: points, exactScores: points === 10 ? 1 : 0, correctResults: points >= 5 ? 1 : 0, matchesPredicted: 1 };

  return {
    match: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'match-1',
        status: 'FINISHED',
        scoreHome: 2,
        scoreAway: 1,
        stage: 'GROUP_STAGE',
        matchday: 1,
        groupName: 'A',
        homeTeamName: 'Brasil',
        awayTeamName: 'Argentina',
        competitionCode,
      }),
    },
    prediction: {
      findMany: jest.fn().mockResolvedValue([
        { id: 'pred-1', userId: 'user-1', matchId: 'match-1', predictedHome: 2, predictedAway: 1, scoredAt: null },
      ]),
      update: jest.fn().mockResolvedValue({}),
    },
    ranking: {
      upsert: jest.fn().mockResolvedValue({}),
      findUnique: jest.fn().mockResolvedValue(rankingRow),
      count: jest.fn().mockResolvedValue(0),
    },
    rankingHistory: {
      upsert: jest.fn().mockResolvedValue({}),
    },
    userCompetitionStats: {
      upsert: jest.fn().mockResolvedValue({}),
    },
  };
}

describe('ScorePredictionsHandler', () => {
  beforeEach(() => jest.clearAllMocks());

  test('upserts userCompetitionStats when match has competitionCode', async () => {
    const prisma = makePrisma({ competitionCode: 'WC', points: 10 });
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle('match-1');

    expect(prisma.userCompetitionStats.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId_competitionCode: { userId: 'user-1', competitionCode: 'WC' } },
      }),
    );
  });

  test('skips userCompetitionStats when match has no competitionCode', async () => {
    const prisma = makePrisma({ competitionCode: null });
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle('match-1');

    expect(prisma.userCompetitionStats.upsert).not.toHaveBeenCalled();
  });

  test('saves competitionCode in rankingHistory snapshot', async () => {
    const prisma = makePrisma({ competitionCode: 'WC' });
    const handler = new ScorePredictionsHandler(prisma as any);

    await handler.handle('match-1');

    expect(prisma.rankingHistory.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({ competitionCode: 'WC' }),
      }),
    );
  });
});
```

- [ ] **Passo 2.2: Rodar o teste para confirmar que falha**

```bash
cd futfun-backend
npm test -- --testPathPattern="ScorePredictionsHandler" --no-coverage
```
Esperado: FAIL — `prisma.userCompetitionStats is not a function` ou similar.

- [ ] **Passo 2.3: Atualizar `ScorePredictionsHandler.ts`**

No loop `for (const prediction of predictions)`, após o bloco `await this.prisma.ranking.upsert(...)`, adicionar:

```typescript
      // Upsert per-competition stats
      if (match.competitionCode) {
        await this.prisma.userCompetitionStats.upsert({
          where: { userId_competitionCode: { userId: prediction.userId, competitionCode: match.competitionCode } },
          create: {
            userId: prediction.userId,
            competitionCode: match.competitionCode,
            totalPoints: points,
            exactScores: isExact ? 1 : 0,
            correctResults: isCorrectResult ? 1 : 0,
            matchesPredicted: 1,
            lastCalculatedAt: now,
          },
          update: {
            totalPoints: { increment: points },
            exactScores: { increment: isExact ? 1 : 0 },
            correctResults: { increment: isCorrectResult ? 1 : 0 },
            matchesPredicted: { increment: 1 },
            lastCalculatedAt: now,
          },
        });
      }
```

Note: manter `isCorrectResult = points === 5 || points === 7` (igual ao modelo `Ranking` — exact score 10pts conta só em `exactScores`, não em `correctResults`, para preservar a lógica de desempate existente).

- [ ] **Passo 2.4: Adicionar `competitionCode` ao snapshot de `rankingHistory`**

No bloco de criação do snapshot (linhas 95–113), atualizar o `create` para incluir:
```typescript
        create: {
          userId,
          snapshotKey: matchId,
          matchday: match.matchday,
          roundStage,
          pointsEarned,
          totalPoints: userRanking.totalPoints,
          exactScores: userRanking.exactScores,
          correctResults: userRanking.correctResults,
          position,
          competitionCode: match.competitionCode ?? null,  // ← ADD THIS
          snapshotAt: now,
        },
```

- [ ] **Passo 2.5: Rodar os testes para confirmar que passam**

```bash
npm test -- --testPathPattern="ScorePredictionsHandler" --no-coverage
```
Esperado: PASS (3 tests).

- [ ] **Passo 2.6: Commit**

```bash
git add src/application/handlers/ScorePredictionsHandler.ts \
        src/application/handlers/__tests__/ScorePredictionsHandler.test.ts
git commit -m "feat: upsert user_competition_stats and save competitionCode in ranking snapshots"
```

---

### Task B3: Ranking Endpoints — parâmetro `competitionCode`

**Files:**
- Modify: `futfun-backend/app/api/rankings/route.ts`
- Modify: `futfun-backend/app/api/rankings/me/route.ts`
- Modify: `futfun-backend/app/api/rankings/history/route.ts`

- [ ] **Passo 3.1: Substituir `app/api/rankings/route.ts`**

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, _user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    const stats = await prisma.userCompetitionStats.findMany({
      where: { competitionCode, totalPoints: { gt: 0 } },
      include: { user: { select: { displayName: true } } },
      orderBy: [
        { totalPoints: 'desc' },
        { exactScores: 'desc' },
        { correctResults: 'desc' },
      ],
    });

    const rankings = stats.map((entry, index) => ({
      position: index + 1,
      userId: entry.userId,
      displayName: entry.user.displayName,
      totalPoints: entry.totalPoints,
      exactScores: entry.exactScores,
      correctResults: entry.correctResults,
      matchesPredicted: entry.matchesPredicted,
    }));

    return NextResponse.json({ rankings });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Passo 3.2: Substituir `app/api/rankings/me/route.ts`**

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    const allStats = await prisma.userCompetitionStats.findMany({
      where: { competitionCode },
      orderBy: [
        { totalPoints: 'desc' },
        { exactScores: 'desc' },
        { correctResults: 'desc' },
      ],
    });

    const positionIndex = allStats.findIndex((s) => s.userId === user.userId);

    if (positionIndex === -1) {
      return NextResponse.json({ ranking: null });
    }

    const entry = allStats[positionIndex];
    const userWithName = await prisma.user.findUnique({
      where: { id: user.userId },
      select: { displayName: true },
    });

    return NextResponse.json({
      ranking: {
        position: positionIndex + 1,
        userId: entry.userId,
        displayName: userWithName?.displayName ?? null,
        totalPoints: entry.totalPoints,
        exactScores: entry.exactScores,
        correctResults: entry.correctResults,
        matchesPredicted: entry.matchesPredicted,
      },
    });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Passo 3.3: Substituir `app/api/rankings/history/route.ts`**

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const competitionCode = req.nextUrl.searchParams.get('competitionCode');
    if (!competitionCode) {
      return NextResponse.json({ error: 'competitionCode is required' }, { status: 400 });
    }

    const { prisma } = getContainer();

    const history = await prisma.rankingHistory.findMany({
      where: { userId: user.userId, competitionCode },
      orderBy: { snapshotAt: 'asc' },
    });

    return NextResponse.json({ history });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Passo 3.4: Rodar todos os testes**

```bash
npm test --no-coverage
```
Esperado: todos passam (os testes existentes não tocam esses endpoints).

- [ ] **Passo 3.5: Commit**

```bash
git add app/api/rankings/route.ts app/api/rankings/me/route.ts app/api/rankings/history/route.ts
git commit -m "feat: ranking endpoints now require competitionCode, query user_competition_stats"
```

---

### Task B4: `/api/competitions` — adicionar `color` e `hasRankingData`

**Files:**
- Modify: `futfun-backend/app/api/competitions/route.ts`

- [ ] **Passo 4.1: Substituir `app/api/competitions/route.ts`**

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { TokenPayload } from '@application/ports/ITokenService';

export const GET = withAuth(async (_req: NextRequest, user: TokenPayload) => {
  try {
    const { prisma } = getContainer();

    const [competitions, preferences, statsGroups] = await Promise.all([
      prisma.competition.findMany({
        where: { enabled: true },
        orderBy: { createdAt: 'asc' },
      }),
      prisma.userCompetitionPreference.findMany({
        where: { userId: user.userId },
        select: { competitionCode: true, hidden: true },
      }),
      prisma.userCompetitionStats.groupBy({
        by: ['competitionCode'],
        where: { totalPoints: { gt: 0 } },
        _count: { userId: true },
      }),
    ]);

    const hiddenSet = new Set(
      preferences.filter((p) => p.hidden).map((p) => p.competitionCode),
    );
    const codesWithData = new Set(statsGroups.map((s) => s.competitionCode));

    const result = competitions.map((c) => ({
      ...c,
      hidden: hiddenSet.has(c.code),
      hasRankingData: codesWithData.has(c.code),
    }));

    return NextResponse.json({ competitions: result });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Passo 4.2: Commit**

```bash
git add app/api/competitions/route.ts
git commit -m "feat: competitions endpoint returns color and hasRankingData"
```

---

### Task B5: seed.ts atualizado + seed-backfill.ts

**Files:**
- Modify: `futfun-backend/prisma/seed.ts`
- Create: `futfun-backend/prisma/seed-backfill.ts`

- [ ] **Passo 5.1: Atualizar `prisma/seed.ts`**

Substituir os dois `upsert` de competições para incluir `color` e `providerConfig`:
```typescript
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
```

- [ ] **Passo 5.2: Criar `prisma/seed-backfill.ts`**

```typescript
// prisma/seed-backfill.ts
// Run once after deploy to populate user_competition_stats from existing scored predictions.
// Safe to run multiple times (uses upsert).

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg(process.env.DATABASE_URL!);
const prisma = new PrismaClient({ adapter });

async function main() {
  const scored = await prisma.prediction.findMany({
    where: { points: { not: null } },
    include: { match: { select: { competitionCode: true } } },
  });

  const statsMap = new Map<
    string,
    { totalPoints: number; exactScores: number; correctResults: number; matchesPredicted: number }
  >();

  for (const p of scored) {
    const code = p.match.competitionCode;
    if (!code || p.points === null) continue;

    const key = `${p.userId}::${code}`;
    const s = statsMap.get(key) ?? { totalPoints: 0, exactScores: 0, correctResults: 0, matchesPredicted: 0 };
    s.totalPoints += p.points;
    s.exactScores += p.points === 10 ? 1 : 0;
    // correctResults = correct result but NOT exact score (matches Ranking table logic)
    s.correctResults += (p.points === 5 || p.points === 7) ? 1 : 0;
    s.matchesPredicted += 1;
    statsMap.set(key, s);
  }

  let count = 0;
  for (const [key, stats] of statsMap.entries()) {
    const [userId, competitionCode] = key.split('::');
    await prisma.userCompetitionStats.upsert({
      where: { userId_competitionCode: { userId, competitionCode } },
      create: { userId, competitionCode, ...stats, lastCalculatedAt: new Date() },
      update: { ...stats, lastCalculatedAt: new Date() },
    });
    count++;
  }

  console.log(`Backfill complete: ${count} user_competition_stats rows upserted from ${scored.length} scored predictions.`);
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });
```

- [ ] **Passo 5.3: Adicionar script no `package.json`**

No `package.json`, na seção `scripts`, adicionar:
```json
"backfill": "tsx prisma/seed-backfill.ts"
```

- [ ] **Passo 5.4: Rodar seed localmente para testar**

```bash
npx prisma db seed
```
Esperado: `Seed completed.` sem erros.

- [ ] **Passo 5.5: Commit**

```bash
git add prisma/seed.ts prisma/seed-backfill.ts package.json
git commit -m "feat: seed.ts adds color/providerConfig, add seed-backfill script"
```

---

### Task B6: Deploy Fase 1 Backend

**Files:**
- Modify: `futfun-backend/cloudbuild.yaml` (verificar se `prisma migrate deploy` está no startup)

- [ ] **Passo 6.1: Verificar startup de migração**

Ler `server.ts` — procurar por `prisma migrate` ou `$executeRaw`. Se não houver, confirmar que o deploy roda migrações.

- [ ] **Passo 6.2: Verificar `cloudbuild.yaml`**

O build deve incluir `npx prisma migrate deploy` como parte do startup ou no Dockerfile. Confirmar que está presente; se não estiver, adicionar como passo antes do start do servidor.

- [ ] **Passo 6.3: Rodar todos os testes**

```bash
cd futfun-backend && npm test --no-coverage
```
Esperado: todos passam.

- [ ] **Passo 6.4: Deploy backend**

```powershell
$env:CLOUDSDK_PYTHON="C:\Users\gugag\AppData\Local\Google\Cloud SDK\google-cloud-sdk\platform\bundledpython\python.exe"
cd E:\source\personal\futfun\futfun-backend
gcloud builds submit --project futfun-498118
```
Aguardar conclusão. Monitorar logs no Cloud Run para confirmar que a migração rodou.

- [ ] **Passo 6.5: Rodar backfill em produção**

Após deploy, executar uma única vez:
```bash
DATABASE_URL="<neon_production_url>" npm run backfill
```
Esperado: `Backfill complete: N rows upserted`.

- [ ] **Passo 6.6: Commit**

Se houver mudanças em `cloudbuild.yaml` ou `server.ts`:
```bash
git add .
git commit -m "chore: ensure prisma migrate deploy runs on backend startup"
```

---

## FASE 2 — Frontend: Estado Global + Tema Dinâmico

### Task F1: CompetitionModel — campos `color` e `hasRankingData`

**Files:**
- Modify: `futfun-frontend/lib/features/competitions/data/models/competition_model.dart`

- [ ] **Passo F1.1: Substituir `competition_model.dart`**

```dart
// lib/features/competitions/data/models/competition_model.dart

class CompetitionModel {
  final String code;
  final String name;
  final bool enabled;
  final bool hidden;
  final String? color;
  final bool hasRankingData;

  const CompetitionModel({
    required this.code,
    required this.name,
    required this.enabled,
    this.hidden = false,
    this.color,
    this.hasRankingData = false,
  });

  factory CompetitionModel.fromJson(Map<String, dynamic> json) {
    return CompetitionModel(
      code: json['code'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool,
      hidden: json['hidden'] as bool? ?? false,
      color: json['color'] as String?,
      hasRankingData: json['hasRankingData'] as bool? ?? false,
    );
  }

  CompetitionModel copyWith({bool? hidden, bool? enabled}) {
    return CompetitionModel(
      code: code,
      name: name,
      enabled: enabled ?? this.enabled,
      hidden: hidden ?? this.hidden,
      color: color,
      hasRankingData: hasRankingData,
    );
  }
}
```

- [ ] **Passo F1.2: Build para verificar sem erros**

```bash
cd futfun-frontend
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web` sem erros de compilação.

- [ ] **Passo F1.3: Commit**

```bash
git add lib/features/competitions/data/models/competition_model.dart
git commit -m "feat: add color and hasRankingData to CompetitionModel"
```

---

### Task F2: activeCompetitionNotifierProvider + competitionPrimaryColorProvider

**Files:**
- Create: `futfun-frontend/lib/core/providers/active_competition_provider.dart`
- Create: `futfun-frontend/lib/core/providers/competition_theme_provider.dart`

- [ ] **Passo F2.1: Criar `lib/core/providers/active_competition_provider.dart`**

```dart
// lib/core/providers/active_competition_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/competitions/data/models/competition_model.dart';
import '../../features/competitions/data/repositories/competition_repository.dart';

class ActiveCompetitionState {
  final List<CompetitionModel> available;
  final CompetitionModel? selected;

  const ActiveCompetitionState({required this.available, this.selected});

  ActiveCompetitionState copyWith({CompetitionModel? selected}) {
    return ActiveCompetitionState(available: available, selected: selected ?? this.selected);
  }
}

class ActiveCompetitionNotifier extends AsyncNotifier<ActiveCompetitionState> {
  static const _storageKey = 'active_competition_code';
  final _storage = const FlutterSecureStorage();

  @override
  Future<ActiveCompetitionState> build() async {
    final all = await CompetitionRepository().getCompetitions();
    final available = all.where((c) => c.enabled && !c.hidden).toList();

    final savedCode = await _storage.read(key: _storageKey);
    CompetitionModel? selected;
    if (savedCode != null) {
      final matches = available.where((c) => c.code == savedCode);
      if (matches.isNotEmpty) selected = matches.first;
    }
    selected ??= available.isNotEmpty ? available.first : null;

    return ActiveCompetitionState(available: available, selected: selected);
  }

  Future<void> select(CompetitionModel competition) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _storage.write(key: _storageKey, value: competition.code);
    state = AsyncValue.data(current.copyWith(selected: competition));
  }
}

final activeCompetitionNotifierProvider =
    AsyncNotifierProvider<ActiveCompetitionNotifier, ActiveCompetitionState>(
        ActiveCompetitionNotifier.new);
```

- [ ] **Passo F2.2: Criar `lib/core/providers/competition_theme_provider.dart`**

```dart
// lib/core/providers/competition_theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'active_competition_provider.dart';

Color _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF16a34a);
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFF16a34a);
  }
}

final competitionPrimaryColorProvider = Provider<Color>((ref) {
  final state = ref.watch(activeCompetitionNotifierProvider).valueOrNull;
  return _parseHex(state?.selected?.color);
});
```

- [ ] **Passo F2.3: Build para verificar sem erros**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web` sem erros.

- [ ] **Passo F2.4: Commit**

```bash
git add lib/core/providers/active_competition_provider.dart \
        lib/core/providers/competition_theme_provider.dart
git commit -m "feat: add activeCompetitionNotifierProvider with SecureStorage persistence"
```

---

### Task F3: `app.dart` — tema dinâmico por campeonato

**Files:**
- Modify: `futfun-frontend/lib/app.dart`

- [ ] **Passo F3.1: Atualizar imports em `app.dart`**

Adicionar import:
```dart
import 'core/providers/competition_theme_provider.dart';
```

- [ ] **Passo F3.2: Atualizar o método `build` em `_FutFunAppState`**

Substituir o bloco do `build`:
```dart
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final primaryColor = ref.watch(competitionPrimaryColorProvider);

    return MaterialApp.router(
      title: 'FutFun',
      routerConfig: router,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
```

- [ ] **Passo F3.3: Remover `backgroundColor` explícito dos AppBars das telas principais**

Nos 3 arquivos abaixo, remover as linhas `backgroundColor: AppColors.primary,` e `foregroundColor: Colors.white,` dos AppBars — o tema global agora cuida disso:
- `lib/features/matches/views/matches_screen.dart` (buscar por `backgroundColor: AppColors.primary`)
- `lib/features/ranking/views/ranking_screen.dart` (idem)
- `lib/features/dashboard/views/dashboard_screen.dart` (idem)

- [ ] **Passo F3.4: Build para verificar sem erros**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web`.

- [ ] **Passo F3.5: Commit**

```bash
git add lib/app.dart \
        lib/features/matches/views/matches_screen.dart \
        lib/features/ranking/views/ranking_screen.dart \
        lib/features/dashboard/views/dashboard_screen.dart
git commit -m "feat: AppBar color now driven by active competition theme"
```

---

### Task F4: Sidebar — Seleção de Campeonato

**Files:**
- Modify: `futfun-frontend/lib/core/router/app_router.dart`

- [ ] **Passo F4.1: Adicionar imports em `app_router.dart`**

No topo do arquivo, adicionar:
```dart
import '../providers/active_competition_provider.dart';
import '../../features/competitions/data/models/competition_model.dart';
```

- [ ] **Passo F4.2: Converter `_NavDrawer` de `StatelessWidget` para `ConsumerWidget`**

Alterar a assinatura da classe:
```dart
class _NavDrawer extends ConsumerWidget {
```
E a assinatura do método `build`:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

- [ ] **Passo F4.3: Substituir o corpo do `build` de `_NavDrawer`**

```dart
  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(activeCompetitionNotifierProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'FutFun',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            // ── Campeonato ───────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'CAMPEONATO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1),
              ),
            ),
            ...competitionAsync.when(
              data: (state) => state.available.map((comp) {
                final isActive = state.selected?.code == comp.code;
                final color = _colorFromHex(comp.color) ?? AppColors.primary;
                return ListTile(
                  leading: Icon(Icons.emoji_events, color: isActive ? color : AppColors.textSecondary),
                  title: Text(
                    comp.name,
                    style: TextStyle(color: isActive ? color : null, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal),
                  ),
                  selected: isActive,
                  selectedTileColor: color.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    ref.read(activeCompetitionNotifierProvider.notifier).select(comp);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
              loading: () => [const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))],
              error: (_, __) => [const SizedBox()],
            ),
            const Divider(),
            // ── Navegação ────────────────────────────────────────
            ...navItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final selected = i == currentIndex;
              return ListTile(
                leading: Icon(item.icon, color: selected ? AppColors.primary : null),
                title: Text(
                  item.label,
                  style: TextStyle(color: selected ? AppColors.primary : null, fontWeight: selected ? FontWeight.w700 : FontWeight.normal),
                ),
                selected: selected,
                selectedTileColor: AppColors.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () => onNavigate(i),
              );
            }),
          ],
        ),
      ),
    );
  }
```

- [ ] **Passo F4.4: Adicionar seletor de campeonato no NavigationRail (desktop)**

No branch `isWideWeb` do `_AppShell`, o `NavigationRail` tem um `leading`. Substituir o leading atual para incluir popup de campeonato:
```dart
              leading: Consumer(
                builder: (ctx, ref, _) {
                  final compAsync = ref.watch(activeCompetitionNotifierProvider);
                  final available = compAsync.valueOrNull?.available ?? [];
                  final selected = compAsync.valueOrNull?.selected;
                  return Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
                      ),
                      if (available.length > 1)
                        PopupMenuButton<CompetitionModel>(
                          icon: const Icon(Icons.emoji_events, color: AppColors.primary),
                          tooltip: selected?.name ?? 'Campeonato',
                          onSelected: (comp) => ref.read(activeCompetitionNotifierProvider.notifier).select(comp),
                          itemBuilder: (ctx) => available
                              .map((c) => PopupMenuItem(value: c, child: Text(c.name)))
                              .toList(),
                        ),
                    ],
                  );
                },
              ),
```

Remover o `leading` antigo:
```dart
              // REMOVER ESTE BLOCO:
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.sports_soccer, color: AppColors.primary, size: 28),
              ),
```

- [ ] **Passo F4.5: Build para verificar sem erros**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web`.

- [ ] **Passo F4.6: Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat: sidebar and NavigationRail show competition switcher"
```

---

### Task F5: `MatchesScreen` — remover TabBar, usar campeonato global

**Files:**
- Modify: `futfun-frontend/lib/features/matches/views/matches_screen.dart`

- [ ] **Passo F5.1: Atualizar import em `matches_screen.dart`**

Substituir o import de `active_competitions_provider.dart` por:
```dart
import '../../../core/providers/active_competition_provider.dart';
```
(Manter imports existentes do `matches_viewmodel` e `match_card`.)

- [ ] **Passo F5.2: Substituir o método `build` de `MatchesScreen`**

O `build` atual usa `activeCompetitionsProvider` para criar tabs. Substituir para usar `activeCompetitionNotifierProvider`:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeCompetitionNotifierProvider);

    return activeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Jogos')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Jogos')),
        body: Center(child: Text('Erro: $err')),
      ),
      data: (state) {
        if (state.selected == null) {
          return Scaffold(
            appBar: _buildAppBar(context, ref, null),
            body: const Center(
              child: Text('Selecione um campeonato na barra lateral.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }
        return Scaffold(
          appBar: _buildAppBar(context, ref, null),
          body: _MatchesBody(competitionCode: state.selected!.code),
        );
      },
    );
  }
```

- [ ] **Passo F5.3: Build para verificar sem erros**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web`.

- [ ] **Passo F5.4: Commit**

```bash
git add lib/features/matches/views/matches_screen.dart
git commit -m "feat: MatchesScreen uses global activeCompetitionNotifier instead of TabBar"
```

---

### Task F6: RankingRepository + RankingViewModel — passar `competitionCode`

**Files:**
- Modify: `futfun-frontend/lib/features/ranking/data/repositories/ranking_repository.dart`
- Modify: `futfun-frontend/lib/features/ranking/viewmodels/ranking_viewmodel.dart`

- [ ] **Passo F6.1: Atualizar `ranking_repository.dart`**

```dart
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/ranking_entry.dart';

class RankingRepository {
  final Dio _dio;

  RankingRepository() : _dio = DioClient().dio;

  Future<List<RankingEntry>> getLeaderboard(String competitionCode) async {
    final response = await _dio.get('/api/rankings', queryParameters: {'competitionCode': competitionCode});
    final list = response.data['rankings'] as List<dynamic>;
    return list.map((e) => RankingEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RankingEntry?> getMyRanking(String competitionCode) async {
    final response = await _dio.get('/api/rankings/me', queryParameters: {'competitionCode': competitionCode});
    final data = response.data['ranking'];
    if (data == null) return null;
    return RankingEntry.fromJson(data as Map<String, dynamic>);
  }
}
```

- [ ] **Passo F6.2: Atualizar `ranking_viewmodel.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ranking_entry.dart';
import '../data/repositories/ranking_repository.dart';
import '../../../core/providers/active_competition_provider.dart';

class RankingState {
  final List<RankingEntry> leaderboard;
  final RankingEntry? myRanking;

  const RankingState({required this.leaderboard, this.myRanking});
}

class RankingViewModel extends AsyncNotifier<RankingState> {
  late final RankingRepository _repository;

  @override
  Future<RankingState> build() async {
    _repository = RankingRepository();

    final activeState = await ref.watch(activeCompetitionNotifierProvider.future);
    final code = activeState.selected?.code;

    if (code == null) {
      return const RankingState(leaderboard: []);
    }

    final results = await Future.wait([
      _repository.getLeaderboard(code),
      _repository.getMyRanking(code),
    ]);

    return RankingState(
      leaderboard: results[0] as List<RankingEntry>,
      myRanking: results[1] as RankingEntry?,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final rankingViewModelProvider =
    AsyncNotifierProvider<RankingViewModel, RankingState>(RankingViewModel.new);
```

- [ ] **Passo F6.3: Build para verificar sem erros**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web`.

- [ ] **Passo F6.4: Commit**

```bash
git add lib/features/ranking/data/repositories/ranking_repository.dart \
        lib/features/ranking/viewmodels/ranking_viewmodel.dart
git commit -m "feat: ranking viewmodel passes competitionCode from active competition"
```

---

### Task F7: DashboardRepository + DashboardViewModel — passar `competitionCode`

**Files:**
- Modify: `futfun-frontend/lib/features/dashboard/data/repositories/dashboard_repository.dart`
- Modify: `futfun-frontend/lib/features/dashboard/viewmodels/dashboard_viewmodel.dart`

- [ ] **Passo F7.1: Atualizar `dashboard_repository.dart`**

```dart
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/ranking_history_entry.dart';

class DashboardRepository {
  final Dio _dio;

  DashboardRepository() : _dio = DioClient().dio;

  Future<List<RankingHistoryEntry>> getRankingHistory(String competitionCode) async {
    final response = await _dio.get(
      '/api/rankings/history',
      queryParameters: {'competitionCode': competitionCode},
    );
    final list = response.data['history'] as List<dynamic>;
    return list
        .map((e) => RankingHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Passo F7.2: Atualizar `dashboard_viewmodel.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ranking_history_entry.dart';
import '../data/repositories/dashboard_repository.dart';
import '../../ranking/data/models/ranking_entry.dart';
import '../../ranking/data/repositories/ranking_repository.dart';
import '../../../core/providers/active_competition_provider.dart';

class DashboardState {
  final List<RankingHistoryEntry> history;
  final RankingEntry? myRanking;

  const DashboardState({required this.history, this.myRanking});
}

class DashboardViewModel extends AsyncNotifier<DashboardState> {
  late final DashboardRepository _dashboardRepo;
  late final RankingRepository _rankingRepo;

  @override
  Future<DashboardState> build() async {
    _dashboardRepo = DashboardRepository();
    _rankingRepo = RankingRepository();

    final activeState = await ref.watch(activeCompetitionNotifierProvider.future);
    final code = activeState.selected?.code;

    if (code == null) {
      return const DashboardState(history: []);
    }

    final results = await Future.wait([
      _dashboardRepo.getRankingHistory(code),
      _rankingRepo.getMyRanking(code),
    ]);

    return DashboardState(
      history: results[0] as List<RankingHistoryEntry>,
      myRanking: results[1] as RankingEntry?,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final dashboardViewModelProvider =
    AsyncNotifierProvider<DashboardViewModel, DashboardState>(DashboardViewModel.new);
```

- [ ] **Passo F7.3: Build para verificar sem erros**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Esperado: `✓ Built build/web`.

- [ ] **Passo F7.4: Commit**

```bash
git add lib/features/dashboard/data/repositories/dashboard_repository.dart \
        lib/features/dashboard/viewmodels/dashboard_viewmodel.dart
git commit -m "feat: dashboard history filtered by active competition"
```

---

### Task F8: Deploy Fase 2 Frontend

- [ ] **Passo F8.1: Build final**

```bash
cd E:\source\personal\futfun\futfun-frontend
flutter build web --no-tree-shake-icons
```
Esperado: `✓ Built build/web` sem erros.

- [ ] **Passo F8.2: Deploy Firebase Hosting**

```bash
firebase deploy --only hosting
```
Esperado: `✔ Deploy complete!` + URL do app.

- [ ] **Passo F8.3: Verificar no browser**
  - Abrir `https://futfun-385ea.web.app`
  - Fazer login
  - Verificar que o Drawer mostra a seção "CAMPEONATO"
  - Trocar de campeonato → AppBar deve mudar de cor
  - Ir para Ranking → deve mostrar ranking do campeonato selecionado
  - Ir para Jogos → deve mostrar só jogos do campeonato selecionado
  - Recarregar a página → campeonato selecionado deve ser lembrado

---

## FASE 3 — Backend: Provider Config (Campeonatos Configuráveis)

*Pode ser implementada após a Copa do Mundo. Não afeta o ranking.*

### Task B7: `TheSportsDbAdapter` — constructor params

**Files:**
- Modify: `futfun-backend/src/infrastructure/football-data/TheSportsDbAdapter.ts`
- Modify: `futfun-backend/src/infrastructure/container/container.ts`

- [ ] **Passo B7.1: Refatorar `TheSportsDbAdapter` para receber configuração no constructor**

Substituir as constantes de módulo por campos do constructor:
```typescript
// Remover:
const LEAGUE_ID = '4562';
const COMPETITION_CODE = 'CLI';
const COMPETITION_NAME = 'Amistosos Internacionais';

// O constructor da classe passa a ser:
export class TheSportsDbAdapter implements IFootballDataProvider {
  private readonly leagueId: string;
  private readonly competitionCode: string;
  private readonly competitionName: string;

  constructor(config: { leagueId: string; competitionCode: string; competitionName: string }) {
    this.leagueId = config.leagueId;
    this.competitionCode = config.competitionCode;
    this.competitionName = config.competitionName;
  }
  // ... resto do código igual
```

Substituir todas as referências a `LEAGUE_ID` por `this.leagueId`, `COMPETITION_CODE` por `this.competitionCode`, `COMPETITION_NAME` por `this.competitionName`.

- [ ] **Passo B7.2: Atualizar `container.ts` para passar config**

```typescript
  const secondaryProvider = new TheSportsDbAdapter({
    leagueId: '4562',
    competitionCode: 'CLI',
    competitionName: 'Amistosos Internacionais',
  });
```

- [ ] **Passo B7.3: Rodar todos os testes**

```bash
npm test --no-coverage
```
Esperado: todos passam.

- [ ] **Passo B7.4: Commit**

```bash
git add src/infrastructure/football-data/TheSportsDbAdapter.ts \
        src/infrastructure/container/container.ts
git commit -m "refactor: TheSportsDbAdapter accepts leagueId/competitionCode in constructor"
```

---

### Task B8: `CompetitionDiscoveryService` — auto-discovery

**Files:**
- Create: `futfun-backend/src/infrastructure/football-data/CompetitionDiscoveryService.ts`

- [ ] **Passo B8.1: Criar `CompetitionDiscoveryService.ts`**

```typescript
// src/infrastructure/football-data/CompetitionDiscoveryService.ts
//
// Discovers which data provider(s) have data for a given competition.
// Tries football-data.org by code, then TheSportsDB by name search.
// Saves result in Competition.providerConfig.

import { PrismaClient } from '@prisma/client';

const FDO_BASE = process.env.FOOTBALL_DATA_ORG_BASE_URL || 'https://api.football-data.org/v4';
const TSDB_BASE = 'https://www.thesportsdb.com/api/v1/json/3';

export class CompetitionDiscoveryService {
  constructor(private readonly prisma: PrismaClient) {}

  /**
   * Discovers and saves providerConfig for a competition.
   * Safe to call multiple times — uses upsert semantics.
   */
  async discover(competitionCode: string, competitionName: string): Promise<void> {
    const config: Record<string, string> = {};

    // 1. Try football-data.org
    try {
      const res = await fetch(`${FDO_BASE}/competitions/${competitionCode}`, {
        headers: { 'X-Auth-Token': process.env.FOOTBALL_DATA_ORG_API_KEY! },
      });
      if (res.ok) {
        config['football-data'] = competitionCode;
        console.log(`[Discovery] ${competitionCode}: found in football-data.org`);
      }
    } catch (err) {
      console.warn(`[Discovery] ${competitionCode}: football-data.org check failed:`, err);
    }

    // 2. Try TheSportsDB — search by name
    try {
      const encoded = encodeURIComponent(competitionName);
      const res = await fetch(`${TSDB_BASE}/searchleagues.php?l=${encoded}`);
      if (res.ok) {
        const data = await res.json();
        const leagues: any[] = data?.countrys ?? data?.leagues ?? [];
        const match = leagues.find(
          (l: any) =>
            l.strLeague?.toLowerCase().includes(competitionName.toLowerCase()) ||
            competitionName.toLowerCase().includes((l.strLeague ?? '').toLowerCase()),
        );
        if (match?.idLeague) {
          config['thesportsdb'] = match.idLeague;
          console.log(`[Discovery] ${competitionCode}: found in TheSportsDB (id=${match.idLeague})`);
        }
      }
    } catch (err) {
      console.warn(`[Discovery] ${competitionCode}: TheSportsDB check failed:`, err);
    }

    if (Object.keys(config).length > 0) {
      await this.prisma.competition.update({
        where: { code: competitionCode },
        data: { providerConfig: config },
      });
      console.log(`[Discovery] ${competitionCode}: providerConfig saved:`, config);
    } else {
      console.warn(`[Discovery] ${competitionCode}: no provider found — providerConfig remains null`);
    }
  }
}
```

- [ ] **Passo B8.2: Commit**

```bash
git add src/infrastructure/football-data/CompetitionDiscoveryService.ts
git commit -m "feat: add CompetitionDiscoveryService for auto-discovering data providers"
```

---

### Task B9: `MatchSyncJob` — usar `providerConfig` do banco

**Files:**
- Modify: `futfun-backend/src/infrastructure/football-data/MatchSyncJob.ts`

- [ ] **Passo B9.1: Adicionar import de `TheSportsDbAdapter` em `MatchSyncJob.ts`**

No topo de `MatchSyncJob.ts`, adicionar:
```typescript
import { TheSportsDbAdapter } from './TheSportsDbAdapter';
```

- [ ] **Passo B9.2: Substituir `syncMatches()` para usar `providerConfig`**

```typescript
  async syncMatches(): Promise<void> {
    try {
      const competitions = await this.prisma.competition.findMany({
        where: { enabled: true },
        select: { code: true, providerConfig: true },
      });

      const fdoCodes = competitions
        .filter((c) => c.providerConfig && (c.providerConfig as any)['football-data'])
        .map((c) => ({ internalCode: c.code, fdoCode: (c.providerConfig as any)['football-data'] as string }));

      for (const { internalCode, fdoCode } of fdoCodes) {
        await this.syncCompetition(fdoCode, internalCode).catch((err) =>
          console.error(`Competition sync failed for ${internalCode} (fdo: ${fdoCode}):`, err),
        );
      }
    } catch (err) {
      console.error('Match sync failed:', err);
    }
  }
```

- [ ] **Passo B9.3: Atualizar `syncCompetition` para aceitar dois parâmetros**

```typescript
  private async syncCompetition(fdoCode: string, internalCode: string): Promise<void> {
    const matches = await this.provider.getCompetitionMatches(fdoCode);
    for (const match of matches) {
      await this.upsertMatch(match, internalCode);
    }
    console.log(`Synced ${matches.length} matches for ${internalCode} (fdo: ${fdoCode})`);
  }
```

- [ ] **Passo B9.4: Substituir `syncDateRange()` para usar `providerConfig`**

```typescript
  async syncDateRange(): Promise<void> {
    try {
      const competitions = await this.prisma.competition.findMany({
        where: { enabled: true },
        select: { code: true, providerConfig: true },
      });

      const fdoCodes = competitions
        .filter((c) => c.providerConfig && (c.providerConfig as any)['football-data'])
        .map((c) => (c.providerConfig as any)['football-data'] as string);

      if (fdoCodes.length === 0) return;

      const { dateFrom, dateTo } = getSevenDayWindow();
      const matches = await this.provider.getMatchesByDateRange(dateFrom, dateTo, fdoCodes);

      const codesInBatch = [...new Set(matches.map((m) => m.competition.code))];
      for (const code of codesInBatch) {
        const matchWithCode = matches.find((m) => m.competition.code === code)!;
        await this.prisma.competition.upsert({
          where: { code },
          update: {},
          create: { code, name: matchWithCode.competition.name, enabled: true },
        });
      }

      for (const match of matches) {
        const isNational =
          !match.homeTeam.type || !match.awayTeam.type ||
          match.homeTeam.type === 'NATIONAL' || match.awayTeam.type === 'NATIONAL';
        if (isNational) {
          await this.upsertMatch(match, match.competition.code);
        }
      }

      console.log(`Date-range sync (${dateFrom} → ${dateTo}): ${matches.length} matches, ${codesInBatch.length} competitions`);
    } catch (err) {
      console.error('Date-range sync failed:', err);
    }
  }
```

- [ ] **Passo B9.5: Substituir `syncSecondary()` para usar `providerConfig`**

```typescript
  async syncSecondary(): Promise<void> {
    try {
      const competitions = await this.prisma.competition.findMany({
        where: { enabled: true },
        select: { code: true, name: true, providerConfig: true },
      });

      const tsdbComps = competitions.filter(
        (c) => c.providerConfig && (c.providerConfig as any)['thesportsdb'],
      );

      if (tsdbComps.length === 0) return;

      const { dateFrom, dateTo } = getTwoWeekWindow();

      for (const comp of tsdbComps) {
        const leagueId = (comp.providerConfig as any)['thesportsdb'] as string;
        const adapter = new TheSportsDbAdapter({
          leagueId,
          competitionCode: comp.code,
          competitionName: comp.name,
        });

        const providerMatches = await adapter.getMatchesByDateRange(dateFrom, dateTo);
        const providerMap = new Map(providerMatches.map((m) => [m.id, m]));

        const dbMatches = await this.prisma.match.findMany({
          where: {
            competitionCode: comp.code,
            externalId: { in: [...providerMap.keys()] },
          },
          select: { id: true, externalId: true, competitionCode: true },
        });

        let updated = 0;
        for (const dbMatch of dbMatches) {
          const pm = providerMap.get(dbMatch.externalId);
          if (pm) {
            await this.upsertMatch(pm, dbMatch.competitionCode ?? comp.code);
            updated++;
          }
        }

        if (updated > 0) {
          console.log(`[TheSportsDB] Secondary sync updated ${updated} match(es) for ${comp.code}`);
        }
      }

      await this.autoExpirePastSecondaryMatches();
    } catch (err: any) {
      const isConnErr =
        err?.code === 'ECONNRESET' ||
        err?.message?.includes('timed out') ||
        err?.message?.includes('Authentication') ||
        err?.message?.includes('terminated');
      if (isConnErr) throw err;
      console.error('[TheSportsDB] Secondary sync failed:', err);
    }
  }
```

- [ ] **Passo B9.6: Substituir `autoExpirePastSecondaryMatches()` para usar `providerConfig`**

```typescript
  private async autoExpirePastSecondaryMatches(): Promise<void> {
    try {
      const competitions = await this.prisma.competition.findMany({
        where: { enabled: true },
        select: { code: true, providerConfig: true },
      });

      const tsdbCodes = competitions
        .filter((c) => c.providerConfig && (c.providerConfig as any)['thesportsdb'])
        .map((c) => c.code);

      if (tsdbCodes.length === 0) return;

      const cutoff = new Date(Date.now() - 150 * 60 * 1000);
      const stale = await this.prisma.match.findMany({
        where: {
          competitionCode: { in: tsdbCodes },
          status: { in: ['SCHEDULED', 'LIVE'] },
          kickoffTime: { lt: cutoff },
        },
        select: { id: true, homeTeamName: true, awayTeamName: true, kickoffTime: true },
      });

      if (stale.length === 0) return;

      console.log(`[TheSportsDB] Auto-expiring ${stale.length} past SCHEDULED/LIVE match(es).`);
      for (const m of stale) {
        await this.prisma.match.update({
          where: { id: m.id },
          data: { status: 'FINISHED', lastSyncedAt: new Date() },
        });
      }
    } catch (err) {
      console.error('[TheSportsDB] autoExpirePastSecondaryMatches failed:', err);
    }
  }
```

- [ ] **Passo B9.7: Remover o parâmetro `secondaryProvider` do constructor de `MatchSyncJob`**

O constructor passa a não aceitar `secondaryProvider` pois os adapters são criados on-demand:
```typescript
  constructor(
    private readonly prisma: PrismaClient,
    private readonly provider: IFootballDataProvider,
    // secondaryProvider removido — agora criado on-demand via providerConfig
  ) {
    this.scorePredictionsHandler = new ScorePredictionsHandler(prisma);
  }
```

Remover também o `if (this.secondaryProvider)` e a `secondaryTask` do método `start()` — agora `syncSecondary()` roda em cron incondicional (pois verifica internamente quais competitions têm TheSportsDB):
```typescript
    // Secondary provider: once per hour
    this.secondaryTask = cron.schedule('0 * * * *', async () => {
      try {
        await this.syncSecondary();
      } catch (err: any) {
        await this.handleCronError(err, 'secondary');
      }
    });
    console.log('MatchSyncJob secondary cron: every hour');
```

- [ ] **Passo B9.8: Atualizar `container.ts`**

```typescript
  // Remover secondaryProvider da criação do MatchSyncJob
  const matchSyncJob = new MatchSyncJob(prisma, footballProvider);
  // IContainer também remove secondaryProvider se não for mais necessário externamente
```

- [ ] **Passo B9.9: Rodar todos os testes**

```bash
npm test --no-coverage
```
Esperado: todos passam.

- [ ] **Passo B9.10: Commit**

```bash
git add src/infrastructure/football-data/MatchSyncJob.ts \
        src/infrastructure/container/container.ts
git commit -m "refactor: MatchSyncJob reads providerConfig from DB, no hardcoded competition codes"
```

---

### Task B10: Admin Competitions POST — auto-discovery + campo `color`

**Files:**
- Modify: `futfun-backend/app/api/admin/competitions/route.ts`

- [ ] **Passo B10.1: Atualizar schema de validação e handler POST**

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAdmin } from '@presentation/middleware/authMiddleware';
import { getContainer } from '@infrastructure/container/container';
import { handleError } from '@presentation/middleware/errorHandler';
import { CompetitionDiscoveryService } from '@infrastructure/football-data/CompetitionDiscoveryService';

const createSchema = z.object({
  code: z.string().min(2).max(10),
  name: z.string().min(2).max(100),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
});

export const GET = withAdmin(async (_req: NextRequest) => {
  try {
    const { prisma } = getContainer();
    const competitions = await prisma.competition.findMany({
      orderBy: { createdAt: 'asc' },
    });
    return NextResponse.json({ competitions });
  } catch (error) {
    return handleError(error);
  }
});

export const POST = withAdmin(async (req: NextRequest) => {
  try {
    const body = await req.json();
    const { code, name, color } = createSchema.parse(body);
    const { prisma } = getContainer();

    const competition = await prisma.competition.create({
      data: { code: code.toUpperCase(), name, color: color ?? null },
    });

    // Fire-and-forget auto-discovery
    const discoveryService = new CompetitionDiscoveryService(prisma);
    discoveryService.discover(competition.code, competition.name).catch((err) =>
      console.error(`[Discovery] Background discovery failed for ${competition.code}:`, err),
    );

    return NextResponse.json({ competition }, { status: 201 });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Passo B10.2: Rodar todos os testes**

```bash
npm test --no-coverage
```
Esperado: todos passam.

- [ ] **Passo B10.3: Commit**

```bash
git add app/api/admin/competitions/route.ts
git commit -m "feat: admin POST /competitions accepts color field and triggers auto-discovery"
```

---

### Task B11: Deploy Fase 3 Backend

- [ ] **Passo B11.1: Rodar todos os testes**

```bash
cd futfun-backend && npm test --no-coverage
```
Esperado: todos passam.

- [ ] **Passo B11.2: Deploy backend**

```powershell
$env:CLOUDSDK_PYTHON="C:\Users\gugag\AppData\Local\Google\Cloud SDK\google-cloud-sdk\platform\bundledpython\python.exe"
cd E:\source\personal\futfun\futfun-backend
gcloud builds submit --project futfun-498118
```

- [ ] **Passo B11.3: Confirmar nos logs do Cloud Run**

Verificar que:
- Migração rodou sem erros
- `MatchSyncJob started` aparece nos logs
- `MatchSyncJob secondary cron: every hour` aparece nos logs (antes dizia "TheSportsDB")
- Após ~1h, `[TheSportsDB] Secondary sync` aparece nos logs confirmando que encontrou competições com TheSportsDB no providerConfig

---

## Resumo por Fase

| Fase | Tarefas | Prioridade | Dependências |
|------|---------|-----------|-------------|
| **Fase 1 - Backend** | B1–B6 | 🔴 Crítico (Copa 12/06) | Nenhuma |
| **Fase 2 - Frontend** | F1–F8 | 🔴 Crítico (Copa 12/06) | Fase 1 deployada |
| **Fase 3 - Backend** | B7–B11 | 🟡 Importante (pós-Copa) | Fase 1 deployada |
