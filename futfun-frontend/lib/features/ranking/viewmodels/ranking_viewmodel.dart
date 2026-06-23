import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ranking_entry.dart';
import '../data/repositories/ranking_repository.dart';
import '../../../core/providers/active_competition_provider.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

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

    // ref.watch MUST be called synchronously before any await — Riverpod
    // throws StateError if called after an await in AsyncNotifier.build().
    final asyncActive = ref.watch(activeCompetitionNotifierProvider);

    // Wait for auth before making API calls — prevents 401 on web reload
    // when the JWT hasn't been restored from flutter_secure_storage yet.
    final authState = await ref.watch(authViewModelProvider.future);
    if (authState.stage == AuthStage.unauthenticated ||
        authState.stage == AuthStage.pending) {
      return const RankingState(leaderboard: []);
    }

    final code = asyncActive.valueOrNull?.selected?.code;

    if (code == null) return const RankingState(leaderboard: []);

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
    ref.invalidateSelf();
  }
}

final rankingViewModelProvider =
    AsyncNotifierProvider<RankingViewModel, RankingState>(RankingViewModel.new);
