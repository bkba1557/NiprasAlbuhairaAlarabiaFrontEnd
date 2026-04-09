import 'package:flutter/foundation.dart';

class SystemPauseNotice {
  final bool isActive;
  final String title;
  final String message;
  final String developerName;
  final String? createdByName;
  final String targetScope;
  final List<String> targetUserIds;
  final List<String> targetUserNames;
  final DateTime? activatedAt;
  final DateTime? updatedAt;

  const SystemPauseNotice({
    required this.isActive,
    required this.title,
    required this.message,
    required this.developerName,
    this.createdByName,
    this.targetScope = 'all',
    this.targetUserIds = const <String>[],
    this.targetUserNames = const <String>[],
    this.activatedAt,
    this.updatedAt,
  });

  factory SystemPauseNotice.fromJson(Map<String, dynamic> json) {
    final rawActive = json['isActive'];
    final isActive = rawActive is bool
        ? rawActive
        : rawActive?.toString().toLowerCase() == 'true';

    DateTime? tryParseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final targetUsersRaw =
        json['targetUsers'] ?? json['selectedUsers'] ?? json['recipients'];
    final targetUserIds = <String>{
      ..._parseStringList(
        json['targetUserIds'] ??
            json['selectedUserIds'] ??
            json['recipientUserIds'] ??
            json['userIds'],
      ),
      ..._parseUserIds(targetUsersRaw),
    }.toList();
    final targetUserNames = <String>{
      ..._parseStringList(json['targetUserNames'] ?? json['selectedUserNames']),
      ..._parseUserNames(targetUsersRaw),
    }.toList();

    return SystemPauseNotice(
      isActive: isActive,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      developerName: (json['developerName'] ?? '').toString(),
      createdByName: _extractCreatedByName(json),
      targetScope: _normalizeTargetScope(json, targetUserIds, targetUserNames),
      targetUserIds: targetUserIds,
      targetUserNames: targetUserNames,
      activatedAt: tryParseDate(json['activatedAt']),
      updatedAt: tryParseDate(json['updatedAt']),
    );
  }

  bool get targetsAll => targetScope != 'selected';

  String get actorDisplayName {
    final actor = (createdByName ?? '').trim();
    if (actor.isNotEmpty) return actor;

    final legacyActor = developerName.trim();
    if (legacyActor.isNotEmpty) return legacyActor;

    return 'غير محدد';
  }

  String get audienceSummary {
    if (targetsAll) return '\u062C\u0645\u064A\u0639 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645\u064A\u0646 \u0645\u0627 \u0639\u062F\u0627 \u0627\u0644\u0645\u0627\u0644\u0643';

    final count = targetUserIds.isNotEmpty
        ? targetUserIds.length
        : targetUserNames.length;
    if (count <= 0) return 'مستخدمون محددون';
    if (count == 1) return 'مستخدم واحد';
    return '$count مستخدمين محددين';
  }

  bool appliesToUserId(String? userId) {
    if (!isActive) return false;
    if (targetsAll) return true;

    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) return false;

    return targetUserIds.contains(normalizedUserId);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isActive': isActive,
      'title': title,
      'message': message,
      'developerName': developerName,
      'createdByName': createdByName,
      'targetScope': targetScope,
      'targetUserIds': targetUserIds,
      'targetUserNames': targetUserNames,
      'activatedAt': activatedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemPauseNotice &&
        other.isActive == isActive &&
        other.title == title &&
        other.message == message &&
        other.developerName == developerName &&
        other.createdByName == createdByName &&
        other.targetScope == targetScope &&
        listEquals(other.targetUserIds, targetUserIds) &&
        listEquals(other.targetUserNames, targetUserNames) &&
        other.activatedAt == activatedAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    isActive,
    title,
    message,
    developerName,
    createdByName,
    targetScope,
    Object.hashAll(targetUserIds),
    Object.hashAll(targetUserNames),
    activatedAt,
    updatedAt,
  );

  static String? _extractCreatedByName(Map<String, dynamic> json) {
    final direct = json['createdByName']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final createdBy = json['createdBy'];
    if (createdBy is Map) {
      final name = createdBy['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }

    return null;
  }

  static String _normalizeTargetScope(
    Map<String, dynamic> json,
    List<String> targetUserIds,
    List<String> targetUserNames,
  ) {
    final rawScope =
        (json['targetScope'] ??
                json['audience'] ??
                json['targetType'] ??
                json['scope'])
            ?.toString()
            .trim()
            .toLowerCase();

    switch (rawScope) {
      case 'selected':
      case 'specific':
      case 'users':
      case 'selected_users':
        return 'selected';
      case 'all':
      case 'everyone':
      case 'all_users':
      case 'global':
        return 'all';
      default:
        return targetUserIds.isNotEmpty || targetUserNames.isNotEmpty
            ? 'selected'
            : 'all';
    }
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const <String>[];

    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return const <String>[];
      return normalized
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return <String>[value.toString()];
  }

  static List<String> _parseUserIds(dynamic value) {
    if (value is! Iterable) return const <String>[];

    return value
        .map((item) {
          if (item is Map) {
            return (item['_id'] ?? item['id'] ?? item['userId'])
                ?.toString()
                .trim();
          }
          return null;
        })
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _parseUserNames(dynamic value) {
    if (value is! Iterable) return const <String>[];

    return value
        .map((item) {
          if (item is Map) {
            return (item['name'] ?? item['fullName'])?.toString().trim();
          }
          if (item is String) return item.trim();
          return null;
        })
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

