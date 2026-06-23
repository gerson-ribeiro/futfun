// lib/app.dart

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/dio_client.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/competition_theme_provider.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';

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
    DioClient.setLogoutCallback(
      () => ref.read(authViewModelProvider.notifier).logout(),
    );
    _initDeepLinks();
    _initPushNotifications();
  }

  void _initPushNotifications() async {
    await PushNotificationService().initialize();
    // Register token if user is already authenticated (app restart after login)
    final auth = ref.read(authViewModelProvider).valueOrNull;
    if (auth?.stage == AuthStage.member || auth?.stage == AuthStage.admin) {
      PushNotificationService().registerToken(DioClient().dio).catchError((_) {});
    }
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links that arrived while the app was cold-starting or resuming
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleUri(initialUri);
    } catch (_) {}

    // Handle links while the app is running (background → foreground)
    _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    // futfun://auth?accessToken=...&refreshToken=...&role=...
    if (uri.host == 'auth') {
      final accessToken = uri.queryParameters['accessToken'];
      final refreshToken = uri.queryParameters['refreshToken'];
      final error = uri.queryParameters['error'];

      if (error == 'true') return;

      if (accessToken != null && refreshToken != null) {
        ref
            .read(authViewModelProvider.notifier)
            .handleDeepLinkCallback(
              accessToken: accessToken,
              refreshToken: refreshToken,
              user: {
                'id': uri.queryParameters['userId'] ?? '',
                'email': uri.queryParameters['email'] ?? '',
                'displayName': uri.queryParameters['displayName'] ?? '',
                'role': uri.queryParameters['role'] ?? 'PENDING',
              },
            )
            .then((_) => _navigateAfterAuth());
      }
    }

    // futfun://invite?token=...
    if (uri.host == 'invite') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        ref.read(routerProvider).go('/invite?token=$token');
      }
    }
  }

  void _navigateAfterAuth() {
    final authState = ref.read(authViewModelProvider).valueOrNull;
    if (authState == null) return;
    final router = ref.read(routerProvider);
    switch (authState.stage) {
      case AuthStage.admin:
        router.go('/admin/users');
      case AuthStage.member:
        router.go('/matches');
      case AuthStage.pending:
        router.go('/pending');
      case AuthStage.unauthenticated:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final primaryColor = ref.watch(competitionPrimaryColorProvider);

    return MaterialApp.router(
      title: 'FutFun',
      routerConfig: router,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}
