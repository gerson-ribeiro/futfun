// lib/features/competitions/viewmodels/admin_competitions_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/competition_model.dart';
import '../data/repositories/competition_repository.dart';

class AdminCompetitionsViewModel
    extends AsyncNotifier<List<CompetitionModel>> {
  late CompetitionRepository _repository;

  @override
  Future<List<CompetitionModel>> build() async {
    _repository = CompetitionRepository();
    return _repository.getAdminCompetitions();
  }

  Future<void> addCompetition(String code, String name) async {
    await _repository.addCompetition(code, name);
    ref.invalidateSelf();
  }

  Future<void> toggleGlobal(String code) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final comp = current.firstWhere((c) => c.code == code);
    final newEnabled = !comp.enabled;
    state = AsyncValue.data(
      current
          .map((c) => c.code == code ? c.copyWith(enabled: newEnabled) : c)
          .toList(),
    );
    try {
      await _repository.toggleGlobal(code, newEnabled);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncError(e, st);
    }
  }
}

final adminCompetitionsViewModelProvider =
    AsyncNotifierProvider<AdminCompetitionsViewModel, List<CompetitionModel>>(
  AdminCompetitionsViewModel.new,
);
