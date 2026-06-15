import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/match_model.dart';
import '../models/prediction_entry.dart';

class PredictionsRepository {
  final Dio _dio;

  PredictionsRepository() : _dio = DioClient().dio;

  Future<List<PredictionEntry>> getUserPredictions() async {
    final response = await _dio.get('/api/predictions');
    final list = response.data['predictions'] as List<dynamic>;
    return list.map((e) => PredictionEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates or updates a prediction.
  /// Sends full match data so the backend can upsert the match on first prediction.
  Future<PredictionEntry> submitPrediction({
    required MatchModel match,
    required int home,
    required int away,
  }) async {
    final response = await _dio.post(
      '/api/predictions',
      data: {
        'match': {
          'externalId': match.externalId,
          'competitionCode': match.competitionCode,
          'competitionName': match.competitionName,
          'homeTeamId': match.homeTeamId,
          'homeTeamName': match.homeTeamName,
          'homeTeamShort': match.homeTeamShort,
          'homeTeamCrest': match.homeTeamCrest,
          'homeTeamType': match.homeTeamType,
          'awayTeamId': match.awayTeamId,
          'awayTeamName': match.awayTeamName,
          'awayTeamShort': match.awayTeamShort,
          'awayTeamCrest': match.awayTeamCrest,
          'awayTeamType': match.awayTeamType,
          'kickoffTime': match.kickoffTime.toUtc().toIso8601String(),
          'stage': match.stage,
          'groupName': match.groupName,
          'matchday': match.matchday,
        },
        'predictedHome': home,
        'predictedAway': away,
      },
    );
    return PredictionEntry.fromJson(response.data['prediction'] as Map<String, dynamic>);
  }

  /// Updates a prediction by DB match UUID.
  /// Used by the My Predictions screen.
  Future<PredictionEntry> updatePrediction(String matchId, int home, int away) async {
    final response = await _dio.put(
      '/api/predictions/$matchId',
      data: {'predictedHome': home, 'predictedAway': away},
    );
    return PredictionEntry.fromJson(response.data['prediction'] as Map<String, dynamic>);
  }
}
