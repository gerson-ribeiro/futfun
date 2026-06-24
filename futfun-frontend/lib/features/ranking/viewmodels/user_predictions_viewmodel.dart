import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_prediction_item.dart';
import '../data/repositories/ranking_repository.dart';

typedef UserPredictionsArg = ({String userId, String competitionCode});
typedef UserPredictionsState = ({String displayName, List<UserPredictionItem> predictions});

class UserPredictionsViewModel
    extends FamilyAsyncNotifier<UserPredictionsState, UserPredictionsArg> {
  final _repo = RankingRepository();

  @override
  Future<UserPredictionsState> build(UserPredictionsArg arg) async {
    return _repo.getUserPredictions(arg.userId, arg.competitionCode);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final userPredictionsProvider = AsyncNotifierProvider.family<
    UserPredictionsViewModel, UserPredictionsState, UserPredictionsArg>(
  UserPredictionsViewModel.new,
);
