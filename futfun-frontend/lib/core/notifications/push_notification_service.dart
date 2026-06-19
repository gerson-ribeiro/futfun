import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_repository.dart';

/// Handles background messages — must be a top-level function.
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

  Future<void> initialize() async {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    await _setupLocalNotifications();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Show notifications when app is in foreground
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    _currentToken = await FirebaseMessaging.instance.getToken();

    // Keep token fresh — FCM can rotate it
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
    });
  }

  Future<void> registerToken(Dio dio) async {
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    _currentToken = token;
    final platform = Platform.isAndroid ? 'android' : 'web';
    await NotificationRepository(dio).registerToken(token, platform);
  }

  Future<void> unregisterToken(Dio dio) async {
    final token = _currentToken;
    if (token == null) return;
    await NotificationRepository(dio).unregisterToken(token);
    await FirebaseMessaging.instance.deleteToken();
    _currentToken = null;
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
