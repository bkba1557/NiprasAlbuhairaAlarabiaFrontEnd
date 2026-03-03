import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/services/local_notification_service.dart';
import 'package:order_tracker/services/web_notifications.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:provider/provider.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _lastToken;

  static Future<void> init() async {
    await LocalNotificationService.init();
    await _requestPermissions();
    try {
      final settings = await _messaging.getNotificationSettings();
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM permission read error: $e');
    }
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kIsWeb) {
      await ensureWebNotificationPermission();
      initWebNotificationSound();
    }

    final vapidKey =
        const String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
    final token = await _messaging.getToken(
      vapidKey: kIsWeb && vapidKey.isNotEmpty ? vapidKey : null,
    );

    if (token != null) {
      debugPrint('FCM token: $token');
      _lastToken = token;
      await _registerToken(token);
    } else {
      debugPrint('FCM token is null (permission denied or not ready).');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refreshed: $token');
      _lastToken = token;
      await _registerToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      await LocalNotificationService.showFromRemoteMessage(message);
      _refreshNotifications();
      _refreshChat();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _refreshNotifications();
      _refreshChat();
      _handleOpenedMessage(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _refreshNotifications();
      _refreshChat();
      _handleOpenedMessage(initialMessage);
    }
  }

  static Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'desktop';
      default:
        return 'web';
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/devices/register'),
        headers: ApiService.headers,
        body: json.encode({
          'token': token,
          'platform': _platformName(),
        }),
      );

      if (response.statusCode >= 400) {
        debugPrint('Device register failed: ${response.body}');
      } else {
        debugPrint('Device register ok: ${response.body}');
      }
    } catch (e) {
      debugPrint('Device register error: $e');
    }
  }

  static Future<void> unregister() async {
    try {
      final token = _lastToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/devices/unregister'),
        headers: ApiService.headers,
        body: json.encode({'token': token}),
      );

      await _messaging.deleteToken();
      _lastToken = null;
    } catch (e) {
      debugPrint('Device unregister error: $e');
    }
  }

  static void _refreshNotifications() {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    try {
      final provider = context.read<NotificationProvider>();
      provider.refreshNotifications();
    } catch (_) {}
  }

  static void _refreshChat() {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    try {
      final provider = context.read<ChatProvider>();
      provider.refreshFromPush();
    } catch (_) {}
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    if (type != 'chat_message') return;

    final conversationId = data['conversationId']?.toString() ?? '';
    if (conversationId.isEmpty) return;

    appNavigatorKey.currentState?.pushNamed(
      AppRoutes.chatConversation,
      arguments: {
        'conversationId': conversationId,
        if (data['senderName'] != null)
          'peer': {'name': data['senderName'].toString()},
      },
    );
  }
}
