import 'package:order_tracker/utils/constants.dart';

class ChatUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String company;
  final bool isOnline;
  final DateTime? lastSeenAt;

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.company,
    required this.isOnline,
    required this.lastSeenAt,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      isOnline: json['isOnline'] == true,
      lastSeenAt: DateTime.tryParse(json['lastSeenAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'company': company,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }
}

class ChatMessageRead {
  final String userId;
  final DateTime? readAt;

  ChatMessageRead({required this.userId, required this.readAt});

  factory ChatMessageRead.fromJson(Map<String, dynamic> json) {
    return ChatMessageRead(
      userId: (json['userId'] ?? '').toString(),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
    );
  }
}

class ChatMessageDelivery {
  final String userId;
  final DateTime? deliveredAt;

  ChatMessageDelivery({required this.userId, required this.deliveredAt});

  factory ChatMessageDelivery.fromJson(Map<String, dynamic> json) {
    return ChatMessageDelivery(
      userId: (json['userId'] ?? '').toString(),
      deliveredAt: DateTime.tryParse(json['deliveredAt']?.toString() ?? ''),
    );
  }
}

class ChatMessageAttachment {
  final String attachmentId;
  final String kind;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String path;
  final String url;
  final int? durationSec;

  ChatMessageAttachment({
    required this.attachmentId,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.path,
    required this.url,
    required this.durationSec,
  });

  factory ChatMessageAttachment.fromJson(Map<String, dynamic> json) {
    return ChatMessageAttachment(
      attachmentId: (json['attachmentId'] ?? '').toString(),
      kind: (json['kind'] ?? 'file').toString(),
      name: (json['name'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] is int)
          ? json['sizeBytes'] as int
          : int.tryParse((json['sizeBytes'] ?? '0').toString()) ?? 0,
      path: (json['path'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      durationSec: int.tryParse((json['durationSec'] ?? '').toString()),
    );
  }

  String get resolvedUrl {
    final raw = url.trim().isNotEmpty ? url.trim() : path.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = ApiEndpoints.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return '$base$normalized';
  }

  bool get isImage => kind == 'image';
  bool get isAudio => kind == 'audio';
  bool get isVideo => kind == 'video';
}

class ChatMessageReaction {
  final String userId;
  final String emoji;
  final DateTime? reactedAt;

  const ChatMessageReaction({
    required this.userId,
    required this.emoji,
    required this.reactedAt,
  });

  factory ChatMessageReaction.fromJson(Map<String, dynamic> json) {
    return ChatMessageReaction(
      userId: (json['userId'] ?? json['user'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      reactedAt: DateTime.tryParse(json['reactedAt']?.toString() ?? ''),
    );
  }
}

class ChatMessageForwardedFrom {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderName;

  const ChatMessageForwardedFrom({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
  });

  factory ChatMessageForwardedFrom.fromJson(Map<String, dynamic> json) {
    return ChatMessageForwardedFrom(
      messageId: (json['messageId'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String kind;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ChatMessageReply? replyTo;
  final ChatMessageForwardedFrom? forwardedFrom;
  final List<ChatMessageReaction> reactions;
  final List<ChatMessageRead> readBy;
  final List<ChatMessageDelivery> deliveredBy;
  final List<ChatMessageAttachment> attachments;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.replyTo,
    required this.forwardedFrom,
    required this.reactions,
    required this.readBy,
    required this.deliveredBy,
    required this.attachments,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final readByRaw = json['readBy'];
    final deliveredRaw = json['deliveredBy'];
    final attachmentsRaw = json['attachments'];
    final reactionsRaw = json['reactions'];

    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? json['conversation'] ?? '')
          .toString(),
      senderId: (json['senderId'] ?? json['sender'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      kind: (json['kind'] ?? 'text').toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      replyTo: json['replyTo'] is Map<String, dynamic>
          ? ChatMessageReply.fromJson(json['replyTo'])
          : null,
      forwardedFrom: json['forwardedFrom'] is Map<String, dynamic>
          ? ChatMessageForwardedFrom.fromJson(json['forwardedFrom'])
          : null,
      reactions: reactionsRaw is List
          ? reactionsRaw
                .whereType<Map<String, dynamic>>()
                .map(ChatMessageReaction.fromJson)
                .toList()
          : const [],
      readBy: readByRaw is List
          ? readByRaw
                .whereType<Map<String, dynamic>>()
                .map(ChatMessageRead.fromJson)
                .toList()
          : const [],
      deliveredBy: deliveredRaw is List
          ? deliveredRaw
                .whereType<Map<String, dynamic>>()
                .map(ChatMessageDelivery.fromJson)
                .toList()
          : const [],
      attachments: attachmentsRaw is List
          ? attachmentsRaw
                .whereType<Map<String, dynamic>>()
                .map(ChatMessageAttachment.fromJson)
                .toList()
          : const [],
    );
  }

  bool isReadByOther(String myId) {
    return readBy.any(
      (entry) => entry.userId.isNotEmpty && entry.userId != myId,
    );
  }

  bool isDeliveredToOther(String myId) {
    return deliveredBy.any(
      (entry) => entry.userId.isNotEmpty && entry.userId != myId,
    );
  }

  String myReaction(String myId) {
    for (final entry in reactions) {
      if (entry.userId == myId && entry.emoji.trim().isNotEmpty) {
        return entry.emoji.trim();
      }
    }
    return '';
  }
}

class ChatMessageReply {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  ChatMessageReply({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageReply.fromJson(Map<String, dynamic> json) {
    return ChatMessageReply(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class ChatConversationLastMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final DateTime? sentAt;
  final String kind;
  final String attachmentKind;

  ChatConversationLastMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    this.kind = 'text',
    this.attachmentKind = 'none',
  });

  factory ChatConversationLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatConversationLastMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      senderId: (json['senderId'] ?? json['sender'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      sentAt: DateTime.tryParse(
        (json['sentAt'] ?? json['createdAt'] ?? '').toString(),
      ),
      kind: (json['kind'] ?? 'text').toString(),
      attachmentKind: (json['attachmentKind'] ?? 'none').toString(),
    );
  }
}

class ChatConversation {
  final String id;
  final String type;
  final String name;
  final String avatarUrl;
  final String createdById;
  final ChatUser? peer;
  final List<ChatUser> participants;
  final ChatConversationLastMessage? lastMessage;
  final int unreadCount;
  final List<String> typingUserIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    required this.avatarUrl,
    required this.createdById,
    required this.peer,
    required this.participants,
    required this.lastMessage,
    required this.unreadCount,
    required this.typingUserIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final participantsRaw = json['participants'];
    final typingRaw = json['typingUserIds'];
    final peerRaw = json['peer'];
    final peer = peerRaw is Map<String, dynamic>
        ? ChatUser.fromJson(peerRaw)
        : null;

    return ChatConversation(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? 'direct').toString(),
      name: (json['name'] ?? '').toString().trim().isNotEmpty
          ? (json['name'] ?? '').toString().trim()
          : (json['groupName'] ?? '').toString().trim().isNotEmpty
          ? (json['groupName'] ?? '').toString().trim()
          : (peer?.name ?? ''),
      avatarUrl:
          (json['avatarUrl'] ??
                  json['groupAvatarUrl'] ??
                  json['groupAvatarPath'] ??
                  '')
              .toString()
              .trim(),
      createdById: (json['createdById'] ?? json['createdBy'] ?? '')
          .toString()
          .trim(),
      peer: peer,
      participants: participantsRaw is List
          ? participantsRaw
                .whereType<Map<String, dynamic>>()
                .map(ChatUser.fromJson)
                .toList()
          : const [],
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? ChatConversationLastMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: (json['unreadCount'] is int)
          ? json['unreadCount'] as int
          : int.tryParse((json['unreadCount'] ?? '0').toString()) ?? 0,
      typingUserIds: typingRaw is List
          ? typingRaw
                .map((item) => item.toString())
                .where((id) => id.isNotEmpty)
                .toList()
          : const [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  String get resolvedAvatarUrl {
    final raw = avatarUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = ApiEndpoints.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return '$base$normalized';
  }

  ChatConversation copyWith({
    String? id,
    String? type,
    String? name,
    String? avatarUrl,
    String? createdById,
    ChatUser? peer,
    List<ChatUser>? participants,
    ChatConversationLastMessage? lastMessage,
    int? unreadCount,
    List<String>? typingUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdById: createdById ?? this.createdById,
      peer: peer ?? this.peer,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatUploadFile {
  final String name;
  final String mimeType;
  final String? filePath;
  final List<int>? bytes;
  final int? durationSec;

  const ChatUploadFile({
    required this.name,
    required this.mimeType,
    required this.filePath,
    required this.bytes,
    this.durationSec,
  });
}

class ChatCallParticipant {
  final String userId;
  final String name;
  final String email;
  final String state;
  final DateTime? invitedAt;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  const ChatCallParticipant({
    required this.userId,
    required this.name,
    required this.email,
    required this.state,
    required this.invitedAt,
    required this.joinedAt,
    required this.leftAt,
  });

  factory ChatCallParticipant.fromJson(Map<String, dynamic> json) {
    return ChatCallParticipant(
      userId: (json['userId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      state: (json['state'] ?? 'invited').toString(),
      invitedAt: DateTime.tryParse(json['invitedAt']?.toString() ?? ''),
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? ''),
      leftAt: DateTime.tryParse(json['leftAt']?.toString() ?? ''),
    );
  }
}

class ChatCallSession {
  final String id;
  final String conversationId;
  final String callType;
  final String status;
  final String initiatorId;
  final String initiatorName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ChatCallParticipant> participants;

  const ChatCallSession({
    required this.id,
    required this.conversationId,
    required this.callType,
    required this.status,
    required this.initiatorId,
    required this.initiatorName,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
  });

  factory ChatCallSession.fromJson(Map<String, dynamic> json) {
    final participantsRaw = json['participants'];
    return ChatCallSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      callType: (json['callType'] ?? 'audio').toString(),
      status: (json['status'] ?? 'ringing').toString(),
      initiatorId: (json['initiatorId'] ?? '').toString(),
      initiatorName: (json['initiatorName'] ?? '').toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      participants: participantsRaw is List
          ? participantsRaw
                .whereType<Map<String, dynamic>>()
                .map(ChatCallParticipant.fromJson)
                .toList()
          : const [],
    );
  }
}
