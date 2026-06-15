# Multi-Provider Auth + Invite System — Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atualizar o app Flutter para suportar Google + Microsoft OAuth (sem camada de senha), adicionar telas de convite e aprovação pendente, e criar o painel admin (gestão de usuários e convites).

**Architecture:** `AuthViewModel` simplificado com estados `unauthenticated | loading | member | admin | pending`. GoRouter redireciona baseado no `role` do JWT. Telas admin protegidas por `AdminShellRoute`. Deep links via `app_links` processam tokens de convite.

**Tech Stack:** Flutter, Riverpod (AsyncNotifier), GoRouter, Dio, flutter_secure_storage, app_links, url_launcher

**Dependência:** Implementar após o plano de backend (`2026-06-01-multi-provider-auth-backend.md`).

> **Nota — Mobile OAuth Flow:** O backend redireciona o browser para `futfun://auth?accessToken=xxx&...` após processar o OAuth. O `app_links` listener em `app.dart` captura esse URI e chama `AuthViewModel.handleDeepLinkCallback(...)`. Ver Tasks 4 e 12.

---

## Mapa de Arquivos

### Novos
- `lib/features/auth/views/pending_approval_screen.dart`
- `lib/features/auth/views/invite_screen.dart`
- `lib/features/admin/data/admin_repository.dart`
- `lib/features/admin/data/models/invite_model.dart`
- `lib/features/admin/data/models/admin_user_model.dart`
- `lib/features/admin/viewmodels/admin_users_viewmodel.dart`
- `lib/features/admin/viewmodels/admin_invites_viewmodel.dart`
- `lib/features/admin/views/admin_shell.dart`
- `lib/features/admin/views/admin_users_screen.dart`
- `lib/features/admin/views/admin_invites_screen.dart`

### Modificados
- `pubspec.yaml`
- `lib/features/auth/data/models/auth_user.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/viewmodels/auth_viewmodel.dart`
- `lib/features/auth/views/login_screen.dart`
- `lib/core/router/app_router.dart`
- `lib/main.dart`

### Deletados
- `lib/features/auth/views/setup_password_screen.dart`
- `lib/features/auth/views/verify_password_screen.dart`

---

## Task 1: Adicionar dependência app_links

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Adicionar app_links ao pubspec.yaml**

Adicionar dentro de `dependencies:`:

```yaml
  # Deep Links
  app_links: ^6.3.2
```

- [ ] **Step 2: Instalar dependências**

```bash
cd E:/source/personal/futfun-frontend && flutter pub get
```

Esperado: saída sem erros, `pubspec.lock` atualizado.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add app_links for deep link handling"
```

---

## Task 2: Atualizar AuthUser model

**Files:**
- Modify: `lib/features/auth/data/models/auth_user.dart`

- [ ] **Step 1: Adicionar role ao AuthUser**

```dart
// lib/features/auth/data/models/auth_user.dart

enum UserRole { pending, member, admin }

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: _parseRole(json['role'] as String? ?? 'PENDING'),
    );
  }

  static UserRole _parseRole(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'MEMBER':
        return UserRole.member;
      default:
        return UserRole.pending;
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/data/models/auth_user.dart
git commit -m "feat: add role field to AuthUser model"
```

---

## Task 3: Atualizar AuthRepository

**Files:**
- Modify: `lib/features/auth/data/auth_repository.dart`

- [ ] **Step 1: Reescrever AuthRepository**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/data/auth_repository.dart
git commit -m "refactor: AuthRepository — dual provider, remove password methods, add invite validation"
```

---

## Task 4: Atualizar AuthViewModel

**Files:**
- Modify: `lib/features/auth/viewmodels/auth_viewmodel.dart`

- [ ] **Step 1: Reescrever AuthViewModel**

```dart
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
      return const AuthState(stage: AuthStage.member);
    }
    return const AuthState(stage: AuthStage.unauthenticated);
  }

  Future<String> getLoginUrl(String provider, {String state = ''}) async {
    return _repository.getLoginUrl(provider, state: state);
  }

  Future<void> handleCallback(String provider, String code, {String state = ''}) async {
    state = const AsyncValue.loading() as String; // ignore: parameter_assignments
    state = await AsyncValue.guard(() async {
      final result = await _repository.handleCallback(provider, code, state: state);
      final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
      await _storage.write(key: 'jwt_token', value: result['accessToken'] as String);
      await _storage.write(key: 'refresh_token', value: result['refreshToken'] as String);
      return AuthState(
        stage: _stageFromRole(user.role),
        user: user,
      );
    }) as String;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
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
```

**Nota:** O método `handleCallback` tem um conflito de nomes com o parâmetro `state` e o campo de estado do Notifier. Renomear o parâmetro para `oauthState`:

```dart
// lib/features/auth/viewmodels/auth_viewmodel.dart
// (versão corrigida do handleCallback)

  Future<void> handleCallback(String provider, String code, {String oauthState = ''}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repository.handleCallback(provider, code, state: oauthState);
      final user = AuthUser.fromJson(result['user'] as Map<String, dynamic>);
      await _storage.write(key: 'jwt_token', value: result['accessToken'] as String);
      await _storage.write(key: 'refresh_token', value: result['refreshToken'] as String);
      return AuthState(
        stage: _stageFromRole(user.role),
        user: user,
      );
    });
  }
```

Escreva o arquivo com a versão corrigida (parâmetro `oauthState`):

```dart
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
      return const AuthState(stage: AuthStage.member);
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
      return AuthState(
        stage: _stageFromRole(authUser.role),
        user: authUser,
      );
    });
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/viewmodels/auth_viewmodel.dart
git commit -m "refactor: simplify AuthViewModel — dual provider, role-based stages, no password flow"
```

---

## Task 5: Atualizar LoginScreen (dois botões OAuth)

**Files:**
- Modify: `lib/features/auth/views/login_screen.dart`

- [ ] **Step 1: Reescrever LoginScreen**

```dart
// lib/features/auth/views/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_soccer, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                AppStrings.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              authState.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, _) => Column(
                  children: [
                    Text('Erro: $err', style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 16),
                    _buildLoginButtons(context, ref),
                  ],
                ),
                data: (_) => _buildLoginButtons(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _OAuthButton(
          provider: 'google',
          label: 'Entrar com Google',
          icon: _GoogleIcon(),
          ref: ref,
        ),
        const SizedBox(height: 12),
        _OAuthButton(
          provider: 'microsoft',
          label: 'Entrar com Microsoft',
          icon: const Icon(Icons.window, color: Colors.white),
          ref: ref,
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String provider;
  final String label;
  final Widget icon;
  final WidgetRef ref;

  const _OAuthButton({
    required this.provider,
    required this.label,
    required this.icon,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final url = await ref.read(authViewModelProvider.notifier).getLoginUrl(provider);
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: icon,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/views/login_screen.dart
git commit -m "feat: update LoginScreen with Google + Microsoft OAuth buttons"
```

---

## Task 6: Criar PendingApprovalScreen

**Files:**
- Create: `lib/features/auth/views/pending_approval_screen.dart`

- [ ] **Step 1: Criar tela**

```dart
// lib/features/auth/views/pending_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Aguardando aprovação',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Seu cadastro está em análise. Você receberá um email assim que o acesso for aprovado.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/views/pending_approval_screen.dart
git commit -m "feat: add PendingApprovalScreen for users awaiting admin approval"
```

---

## Task 7: Criar InviteScreen

**Files:**
- Create: `lib/features/auth/views/invite_screen.dart`

- [ ] **Step 1: Criar tela**

```dart
// lib/features/auth/views/invite_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/auth_repository.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';

final _inviteValidationProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, token) async {
    final repo = AuthRepository(DioClient().dio);
    return repo.validateInvite(token);
  },
);

class InviteScreen extends ConsumerWidget {
  final String token;

  const InviteScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteAsync = ref.watch(_inviteValidationProvider(token));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: inviteAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Convite inválido ou expirado',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.error,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            data: (invite) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer, size: 72, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  'Você foi convidado!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre para participar do FutFun — bolão da Copa do Mundo 2026.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _InviteOAuthButton(
                  provider: 'google',
                  label: 'Entrar com Google',
                  inviteToken: token,
                  ref: ref,
                ),
                const SizedBox(height: 12),
                _InviteOAuthButton(
                  provider: 'microsoft',
                  label: 'Entrar com Microsoft',
                  inviteToken: token,
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteOAuthButton extends StatelessWidget {
  final String provider;
  final String label;
  final String inviteToken;
  final WidgetRef ref;

  const _InviteOAuthButton({
    required this.provider,
    required this.label,
    required this.inviteToken,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final state = 'invite:$inviteToken';
          final url = await ref
              .read(authViewModelProvider.notifier)
              .getLoginUrl(provider, state: state);
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: Text(label),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/views/invite_screen.dart
git commit -m "feat: add InviteScreen with token validation and dual-provider OAuth buttons"
```

---

## Task 8: Criar AdminRepository e models

**Files:**
- Create: `lib/features/admin/data/admin_repository.dart`
- Create: `lib/features/admin/data/models/admin_user_model.dart`
- Create: `lib/features/admin/data/models/invite_model.dart`

- [ ] **Step 1: Criar admin_user_model.dart**

```dart
// lib/features/admin/data/models/admin_user_model.dart

import '../../../features/auth/data/models/auth_user.dart';

class AdminUser {
  final String id;
  final String email;
  final String displayName;
  final String provider;
  final UserRole role;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      provider: json['provider'] as String,
      role: AuthUser._parseRole(json['role'] as String? ?? 'PENDING'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }
}
```

**Nota:** `AuthUser._parseRole` é privado. Mover `_parseRole` para uma função top-level em `auth_user.dart` chamada `parseUserRole`:

```dart
// No final de lib/features/auth/data/models/auth_user.dart, adicionar:

UserRole parseUserRole(String role) {
  switch (role.toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'MEMBER':
      return UserRole.member;
    default:
      return UserRole.pending;
  }
}
```

E atualizar `AuthUser.fromJson` para usar `parseUserRole(json['role'] ...)` em vez de `_parseRole(...)`.

Escreva `admin_user_model.dart` usando `parseUserRole`:

```dart
// lib/features/admin/data/models/admin_user_model.dart

import '../../../features/auth/data/models/auth_user.dart';

class AdminUser {
  final String id;
  final String email;
  final String displayName;
  final String provider;
  final UserRole role;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      provider: json['provider'] as String,
      role: parseUserRole(json['role'] as String? ?? 'PENDING'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }
}
```

- [ ] **Step 2: Criar invite_model.dart**

```dart
// lib/features/admin/data/models/invite_model.dart

enum InviteStatus { pending, used, expired }

class InviteModel {
  final String id;
  final String email;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;
  final String? creatorName;

  const InviteModel({
    required this.id,
    required this.email,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
    this.creatorName,
  });

  InviteStatus get status {
    if (usedAt != null) return InviteStatus.used;
    if (expiresAt.isBefore(DateTime.now())) return InviteStatus.expired;
    return InviteStatus.pending;
  }

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      id: json['id'] as String,
      email: json['email'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      usedAt: json['usedAt'] != null ? DateTime.parse(json['usedAt'] as String) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      creatorName: (json['creator'] as Map<String, dynamic>?)?['displayName'] as String?,
    );
  }
}
```

- [ ] **Step 3: Criar admin_repository.dart**

```dart
// lib/features/admin/data/admin_repository.dart

import 'package:dio/dio.dart';
import 'models/admin_user_model.dart';
import 'models/invite_model.dart';

class AdminRepository {
  final Dio _dio;

  AdminRepository(this._dio);

  Future<List<AdminUser>> getUsers() async {
    final response = await _dio.get('/api/admin/users');
    final list = response.data['users'] as List<dynamic>;
    return list.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminUser> updateUserRole(String userId, String role) async {
    final response = await _dio.patch(
      '/api/admin/users/$userId/role',
      data: {'role': role},
    );
    return AdminUser.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete('/api/admin/users/$userId');
  }

  Future<List<InviteModel>> getInvites() async {
    final response = await _dio.get('/api/admin/invites');
    final list = response.data['invites'] as List<dynamic>;
    return list.map((e) => InviteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> sendInvite(String email) async {
    await _dio.post('/api/admin/invites', data: {'email': email});
  }

  Future<void> cancelInvite(String inviteId) async {
    await _dio.delete('/api/admin/invites/$inviteId');
  }
}
```

- [ ] **Step 4: Atualizar auth_user.dart com parseUserRole pública**

```dart
// lib/features/auth/data/models/auth_user.dart

enum UserRole { pending, member, admin }

UserRole parseUserRole(String role) {
  switch (role.toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'MEMBER':
      return UserRole.member;
    default:
      return UserRole.pending;
  }
}

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: parseUserRole(json['role'] as String? ?? 'PENDING'),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/ lib/features/auth/data/models/auth_user.dart
git commit -m "feat: add admin data layer — AdminRepository, AdminUser, InviteModel"
```

---

## Task 9: Criar AdminUsersViewModel e AdminUsersScreen

**Files:**
- Create: `lib/features/admin/viewmodels/admin_users_viewmodel.dart`
- Create: `lib/features/admin/views/admin_users_screen.dart`

- [ ] **Step 1: Criar admin_users_viewmodel.dart**

```dart
// lib/features/admin/viewmodels/admin_users_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../data/models/admin_user_model.dart';
import '../../../core/network/dio_client.dart';

class AdminUsersViewModel extends AsyncNotifier<List<AdminUser>> {
  late final AdminRepository _repository;

  @override
  Future<List<AdminUser>> build() async {
    _repository = AdminRepository(DioClient().dio);
    return _repository.getUsers();
  }

  Future<void> approveUser(String userId) async {
    await _repository.updateUserRole(userId, 'MEMBER');
    ref.invalidateSelf();
  }

  Future<void> promoteToAdmin(String userId) async {
    await _repository.updateUserRole(userId, 'ADMIN');
    ref.invalidateSelf();
  }

  Future<void> removeUser(String userId) async {
    await _repository.deleteUser(userId);
    ref.invalidateSelf();
  }
}

final adminUsersViewModelProvider =
    AsyncNotifierProvider<AdminUsersViewModel, List<AdminUser>>(
  AdminUsersViewModel.new,
);
```

- [ ] **Step 2: Criar admin_users_screen.dart**

```dart
// lib/features/admin/views/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/admin_users_viewmodel.dart';
import '../data/models/admin_user_model.dart';
import '../../../features/auth/data/models/auth_user.dart';
import '../../../core/constants/app_colors.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (users) {
          final pending = users.where((u) => u.role == UserRole.pending).toList();
          final members = users.where((u) => u.role == UserRole.member).toList();
          final admins = users.where((u) => u.role == UserRole.admin).toList();

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Pendentes (${pending.length})'),
                    Tab(text: 'Membros (${members.length})'),
                    Tab(text: 'Admins (${admins.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _UserList(users: pending, showApprove: true, ref: ref),
                      _UserList(users: members, showPromote: true, ref: ref),
                      _UserList(users: admins, ref: ref),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<AdminUser> users;
  final WidgetRef ref;
  final bool showApprove;
  final bool showPromote;

  const _UserList({
    required this.users,
    required this.ref,
    this.showApprove = false,
    this.showPromote = false,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('Nenhum usuário'));
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(user.displayName),
          subtitle: Text('${user.email} • ${user.provider}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showApprove)
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Aprovar',
                  onPressed: () => ref
                      .read(adminUsersViewModelProvider.notifier)
                      .approveUser(user.id),
                ),
              if (showPromote)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  tooltip: 'Promover a Admin',
                  onPressed: () => ref
                      .read(adminUsersViewModelProvider.notifier)
                      .promoteToAdmin(user.id),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Remover',
                onPressed: () => _confirmDelete(context, user),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover usuário'),
        content: Text('Tem certeza que deseja remover ${user.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(adminUsersViewModelProvider.notifier).removeUser(user.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/admin/viewmodels/admin_users_viewmodel.dart lib/features/admin/views/admin_users_screen.dart
git commit -m "feat: add AdminUsersScreen with pending/members/admins tabs and user actions"
```

---

## Task 10: Criar AdminInvitesViewModel e AdminInvitesScreen

**Files:**
- Create: `lib/features/admin/viewmodels/admin_invites_viewmodel.dart`
- Create: `lib/features/admin/views/admin_invites_screen.dart`

- [ ] **Step 1: Criar admin_invites_viewmodel.dart**

```dart
// lib/features/admin/viewmodels/admin_invites_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../data/models/invite_model.dart';
import '../../../core/network/dio_client.dart';

class AdminInvitesViewModel extends AsyncNotifier<List<InviteModel>> {
  late final AdminRepository _repository;

  @override
  Future<List<InviteModel>> build() async {
    _repository = AdminRepository(DioClient().dio);
    return _repository.getInvites();
  }

  Future<void> sendInvite(String email) async {
    await _repository.sendInvite(email);
    ref.invalidateSelf();
  }

  Future<void> cancelInvite(String inviteId) async {
    await _repository.cancelInvite(inviteId);
    ref.invalidateSelf();
  }
}

final adminInvitesViewModelProvider =
    AsyncNotifierProvider<AdminInvitesViewModel, List<InviteModel>>(
  AdminInvitesViewModel.new,
);
```

- [ ] **Step 2: Criar admin_invites_screen.dart**

```dart
// lib/features/admin/views/admin_invites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../viewmodels/admin_invites_viewmodel.dart';
import '../data/models/invite_model.dart';
import '../../../core/constants/app_colors.dart';

class AdminInvitesScreen extends ConsumerStatefulWidget {
  const AdminInvitesScreen({super.key});

  @override
  ConsumerState<AdminInvitesScreen> createState() => _AdminInvitesScreenState();
}

class _AdminInvitesScreenState extends ConsumerState<AdminInvitesScreen> {
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(adminInvitesViewModelProvider.notifier).sendInvite(email);
      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Convite enviado para $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(adminInvitesViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Convites'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email do convidado',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _sending ? null : _sendInvite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: invitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro: $err')),
              data: (invites) {
                if (invites.isEmpty) {
                  return const Center(child: Text('Nenhum convite enviado ainda'));
                }
                return ListView.builder(
                  itemCount: invites.length,
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    return _InviteTile(
                      invite: invite,
                      onCancel: invite.status == InviteStatus.pending
                          ? () => ref
                              .read(adminInvitesViewModelProvider.notifier)
                              .cancelInvite(invite.id)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  final InviteModel invite;
  final VoidCallback? onCancel;

  const _InviteTile({required this.invite, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    Color statusColor;
    String statusLabel;

    switch (invite.status) {
      case InviteStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pendente';
      case InviteStatus.used:
        statusColor = Colors.green;
        statusLabel = 'Usado';
      case InviteStatus.expired:
        statusColor = Colors.grey;
        statusLabel = 'Expirado';
    }

    return ListTile(
      leading: Icon(Icons.email_outlined, color: statusColor),
      title: Text(invite.email),
      subtitle: Text(
        'Enviado: ${fmt.format(invite.createdAt)} • Expira: ${fmt.format(invite.expiresAt)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: 'Cancelar convite',
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/admin/viewmodels/admin_invites_viewmodel.dart lib/features/admin/views/admin_invites_screen.dart
git commit -m "feat: add AdminInvitesScreen with send invite form and invite list"
```

---

## Task 11: Criar AdminShell e atualizar GoRouter

**Files:**
- Create: `lib/features/admin/views/admin_shell.dart`
- Modify: `lib/core/router/app_router.dart`
- Delete: `lib/features/auth/views/setup_password_screen.dart`
- Delete: `lib/features/auth/views/verify_password_screen.dart`

- [ ] **Step 1: Criar admin_shell.dart**

```dart
// lib/features/admin/views/admin_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/admin/invites')) currentIndex = 1;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/admin/users');
            case 1:
              context.go('/admin/invites');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Usuários',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.email),
            label: 'Convites',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Reescrever app_router.dart**

```dart
// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/pending_approval_screen.dart';
import '../../features/auth/views/invite_screen.dart';
import '../../features/matches/views/matches_screen.dart';
import '../../features/ranking/views/ranking_screen.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/admin/views/admin_shell.dart';
import '../../features/admin/views/admin_users_screen.dart';
import '../../features/admin/views/admin_invites_screen.dart';
import '../constants/app_colors.dart';

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/ranking')) currentIndex = 1;
    if (location.startsWith('/dashboard')) currentIndex = 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/matches');
            case 1:
              context.go('/ranking');
            case 2:
              context.go('/dashboard');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
            label: 'Jogos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authStateAsync = ref.read(authViewModelProvider);
      return authStateAsync.when(
        loading: () => null,
        error: (_, __) => '/login',
        data: (authState) {
          final loc = state.matchedLocation;

          // Allow public routes always
          if (loc.startsWith('/invite') || loc == '/login') return null;

          switch (authState.stage) {
            case AuthStage.unauthenticated:
              return '/login';
            case AuthStage.pending:
              return loc == '/pending' ? null : '/pending';
            case AuthStage.member:
              if (loc == '/login' || loc == '/pending') return '/matches';
              if (loc.startsWith('/admin')) return '/matches';
              return null;
            case AuthStage.admin:
              if (loc == '/login' || loc == '/pending') return '/admin/users';
              return null;
          }
        },
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/pending', builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(
        path: '/invite',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return InviteScreen(token: token);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/matches', builder: (_, __) => const MatchesScreen()),
          GoRoute(path: '/ranking', builder: (_, __) => const RankingScreen()),
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
          GoRoute(path: '/admin/invites', builder: (_, __) => const AdminInvitesScreen()),
        ],
      ),
    ],
  );
  return router;
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen(authViewModelProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
```

- [ ] **Step 3: Deletar telas de senha obsoletas**

```bash
rm "E:/source/personal/futfun-frontend/lib/features/auth/views/setup_password_screen.dart"
rm "E:/source/personal/futfun-frontend/lib/features/auth/views/verify_password_screen.dart"
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/admin/views/admin_shell.dart
git rm lib/features/auth/views/setup_password_screen.dart lib/features/auth/views/verify_password_screen.dart
git commit -m "feat: update router with pending/invite/admin routes, remove password screens"
```

---

## Task 12: Configurar deep links em main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Ler main.dart atual**

```bash
cat "E:/source/personal/futfun-frontend/lib/main.dart"
```

- [ ] **Step 2: Adicionar listener de deep link**

Adicionar o listener de `app_links` ao `main.dart`. O padrão é inicializar no `main()` ou num widget raiz. Como o app usa `GoRouter` via `routerProvider`, o handler deve chamar `router.go('/invite?token=...')` quando receber um link.

```dart
// lib/main.dart

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FutFunApp()));
}

// Em app.dart ou no widget raiz, adicionar o listener:
// (ver step 3)
```

- [ ] **Step 3: Ler app.dart e adicionar deep link listener**

```bash
cat "E:/source/personal/futfun-frontend/lib/app.dart"
```

Adicionar `_initDeepLinks` ao widget raiz do app (provavelmente `FutFunApp` ou o `ConsumerStatefulWidget` que usa o `routerProvider`). O widget deve ser `ConsumerStatefulWidget` para ter acesso ao ref e ao router:

```dart
// lib/app.dart (adicionar deep link handling)

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

class FutFunApp extends ConsumerStatefulWidget {
  const FutFunApp({super.key});

  @override
  ConsumerState<FutFunApp> createState() => _FutFunAppState();
}

class _FutFunAppState extends ConsumerState<FutFunApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      // futfun://auth?accessToken=...&refreshToken=...&role=...&userId=...&email=...&displayName=...
      if (uri.host == 'auth') {
        final accessToken = uri.queryParameters['accessToken'];
        final refreshToken = uri.queryParameters['refreshToken'];
        final error = uri.queryParameters['error'];

        if (error == 'true') {
          // OAuth failed — stay on login screen (GoRouter redirect handles this)
          return;
        }

        if (accessToken != null && refreshToken != null) {
          ref.read(authViewModelProvider.notifier).handleDeepLinkCallback(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: {
              'id': uri.queryParameters['userId'] ?? '',
              'email': uri.queryParameters['email'] ?? '',
              'displayName': uri.queryParameters['displayName'] ?? '',
              'role': uri.queryParameters['role'] ?? 'PENDING',
            },
          );
        }
      }

      // futfun://invite?token=...
      if (uri.host == 'invite') {
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          final router = ref.read(routerProvider);
          router.go('/invite?token=$token');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'FutFun',
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16a34a)),
        useMaterial3: true,
      ),
    );
  }
}
```

**Nota:** Se `app.dart` já tem um widget diferente, adapte mantendo a mesma estrutura. O ponto essencial é chamar `_appLinks.uriLinkStream.listen(...)` no `initState`.

- [ ] **Step 4: Verificar compilação**

```bash
cd E:/source/personal/futfun-frontend && flutter analyze
```

Esperado: sem erros (warnings são aceitáveis).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: add deep link handling for invite tokens via app_links"
```

---

## Task 13: Limpeza final e verificação

- [ ] **Step 1: Rodar análise estática completa**

```bash
cd E:/source/personal/futfun-frontend && flutter analyze
```

Corrigir qualquer erro antes de continuar. Warnings de lint podem ser ignorados.

- [ ] **Step 2: Verificar que não há referências às telas deletadas**

```bash
grep -r "setup_password_screen\|verify_password_screen\|SetupPasswordScreen\|VerifyPasswordScreen\|awaitingPassword\|awaitingPasswordSetup\|getMicrosoftLoginUrl\|exchangeCallback\|setupPassword\|verifyPassword" "E:/source/personal/futfun-frontend/lib"
```

Esperado: nenhum resultado.

- [ ] **Step 3: Commit final**

```bash
git add -A
git commit -m "chore: final cleanup — verify no stale references to removed auth flow"
```
