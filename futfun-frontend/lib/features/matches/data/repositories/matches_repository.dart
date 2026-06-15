import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/match_model.dart';

class MatchesRepository {
  final Dio _dio;

  MatchesRepository() : _dio = DioClient().dio;

  /// Fetches upcoming matches directly from providers (no DB dependency).
  /// The backend caches provider data for 5 minutes per daysAhead value.
  /// [daysAhead] controls the date window: 7 (default), 14, 21, or 999 (all).
  Future<List<MatchModel>> getUpcomingMatches({
    String? competitionCode,
    int daysAhead = 7,
  }) async {
    final queryParams = <String, dynamic>{'daysAhead': daysAhead};
    if (competitionCode != null) queryParams['competitionCode'] = competitionCode;

    final response = await _dio.get(
      '/api/upcoming-matches',
      queryParameters: queryParams,
    );
    final list = response.data['matches'] as List<dynamic>;
    return list.map((e) => MatchModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Legacy: fetches matches already stored in the DB.
  /// Still used by admin/debug views; not used for the main bet screen.
  Future<List<MatchModel>> getMatches({
    String? competitionCode,
    String? status,
    String? stage,
    int? matchday,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool nationalTeamsOnly = false,
  }) async {
    final queryParams = <String, dynamic>{};
    if (competitionCode != null) queryParams['competitionCode'] = competitionCode;
    if (status != null) queryParams['status'] = status;
    if (stage != null) queryParams['stage'] = stage;
    if (matchday != null) queryParams['matchday'] = matchday;
    if (dateFrom != null) queryParams['dateFrom'] = dateFrom.toUtc().toIso8601String();
    if (dateTo != null) queryParams['dateTo'] = dateTo.toUtc().toIso8601String();
    if (nationalTeamsOnly) queryParams['nationalTeamsOnly'] = 'true';

    final response = await _dio.get(
      '/api/matches',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final list = response.data['matches'] as List<dynamic>;
    return list.map((e) => MatchModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MatchModel> getMatch(String matchId) async {
    final response = await _dio.get('/api/matches/$matchId');
    return MatchModel.fromJson(response.data['match'] as Map<String, dynamic>);
  }
}
