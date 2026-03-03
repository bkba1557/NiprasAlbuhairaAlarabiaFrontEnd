import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String company;
  final String? phone;
  final DateTime? createdAt;
  final String? stationId;
  final String? stationName;
  final String? stationCode;
  final bool isBlocked;
  final List<String> permissions;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.company,
    this.phone,
    this.createdAt,
    this.stationId,
    this.stationName,
    this.stationCode,
    this.isBlocked = false,
    this.permissions = const [],
  });

  // =========================
  // ✅ FIXED fromJson (MongoDB Safe)
  // =========================
  factory User.fromJson(Map<String, dynamic> json) {
    // 🔐 stationId قد يكون String أو ObjectId
    String? parsedStationId;
    if (json['stationId'] is Map) {
      parsedStationId = json['stationId']['_id'] ?? json['stationId']['\$oid'];
    } else if (json['stationId'] is String) {
      parsedStationId = json['stationId'];
    }

    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      company: json['company'] ?? '',
      phone: json['phone'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      stationId: parsedStationId,
      stationName: json['stationName'],
      stationCode: json['stationCode'],
      isBlocked: json['isBlocked'] ?? false,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  // =========================
  // toJson
  // =========================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'company': company,
      'phone': phone,
      'createdAt': createdAt?.toIso8601String(),
      'stationId': stationId,
      'stationName': stationName,
      'stationCode': stationCode,
      'isBlocked': isBlocked,
      'permissions': permissions,
    };
  }
}

extension UserPermissionHelpers on User {
  bool hasPermission(String key) {
    if (role == 'owner' || role == 'admin') {
      return true;
    }

    if (permissions.contains(key)) {
      return true;
    }

    if (key.startsWith('orders_') && permissions.contains('orders_manage')) {
      return true;
    }

    if (key.startsWith('customers_') &&
        permissions.contains('customers_manage')) {
      return true;
    }

    if (key.startsWith('drivers_') && permissions.contains('drivers_manage')) {
      return true;
    }

    if (key.startsWith('suppliers_') &&
        permissions.contains('suppliers_manage')) {
      return true;
    }

    return false;
  }

  bool hasAnyPermission(Iterable<String> keys) {
    return keys.any(hasPermission);
  }
}

class OrderTimer {
  final String orderId;
  final DateTime arrivalDateTime;
  final DateTime loadingDateTime;
  final String orderNumber;
  final String supplierName;
  final String? customerName;
  final String? driverName;
  final String status;

  OrderTimer({
    required this.orderId,
    required this.arrivalDateTime,
    required this.loadingDateTime,
    required this.orderNumber,
    required this.supplierName,
    this.customerName,
    this.driverName,
    required this.status,
  });

  Duration get remainingTimeToArrival {
    final now = DateTime.now();
    return arrivalDateTime.difference(now);
  }

  Duration get remainingTimeToLoading {
    final now = DateTime.now();
    return loadingDateTime.difference(now);
  }

  bool get shouldShowCountdown {
    return status != 'تم التحميل' && status != 'ملغى';
  }

  bool get isApproachingArrival {
    return remainingTimeToArrival <= const Duration(hours: 2, minutes: 30) &&
        remainingTimeToArrival > Duration.zero;
  }

  bool get isApproachingLoading {
    return remainingTimeToLoading <= const Duration(hours: 2, minutes: 30) &&
        remainingTimeToLoading > Duration.zero;
  }

  bool get isOverdue {
    return remainingTimeToLoading < Duration.zero;
  }

  String get formattedArrivalCountdown {
    if (!shouldShowCountdown) return '--:--:--';

    final remaining = remainingTimeToArrival;

    if (remaining <= Duration.zero) {
      return '00:00:00';
    }

    return _formatDurationHMS(remaining);
  }

  String get formattedLoadingCountdown {
    if (!shouldShowCountdown) return '--:--:--';

    final remaining = remainingTimeToLoading;

    if (remaining <= Duration.zero) {
      return '00:00:00';
    }

    return _formatDurationHMS(remaining);
  }

  String _formatDurationHMS(Duration duration) {
    final totalSeconds = duration.inSeconds;

    if (totalSeconds <= 0) {
      return '00:00:00';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days} يوم ${hours} ساعة';
    } else if (hours > 0) {
      return '${hours} ساعة ${minutes} دقيقة';
    } else if (minutes > 0) {
      return '${minutes} دقيقة';
    } else {
      return 'أقل من دقيقة';
    }
  }

  Color get countdownColor {
    if (!shouldShowCountdown) return Colors.grey;

    if (isOverdue) return Colors.red; // ⬅️ الأول

    if (isApproachingArrival || isApproachingLoading) {
      return Colors.orange;
    }

    return Colors.green;
  }

  IconData get countdownIcon {
    if (isOverdue) return Icons.warning;
    if (isApproachingArrival) return Icons.access_time_filled;
    if (isApproachingLoading) return Icons.timer;
    return Icons.schedule;
  }
}

class Attachment {
  final String id;
  final String filename;
  final String path;
  final DateTime uploadedAt;

  Attachment({
    required this.id,
    required this.filename,
    required this.path,
    required this.uploadedAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['_id'] ?? json['id'] ?? '',
      filename: json['filename'],
      path: json['path'],
      uploadedAt: DateTime.parse(
        json['uploadedAt'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'filename': filename, 'path': path};
  }
}

// activity_model.dart
class Activity {
  final String id;
  final String orderId;
  final String activityType;
  final String description;
  final String performedById;
  final String performedByName;
  final Map<String, String>? changes;
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.orderId,
    required this.activityType,
    required this.description,
    required this.performedById,
    required this.performedByName,
    this.changes,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['_id'] ?? json['id'],
      orderId: json['orderId'] is String
          ? json['orderId']
          : json['orderId']?['_id'] ?? '',
      activityType: json['activityType'],
      description: json['description'],
      performedById: json['performedBy'] is String
          ? json['performedBy']
          : json['performedBy']?['_id'] ?? '',
      performedByName:
          json['performedByName'] ?? json['performedBy']?['name'] ?? '',
      changes: json['changes'] != null
          ? Map<String, String>.from(json['changes'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'activityType': activityType,
      'description': description,
    };
  }
}

// api_response_model.dart
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic error;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJson,
  ) {
    return ApiResponse(
      success: json['success'] ?? true,
      message: json['message'] ?? '',
      data: fromJson != null && json['data'] != null
          ? fromJson(json['data'])
          : json['data'],
      error: json['error'],
    );
  }
}

// enums.dart
enum OrderStatus {
  pending('في انتظار عمل طلب جديد', AppColors.pendingYellow),
  assigned('مخصص للعميل', AppColors.infoBlue),
  processing('قيد التجهيز', AppColors.warningOrange),
  ready('جاهز للتحميل', AppColors.infoBlue),
  completed('تم التحميل', AppColors.successGreen),
  cancelled('ملغى', AppColors.errorRed);

  final String arabicName;
  final Color color;

  const OrderStatus(this.arabicName, this.color);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

// إضافة أنواع الطلبات الجديدة
enum RequestType {
  fuelSupply('تزويد وقود'),
  maintenance('صيانة'),
  logistics('خدمات لوجستية'),
  supplier('مورد'), // جديد
  other('أخرى');

  final String arabicName;

  const RequestType(this.arabicName);

  static RequestType fromString(String value) {
    return RequestType.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => RequestType.fuelSupply,
    );
  }
}

// أنواع الإشعارات
enum NotificationType {
  orderCreated('order_created', 'طلب جديد'),
  orderAssigned('order_assigned', 'تعيين طلب'),
  orderOverdue('order_overdue', 'طلب متأخر'),
  orderUpdated('order_updated', 'تحديث طلب'),
  system('system', 'نظام');

  final String value;
  final String arabicName;

  const NotificationType(this.value, this.arabicName);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

enum FuelType {
  gasoline91('بنزين 91'),
  gasoline95('بنزين 95'),
  diesel('ديزل'),
  kerosene('كيروسين'),
  naturalGas('غاز طبيعي');

  final String arabicName;

  const FuelType(this.arabicName);

  static FuelType fromString(String value) {
    return FuelType.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => FuelType.diesel,
    );
  }
}

enum UnitType {
  liter('لتر'),
  gallon('جالون'),
  barrel('برميل'),
  ton('طن');

  final String arabicName;

  const UnitType(this.arabicName);

  static UnitType fromString(String value) {
    return UnitType.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => UnitType.liter,
    );
  }
}

enum ActivityType {
  create('إنشاء'),
  update('تعديل'),
  delete('حذف'),
  statusChange('تغيير حالة'),
  note('إضافة ملاحظة'),
  upload('رفع ملف');

  final String arabicName;

  const ActivityType(this.arabicName);

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => ActivityType.update,
    );
  }
}
