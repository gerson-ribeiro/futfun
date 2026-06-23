// lib/core/providers/active_competition_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/competitions/data/models/competition_model.dart';
import '../storage/app_storage.dart';
import '../storage/app_logger.dart';
import '../../features/competitions/data/repositories/competition_repository.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';

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
  final _storage = appStorage;

  @override
  Future<ActiveCompetitionState> build() async {
    // Wait for auth before calling /api/competitions — prevents 401 on
    // deep-link login where the token arrives slightly after the shell builds.
    final authState = await ref.watch(authViewModelProvider.future);
    if (authState.stage == AuthStage.unauthenticated ||
        authState.stage == AuthStage.pending) {
      AppLogger.log('[Competition] Skipping load — not authenticated yet');
      return const ActiveCompetitionState(available: []);
    }

    AppLogger.log('[Competition] Loading competitions (stage=${authState.stage.name})');
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
