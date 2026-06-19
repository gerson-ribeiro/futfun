import 'package:dio/dio.dart';

class NotificationRepository {
  final Dio _dio;

  NotificationRepository(this._dio);

  Future<void> registerToken(String token, String platform) async {
    await _dio.post('/api/device-tokens', data: {'token': token, 'platform': platform});
  }

  Future<void> unregisterToken(String token) async {
    await _dio.delete('/api/device-tokens', data: {'token': token});
  }
}
