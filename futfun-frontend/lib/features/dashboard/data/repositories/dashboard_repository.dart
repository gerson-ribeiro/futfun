import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/ranking_history_entry.dart';

class DashboardRepository {
  final Dio _dio;

  DashboardRepository() : _dio = DioClient().dio;

  Future<List<RankingHistoryEntry>> getRankingHistory(String competitionCode) async {
    final response = await _dio.get(
      '/api/rankings/history',
      queryParameters: {'competitionCode': competitionCode},
    );
    final list = response.data['history'] as List<dynamic>;
    return list
        .map((e) => RankingHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
