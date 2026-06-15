// lib/features/auth/data/auth_repository.dart

import 'package:dio/dio.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<String> getLoginUrl(String provider, {String state = ''}) async {
    final response = await _dio.get(
      '/api/auth/$provider/login',
      queryParameters: state.isNotEmpty ? {'state': state} : null,
    );
    return response.data['authUrl'] as String;
  }

  Future<Map<String, dynamic>> handleCallback(
    String provider,
    String code, {
    String state = '',
  }) async {
    final response = await _dio.get(
      '/api/auth/callback',
      queryParameters: {
        'provider': provider,
        'code': code,
        if (state.isNotEmpty) 'state': state,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<String> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return response.data['accessToken'] as String;
  }

  Future<Map<String, dynamic>> validateInvite(String token) async {
    final response = await _dio.get('/api/invites/$token');
    return response.data as Map<String, dynamic>;
  }
}
