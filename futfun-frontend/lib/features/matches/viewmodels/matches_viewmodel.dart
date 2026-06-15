import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/match_model.dart';
import '../data/repositories/matches_repository.dart';
import '../data/repositories/predictions_repository.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

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
    final authState = await ref.watch(authViewModelProvider.future);
    if (authState.stage == AuthStage.unauthenticated ||
        authState.stage == AuthStage.pending) {
      return const MatchesState(matches: []);
    }
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
      final moreMatches = await _matchesRepo.getUpcomingMatches(
        competitionCode: arg.isEmpty ? null : arg,
        daysAhead: nextDays,
      );

      final now = DateTime.now();
      final existingIds = current.matches.map((m) => m.id).toSet();
      final additional = moreMatches
          .where((m) =>
              !m.hasPrediction &&
              m.kickoffTime.isAfter(now) &&
              !existingIds.contains(m.id))
          .toList()
        ..sort((a, b) => a.kickoffTime.compareTo(b.kickoffTime));

      final merged = [...current.matches, ...additional];
      final hasReachedEnd = nextDays == 999 || additional.isEmpty;

      state = AsyncValue.data(current.copyWith(
        matches: merged,
        isLoadingMore: false,
        hasReachedEnd: hasReachedEnd,
        currentDaysAhead: nextDays,
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
