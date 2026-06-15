import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/active_competition_provider.dart';
import '../data/models/prediction_with_match.dart';
import '../data/repositories/predictions_list_repository.dart';

class PredictionsViewModel extends AsyncNotifier<List<PredictionWithMatch>> {
  final _repository = PredictionsListRepository();

  @override
  Future<List<PredictionWithMatch>> build() async {
    final competitionState = await ref.watch(activeCompetitionNotifierProvider.future);
    final competitionCode = competitionState.selected?.code;
    return _repository.getUserPredictions(competitionCode: competitionCode);
  }

  Future<void> updatePrediction(String matchId, int home, int away) async {
    await _repository.updatePrediction(matchId, home, away);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final predictionsViewModelProvider =
    AsyncNotifierProvider<PredictionsViewModel, List<PredictionWithMatch>>(
  PredictionsViewModel.new,
);
