# Matches & Predictions Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the matches screen to d+7 with load-more, remove predicted games from it, and make the betting window explicit with locked-card design.

**Architecture:** Backend adds `daysAhead` query param and a per-user `hasPrediction` flag to `/api/upcoming-matches`. Provider data is cached per `daysAhead` value; user-specific flag is injected at request time (not cached). Frontend filters matches using `hasPrediction`, removes the predictions second-call, and adds locked-card styling.

**Tech Stack:** Next.js 15 + TypeScript + Prisma (backend); Flutter + Riverpod (frontend)

---

## File Map

| File | Change |
|---|---|
| `futfun-backend/app/api/upcoming-matches/route.ts` | Add `daysAhead` param, keyed cache, `hasPrediction` flag |
| `futfun-frontend/lib/features/matches/data/models/match_model.dart` | Add `hasPrediction: bool` field |
| `futfun-frontend/lib/features/matches/data/repositories/matches_repository.dart` | Add `daysAhead` param to `getUpcomingMatches` |
| `futfun-frontend/lib/features/matches/viewmodels/matches_viewmodel.dart` | Refactor state + load-more; remove predictions second-call |
| `futfun-frontend/lib/features/matches/views/widgets/match_card.dart` | Remove `prediction` param; simplify to bet/locked states |
| `futfun-frontend/lib/features/matches/views/matches_screen.dart` | Remove `prediction` arg from MatchCard call |
| `futfun-frontend/lib/features/predictions/views/predictions_screen.dart` | Add betting-window check to edit; add visible Editar button |

---

## Task 1: Backend — `daysAhead` param, keyed cache, `hasPrediction` flag

**Files:**
- Modify: `futfun-backend/app/api/upcoming-matches/route.ts`

The current implementation has a single shared cache and no per-user data. The changes:
- Split `UpcomingMatch` into `CachedMatch` (provider data, shareable) and `UpcomingMatch` (adds `hasPrediction`, per-request)
- Replace `let cache` with `Map<number, ...>` keyed by `daysAhead`
- Window: `dateFrom = today 00:00 UTC`, `dateTo = today + daysAhead days 23:59 UTC` (was d-1 to d+3)
- After provider fetch, one Prisma query for user's predicted externalIds → set flag

- [ ] **Step 1: Replace `futfun-backend/app/api/upcoming-matches/route.ts` with the new implementation**

```typescript
// app/api/upcoming-matches/route.ts
//
// Returns upcoming matches from both providers without writing to the DB.
// Provider data is cached per daysAhead value for 5 minutes.
// hasPrediction is injected per-request (user-specific, never cached).

import { NextRequest, NextResponse } from 'next/server';
import { getContainer } from '@infrastructure/container/container';
import { withAuth } from '@presentation/middleware/authMiddleware';
import { handleError } from '@presentation/middleware/errorHandler';
import { ProviderMatchWithCompetition } from '@application/ports/IFootballDataProvider';
import { TokenPayload } from '@application/ports/ITokenService';

// Provider data only — shared across users, safe to cache
interface CachedMatch {
  id: string;
  externalId: number;
  competitionCode: string;
  competitionName: string;
  homeTeamId: number;
  homeTeamName: string;
  homeTeamShort: string | null;
  homeTeamCrest: string | null;
  homeTeamType: string | null;
  awayTeamId: number;
  awayTeamName: string;
  awayTeamShort: string | null;
  awayTeamCrest: string | null;
  awayTeamType: string | null;
  kickoffTime: string;
  status: string;
  scoreHome: number | null;
  scoreAway: number | null;
  stage: string;
  groupName: string | null;
  matchday: number | null;
}

// Sent to client — adds per-user hasPrediction flag
interface UpcomingMatch extends CachedMatch {
  hasPrediction: boolean;
}

// Cache keyed by daysAhead; stores provider data only (no user-specific fields)
const matchCache = new Map<number, { data: CachedMatch[]; ts: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000;

// dateFrom = today 00:00 UTC; dateTo = today + daysAhead days 23:59 UTC
function getMatchWindow(daysAhead: number) {
  const now = new Date();
  const from = new Date(now);
  from.setUTCHours(0, 0, 0, 0);
  const to = new Date(now);
  to.setUTCDate(now.getUTCDate() + daysAhead);
  to.setUTCHours(23, 59, 59, 999);
  return {
    dateFrom: from.toISOString().split('T')[0],
    dateTo: to.toISOString().split('T')[0],
  };
}

function toCachedMatch(m: ProviderMatchWithCompetition): CachedMatch {
  return {
    id: m.id.toString(),
    externalId: m.id,
    competitionCode: m.competition.code,
    competitionName: m.competition.name,
    homeTeamId: m.homeTeam.id,
    homeTeamName: m.homeTeam.name,
    homeTeamShort: m.homeTeam.shortName ?? null,
    homeTeamCrest: m.homeTeam.crest ?? null,
    homeTeamType: m.homeTeam.type ?? null,
    awayTeamId: m.awayTeam.id,
    awayTeamName: m.awayTeam.name,
    awayTeamShort: m.awayTeam.shortName ?? null,
    awayTeamCrest: m.awayTeam.crest ?? null,
    awayTeamType: m.awayTeam.type ?? null,
    kickoffTime: m.utcDate.includes('T') ? m.utcDate : `${m.utcDate}T00:00:00Z`,
    status: m.status,
    scoreHome: m.score.fullTime.home ?? null,
    scoreAway: m.score.fullTime.away ?? null,
    stage: m.stage,
    groupName: m.group ?? null,
    matchday: m.matchday ?? null,
  };
}

export const GET = withAuth(async (req: NextRequest, user: TokenPayload) => {
  try {
    const { searchParams } = req.nextUrl;
    const competitionCode = searchParams.get('competitionCode');
    const daysAhead = Math.max(1, parseInt(searchParams.get('daysAhead') ?? '7', 10) || 7);

    const { prisma, footballProvider, secondaryProvider } = getContainer();
    const now = Date.now();
    const cached = matchCache.get(daysAhead);

    let providerMatches: CachedMatch[];

    if (cached && now - cached.ts <= CACHE_TTL_MS) {
      providerMatches = cached.data;
    } else {
      const { dateFrom, dateTo } = getMatchWindow(daysAhead);

      // Primary provider: enabled competitions (excludes friendlies / AF_ codes)
      let primaryMatches: ProviderMatchWithCompetition[] = [];
      try {
        const competitions = await prisma.competition.findMany({
          where: { enabled: true },
          select: { code: true },
        });
        const fdCodes = competitions
          .map((c) => c.code)
          .filter((code) => !code.startsWith('AF_') && code !== 'FRIENDLIES');

        if (fdCodes.length > 0) {
          primaryMatches = await footballProvider.getMatchesByDateRange(dateFrom, dateTo, fdCodes);
        }
      } catch (err) {
        console.warn('[UpcomingMatches] Primary provider failed:', err);
      }

      // Secondary provider: TheSportsDB (international friendlies)
      let secondaryMatches: ProviderMatchWithCompetition[] = [];
      try {
        secondaryMatches = await secondaryProvider.getMatchesByDateRange(dateFrom, dateTo);
      } catch (err) {
        console.warn('[UpcomingMatches] Secondary provider failed:', err);
      }

      // Merge, deduplicate by externalId, sort by kickoff
      const seen = new Set<number>();
      const all: CachedMatch[] = [];
      for (const m of [...primaryMatches, ...secondaryMatches]) {
        if (!m.homeTeam?.id || !m.awayTeam?.id) continue;
        if (seen.has(m.id)) continue;
        seen.add(m.id);
        all.push(toCachedMatch(m));
      }
      all.sort((a, b) => new Date(a.kickoffTime).getTime() - new Date(b.kickoffTime).getTime());

      matchCache.set(daysAhead, { data: all, ts: now });
      console.log(`[UpcomingMatches] Cache refreshed for daysAhead=${daysAhead}: ${all.length} matches`);
      providerMatches = all;
    }

    // Apply competition filter before user query to reduce lookup set
    const filtered = competitionCode
      ? providerMatches.filter((m) => m.competitionCode === competitionCode)
      : providerMatches;

    // One DB query: find which of these matches the user has already predicted
    const externalIds = filtered.map((m) => m.externalId);
    const predictedRows = externalIds.length > 0
      ? await prisma.prediction.findMany({
          where: {
            userId: user.userId,
            match: { externalId: { in: externalIds } },
          },
          select: { match: { select: { externalId: true } } },
        })
      : [];
    const predictedSet = new Set(predictedRows.map((r) => r.match.externalId));

    const matches: UpcomingMatch[] = filtered.map((m) => ({
      ...m,
      hasPrediction: predictedSet.has(m.externalId),
    }));

    return NextResponse.json({ matches });
  } catch (error) {
    return handleError(error);
  }
});
```

- [ ] **Step 2: Verify the backend builds without TypeScript errors**

```bash
cd E:/source/personal/futfun/futfun-backend
npx tsc --noEmit
```
Expected: no errors. If errors, fix before continuing.

- [ ] **Step 3: Start backend locally and smoke-test the new param**

```bash
cd E:/source/personal/futfun/futfun-backend
npm run dev
```

In a second terminal (replace TOKEN with a valid JWT):
```bash
curl -s "http://localhost:4000/api/upcoming-matches?daysAhead=7" \
  -H "Authorization: Bearer TOKEN" | jq '.matches[0] | {id, kickoffTime, hasPrediction}'
```
Expected: object with `hasPrediction: false` or `true` depending on user's predictions.

```bash
curl -s "http://localhost:4000/api/upcoming-matches?daysAhead=14" \
  -H "Authorization: Bearer TOKEN" | jq '.matches | length'
```
Expected: equal or greater count than daysAhead=7.

- [ ] **Step 4: Commit**

```bash
cd E:/source/personal/futfun/futfun-backend
git add app/api/upcoming-matches/route.ts
git commit -m "feat(api): expand match window to daysAhead param + hasPrediction flag per user"
```

---

## Task 2: Frontend — add `hasPrediction` to `MatchModel`

**Files:**
- Modify: `futfun-frontend/lib/features/matches/data/models/match_model.dart`

- [ ] **Step 1: Add `hasPrediction` field to `MatchModel`**

Replace the entire file content:

```dart
class MatchModel {
  final String id; // externalId.toString() for upcoming-matches; DB UUID for predictions screen
  final int externalId;
  final String competitionCode;
  final String competitionName;
  final int homeTeamId;
  final String homeTeamName;
  final String? homeTeamShort;
  final String? homeTeamCrest;
  final String? homeTeamType;
  final int awayTeamId;
  final String awayTeamName;
  final String? awayTeamShort;
  final String? awayTeamCrest;
  final String? awayTeamType;
  final DateTime kickoffTime;
  final String status; // SCHEDULED, LIVE, FINISHED
  final int? scoreHome;
  final int? scoreAway;
  final String stage;
  final String? groupName;
  final int? matchday;
  final bool hasPrediction;

  const MatchModel({
    required this.id,
    required this.externalId,
    required this.competitionCode,
    required this.competitionName,
    required this.homeTeamId,
    required this.homeTeamName,
    this.homeTeamShort,
    this.homeTeamCrest,
    this.homeTeamType,
    required this.awayTeamId,
    required this.awayTeamName,
    this.awayTeamShort,
    this.awayTeamCrest,
    this.awayTeamType,
    required this.kickoffTime,
    required this.status,
    this.scoreHome,
    this.scoreAway,
    required this.stage,
    this.groupName,
    this.matchday,
    this.hasPrediction = false,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final extId = json['externalId'] as int? ?? 0;
    return MatchModel(
      id: json['id'] as String,
      externalId: extId,
      competitionCode: json['competitionCode'] as String? ?? '',
      competitionName: json['competitionName'] as String? ?? '',
      homeTeamId: json['homeTeamId'] as int? ?? 0,
      homeTeamName: json['homeTeamName'] as String,
      homeTeamShort: json['homeTeamShort'] as String?,
      homeTeamCrest: json['homeTeamCrest'] as String?,
      homeTeamType: json['homeTeamType'] as String?,
      awayTeamId: json['awayTeamId'] as int? ?? 0,
      awayTeamName: json['awayTeamName'] as String,
      awayTeamShort: json['awayTeamShort'] as String?,
      awayTeamCrest: json['awayTeamCrest'] as String?,
      awayTeamType: json['awayTeamType'] as String?,
      kickoffTime: DateTime.parse(json['kickoffTime'] as String),
      status: json['status'] as String,
      scoreHome: json['scoreHome'] as int?,
      scoreAway: json['scoreAway'] as int?,
      stage: json['stage'] as String,
      groupName: json['groupName'] as String?,
      matchday: json['matchday'] as int?,
      hasPrediction: json['hasPrediction'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 2: Verify Flutter analyzes cleanly**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/features/matches/data/models/match_model.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd E:/source/personal/futfun/futfun-frontend
git add lib/features/matches/data/models/match_model.dart
git commit -m "feat(model): add hasPrediction field to MatchModel"
```

---

## Task 3: Frontend — add `daysAhead` param to `MatchesRepository`

**Files:**
- Modify: `futfun-frontend/lib/features/matches/data/repositories/matches_repository.dart`

- [ ] **Step 1: Add `daysAhead` param to `getUpcomingMatches`**

Replace only the `getUpcomingMatches` method (keep `getMatches` and `getMatch` unchanged):

```dart
  /// Fetches upcoming matches directly from providers (no DB dependency).
  /// The backend caches provider data for 5 minutes per daysAhead value.
  /// [daysAhead] controls the date window: 7 (default), 14, 21, or 999 (all).
  Future<List<MatchModel>> getUpcomingMatches({
    String? competitionCode,
    int daysAhead = 7,
  }) async {
    final queryParams = <String, dynamic>{'daysAhead': daysAhead};
    if (competitionCode != null) queryParams['competitionCode'] = competitionCode;

    final response = await _dio.get(
      '/api/upcoming-matches',
      queryParameters: queryParams,
    );
    final list = response.data['matches'] as List<dynamic>;
    return list.map((e) => MatchModel.fromJson(e as Map<String, dynamic>)).toList();
  }
```

- [ ] **Step 2: Verify**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/features/matches/data/repositories/matches_repository.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd E:/source/personal/futfun/futfun-frontend
git add lib/features/matches/data/repositories/matches_repository.dart
git commit -m "feat(repo): add daysAhead param to getUpcomingMatches"
```

---

## Task 4: Frontend — refactor `MatchesViewModel` and `MatchesState`

**Files:**
- Modify: `futfun-frontend/lib/features/matches/viewmodels/matches_viewmodel.dart`

Key changes:
- Remove `predictions` map from `MatchesState` — `hasPrediction` comes from backend now
- Add `currentDaysAhead: int` to `MatchesState`
- `_fetchMatches` no longer calls `_predictionsRepo` (single API call)
- `_fetchMatches` filters matches: hide where `hasPrediction == true` or `kickoffTime < now`
- `loadMore()` advances `daysAhead` through 7 → 14 → 21 → 999; sets `hasReachedEnd` after 999 or when count doesn't grow
- `submitPrediction` removes the match from the list on success (instead of updating predictions map)

- [ ] **Step 1: Replace `futfun-frontend/lib/features/matches/viewmodels/matches_viewmodel.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/match_model.dart';
import '../data/repositories/matches_repository.dart';
import '../data/repositories/predictions_repository.dart';

class MatchesState {
  final List<MatchModel> matches;
  final String? submittingMatchId;
  final bool isLoadingMore;
  final bool hasReachedEnd;
  final int currentDaysAhead;

  const MatchesState({
    required this.matches,
    this.submittingMatchId,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.currentDaysAhead = 7,
  });

  MatchesState copyWith({
    List<MatchModel>? matches,
    String? submittingMatchId,
    bool clearSubmitting = false,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    int? currentDaysAhead,
  }) {
    return MatchesState(
      matches: matches ?? this.matches,
      submittingMatchId:
          clearSubmitting ? null : (submittingMatchId ?? this.submittingMatchId),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      currentDaysAhead: currentDaysAhead ?? this.currentDaysAhead,
    );
  }
}

class MatchesViewModel extends FamilyAsyncNotifier<MatchesState, String> {
  final _matchesRepo = MatchesRepository();
  final _predictionsRepo = PredictionsRepository();

  @override
  // ignore: avoid_renaming_method_parameters
  Future<MatchesState> build(String competitionCode) async {
    return _fetchMatches(competitionCode, daysAhead: 7);
  }

  Future<MatchesState> _fetchMatches(
    String competitionCode, {
    required int daysAhead,
  }) async {
    final matches = await _matchesRepo.getUpcomingMatches(
      competitionCode: competitionCode.isEmpty ? null : competitionCode,
      daysAhead: daysAhead,
    );

    final now = DateTime.now();
    final visible = matches
        .where((m) => !m.hasPrediction && m.kickoffTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.kickoffTime.compareTo(b.kickoffTime));

    return MatchesState(matches: visible, currentDaysAhead: daysAhead);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || current.hasReachedEnd) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final nextDays = switch (current.currentDaysAhead) {
      7 => 14,
      14 => 21,
      _ => 999,
    };

    try {
      final newState = await _fetchMatches(arg, daysAhead: nextDays);
      final hasReachedEnd =
          nextDays == 999 || newState.matches.length <= current.matches.length;
      state = AsyncValue.data(newState.copyWith(
        isLoadingMore: false,
        hasReachedEnd: hasReachedEnd,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Submits a prediction for [matchId] (= externalId.toString()).
  /// On success the match is removed from the list — it now belongs to predictions screen.
  Future<void> submitPrediction(String matchId, int home, int away) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(current.copyWith(submittingMatchId: matchId));

    try {
      final match = current.matches.firstWhere((m) => m.id == matchId);
      await _predictionsRepo.submitPrediction(
        match: match,
        home: home,
        away: away,
      );

      final updatedMatches =
          current.matches.where((m) => m.id != matchId).toList();
      state = AsyncValue.data(
        current.copyWith(matches: updatedMatches, clearSubmitting: true),
      );
    } catch (e, st) {
      state = AsyncValue.data(current.copyWith(clearSubmitting: true));
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final matchesViewModelProvider =
    AsyncNotifierProvider.family<MatchesViewModel, MatchesState, String>(
  MatchesViewModel.new,
);
```

- [ ] **Step 2: Verify**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/features/matches/viewmodels/matches_viewmodel.dart
```
Expected: no errors. If it reports `PredictionsRepository` unused — check import; it's still needed for `submitPrediction`.

- [ ] **Step 3: Commit**

```bash
cd E:/source/personal/futfun/futfun-frontend
git add lib/features/matches/viewmodels/matches_viewmodel.dart
git commit -m "feat(vm): refactor MatchesState — daysAhead load-more, hasPrediction filter, remove predictions map"
```

---

## Task 5: Frontend — simplify `MatchCard` (remove prediction display)

**Files:**
- Modify: `futfun-frontend/lib/features/matches/views/widgets/match_card.dart`

With the new flow, a match card is only shown when `hasPrediction == false` and `kickoffTime > now`. Cards never show a previous prediction inline. Only two states remain:
- `canBet` (within d+1): show `PredictionInput`
- `!canBet` (beyond d+1): show locked badge "Abre em X dias"

Remove `_PredictionResult`, `_NoPredictionLabel`. Update `_BettingOpensLabel` to an amber badge matching the approved design. Remove `prediction` parameter from `MatchCard`.

- [ ] **Step 1: Replace `futfun-frontend/lib/features/matches/views/widgets/match_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/team_crest.dart';
import '../../data/models/match_model.dart';
import '../../viewmodels/matches_viewmodel.dart';
import 'prediction_input.dart';

/// Betting opens when kickoff is ≤ 1 day away and hasn't started.
const int _bettingWindowDays = 1;

class MatchCard extends ConsumerWidget {
  final MatchModel match;
  final String competitionCode;

  const MatchCard({
    super.key,
    required this.match,
    required this.competitionCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vmState = ref.watch(matchesViewModelProvider(competitionCode));
    final isSubmitting = vmState.valueOrNull?.submittingMatchId == match.id;

    final now = DateTime.now();
    final daysUntilKickoff = match.kickoffTime.difference(now).inDays;
    final canBet = match.kickoffTime.isAfter(now) && daysUntilKickoff <= _bettingWindowDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date/time + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM HH:mm').format(match.kickoffTime.toLocal()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!canBet) _LockedBadge(daysUntilKickoff: daysUntilKickoff),
              ],
            ),
            const SizedBox(height: 10),
            // Teams row
            Row(
              children: [
                Expanded(
                  child: _TeamDisplay(
                    name: match.homeTeamShort ?? match.homeTeamName,
                    crestUrl: match.homeTeamCrest,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'vs',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: _TeamDisplay(
                    name: match.awayTeamShort ?? match.awayTeamName,
                    crestUrl: match.awayTeamCrest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Prediction area
            if (canBet)
              PredictionInput(
                matchId: match.id,
                kickoffTime: match.kickoffTime,
                isSubmitting: isSubmitting,
                onSubmit: (home, away) {
                  ref
                      .read(matchesViewModelProvider(competitionCode).notifier)
                      .submitPrediction(match.id, home, away);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Amber badge shown when the match is in the window but betting is not yet open.
class _LockedBadge extends StatelessWidget {
  final int daysUntilKickoff;
  const _LockedBadge({required this.daysUntilKickoff});

  @override
  Widget build(BuildContext context) {
    final label = 'Abre em $daysUntilKickoff dias';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, size: 12, color: Colors.amber.shade800),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamDisplay extends StatelessWidget {
  final String name;
  final String? crestUrl;

  const _TeamDisplay({required this.name, this.crestUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamCrest(url: crestUrl, size: 30),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/features/matches/views/widgets/match_card.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd E:/source/personal/futfun/futfun-frontend
git add lib/features/matches/views/widgets/match_card.dart
git commit -m "feat(ui): simplify MatchCard — remove prediction display, add locked badge"
```

---

## Task 6: Frontend — update `MatchesScreen` to remove `prediction` arg

**Files:**
- Modify: `futfun-frontend/lib/features/matches/views/matches_screen.dart`

`MatchCard` no longer accepts a `prediction` parameter. Remove it from the call site in `_MatchGroupWidget`.

- [ ] **Step 1: Remove `prediction` arg from `MatchCard` in `_MatchGroupWidget.build`**

Find this block in `_MatchGroupWidget.build`:
```dart
        ...group.matchIds.map((id) {
          final match = matchesState.matches.firstWhere((m) => m.id == id);
          return MatchCard(
            match: match,
            competitionCode: competitionCode,
            prediction: matchesState.predictions[id],
          );
        }),
```

Replace with:
```dart
        ...group.matchIds.map((id) {
          final match = matchesState.matches.firstWhere((m) => m.id == id);
          return MatchCard(
            match: match,
            competitionCode: competitionCode,
          );
        }),
```

- [ ] **Step 2: Verify the whole screen compiles**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/features/matches/views/matches_screen.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd E:/source/personal/futfun/futfun-frontend
git add lib/features/matches/views/matches_screen.dart
git commit -m "feat(ui): remove prediction arg from MatchCard call in MatchesScreen"
```

---

## Task 7: Frontend — update `PredictionsScreen` edit button

**Files:**
- Modify: `futfun-frontend/lib/features/predictions/views/predictions_screen.dart`

Two changes to `_PredictionCard.build`:
1. `isEditable` must also check that the betting window is open (`kickoffTime.difference(now).inDays <= 1`). Currently it only checks `kickoffTime.isAfter(now)`.
2. Add a visible "Editar" button in the prediction row when `isEditable`, so users can clearly see they can modify their bet (not just tap the card).

- [ ] **Step 1: Update `isEditable` and add Editar button in `_PredictionCard.build`**

Find this block inside `_PredictionCard.build`:
```dart
    final isFinished = m.status == 'FINISHED';
    final isEditable = m.status == 'SCHEDULED' && m.kickoffTime.isAfter(DateTime.now());
```

Replace with:
```dart
    final now = DateTime.now();
    final isFinished = m.status == 'FINISHED';
    final isEditable = m.status == 'SCHEDULED' &&
        m.kickoffTime.isAfter(now) &&
        m.kickoffTime.difference(now).inDays <= 1;
```

Then find the prediction row (the last `Row` inside the `Column`):
```dart
            // Prediction row
            Row(
              children: [
                const Icon(Icons.sports_soccer, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Palpite: ${prediction.predictedHome} × ${prediction.predictedAway}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (pts != null)
                  Container(
```

Replace the `const Spacer(),` and everything after it up to (but not including) the closing `],` of the Row's children, with:

```dart
                const Spacer(),
                if (isEditable)
                  TextButton.icon(
                    onPressed: () => _showEditDialog(context, ref, prediction),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Editar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else if (pts != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ptsColor?.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ptsColor ?? AppColors.textSecondary),
                    ),
                    child: Text(
                      pts > 0 ? '+$pts pts' : '0 pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ptsColor,
                      ),
                    ),
                  )
                else if (isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Apurando...',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                    ),
                  ),
```

- [ ] **Step 2: Verify**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/features/predictions/views/predictions_screen.dart
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd E:/source/personal/futfun/futfun-frontend
git add lib/features/predictions/views/predictions_screen.dart
git commit -m "feat(ui): add Editar button to PredictionCard, restrict edit to betting window"
```

---

## Task 8: Full analyze + manual smoke test

- [ ] **Step 1: Run full Flutter analyze**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter analyze lib/
```
Expected: no errors. Fix any remaining references to removed `predictions` map or `prediction` param.

- [ ] **Step 2: Build web**

```bash
cd E:/source/personal/futfun/futfun-frontend
flutter build web --no-tree-shake-icons
```
Expected: build succeeds.

- [ ] **Step 3: Manual smoke test checklist**

Start backend (`npm run dev`) and Flutter web (`flutter run -d chrome`), then verify:

- [ ] Matches screen shows games up to ~7 days ahead
- [ ] Games beyond 1 day show amber "Abre em X dias" badge with team flags, no bet inputs
- [ ] Games within 1 day show bet inputs + "Palpitar" button
- [ ] After palpitar: card disappears from matches screen immediately
- [ ] Game appears on predictions screen after palpitar
- [ ] Load more (1st click): more games appear (up to d+14)
- [ ] Load more (2nd click): more games (up to d+21)
- [ ] Load more (3rd click): remaining games; button disappears
- [ ] Predictions screen: "Editar" button visible on editable predictions (within d+1 window)
- [ ] Predictions screen: no "Editar" button on predictions beyond betting window
- [ ] Edit dialog works and updates the prediction

- [ ] **Step 4: Deploy**

```powershell
# Backend
$env:CLOUDSDK_PYTHON="C:\Users\gugag\AppData\Local\Google\Cloud SDK\google-cloud-sdk\platform\bundledpython\python.exe"
cd E:\source\personal\futfun\futfun-backend
gcloud builds submit --project futfun-498118

# Frontend
cd E:\source\personal\futfun\futfun-frontend
flutter build web --no-tree-shake-icons
firebase deploy --only hosting
```
