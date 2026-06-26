// lib/features/auth/viewmodels/auth_viewmodel.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/storage/app_logger.dart';
import '../../../core/storage/app_storage.dart';

enum AuthStage { unauthenticated, pending, member, admin }

class AuthState {
  final AuthStage stage;
  final AuthUser? user;
  final String? error;

  const AuthState({required this.stage, this.user, this.error});

  AuthState copyWith({AuthStage? stage, AuthUser? user, String? error}) {
    return AuthState(
      stage: stage ?? this.stage,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthViewModel extends AsyncNotifier<AuthState> {
  final _storage = appStorage;
  late final AuthRepository _repository;

  @override
  Future<AuthState> build() async {
    _repository = AuthRepository(DioClient().dio);
    final token = await _storage.read(key: 'jwt_token');
    AppLogger.log('✓ [Auth] Iniciando — token=${token != null ? "encontrado" : "ausente"}');
    if (token != null) {
      return _fetchCurrentRole();
    }

    final persistentToken = await _storage.read(key: 'persistent_login_token');
    if (persistentToken != null) {
      AppLogger.log('✓ [Auth] Persistent token encontrado, tentando login automático...');
      try {
        final newToken = await _repository.refreshToken(persistentToken);
        final roleStr = _roleFromJwt(newToken);
        final role = parseUserRole(roleStr);
        await _storage.write(key: 'jwt_token', value: newToken);
        await _storage.write(key: 'refresh_token', value: persistentToken);
        await _storage.write(key: 'user_role', value: role.name);

        AuthUser? user;
        final userStr = await _storage.read(key: 'auth_user');
        if (userStr != null) {
          try {
            user = AuthUser.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
          } catch (_) {}
        }

        AppLogger.log('✓ [Auth] Relogado automaticamente com sucesso!');
        return AuthState(stage: _stageFromRole(role), user: user);
      } catch (e) {
        AppLogger.log('✗ [Auth] Falha no login automático: $e');
        final isAuthRejection = e is DioException &&
            e.type == DioExceptionType.badResponse &&
            (e.response?.statusCode == 401 || e.response?.statusCode == 403);
        if (isAuthRejection) {
          await _storage.delete(key: 'persistent_login_token');
          await _storage.delete(key: 'auth_user');
        }
      }
    }

    return const AuthState(stage: AuthStage.unauthenticated);
  }

  /// Exchanges the stored refresh token for a fresh access token and returns
  /// an AuthState reflecting the role currently recorded in the database.
  /// Only forces logout on explicit HTTP 401/403 — all other errors (5xx,
  /// network timeouts, unknown) fall back to the cached role so the user
  /// stays logged in when the server is temporarily unavailable.
  Future<AuthState> _fetchCurrentRole() async {
    try {
      AppLogger.log('✓ [Auth] Tentando refresh...');
      final storedRefresh = await _storage.read(key: 'refresh_token');
      if (storedRefresh == null) {
        AppLogger.log('✗ [Auth] Refresh token ausente → logout');
        return const AuthState(stage: AuthStage.unauthenticated);
      }
      final newToken = await _repository.refreshToken(storedRefresh);
      final roleStr = _roleFromJwt(newToken);
      final role = parseUserRole(roleStr);
      await _storage.write(key: 'jwt_token', value: newToken);
      await _storage.write(key: 'user_role', value: role.name);

      AuthUser? user;
      final userStr = await _storage.read(key: 'auth_user');
      if (userStr != null) {
        try {
          user = AuthUser.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
        } catch (_) {}
      }

      AppLogger.log('✓ [Auth] Refresh OK → role=${role.name}');
      return AuthState(stage: _stageFromRole(role), user: user);
    } catch (e) {
      // Only force logout when the server explicitly rejects the token (401/403).
      // Any other error (5xx, timeout, connection failure) keeps the session
      // alive using the cached role — the user should not be logged out because
      // the server had a transient issue.
      final isAuthRejection = e is DioException &&
          e.type == DioExceptionType.badResponse &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403);

      if (isAuthRejection) {
        AppLogger.log('✗ [Auth] Token rejeitado (${e.response?.statusCode}) → logout');
        await _storage.delete(key: 'jwt_token');
        await _storage.delete(key: 'refresh_token');
        await _storage.delete(key: 'persistent_login_token');
        await _storage.delete(key: 'user_role');
        await _storage.delete(key: 'auth_user');
        return const AuthState(stage: AuthStage.unauthenticated);
      }

      final desc = _describeError(e);
      AppLogger.log('⚠ [Auth] Erro no refresh ($desc) → mantendo sessão com cache');
      final roleStr = await _storage.read(key: 'user_role') ?? 'member';

      AuthUser? user;
      final userStr = await _storage.read(key: 'auth_user');
      if (userStr != null) {
        try {
          user = AuthUser.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
        } catch (_) {}
      }

      return AuthState(stage: _stageFromRole(parseUserRole(roleStr)), user: user);
    }
  }

  String _describeError(Object e) {
    if (e is DioException) {
      if (e.response != null) return 'HTTP ${e.response!.statusCode}';
      return e.type.name;
    }
    return e.runtimeType.toString();
  }

  String _roleFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'PENDING';
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['role'] as String? ?? 'PENDING';
    } catch (_) {
      return 'PENDING';
    }
  }

  /// Called from the pending screen's "Verificar aprovação" button.
  Future<void> checkApprovalStatus() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchCurrentRole);
  }

  Future<String> getLoginUrl(String provider, {String state = ''}) async {
    return _repository.getLoginUrl(provider, state: state);
  }

  Future<void> handleCallback(String provider, String code, {String oauthState = ''}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repository.handleCallback(provider, code, state: oauthState);
      final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
      await _storage.write(key: 'jwt_token', value: result['accessToken'] as String);
      await _storage.write(key: 'refresh_token', value: result['refreshToken'] as String);
      await _storage.write(key: 'persistent_login_token', value: result['refreshToken'] as String);
      await _storage.write(key: 'user_role', value: user.role.name);
      await _storage.write(key: 'auth_user', value: jsonEncode(user.toJson()));
      return AuthState(
        stage: _stageFromRole(user.role),
        user: user,
      );
    });
  }

  // Called by app_links when backend redirects to futfun://auth?accessToken=...
  Future<void> handleDeepLinkCallback({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authUser = AuthUser.fromJson(user);
      await _storage.write(key: 'jwt_token', value: accessToken);
      await _storage.write(key: 'refresh_token', value: refreshToken);
      await _storage.write(key: 'persistent_login_token', value: refreshToken);
      await _storage.write(key: 'user_role', value: authUser.role.name);
      await _storage.write(key: 'auth_user', value: jsonEncode(authUser.toJson()));
      if (!kIsWeb) {
        PushNotificationService()
            .registerToken(DioClient().dio)
            .catchError((_) {});
      }
      return AuthState(
        stage: _stageFromRole(authUser.role),
        user: authUser,
      );
    });
  }

  Future<void> logout() async {
    AppLogger.log('✓ [Auth] Logout iniciado');
    if (!kIsWeb) {
      await PushNotificationService()
          .unregisterToken(DioClient().dio)
          .catchError((_) {});
    }
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'persistent_login_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'auth_user');
    AppLogger.log('✓ [Auth] Logout concluído');
    state = const AsyncValue.data(AuthState(stage: AuthStage.unauthenticated));
  }

  AuthStage _stageFromRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AuthStage.admin;
      case UserRole.member:
        return AuthStage.member;
      case UserRole.pending:
        return AuthStage.pending;
    }
  }
}

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);
