class SystemPauseNotice {
  final bool isActive;
  final String title;
  final String message;
  final String developerName;
  final String? createdByName;
  final DateTime? activatedAt;
  final DateTime? updatedAt;

  const SystemPauseNotice({
    required this.isActive,
    required this.title,
    required this.message,
    required this.developerName,
    this.createdByName,
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

    return SystemPauseNotice(
      isActive: isActive,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      developerName: (json['developerName'] ?? '').toString(),
      createdByName: json['createdByName']?.toString(),
      activatedAt: tryParseDate(json['activatedAt']),
      updatedAt: tryParseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isActive': isActive,
      'title': title,
      'message': message,
      'developerName': developerName,
      'createdByName': createdByName,
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
        activatedAt,
        updatedAt,
      );
}

