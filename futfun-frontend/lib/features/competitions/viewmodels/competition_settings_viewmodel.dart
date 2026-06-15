// lib/features/competitions/viewmodels/competition_settings_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/competition_model.dart';
import '../data/repositories/competition_repository.dart';

class CompetitionSettingsViewModel
    extends AsyncNotifier<List<CompetitionModel>> {
  final _repository = CompetitionRepository();

  @override
  Future<List<CompetitionModel>> build() async {
    return _repository.getCompetitions();
  }

  Future<void> toggleHidden(String code) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final comp = current.firstWhere((c) => c.code == code);
    final newHidden = !comp.hidden;
    // optimistic update
    state = AsyncValue.data(
      current
          .map((c) => c.code == code ? c.copyWith(hidden: newHidden) : c)
          .toList(),
    );
    try {
      await _repository.toggleUserPreference(code, newHidden);
    } catch (e, st) {
      state = AsyncValue.data(current); // revert
      state = AsyncError(e, st);
    }
  }
}

final competitionSettingsViewModelProvider =
    AsyncNotifierProvider<CompetitionSettingsViewModel, List<CompetitionModel>>(
  CompetitionSettingsViewModel.new,
);
