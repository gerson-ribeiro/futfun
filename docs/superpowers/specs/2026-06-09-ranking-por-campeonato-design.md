# Design: Ranking por Campeonato + Campeonatos Configuráveis

**Data:** 2026-06-09  
**Status:** Aprovado  
**Contexto:** Copa do Mundo começa 2026-06-12 (quinta-feira). O ranking atual é global (soma pontos de todos os campeonatos). Campeonatos são parcialmente hardcoded nos adapters.

---

## Objetivo

1. Ranking separado por campeonato (Copa do Mundo e Amistosos independentes)
2. Histórico de ranking também por campeonato
3. Campeonatos totalmente configuráveis via admin — sem programação para adicionar novos
4. Auto-discovery de provider de dados ao criar nova competição
5. Seletor global de campeonato no app com tema visual dinâmico por campeonato

---

## Escopo

### O que muda
- Schema: 3 mudanças (2 campos em `competitions`, nova tabela, 1 campo em `ranking_snapshots`)
- Backend: ranking endpoints, scoring handler, sync job, adapters
- Frontend: estado global de competição, sidebar, tema dinâmico, telas de jogos e ranking

### O que NÃO muda
- Regras de pontuação (universais para todos os campeonatos)
- Auth / invite flow / roles
- Admin CRUD de competições (apenas ganha novos campos)

---

## Seção 1 — Backend: Schema

### 1.1 Tabela `competitions` — novos campos

```prisma
model Competition {
  // campos existentes...
  color         String?   // hex "#1A6B3A" — cor da topbar/tema no app
  providerConfig Json?    // { "football-data": "WC", "thesportsdb": "4562" }
                          // preenchido por auto-discovery ou seed
}
```

**`color`:** Hex string usada pelo frontend para tema dinâmico. Admin pode definir ao criar/editar competição. Se nulo, frontend usa cor padrão.

**`providerConfig`:** JSON com mapeamento entre provider e código/ID nativo do provider. Exemplos:
- Copa do Mundo: `{ "football-data": "WC" }`
- Amistosos: `{ "thesportsdb": "4562" }`
- Competição em ambas as fontes: `{ "football-data": "CL", "thesportsdb": "9876" }`
- Pending discovery: `null`

### 1.2 Nova tabela `user_competition_stats`

```prisma
model UserCompetitionStats {
  id              String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  userId          String   @db.Uuid
  competitionCode String
  totalPoints     Int      @default(0)
  exactScores     Int      @default(0)
  correctResults  Int      @default(0)
  predictionCount Int      @default(0)
  updatedAt       DateTime @updatedAt
  user            User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, competitionCode])
  @@index([competitionCode])
  @@map("user_competition_stats")
}
```

Atualizada via upsert pelo `ScorePredictionsHandler` a cada pontuação. Permite query de ranking O(1) por competição sem full-scan de predictions.

### 1.3 Tabela `ranking_snapshots` — novo campo

```prisma
model RankingSnapshot {
  // campos existentes...
  competitionCode String?  // null = snapshot global (legado); preenchido = por competição
}
```

Snapshots novos sempre terão `competitionCode` preenchido. Snapshots legados (null) são mantidos para compatibilidade mas não expostos nos novos endpoints.

---

## Seção 2 — Backend: Lógica

### 2.1 ScorePredictionsHandler

Ao pontuar uma prediction, além do que já faz, executa:
```typescript
await prisma.userCompetitionStats.upsert({
  where: { userId_competitionCode: { userId, competitionCode } },
  update: {
    totalPoints: { increment: points },
    exactScores: { increment: isExact ? 1 : 0 },
    correctResults: { increment: isCorrect ? 1 : 0 },
    predictionCount: { increment: 1 },
  },
  create: { userId, competitionCode, totalPoints: points, ... }
})
```

Cria snapshot `ranking_snapshots` com `competitionCode` preenchido.

### 2.2 Endpoints de Ranking

**`GET /api/rankings?competitionCode=WC`**
- `competitionCode` obrigatório
- Consulta `user_competition_stats WHERE competitionCode = :code AND totalPoints > 0`
- Ordenação: totalPoints DESC → exactScores DESC → correctResults DESC
- Retorna posição calculada no momento (row_number)

**`GET /api/rankings/me?competitionCode=WC`**
- Retorna posição e stats do usuário autenticado para aquela competição

**`GET /api/rankings/history?competitionCode=WC`**
- Retorna `ranking_snapshots WHERE userId = :id AND competitionCode = :code`
- Ordenado por `createdAt ASC`

**`GET /api/competitions`** (existente)
- Passa a incluir campos `color` e `hasRankingData: boolean` na resposta
- `hasRankingData = true` se existir ao menos 1 registro em `user_competition_stats` para aquela competição com `totalPoints > 0`

### 2.3 POST /api/admin/competitions — Auto-discovery

Ao criar uma competição, responde imediatamente com `201` e dispara job assíncrono:

```
1. Testa football-data.org: GET /v4/competitions/{code}
   → 200: salva providerConfig["football-data"] = code

2. Testa TheSportsDB: GET /searchleagues.php?l={name}
   → encontrou: salva providerConfig["thesportsdb"] = leagueId encontrado

3. Atualiza Competition.providerConfig no banco com resultado
```

Se nenhum provider encontrar dados: `providerConfig` permanece `null`. Admin pode tentar novamente ou o `MatchSyncJob` reprocessa competitions com `providerConfig = null` periodicamente.

### 2.4 MatchSyncJob — sem hardcoding

Elimina filtros `code !== 'FRIENDLIES'` e `code.startsWith('AF_')`. Nova lógica:

```typescript
const competitions = await prisma.competition.findMany({
  where: { enabled: true, providerConfig: { not: null } }
})

for (const competition of competitions) {
  const config = competition.providerConfig as ProviderConfig

  if (config['football-data']) {
    await footballDataAdapter.sync(config['football-data'], competition.code)
  }
  if (config['thesportsdb']) {
    await theSportsDbAdapter.sync(config['thesportsdb'], competition.code)
  }
}
```

Competitions com `providerConfig = null` ficam em fila de auto-discovery, não bloqueiam o sync.

### 2.5 TheSportsDbAdapter — sem constantes de módulo

Remove `COMPETITION_CODE` e `LEAGUE_ID` como constantes. Métodos de sync passam a receber `(leagueId: string, competitionCode: string)`.

### 2.6 Seed e Backfill

**`seed.ts` atualizado:** preenche `providerConfig` e `color` para competições existentes:
```typescript
WC:  { providerConfig: { "football-data": "WC" }, color: "#1A6B3A" }
CLI: { providerConfig: { "thesportsdb": "4562" }, color: "#2E4A8C" }
```

**`seed-backfill.ts` (novo, roda uma vez no deploy):** Recalcula `user_competition_stats` a partir de todas as `Prediction` já pontuadas no banco:
```
SELECT
  userId,
  match.competitionCode,
  SUM(points)                          AS totalPoints,
  COUNT(*) FILTER (points = 10)        AS exactScores,
  COUNT(*) FILTER (points IN (5,7,10)) AS correctResults,
  COUNT(*)                             AS predictionCount
FROM predictions
JOIN matches ON predictions.matchId = matches.id
WHERE predictions.points IS NOT NULL
  AND matches.competitionCode IS NOT NULL
GROUP BY userId, competitionCode
→ upsert em user_competition_stats
```

---

## Seção 3 — Frontend: Estado Global e Tema

### 3.1 activeCompetitionProvider

```dart
// Riverpod StateNotifier
// Persiste seleção em flutter_secure_storage
// Inicialização: carrega competitions do backend, restaura última seleção
// Se só 1 competition disponível: seleciona automaticamente
final activeCompetitionProvider = StateNotifierProvider<
  ActiveCompetitionNotifier, Competition?>(...)
```

### 3.2 competitionThemeProvider

```dart
// Derivado de activeCompetitionProvider
// Constrói ThemeData com primaryColor = competition.color (ou padrão se null)
final competitionThemeProvider = Provider<ThemeData>((ref) {
  final competition = ref.watch(activeCompetitionProvider)
  final color = competition?.color != null
      ? Color(int.parse(competition!.color!.replaceAll('#', '0xFF')))
      : defaultPrimaryColor
  return AppTheme.buildFrom(color)
})
```

O `MaterialApp` / `AppShell` observa este provider e aplica o tema. `AnimatedTheme` garante transição suave ao trocar.

### 3.3 Sidebar — Seletor de Campeonato

Nova seção "Campeonato" na sidebar (drawer):

```
┌─────────────────────────┐
│  [Avatar] Nome usuário  │
├─────────────────────────┤
│  CAMPEONATO             │
│  ● Copa do Mundo 2026   │  ← item ativo, cor do campeonato
│    Amistosos            │
├─────────────────────────┤
│  Jogos                  │
│  Ranking                │
│  ...                    │
└─────────────────────────┘
```

- Ícone/bandeira do campeonato (campo `iconUrl` opcional, ou emoji; fallback = `EmojiEvents`)
- Item ativo com cor de fundo = `competition.color` (levemente transparente)
- Ao tocar: `activeCompetitionNotifier.select(competition)` → drawer fecha → tema muda

### 3.4 AppBar dinâmica

```dart
AppBar(
  backgroundColor: Theme.of(context).primaryColor,
  // AnimatedTheme no MaterialApp cuida da transição suave
)
```

Quando o campeonato muda na sidebar, a cor do `AppBar` anima suavemente para a nova cor.

### 3.5 MatchesScreen

- Remove drawer de filtro de competição atual
- Observa `activeCompetitionProvider`
- Chama `/api/matches?competitionCode={code}` automaticamente ao trocar competição
- Sem outras mudanças na tela

### 3.6 RankingScreen

- Observa `activeCompetitionProvider`
- Chama `/api/rankings?competitionCode={code}`
- Sem dropdown interno próprio (seleção fica na sidebar)
- **Competições sem palpites pontuados:** o endpoint `/api/competitions` passa a incluir `hasRankingData: boolean` (calculado a partir de `user_competition_stats`). A RankingScreen usa esse campo para exibir na sidebar apenas as competições com `hasRankingData = true`. A MatchesScreen não aplica esse filtro — mostra todas as competições habilitadas. A lógica de filtragem fica no presenter/viewmodel de cada tela, não no sidebar em si.

### 3.7 DashboardScreen (histórico pessoal)

- Gráfico de linha: chama `/api/rankings/history?competitionCode={code}`
- Mostra evolução de pontos no campeonato ativo

---

## Seção 4 — Admin Panel

### Criar competição (fluxo completo)

1. Admin preenche: **Código** (ex: `BRA`) + **Nome** (ex: `Brasileirão 2025`) + **Cor** (color picker hex, opcional)
2. Backend cria registro e dispara auto-discovery assíncrono
3. Admin pode ver status do discovery na listagem (campo `providerConfig`: `null` = pendente, objeto = configurado)
4. Campo `providerConfig` exibido como readonly (JSON formatado) para diagnóstico
5. Admin pode reativar/desativar a qualquer momento via campo `enabled`

---

## Dependências e Ordem de Implementação

```
1. Migração Prisma (schema)
2. seed.ts + seed-backfill.ts
3. ScorePredictionsHandler (upsert stats)
4. Endpoints ranking (competitionCode param)
5. TheSportsDbAdapter (parâmetros em vez de constantes)
6. MatchSyncJob (lê providerConfig)
7. Auto-discovery job
8. Deploy backend

9. activeCompetitionProvider + competitionThemeProvider (Flutter)
10. Sidebar com seletor
11. AppBar animada
12. MatchesScreen (remove drawer, usa provider)
13. RankingScreen (usa provider)
14. DashboardScreen (usa provider)
15. Deploy frontend
```

---

## Notas e Decisões

- **Snapshots globais legados** (competitionCode = null): mantidos no banco, não expostos nos novos endpoints. Não são migrados para evitar dados inconsistentes.
- **Competições sem palpites pontuados** não aparecem no dropdown de ranking (controlado pelo backend retornando lista vazia → frontend oculta na sidebar para ranking).
- **Fluxo de novo campeonato** (ex: Brasileirão): o usuário pediu revisão futura deste fluxo — não está no escopo desta iteração.
- **iconUrl** no Competition: campo opcional, pode ser adicionado na iteração futura junto com o novo fluxo de campeonatos.
