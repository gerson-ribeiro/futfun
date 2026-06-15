import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/prediction_with_match.dart';

class PredictionsListRepository {
  final Dio _dio;

  PredictionsListRepository() : _dio = DioClient().dio;

  Future<List<PredictionWithMatch>> getUserPredictions({String? competitionCode}) async {
    final response = await _dio.get(
      '/api/predictions',
      queryParameters: competitionCode != null ? {'competitionCode': competitionCode} : null,
    );
    final list = response.data['predictions'] as List<dynamic>;
    return list
        .map((e) => PredictionWithMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updatePrediction(String matchId, int home, int away) async {
    await _dio.put(
      '/api/predictions/$matchId',
      data: {'predictedHome': home, 'predictedAway': away},
    );
  }
}
