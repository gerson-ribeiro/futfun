import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../storage/app_logger.dart';
import 'firebase_web_config.dart';
import 'notification_repository.dart';

/// Handles background messages on native — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static PushNotificationService? _instance;
  factory PushNotificationService() => _instance ??= PushNotificationService._();
  PushNotificationService._();

  String? _currentToken;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'futfun_notifications';
  static const _channelName = 'FutFun';

  String? get currentToken => _currentToken;

  Future<void> initialize() async {
    if (kIsWeb) {
      await _initWeb();
    } else {
      await _initNative();
    }
  }

  Future<void> _initWeb() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: kFirebaseWebApiKey,
          authDomain: kFirebaseWebAuthDomain,
          projectId: kFirebaseWebProjectId,
          storageBucket: kFirebaseWebStorageBucket,
          messagingSenderId: kFirebaseWebMessagingSenderId,
          appId: kFirebaseWebAppId,
        ),
      );
      AppLogger.log('✓ [Push] Firebase inicializado (web)');
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        AppLogger.log('✓ [Push] Firebase já inicializado (web)');
      } else {
        AppLogger.log('✗ [Push] Erro ao inicializar Firebase (web): ${e.code}');
        rethrow;
      }
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    AppLogger.log('✓ [Push] Permissão: ${settings.authorizationStatus.name}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.log('⚠ [Push] Notificações negadas pelo usuário (web)');
      return;
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _currentToken = t;
      AppLogger.log('✓ [Push] Token FCM atualizado (web)');
    });

    _currentToken = await FirebaseMessaging.instance.getToken(
      vapidKey: kFirebaseWebVapidKey,
    );
    if (_currentToken != null) {
      AppLogger.log('✓ [Push] Token FCM obtido (web)');
    } else {
      AppLogger.log('✗ [Push] Token FCM nulo (web) — verifique VAPID key e firebase-messaging-sw.js');
    }
  }

  Future<void> _initNative() async {
    await Firebase.initializeApp();
    AppLogger.log('✓ [Push] Firebase inicializado (native)');

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    await _setupLocalNotifications();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    AppLogger.log('✓ [Push] Permissão: ${settings.authorizationStatus.name}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.log('⚠ [Push] Notificações negadas pelo usuário (native)');
      return;
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    _currentToken = await FirebaseMessaging.instance.getToken();
    if (_currentToken != null) {
      AppLogger.log('✓ [Push] Token FCM obtido (native)');
    } else {
      AppLogger.log('✗ [Push] Token FCM nulo (native) — verifique google-services.json');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _currentToken = t;
      AppLogger.log('✓ [Push] Token FCM atualizado (native)');
    });
  }

  Future<void> registerToken(Dio dio) async {
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) {
      AppLogger.log('✗ [Push] registerToken: token nulo, ignorando');
      return;
    }
    _currentToken = token;
    const platform = kIsWeb ? 'web' : 'android';
    try {
      await NotificationRepository(dio).registerToken(token, platform);
      AppLogger.log('✓ [Push] Token registrado no servidor ($platform)');
    } catch (e) {
      AppLogger.log('✗ [Push] Falha ao registrar token no servidor: $e');
      rethrow;
    }
  }

  Future<void> unregisterToken(Dio dio) async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await NotificationRepository(dio).unregisterToken(token);
    } catch (_) {}
    await FirebaseMessaging.instance.deleteToken();
    _currentToken = null;
    AppLogger.log('✓ [Push] Token removido');
  }

  Future<void> _setupLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(const InitializationSettings(android: android));

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
        ));
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
