import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/chat_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatConversation> _conversations = [];
  final List<ChatUser> _users = [];
  final Map<String, List<ChatMessage>> _messagesByConversation = {};

  bool _isLoadingConversations = false;
  bool _isLoadingUsers = false;
  bool _isLoadingMessages = false;
  String? _error;
  String? _lastCallError;
  int _totalUnread = 0;

  Timer? _backgroundSyncTimer;
  Timer? _activeConversationTimer;
  Timer? _presencePingTimer;
  String? _activeConversationId;

  final Map<String, bool> _typingState = {};
  final Map<String, DateTime> _typingLastEmitAt = {};

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  List<ChatUser> get users => List.unmodifiable(_users);
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get error => _error;
  String? get lastCallError => _lastCallError;
  int get totalUnread => _totalUnread;
  String? get activeConversationId => _activeConversationId;
  bool get hasRunningSync =>
      _backgroundSyncTimer != null ||
      _activeConversationTimer != null ||
      _presencePingTimer != null;

  List<ChatMessage> messagesFor(String conversationId) {
    return List.unmodifiable(
      _messagesByConversation[conversationId] ?? const [],
    );
  }

  ChatConversation? conversationById(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  Future<void> fetchUsers({String? search, bool silent = false}) async {
    if (!silent) {
      _isLoadingUsers = true;
      notifyListeners();
    }

    try {
      final query = <String, String>{'limit': '300'};
      final normalizedSearch = search?.trim();
      if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
        query['search'] = normalizedSearch;
      }

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatUsers}',
      ).replace(queryParameters: query);
      final response = await http.get(uri, headers: ApiService.headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawUsers = data['users'];
        if (rawUsers is List) {
          _users
            ..clear()
            ..addAll(
              rawUsers.whereType<Map<String, dynamic>>().map(ChatUser.fromJson),
            );
        }
      } else {
        throw Exception(
          'ÙØ´Ù„ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙŠÙ† (${response.statusCode})',
        );
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!silent) {
        _isLoadingUsers = false;
        notifyListeners();
      } else if (_error != null) {
        notifyListeners();
      }
    }
  }

  Future<void> fetchConversations({bool silent = false}) async {
    if (!silent) {
      _isLoadingConversations = true;
      notifyListeners();
    }

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversations}?limit=80',
      );
      final response = await http.get(uri, headers: ApiService.headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawConversations = data['conversations'];
        if (rawConversations is List) {
          _conversations
            ..clear()
            ..addAll(
              rawConversations.whereType<Map<String, dynamic>>().map(
                ChatConversation.fromJson,
              ),
            );
        }
        _totalUnread = _computeTotalUnread(fallback: data['totalUnread']);
        _error = null;
      } else {
        throw Exception(
          'ÙØ´Ù„ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ù…Ø­Ø§Ø¯Ø«Ø§Øª (${response.statusCode})',
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!silent) {
        _isLoadingConversations = false;
      }
      notifyListeners();
    }
  }

  Future<ChatConversation?> fetchConversationById(
    String conversationId, {
    bool silent = false,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationById(conversationId)}',
      );
      final response = await http.get(uri, headers: ApiService.headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['conversation'] is Map<String, dynamic>) {
          final conversation = ChatConversation.fromJson(data['conversation']);
          _upsertConversation(conversation);
          if (!silent) notifyListeners();
          return conversation;
        }
      }
    } catch (e) {
      _error = e.toString();
      if (!silent) notifyListeners();
    }
    return null;
  }

  Future<ChatConversation?> startDirectConversation(String peerId) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatDirectConversation}',
        ),
        headers: ApiService.headers,
        body: json.encode({'peerId': peerId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['conversation'] is Map<String, dynamic>) {
          final conversation = ChatConversation.fromJson(data['conversation']);
          _upsertConversation(conversation, pushToTop: true);
          notifyListeners();
          return conversation;
        }
      } else {
        throw Exception(
          'ÙØ´Ù„ Ø¨Ø¯Ø¡ Ø§Ù„Ù…Ø­Ø§Ø¯Ø«Ø© (${response.statusCode})',
        );
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  Future<ChatConversation?> startGroupConversation(
    List<String> participantIds, {
    String? name,
    String? avatarPath,
    Uint8List? avatarBytes,
    String? avatarFileName,
  }) async {
    final normalizedIds = participantIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedIds.length < 2) {
      _error = 'اختر عضوين على الأقل لإنشاء مجموعة';
      notifyListeners();
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatGroupConversation}',
        ),
      );
      final headers = Map<String, String>.from(ApiService.headers);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.fields['participantIds'] = json.encode(normalizedIds);
      final trimmedName = name?.trim() ?? '';
      if (trimmedName.isNotEmpty) {
        request.fields['name'] = trimmedName;
      }

      final normalizedAvatarPath = (avatarPath ?? '').trim();
      if (avatarBytes != null && avatarBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            avatarBytes,
            filename: avatarFileName?.trim().isNotEmpty == true
                ? avatarFileName!.trim()
                : 'group-avatar.jpg',
          ),
        );
      } else if (!kIsWeb && normalizedAvatarPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            normalizedAvatarPath,
            filename: avatarFileName?.trim().isNotEmpty == true
                ? avatarFileName!.trim()
                : null,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['conversation'] is Map<String, dynamic>) {
          final conversation = ChatConversation.fromJson(data['conversation']);
          _upsertConversation(conversation, pushToTop: true);
          _error = null;
          notifyListeners();
          return conversation;
        }
        throw Exception('بيانات المجموعة المستلمة من الخادم غير صالحة');
      }

      String detail = '';
      try {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          detail = (data['error'] ?? data['message'] ?? '').toString().trim();
        }
      } catch (_) {}

      throw Exception(
        detail.isNotEmpty
            ? 'تعذر إنشاء المجموعة (${response.statusCode}): $detail'
            : 'تعذر إنشاء المجموعة (${response.statusCode})',
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  Future<ChatConversation?> updateGroupConversation(
    String conversationId, {
    String? name,
    String? avatarPath,
    Uint8List? avatarBytes,
    String? avatarFileName,
    bool removeAvatar = false,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationById(conversationId)}',
        ),
      );
      final headers = Map<String, String>.from(ApiService.headers);
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      if (name != null) {
        request.fields['name'] = name.trim();
      }
      if (removeAvatar) {
        request.fields['removeAvatar'] = 'true';
      }

      final normalizedAvatarPath = (avatarPath ?? '').trim();
      if (avatarBytes != null && avatarBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            avatarBytes,
            filename: avatarFileName?.trim().isNotEmpty == true
                ? avatarFileName!.trim()
                : 'group-avatar.jpg',
          ),
        );
      } else if (!kIsWeb && normalizedAvatarPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            normalizedAvatarPath,
            filename: avatarFileName?.trim().isNotEmpty == true
                ? avatarFileName!.trim()
                : null,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر تعديل المجموعة (${response.statusCode}): $detail'
              : 'تعذر تعديل المجموعة (${response.statusCode})',
        );
      }

      if (data['conversation'] is! Map<String, dynamic>) return null;
      final conversation = ChatConversation.fromJson(data['conversation']);
      _upsertConversation(conversation, pushToTop: true);
      _error = null;
      notifyListeners();
      return conversation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ChatConversation?> addGroupParticipants(
    String conversationId,
    List<String> participantIds,
  ) async {
    final ids = participantIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationParticipants(conversationId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'participantIds': ids}),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر إضافة الأعضاء (${response.statusCode}): $detail'
              : 'تعذر إضافة الأعضاء (${response.statusCode})',
        );
      }

      if (data['conversation'] is! Map<String, dynamic>) return null;
      final conversation = ChatConversation.fromJson(data['conversation']);
      _upsertConversation(conversation, pushToTop: true);
      _error = null;
      notifyListeners();
      return conversation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ChatConversation?> removeGroupParticipant(
    String conversationId,
    String userId,
  ) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) return null;
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationParticipant(conversationId, trimmedId)}',
        ),
        headers: ApiService.headers,
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر إزالة العضو (${response.statusCode}): $detail'
              : 'تعذر إزالة العضو (${response.statusCode})',
        );
      }

      if (data['conversation'] is! Map<String, dynamic>) return null;
      final conversation = ChatConversation.fromJson(data['conversation']);
      _upsertConversation(conversation, pushToTop: true);
      _error = null;
      notifyListeners();
      return conversation;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationById(conversationId)}',
        ),
        headers: ApiService.headers,
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر حذف المحادثة (${response.statusCode}): $detail'
              : 'تعذر حذف المحادثة (${response.statusCode})',
        );
      }

      _messagesByConversation.remove(conversationId);
      _conversations.removeWhere((item) => item.id == conversationId);
      _totalUnread = _computeTotalUnread();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMessage(String conversationId, String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationMessage(conversationId, messageId)}',
        ),
        headers: ApiService.headers,
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر حذف الرسالة (${response.statusCode}): $detail'
              : 'تعذر حذف الرسالة (${response.statusCode})',
        );
      }

      final current = List<ChatMessage>.from(
        _messagesByConversation[conversationId] ?? const [],
      );
      current.removeWhere((item) => item.id == messageId);
      _messagesByConversation[conversationId] = _normalizeMessages(current);

      if (data['conversation'] is Map<String, dynamic>) {
        final updatedConversation = ChatConversation.fromJson(
          data['conversation'],
        );
        _upsertConversation(updatedConversation);
      } else {
        unawaited(fetchConversationById(conversationId, silent: true));
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<ChatMessage?> reactToMessage(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final cleanEmoji = emoji.trim();
    if (cleanEmoji.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationMessageReactions(conversationId, messageId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'emoji': cleanEmoji}),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر تحديث الريأكشن (${response.statusCode}): $detail'
              : 'تعذر تحديث الريأكشن (${response.statusCode})',
        );
      }
      if (data['message'] is! Map<String, dynamic>) return null;
      final message = ChatMessage.fromJson(data['message']);
      _upsertMessage(conversationId, message);
      _error = null;
      notifyListeners();
      return message;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<int> forwardMessage(
    String sourceMessageId,
    List<String> targetConversationIds, {
    String? text,
  }) async {
    final ids = targetConversationIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return 0;

    final payload = <String, dynamic>{'targetConversationIds': ids};
    final textValue = text?.trim() ?? '';
    if (textValue.isNotEmpty) {
      payload['text'] = textValue;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatForwardMessage(sourceMessageId)}',
        ),
        headers: ApiService.headers,
        body: json.encode(payload),
      );
      final data = _decodeJsonMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _extractError(data);
        throw Exception(
          detail.isNotEmpty
              ? 'تعذر عمل فوروورد (${response.statusCode}): $detail'
              : 'تعذر عمل فوروورد (${response.statusCode})',
        );
      }

      final rawMessages = data['messages'];
      var forwardedCount = 0;
      if (rawMessages is List) {
        for (final row in rawMessages.whereType<Map<String, dynamic>>()) {
          final cid = (row['conversationId'] ?? '').toString();
          final messageRaw = row['message'];
          if (cid.trim().isEmpty || messageRaw is! Map<String, dynamic>) {
            continue;
          }
          forwardedCount += 1;
          _upsertMessage(cid, ChatMessage.fromJson(messageRaw));
          unawaited(fetchConversationById(cid, silent: true));
        }
      } else {
        forwardedCount =
            int.tryParse((data['forwardedCount'] ?? '0').toString()) ?? 0;
      }

      unawaited(fetchConversations(silent: true));
      _error = null;
      notifyListeners();
      return forwardedCount;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int limit = 200,
    bool markRead = true,
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoadingMessages = true;
      notifyListeners();
    }

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationMessages(conversationId)}'
        '?limit=$limit&markRead=${markRead ? 'true' : 'false'}',
      );
      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final raw = data['messages'];
        if (raw is List) {
          final parsed = raw
              .whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList();
          final normalized = _normalizeMessages(parsed);
          _messagesByConversation[conversationId] = normalized;
          if (markRead) {
            _setConversationUnread(conversationId, 0);
          }
          _error = null;
          if (!silent) {
            _isLoadingMessages = false;
          }
          notifyListeners();
          return normalized;
        }
      } else {
        throw Exception(
          'ÙØ´Ù„ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø±Ø³Ø§Ø¦Ù„ (${response.statusCode})',
        );
      }
    } catch (e) {
      _error = e.toString();
      if (!silent) {
        _isLoadingMessages = false;
      }
      notifyListeners();
    }

    return _messagesByConversation[conversationId] ?? const [];
  }

  Future<ChatCallSession?> startCall(
    String conversationId, {
    required bool isVideo,
  }) async {
    final callType = isVideo ? 'video' : 'audio';
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationCalls(conversationId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'callType': callType}),
      );
      Map<String, dynamic>? data;
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      if (response.statusCode != 200 && response.statusCode != 201) {
        if (response.statusCode == 409) {
          final activeCall = await fetchActiveCall(conversationId);
          if (activeCall != null) {
            _lastCallError = null;
            _error = null;
            notifyListeners();
            return activeCall;
          }
        }

        final detail = (data?['error'] ?? data?['message'] ?? '').toString();
        _lastCallError = detail.isNotEmpty
            ? 'Failed to start call (${response.statusCode}): $detail'
            : 'Failed to start call (${response.statusCode})';
        _error = _lastCallError;
        notifyListeners();
        return null;
      }
      if (data?['call'] is! Map<String, dynamic>) {
        _lastCallError = 'Invalid call payload from server';
        _error = _lastCallError;
        notifyListeners();
        return null;
      }
      _lastCallError = null;
      return ChatCallSession.fromJson(data!['call']);
    } catch (e) {
      _lastCallError = e.toString();
      _error = _lastCallError;
      notifyListeners();
      return null;
    }
  }

  Future<ChatCallSession?> fetchActiveCall(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationActiveCall(conversationId)}',
        ),
        headers: ApiService.headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load active call (${response.statusCode})');
      }
      final data = json.decode(response.body);
      if (data['call'] is! Map<String, dynamic>) return null;
      return ChatCallSession.fromJson(data['call']);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ChatCallSession?> respondToCall(
    String callId, {
    required String action,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatCallRespond(callId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'action': action}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to respond to call (${response.statusCode})');
      }
      final data = json.decode(response.body);
      if (data['call'] is! Map<String, dynamic>) return null;
      return ChatCallSession.fromJson(data['call']);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ChatCallSession?> endCall(String callId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.chatCallEnd(callId)}'),
        headers: ApiService.headers,
        body: '{}',
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to end call (${response.statusCode})');
      }
      final data = json.decode(response.body);
      if (data['call'] is! Map<String, dynamic>) return null;
      return ChatCallSession.fromJson(data['call']);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ChatMessage?> sendMessage(
    String conversationId,
    String text, {
    String? replyToMessageId,
    List<ChatUploadFile> attachments = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return null;

    try {
      ChatMessage? message;
      if (attachments.isEmpty) {
        message = await _sendMessageJson(
          conversationId,
          trimmed,
          replyToMessageId: replyToMessageId,
        );
      } else {
        message = await _sendMessageMultipart(
          conversationId,
          trimmed,
          attachments: attachments,
          replyToMessageId: replyToMessageId,
        );
      }

      if (message == null) return null;
      _applyNewMessage(conversationId, message);
      _error = null;
      notifyListeners();
      return message;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ChatMessage?> _sendMessageJson(
    String conversationId,
    String text, {
    String? replyToMessageId,
  }) async {
    final payload = <String, dynamic>{'text': text};
    if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty) {
      payload['replyToMessageId'] = replyToMessageId.trim();
    }

    final response = await http.post(
      Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationMessages(conversationId)}',
      ),
      headers: ApiService.headers,
      body: json.encode(payload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'ÙØ´Ù„ Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø±Ø³Ø§Ù„Ø© (${response.statusCode})',
      );
    }

    final data = json.decode(response.body);
    if (data['message'] is! Map<String, dynamic>) return null;
    return ChatMessage.fromJson(data['message']);
  }

  Future<ChatMessage?> _sendMessageMultipart(
    String conversationId,
    String text, {
    required List<ChatUploadFile> attachments,
    String? replyToMessageId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationMessages(conversationId)}',
      ),
    );

    final headers = Map<String, String>.from(ApiService.headers);
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    if (text.isNotEmpty) {
      request.fields['text'] = text;
    }
    if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty) {
      request.fields['replyToMessageId'] = replyToMessageId.trim();
    }

    for (var i = 0; i < attachments.length; i++) {
      final item = attachments[i];
      if (item.durationSec != null) {
        request.fields['attachmentDurationSec_$i'] = item.durationSec
            .toString();
      }

      if (kIsWeb) {
        var webBytes = item.bytes;
        if ((webBytes == null || webBytes.isEmpty) &&
            item.filePath != null &&
            item.filePath!.trim().isNotEmpty) {
          webBytes = await _fetchBytesFromUrl(item.filePath!);
        }
        if (webBytes != null && webBytes.isNotEmpty) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'attachments',
              webBytes,
              filename: item.name,
            ),
          );
        }
        continue;
      }

      if (item.filePath != null && item.filePath!.trim().isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachments',
            item.filePath!,
            filename: item.name,
          ),
        );
      } else if (item.bytes != null && item.bytes!.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'attachments',
            item.bytes!,
            filename: item.name,
          ),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'ÙØ´Ù„ Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ù…Ø±ÙÙ‚ (${response.statusCode})',
      );
    }

    final data = json.decode(response.body);
    if (data['message'] is! Map<String, dynamic>) return null;
    return ChatMessage.fromJson(data['message']);
  }

  Future<List<int>?> _fetchBytesFromUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;
    try {
      final response = await http.get(uri);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _extractError(Map<String, dynamic> data) {
    return (data['error'] ?? data['message'] ?? '').toString().trim();
  }

  void _applyNewMessage(String conversationId, ChatMessage message) {
    final current = List<ChatMessage>.from(
      _messagesByConversation[conversationId] ?? const [],
    );
    current.add(message);
    _messagesByConversation[conversationId] = _normalizeMessages(current);

    final existing = conversationById(conversationId);
    final fallbackText = message.text.trim();
    final preview = fallbackText.isNotEmpty
        ? fallbackText
        : message.attachments.length == 1
        ? (message.attachments.first.isImage
              ? '\u0635\u0648\u0631\u0629'
              : message.attachments.first.isAudio
              ? '\u0631\u0633\u0627\u0644\u0629 \u0635\u0648\u062A\u064A\u0629'
              : message.attachments.first.isVideo
              ? '\u0641\u064A\u062F\u064A\u0648'
              : '\u0645\u0631\u0641\u0642')
        : message.attachments.isNotEmpty
        ? '${message.attachments.length} \u0645\u0631\u0641\u0642\u0627\u062A'
        : '';

    if (existing != null) {
      final updated = existing.copyWith(
        lastMessage: ChatConversationLastMessage(
          id: message.id,
          text: preview,
          senderId: message.senderId,
          senderName: message.senderName,
          sentAt: message.createdAt,
          kind: message.kind,
          attachmentKind: message.attachments.isEmpty
              ? 'none'
              : message.attachments.length == 1
              ? message.attachments.first.kind
              : 'mixed',
        ),
        updatedAt: message.createdAt,
      );
      _upsertConversation(updated, pushToTop: true);
    } else {
      unawaited(fetchConversationById(conversationId, silent: true));
    }
  }

  void _upsertMessage(String conversationId, ChatMessage message) {
    final current = List<ChatMessage>.from(
      _messagesByConversation[conversationId] ?? const [],
    );
    final index = current.indexWhere((entry) => entry.id == message.id);
    if (index >= 0) {
      current[index] = message;
    } else {
      current.add(message);
    }
    _messagesByConversation[conversationId] = _normalizeMessages(current);
  }

  List<ChatMessage> _normalizeMessages(List<ChatMessage> source) {
    final normalized = <ChatMessage>[];
    final indexById = <String, int>{};

    for (final message in source) {
      final id = message.id.trim();
      if (id.isEmpty) {
        normalized.add(message);
        continue;
      }

      final existingIndex = indexById[id];
      if (existingIndex == null) {
        indexById[id] = normalized.length;
        normalized.add(message);
        continue;
      }

      final existing = normalized[existingIndex];
      final existingUpdated = existing.updatedAt ?? existing.createdAt;
      final candidateUpdated = message.updatedAt ?? message.createdAt;
      if (candidateUpdated.isAfter(existingUpdated) ||
          candidateUpdated.isAtSameMomentAs(existingUpdated)) {
        normalized[existingIndex] = message;
      }
    }

    normalized.sort((a, b) {
      final createdCompare = a.createdAt.compareTo(b.createdAt);
      if (createdCompare != 0) return createdCompare;
      final aUpdated = a.updatedAt ?? a.createdAt;
      final bUpdated = b.updatedAt ?? b.createdAt;
      return aUpdated.compareTo(bUpdated);
    });

    return normalized;
  }

  Future<void> markConversationRead(String conversationId) async {
    try {
      await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationRead(conversationId)}',
        ),
        headers: ApiService.headers,
      );
      _setConversationUnread(conversationId, 0);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTyping(
    String conversationId,
    bool isTyping, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    final lastEmit = _typingLastEmitAt[conversationId];
    final previous = _typingState[conversationId];

    if (!force &&
        previous == isTyping &&
        lastEmit != null &&
        now.difference(lastEmit).inMilliseconds < 700) {
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chatConversationTyping(conversationId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'isTyping': isTyping}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _typingState[conversationId] = isTyping;
        _typingLastEmitAt[conversationId] = now;
      }
    } catch (_) {}
  }

  Future<void> pingPresence({bool silent = true}) async {
    try {
      await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.chatPresencePing}'),
        headers: ApiService.headers,
        body: '{}',
      );
    } catch (e) {
      if (!silent) {
        _error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> setPresenceOffline() async {
    try {
      await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.chatPresenceOffline}'),
        headers: ApiService.headers,
        body: '{}',
      );
    } catch (_) {}
  }

  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  void startBackgroundSync() {
    if (_backgroundSyncTimer == null) {
      _backgroundSyncTimer = Timer.periodic(
        const Duration(seconds: 18),
        (_) => fetchConversations(silent: true),
      );
      fetchConversations(silent: true);
    }

    if (_presencePingTimer == null) {
      _presencePingTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => pingPresence(),
      );
      pingPresence();
    }
  }

  void stopBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    _presencePingTimer?.cancel();
    _presencePingTimer = null;
  }

  void startActiveConversationSync(String conversationId) {
    _activeConversationId = conversationId;
    _activeConversationTimer?.cancel();
    _activeConversationTimer = Timer.periodic(const Duration(seconds: 4), (
      _,
    ) async {
      await fetchMessages(conversationId, markRead: true, silent: true);
      await fetchConversationById(conversationId, silent: true);
      await fetchConversations(silent: true);
    });
  }

  void stopActiveConversationSync() {
    _activeConversationTimer?.cancel();
    _activeConversationTimer = null;
    _activeConversationId = null;
  }

  void clearState() {
    final shouldSetOffline = hasRunningSync || _totalUnread > 0;
    stopBackgroundSync();
    stopActiveConversationSync();
    _conversations.clear();
    _users.clear();
    _messagesByConversation.clear();
    _typingState.clear();
    _typingLastEmitAt.clear();
    _isLoadingConversations = false;
    _isLoadingUsers = false;
    _isLoadingMessages = false;
    _error = null;
    _totalUnread = 0;

    if (shouldSetOffline) {
      unawaited(setPresenceOffline());
    }

    notifyListeners();
  }

  void refreshFromPush() {
    fetchConversations(silent: true);
    final active = _activeConversationId;
    if (active != null && active.isNotEmpty) {
      fetchMessages(active, markRead: true, silent: true);
      fetchConversationById(active, silent: true);
    }
  }

  int _computeTotalUnread({dynamic fallback}) {
    final fromConversations = _conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );
    if (fromConversations > 0 || fallback == null) {
      return fromConversations;
    }
    if (fallback is int) return fallback;
    return int.tryParse(fallback.toString()) ?? 0;
  }

  void _setConversationUnread(String conversationId, int value) {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) {
      _totalUnread = _computeTotalUnread();
      return;
    }
    _conversations[index] = _conversations[index].copyWith(unreadCount: value);
    _totalUnread = _computeTotalUnread();
  }

  void _upsertConversation(
    ChatConversation conversation, {
    bool pushToTop = false,
  }) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index >= 0) {
      _conversations[index] = conversation;
      if (pushToTop) {
        final item = _conversations.removeAt(index);
        _conversations.insert(0, item);
      }
    } else {
      if (pushToTop) {
        _conversations.insert(0, conversation);
      } else {
        _conversations.add(conversation);
      }
    }
    _conversations.sort((a, b) {
      final aDate = a.updatedAt ?? a.lastMessage?.sentAt ?? DateTime(1970);
      final bDate = b.updatedAt ?? b.lastMessage?.sentAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    _totalUnread = _computeTotalUnread();
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _activeConversationTimer?.cancel();
    _presencePingTimer?.cancel();
    super.dispose();
  }
}
