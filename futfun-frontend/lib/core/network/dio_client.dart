import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/app_storage.dart';
import '../storage/app_logger.dart';

class DioClient {
  // Singleton — all repositories share the same Dio instance and refresh state.
  static DioClient? _instance;
  factory DioClient() => _instance ??= DioClient._internal();

  // Set once from app.dart after the widget tree is ready.
  static Future<void> Function()? _onForceLogout;
  static void setLogoutCallback(Future<void> Function() callback) {
    _onForceLogout = callback;
  }

  static const _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://futfun-backend-dlpljkbcta-rj.a.run.app',
  );

  late final Dio _dio;
  late final Dio _refreshDio; // no interceptors — avoids infinite refresh loops
  final _storage = appStorage;

  // Refresh state shared across all concurrent requests.
  bool _isRefreshing = false;
  final _queue = <({RequestOptions options, ErrorInterceptorHandler handler})>[];

  DioClient._internal() {
    _refreshDio = Dio(BaseOptions(
      baseUrl: _apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio = Dio(BaseOptions(
      baseUrl: _apiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint('[Dio] $obj'),
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        final hasToken = token != null;
        AppLogger.log('→ ${options.method} ${options.path} token=$hasToken');
        if (hasToken) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode ?? 0;
        AppLogger.log('✗ ${error.requestOptions.method} ${error.requestOptions.path} status=$status hasAuth=${error.requestOptions.headers.containsKey("Authorization")}');
        final is401 = error.response?.statusCode == 401;
        if (!is401) return handler.next(error);

        // Avoid looping if the refresh endpoint itself returns 401.
        final isRefreshPath =
            error.requestOptions.path.contains('/api/auth/refresh');
        if (isRefreshPath) {
          await _doForceLogout();
          return handler.next(error);
        }

        // Another refresh is already in flight — queue this request.
        if (_isRefreshing) {
          _queue.add((options: error.requestOptions, handler: handler));
          return;
        }

        _isRefreshing = true;
        try {
          final storedRefresh = await _storage.read(key: 'refresh_token');
          if (storedRefresh == null) {
            await _doForceLogout();
            return handler.next(error);
          }

          final resp = await _refreshDio.post(
            '/api/auth/refresh',
            data: {'refreshToken': storedRefresh},
          );
          final newToken = resp.data['accessToken'] as String;
          await _storage.write(key: 'jwt_token', value: newToken);
          // Keep user_role in sync so app restarts reflect the latest role from DB
          final roleFromToken = _extractRoleFromToken(newToken);
          if (roleFromToken != null) {
            await _storage.write(key: 'user_role', value: roleFromToken.toLowerCase());
          }

          // Flush queued requests with the new token.
          for (final pending in _queue) {
            pending.options.headers['Authorization'] = 'Bearer $newToken';
            try {
              final r = await _dio.fetch(pending.options);
              pending.handler.resolve(r);
            } catch (_) {
              pending.handler
                  .next(DioException(requestOptions: pending.options));
            }
          }
          _queue.clear();

          // Retry the original failing request.
          error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResp = await _dio.fetch(error.requestOptions);
          handler.resolve(retryResp);
        } catch (_) {
          // Refresh failed — reject all queued requests and force logout.
          for (final pending in _queue) {
            pending.handler.next(DioException(requestOptions: pending.options));
          }
          _queue.clear();
          await _doForceLogout();
          handler.next(error);
        } finally {
          _isRefreshing = false;
        }
      },
    ));
  }

  String? _extractRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _doForceLogout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'persistent_login_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'auth_user');
    await _onForceLogout?.call();
  }

  Dio get dio => _dio;
}
