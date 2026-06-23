// lib/features/competitions/data/repositories/competition_repository.dart

import 'package:dio/dio.dart';
import '../models/competition_model.dart';
import '../../../../core/network/dio_client.dart';

class CompetitionRepository {
  final Dio _dio;

  CompetitionRepository() : _dio = DioClient().dio;

  Future<List<CompetitionModel>> getCompetitions() async {
    final response = await _dio.get('/api/competitions');
    final list = response.data['competitions'] as List<dynamic>;
    return list
        .map((e) => CompetitionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleUserPreference(String code, bool hidden) async {
    await _dio.patch(
      '/api/user/competition-preferences/$code',
      data: {'hidden': hidden},
    );
  }

  Future<List<CompetitionModel>> getAdminCompetitions() async {
    final response = await _dio.get('/api/admin/competitions');
    final list = response.data['competitions'] as List<dynamic>;
    return list
        .map((e) => CompetitionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompetitionModel> addCompetition(String code, String name) async {
    final response = await _dio.post(
      '/api/admin/competitions',
      data: {'code': code, 'name': name},
    );
    return CompetitionModel.fromJson(
        response.data['competition'] as Map<String, dynamic>);
  }

  Future<CompetitionModel> toggleGlobal(String code, bool enabled) async {
    final response = await _dio.patch(
      '/api/admin/competitions/$code',
      data: {'enabled': enabled},
    );
    return CompetitionModel.fromJson(
        response.data['competition'] as Map<String, dynamic>);
  }

  Future<void> resetRanking(String code) async {
    await _dio.post('/api/admin/competitions/$code/reset-ranking');
  }
}
