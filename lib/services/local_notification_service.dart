import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  unawaited(
    LocalNotificationService.handleNotificationResponse(
      notificationResponse,
      fromBackground: true,
    ),
  );
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const String _channelId = 'task_notifications_v3';
  static const String _channelName = 'Task Notifications';
  static const String _channelDescription = 'Task and system notifications';

  static const String _chatCategoryId = 'chat_category';
  static const String _chatReplyActionId = 'chat_reply_action';

  static Map<String, dynamic>? _pendingNavigationPayload;

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _chatCategoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.text(
              _chatReplyActionId,
              'رد',
              buttonTitle: 'إرسال',
              placeholder: 'اكتب ردك',
            ),
          ],
        ),
      ],
    );

    final settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(handleNotificationResponse(response));
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    final parsed = _decodePayload(launchPayload);
    if (parsed != null) {
      _pendingNavigationPayload = parsed;
    }

    _initialized = true;
  }

  static Map<String, dynamic>? takePendingNavigationPayload() {
    final payload = _pendingNavigationPayload;
    _pendingNavigationPayload = null;
    return payload;
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'إشعار';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';

    if (kIsWeb) {
      await ensureWebNotificationPermission();
      showWebNotification(title, body);
      initWebNotificationSound();
      playWebNotificationSound();
      return;
    }

    await init();
    final isChat = message.data['type']?.toString() == 'chat_message';
    final payload = isChat ? _encodeChatPayload(message.data) : null;

    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: isChat
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                _chatReplyActionId,
                'رد سريع',
                semanticAction: SemanticAction.reply,
                inputs: <AndroidNotificationActionInput>[
                  AndroidNotificationActionInput(label: 'اكتب ردك'),
                ],
              ),
            ]
          : null,
    );

    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      categoryIdentifier: isChat ? _chatCategoryId : null,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response, {
    bool fromBackground = false,
  }) async {
    final payload = _decodePayload(response.payload);
    if (payload == null) return;

    final isChat = payload['kind'] == 'chat' &&
        (payload['conversationId']?.toString().isNotEmpty ?? false);
    if (!isChat) return;

    final actionId = response.actionId?.trim();
    final quickReplyText = response.input?.trim() ?? '';

    if (actionId == _chatReplyActionId && quickReplyText.isNotEmpty) {
      await _sendQuickReply(
        conversationId: payload['conversationId'].toString(),
        text: quickReplyText,
      );
      return;
    }

    _openChatConversation(payload, fromBackground: fromBackground);
  }

  static void openChatFromPayload(Map<String, dynamic> payload) {
    _openChatConversation(payload, fromBackground: false);
  }

  static void _openChatConversation(
    Map<String, dynamic> payload, {
    required bool fromBackground,
  }) {
    final conversationId = payload['conversationId']?.toString();
    if (conversationId == null || conversationId.isEmpty) return;

    final args = <String, dynamic>{
      'conversationId': conversationId,
      if (payload['senderName'] != null)
        'peer': {'name': payload['senderName'].toString()},
    };

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || fromBackground) {
      _pendingNavigationPayload = payload;
      return;
    }

    navigator.pushNamed(AppRoutes.chatConversation, arguments: args);
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = json.decode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  static String _encodeChatPayload(Map<String, dynamic> data) {
    return json.encode({
      'kind': 'chat',
      'conversationId': data['conversationId']?.toString() ?? '',
      'messageId': data['messageId']?.toString() ?? '',
      'senderId': data['senderId']?.toString() ?? '',
      'senderName': data['senderName']?.toString() ?? '',
    });
  }

  static Future<void> _sendQuickReply({
    required String conversationId,
    required String text,
  }) async {
    if (conversationId.trim().isEmpty || text.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('auth_token') ?? prefs.getString('token') ?? '';
      if (token.trim().isEmpty) return;

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationMessages(conversationId)}',
      );
      await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'text': text.trim()}),
      );
    } catch (_) {}
  }
}
