// lib/features/auth/viewmodels/auth_viewmodel.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/push_notification_service.dart';
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
    if (token != null) {
      // Always validate + refresh on startup so the session is guaranteed fresh.
      // Falls back to cached role on network errors (offline mode).
      return _fetchCurrentRole();
    }
    return const AuthState(stage: AuthStage.unauthenticated);
  }

  /// Exchanges the stored refresh token for a fresh access token and returns
  /// an AuthState reflecting the role currently recorded in the database.
  /// On network errors, falls back to the cached role (offline mode).
  /// On auth errors (token expired/invalid), clears storage and returns unauthenticated.
  Future<AuthState> _fetchCurrentRole() async {
    try {
      final storedRefresh = await _storage.read(key: 'refresh_token');
      if (storedRefresh == null) return const AuthState(stage: AuthStage.unauthenticated);
      final newToken = await _repository.refreshToken(storedRefresh);
      final roleStr = _roleFromJwt(newToken);
      final role = parseUserRole(roleStr);
      await _storage.write(key: 'jwt_token', value: newToken);
      await _storage.write(key: 'user_role', value: role.name);
      return AuthState(stage: _stageFromRole(role));
    } catch (e) {
      // Network/connectivity error → use cached role so user stays logged in offline
      final isNetworkError = e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout);
      if (isNetworkError) {
        final roleStr = await _storage.read(key: 'user_role') ?? 'member';
        return AuthState(stage: _stageFromRole(parseUserRole(roleStr)));
      }
      // Auth error (refresh token expired/invalid) → force login
      await _storage.delete(key: 'jwt_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'user_role');
      return const AuthState(stage: AuthStage.unauthenticated);
    }
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
      await _storage.write(key: 'user_role', value: user.role.name);
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
      await _storage.write(key: 'user_role', value: authUser.role.name);
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
    if (!kIsWeb) {
      await PushNotificationService()
          .unregisterToken(DioClient().dio)
          .catchError((_) {});
    }
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_role');
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
