import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/ranking_entry.dart';

class RankingRepository {
  final Dio _dio;

  RankingRepository() : _dio = DioClient().dio;

  Future<List<RankingEntry>> getLeaderboard(String competitionCode) async {
    final response = await _dio.get('/api/rankings', queryParameters: {'competitionCode': competitionCode});
    final list = response.data['rankings'] as List<dynamic>;
    return list.map((e) => RankingEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RankingEntry?> getMyRanking(String competitionCode) async {
    final response = await _dio.get('/api/rankings/me', queryParameters: {'competitionCode': competitionCode});
    final data = response.data['ranking'];
    if (data == null) return null;
    return RankingEntry.fromJson(data as Map<String, dynamic>);
  }
}
