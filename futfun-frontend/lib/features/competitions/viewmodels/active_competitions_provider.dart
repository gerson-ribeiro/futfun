// lib/features/competitions/viewmodels/active_competitions_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/competition_model.dart';
import '../data/repositories/competition_repository.dart';

final activeCompetitionsProvider =
    FutureProvider<List<CompetitionModel>>((ref) async {
  final repo = CompetitionRepository();
  final all = await repo.getCompetitions();
  return all.where((c) => c.enabled && !c.hidden).toList();
});
