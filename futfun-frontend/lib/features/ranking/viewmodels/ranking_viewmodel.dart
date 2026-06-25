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

    // All ref.watch calls must be synchronous (before any await).
    // .future awaits the resolved value instead of reading a potentially-null
    // snapshot — fixes the web reload race condition where competitions finish
    // loading after auth but before rankingViewModelProvider reads them.
    final authFuture = ref.watch(authViewModelProvider.future);
    final activeFuture = ref.watch(activeCompetitionNotifierProvider.future);

    final authState = await authFuture;
    if (authState.stage == AuthStage.unauthenticated ||
        authState.stage == AuthStage.pending) {
      return const RankingState(leaderboard: []);
    }

    final active = await activeFuture;
    final code = active.selected?.code;

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
