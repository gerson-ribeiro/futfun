// lib/features/auth/viewmodels/auth_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';
import '../../../core/network/dio_client.dart';

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
  final _storage = const FlutterSecureStorage();
  late final AuthRepository _repository;

  @override
  Future<AuthState> build() async {
    _repository = AuthRepository(DioClient().dio);
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      final roleStr = await _storage.read(key: 'user_role') ?? 'member';
      final role = parseUserRole(roleStr);
      return AuthState(stage: _stageFromRole(role));
    }
    return const AuthState(stage: AuthStage.unauthenticated);
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
      return AuthState(
        stage: _stageFromRole(authUser.role),
        user: authUser,
      );
    });
  }

  Future<void> logout() async {
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
