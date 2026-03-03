class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final List<NotificationRecipient> recipients;
  final String? createdById;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.recipients,
    this.createdById,
    this.createdByName,
    required this.createdAt,
    required this.expiresAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final dynamic recipientsRaw = json['recipients'];
    final recipientsList = recipientsRaw is List ? recipientsRaw : const [];

    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed ?? fallback ?? DateTime.now();
    }

    return NotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? 'system_alert').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      recipients: recipientsList
          .map((e) => NotificationRecipient.fromJson(e))
          .where((recipient) => recipient.userId.isNotEmpty)
          .toList(),
      createdById: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id'],
      createdByName: json['createdBy'] is Map
          ? json['createdBy']['name']
          : null,
      createdAt: parseDate(json['createdAt']),
      expiresAt: parseDate(
        json['expiresAt'],
        fallback: DateTime.now().add(const Duration(days: 7)),
      ),
    );
  }

  // دالة لإنشاء نسخة جديدة مع قراءة محدثة
  NotificationModel copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    List<NotificationRecipient>? recipients,
    String? createdById,
    String? createdByName,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      recipients: recipients ?? this.recipients,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // دالة لتحديث حالة القراءة لمستلم معين
  NotificationModel markAsReadForUser(String userId) {
    final updatedRecipients = recipients.map((recipient) {
      if (recipient.userId == userId && !recipient.read) {
        return NotificationRecipient(
          userId: recipient.userId,
          read: true,
          readAt: DateTime.now(),
        );
      }
      return recipient;
    }).toList();

    return copyWith(recipients: updatedRecipients);
  }

  // دالة للتحقق مما إذا كان المستخدم قد قرأ الإشعار
  bool isReadByUser(String userId) {
    final recipient = recipients.firstWhere(
      (r) => r.userId == userId,
      orElse: () => NotificationRecipient(userId: '', read: true),
    );
    return recipient.read;
  }

  // دالة للحصول على المستلم الخاص بالمستخدم الحالي
  NotificationRecipient? getRecipientForUser(String userId) {
    try {
      return recipients.firstWhere((r) => r.userId == userId);
    } catch (e) {
      return null;
    }
  }
}

class NotificationRecipient {
  final String userId;
  final bool read;
  final DateTime? readAt;

  NotificationRecipient({
    required this.userId,
    required this.read,
    this.readAt,
  });

  factory NotificationRecipient.fromJson(Map<String, dynamic> json) {
    final dynamic userRaw = json['user'];
    final userId = userRaw is String ? userRaw : userRaw?['_id']?.toString();

    return NotificationRecipient(
      userId: (userId ?? '').toString(),
      read: json['read'] ?? false,
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
    );
  }
}
