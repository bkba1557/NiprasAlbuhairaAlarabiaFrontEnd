import 'package:flutter/material.dart';

/// نموذج الملاحظة داخل التطبيق.
class NoteModel {
  /* ---------- الحقول الأساسية ---------- */
  final String id;
  final String title;
  final String message;
  final int repeatDays;
  final int repeatHours;
  final int repeatMinutes;
  final int intervalMinutes;
  final DateTime nextRunAt;
  final bool active;
  final DateTime? lastSentAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// اللون المخزن كـ HEX (مثلاً "FF5722").
  /// إذا كانت القيمة null → يُستَخدم اللون الافتراضي الأزرق.
  final String? colorHex;

  /* ---------- المُنشئ ---------- */
  NoteModel({
    required this.id,
    required this.title,
    required this.message,
    required this.repeatDays,
    required this.repeatHours,
    required this.repeatMinutes,
    required this.intervalMinutes,
    required this.nextRunAt,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.lastSentAt,
    this.colorHex,
  });

  /* ---------- تحويل HEX → Color ----------
   * يُستَخدم في الواجهة لعرض لون الملاحظة.
   */
  Color get color => colorHex == null
      ? const Color(0xFF2196F3) // أزرق Material افتراضي
      : Color(int.parse('0xFF$colorHex'));

  /* ---------- قراءة من JSON ---------- */
  factory NoteModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is DateTime) return value;
      if (value == null) return fallback ?? DateTime.now();
      return DateTime.tryParse(value.toString()) ?? fallback ?? DateTime.now();
    }

    return NoteModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      repeatDays: int.tryParse(json['repeatDays']?.toString() ?? '') ?? 0,
      repeatHours: int.tryParse(json['repeatHours']?.toString() ?? '') ?? 0,
      repeatMinutes: int.tryParse(json['repeatMinutes']?.toString() ?? '') ?? 0,
      intervalMinutes:
          int.tryParse(json['intervalMinutes']?.toString() ?? '') ?? 0,
      nextRunAt: parseDate(json['nextRunAt'], fallback: DateTime.now()),
      active: json['active'] ?? true,
      lastSentAt: json['lastSentAt'] != null
          ? parseDate(json['lastSentAt'])
          : null,
      createdAt: parseDate(json['createdAt'], fallback: DateTime.now()),
      updatedAt: parseDate(json['updatedAt'], fallback: DateTime.now()),
      // قراءة اللون (إذا كان موجودًا)
      colorHex: json['colorHex']?.toString(),
    );
  }

  /* ---------- كتابة إلى JSON ----------
   * يرسل الحقول التي تدعمها الـ backend.
   * إذا لم يدعم الخادم حقل اللون يمكنك إزالته من الـ map
   * (الـ Provider لا يرسل إلا ما هو موجود في `toJson()`).
   */
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'message': message,
      'repeatDays': repeatDays,
      'repeatHours': repeatHours,
      'repeatMinutes': repeatMinutes,
      'intervalMinutes': intervalMinutes,
      'nextRunAt': nextRunAt.toIso8601String(),
      'active': active,
    };

    // أضف اللون إذا كان مُحدَّدًا
    if (colorHex != null) {
      map['colorHex'] = colorHex;
    }

    return map;
  }

  /* ---------- نص مناسب للفترة المتكررة ---------- */
  String get repeatLabel {
    final parts = <String>[];
    if (repeatDays > 0) {
      parts.add('$repeatDays يوم${repeatDays == 1 ? '' : ''}');
    }
    if (repeatHours > 0) {
      parts.add('$repeatHours ساعة${repeatHours == 1 ? '' : ''}');
    }
    if (repeatMinutes > 0) {
      parts.add('$repeatMinutes دقيقة${repeatMinutes == 1 ? '' : ''}');
    }
    return parts.isNotEmpty ? parts.join('، ') : 'مرة واحدة';
  }

  /* ---------- نسخة معدّلة ---------- */
  NoteModel copyWith({
    String? id,
    String? title,
    String? message,
    int? repeatDays,
    int? repeatHours,
    int? repeatMinutes,
    int? intervalMinutes,
    DateTime? nextRunAt,
    bool? active,
    DateTime? lastSentAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? colorHex,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatHours: repeatHours ?? this.repeatHours,
      repeatMinutes: repeatMinutes ?? this.repeatMinutes,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      active: active ?? this.active,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  @override
  String toString() {
    return 'NoteModel('
        'id: $id, '
        'title: $title, '
        'message: $message, '
        'repeatDays: $repeatDays, '
        'repeatHours: $repeatHours, '
        'repeatMinutes: $repeatMinutes, '
        'intervalMinutes: $intervalMinutes, '
        'nextRunAt: $nextRunAt, '
        'active: $active, '
        'lastSentAt: $lastSentAt, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'colorHex: $colorHex'
        ')';
  }
}
