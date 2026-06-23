import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ranking_history_entry.dart';
import '../data/repositories/dashboard_repository.dart';
import '../../ranking/data/models/ranking_entry.dart';
import '../../ranking/data/repositories/ranking_repository.dart';
import '../../../core/providers/active_competition_provider.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

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

    // ref.watch MUST be called synchronously before any await.
    final asyncActive = ref.watch(activeCompetitionNotifierProvider);

    // Wait for auth before making API calls.
    final authState = await ref.watch(authViewModelProvider.future);
    if (authState.stage == AuthStage.unauthenticated ||
        authState.stage == AuthStage.pending) {
      return const DashboardState(history: []);
    }

    final code = asyncActive.valueOrNull?.selected?.code;

    if (code == null) return const DashboardState(history: []);

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
    ref.invalidateSelf();
  }
}

final dashboardViewModelProvider =
    AsyncNotifierProvider<DashboardViewModel, DashboardState>(DashboardViewModel.new);
