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

    // Synchronous watch — Riverpod re-runs build() whenever the competition
    // state changes (selection, loading, etc).  Using the raw provider (not
    // .future or .select) avoids the new-object-per-build issue with selectors.
    final asyncActive = ref.watch(activeCompetitionNotifierProvider);
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
