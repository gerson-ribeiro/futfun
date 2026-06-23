// lib/core/providers/active_competition_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/competitions/data/models/competition_model.dart';
import '../storage/app_storage.dart';
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
  final _storage = appStorage;

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
