import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/match_prediction_item.dart';
import '../data/repositories/matches_repository.dart';

class MatchPredictionsViewModel
    extends FamilyAsyncNotifier<List<MatchPredictionItem>, int> {
  final _repo = MatchesRepository();

  @override
  Future<List<MatchPredictionItem>> build(int matchExternalId) async {
    return _repo.getMatchPredictions(matchExternalId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final matchPredictionsProvider = AsyncNotifierProvider.family<
    MatchPredictionsViewModel, List<MatchPredictionItem>, int>(
  MatchPredictionsViewModel.new,
);
