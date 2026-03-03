import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaintenanceRecord {
  final String id;
  final String driverId;
  final String driverName;
  final String tankNumber;
  final String plateNumber;
  final String driverLicenseNumber;
  final DateTime driverLicenseExpiry;
  final String vehicleLicenseNumber;
  final DateTime vehicleLicenseExpiry;
  final String inspectionMonth;
  final DateTime inspectionDate;
  final String inspectedById;
  final String inspectedByName;
  final List<DailyCheck> dailyChecks;
  final String monthlyStatus;
  final int totalDays;
  final int completedDays;
  final int pendingDays;
  final List<SupervisorAction> supervisorActions;
  final String vehicleType;
  final String vehicleModel;
  final int vehicleYear;
  final String fuelType;
  final String vehicleOperatingCardNumber;
  final DateTime? vehicleOperatingCardIssueDate;
  final DateTime? vehicleOperatingCardExpiryDate;
  final String driverOperatingCardName;
  final String driverOperatingCardNumber;
  final DateTime? driverOperatingCardIssueDate;
  final DateTime? driverOperatingCardExpiryDate;
  final String vehicleRegistrationSerialNumber;
  final String vehicleRegistrationNumber;
  final DateTime? vehicleRegistrationIssueDate;
  final DateTime? vehicleRegistrationExpiryDate;
  final String driverInsurancePolicyNumber;
  final DateTime? driverInsuranceIssueDate;
  final DateTime? driverInsuranceExpiryDate;
  final String vehicleInsurancePolicyNumber;
  final DateTime? vehicleInsuranceIssueDate;
  final DateTime? vehicleInsuranceExpiryDate;
  final String insuranceNumber;
  final DateTime? insuranceExpiry;
  final String status;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final List<MaintenanceNotification> notifications;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? lastOdometerReading; // آخر قراءة عداد محفوظة
  final int?
  totalDistanceSinceOilChange; // إجمالي الكيلومترات منذ آخر تغيير زيت
  final DateTime? lastOilChangeDate; // تاريخ آخر تغيير زيت

  MaintenanceRecord({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.tankNumber,
    required this.plateNumber,
    required this.driverLicenseNumber,
    required this.driverLicenseExpiry,
    required this.vehicleLicenseNumber,
    required this.vehicleLicenseExpiry,
    required this.inspectionMonth,
    required this.inspectionDate,
    required this.inspectedById,
    required this.inspectedByName,
    required this.dailyChecks,
    required this.monthlyStatus,
    required this.totalDays,
    required this.completedDays,
    required this.pendingDays,
    required this.supervisorActions,
    required this.vehicleType,
    this.vehicleModel = '',
    this.vehicleYear = 0,
    required this.fuelType,
    this.vehicleOperatingCardNumber = '',
    this.vehicleOperatingCardIssueDate,
    this.vehicleOperatingCardExpiryDate,
    this.driverOperatingCardName = '',
    this.driverOperatingCardNumber = '',
    this.driverOperatingCardIssueDate,
    this.driverOperatingCardExpiryDate,
    this.vehicleRegistrationSerialNumber = '',
    this.vehicleRegistrationNumber = '',
    this.vehicleRegistrationIssueDate,
    this.vehicleRegistrationExpiryDate,
    this.driverInsurancePolicyNumber = '',
    this.driverInsuranceIssueDate,
    this.driverInsuranceExpiryDate,
    this.vehicleInsurancePolicyNumber = '',
    this.vehicleInsuranceIssueDate,
    this.vehicleInsuranceExpiryDate,
    this.insuranceNumber = '',
    this.insuranceExpiry,
    required this.status,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    required this.notifications,
    required this.createdAt,
    required this.updatedAt,
    this.lastOdometerReading,
    this.totalDistanceSinceOilChange,
    this.lastOilChangeDate,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['_id'] ?? json['id'],
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? '',
      tankNumber: json['tankNumber'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      driverLicenseNumber: json['driverLicenseNumber'] ?? '',
      driverLicenseExpiry: DateTime.parse(json['driverLicenseExpiry']),
      vehicleLicenseNumber: json['vehicleLicenseNumber'] ?? '',
      vehicleLicenseExpiry: DateTime.parse(json['vehicleLicenseExpiry']),
      inspectionMonth: json['inspectionMonth'] ?? '',
      inspectionDate: DateTime.parse(json['inspectionDate']),
      inspectedById: json['inspectedBy'] is String
          ? json['inspectedBy']
          : json['inspectedBy']?['_id'] ?? '',
      inspectedByName:
          json['inspectedByName'] ?? json['inspectedBy']?['name'] ?? '',
      dailyChecks: (json['dailyChecks'] as List<dynamic>? ?? [])
          .map((e) => DailyCheck.fromJson(e))
          .toList(),
      monthlyStatus: json['monthlyStatus'] ?? 'غير مكتمل',
      totalDays: json['totalDays'] ?? 30,
      completedDays: json['completedDays'] ?? 0,
      pendingDays: json['pendingDays'] ?? 30,
      supervisorActions: (json['supervisorActions'] as List<dynamic>? ?? [])
          .map((e) => SupervisorAction.fromJson(e))
          .toList(),
      vehicleType: json['vehicleType'] ?? 'صهريج وقود',
      vehicleModel: json['vehicleModel'] ?? '',
      vehicleYear: json['vehicleYear'] ?? 0,
      fuelType: json['fuelType'] ?? 'ديزل',
      vehicleOperatingCardNumber: json['vehicleOperatingCardNumber'] ?? '',
      vehicleOperatingCardIssueDate:
          json['vehicleOperatingCardIssueDate'] != null
          ? DateTime.parse(json['vehicleOperatingCardIssueDate'])
          : null,
      vehicleOperatingCardExpiryDate:
          json['vehicleOperatingCardExpiryDate'] != null
          ? DateTime.parse(json['vehicleOperatingCardExpiryDate'])
          : null,
      driverOperatingCardName: json['driverOperatingCardName'] ?? '',
      driverOperatingCardNumber: json['driverOperatingCardNumber'] ?? '',
      driverOperatingCardIssueDate: json['driverOperatingCardIssueDate'] != null
          ? DateTime.parse(json['driverOperatingCardIssueDate'])
          : null,
      driverOperatingCardExpiryDate:
          json['driverOperatingCardExpiryDate'] != null
          ? DateTime.parse(json['driverOperatingCardExpiryDate'])
          : null,
      vehicleRegistrationSerialNumber:
          json['vehicleRegistrationSerialNumber'] ?? '',
      vehicleRegistrationNumber: json['vehicleRegistrationNumber'] ?? '',
      vehicleRegistrationIssueDate: json['vehicleRegistrationIssueDate'] != null
          ? DateTime.parse(json['vehicleRegistrationIssueDate'])
          : null,
      vehicleRegistrationExpiryDate:
          json['vehicleRegistrationExpiryDate'] != null
          ? DateTime.parse(json['vehicleRegistrationExpiryDate'])
          : null,
      driverInsurancePolicyNumber: json['driverInsurancePolicyNumber'] ?? '',
      driverInsuranceIssueDate: json['driverInsuranceIssueDate'] != null
          ? DateTime.parse(json['driverInsuranceIssueDate'])
          : null,
      driverInsuranceExpiryDate: json['driverInsuranceExpiryDate'] != null
          ? DateTime.parse(json['driverInsuranceExpiryDate'])
          : null,
      vehicleInsurancePolicyNumber: json['vehicleInsurancePolicyNumber'] ?? '',
      vehicleInsuranceIssueDate: json['vehicleInsuranceIssueDate'] != null
          ? DateTime.parse(json['vehicleInsuranceIssueDate'])
          : null,
      vehicleInsuranceExpiryDate: json['vehicleInsuranceExpiryDate'] != null
          ? DateTime.parse(json['vehicleInsuranceExpiryDate'])
          : null,
      insuranceNumber: json['insuranceNumber'] ?? '',
      insuranceExpiry: json['insuranceExpiry'] != null
          ? DateTime.parse(json['insuranceExpiry'])
          : null,
      status: json['status'] ?? 'active',
      lastMaintenanceDate: json['lastMaintenanceDate'] != null
          ? DateTime.parse(json['lastMaintenanceDate'])
          : null,
      nextMaintenanceDate: json['nextMaintenanceDate'] != null
          ? DateTime.parse(json['nextMaintenanceDate'])
          : null,
      notifications: (json['notifications'] as List<dynamic>? ?? [])
          .map((e) => MaintenanceNotification.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastOdometerReading: json['lastOdometerReading'],
      totalDistanceSinceOilChange: json['totalDistanceSinceOilChange'],
      lastOilChangeDate: json['lastOilChangeDate'] != null
          ? DateTime.parse(json['lastOilChangeDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'tankNumber': tankNumber,
      'plateNumber': plateNumber,
      'driverLicenseNumber': driverLicenseNumber,
      'driverLicenseExpiry': driverLicenseExpiry.toIso8601String(),
      'vehicleLicenseNumber': vehicleLicenseNumber,
      'vehicleLicenseExpiry': vehicleLicenseExpiry.toIso8601String(),
      'inspectionMonth': inspectionMonth,
      'vehicleType': vehicleType,
      'fuelType': fuelType,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'vehicleOperatingCardNumber': vehicleOperatingCardNumber,
      'vehicleOperatingCardIssueDate': vehicleOperatingCardIssueDate
          ?.toIso8601String(),
      'vehicleOperatingCardExpiryDate': vehicleOperatingCardExpiryDate
          ?.toIso8601String(),
      'driverOperatingCardName': driverOperatingCardName,
      'driverOperatingCardNumber': driverOperatingCardNumber,
      'driverOperatingCardIssueDate': driverOperatingCardIssueDate
          ?.toIso8601String(),
      'driverOperatingCardExpiryDate': driverOperatingCardExpiryDate
          ?.toIso8601String(),
      'vehicleRegistrationSerialNumber': vehicleRegistrationSerialNumber,
      'vehicleRegistrationNumber': vehicleRegistrationNumber,
      'vehicleRegistrationIssueDate': vehicleRegistrationIssueDate
          ?.toIso8601String(),
      'vehicleRegistrationExpiryDate': vehicleRegistrationExpiryDate
          ?.toIso8601String(),
      'driverInsurancePolicyNumber': driverInsurancePolicyNumber,
      'driverInsuranceIssueDate': driverInsuranceIssueDate?.toIso8601String(),
      'driverInsuranceExpiryDate': driverInsuranceExpiryDate?.toIso8601String(),
      'vehicleInsurancePolicyNumber': vehicleInsurancePolicyNumber,
      'vehicleInsuranceIssueDate': vehicleInsuranceIssueDate?.toIso8601String(),
      'vehicleInsuranceExpiryDate': vehicleInsuranceExpiryDate
          ?.toIso8601String(),
      'insuranceNumber': insuranceNumber,
      'insuranceExpiry': insuranceExpiry?.toIso8601String(),
      'lastOdometerReading': lastOdometerReading,
      'totalDistanceSinceOilChange': totalDistanceSinceOilChange,
      'lastOilChangeDate': lastOilChangeDate?.toIso8601String(),
    };
  }

  String get formattedDriverLicenseExpiry =>
      DateFormat('yyyy/MM/dd').format(driverLicenseExpiry);

  String get formattedVehicleLicenseExpiry =>
      DateFormat('yyyy/MM/dd').format(vehicleLicenseExpiry);

  String get formattedInspectionDate =>
      DateFormat('yyyy/MM/dd').format(inspectionDate);

  String get formattedCreatedAt =>
      DateFormat('yyyy/MM/dd HH:mm').format(createdAt);

  String get formattedUpdatedAt =>
      DateFormat('yyyy/MM/dd HH:mm').format(updatedAt);

  double get completionRate =>
      totalDays > 0 ? (completedDays / totalDays) * 100 : 0.0;
}

class DailyCheck {
  final String id;
  final DateTime date;
  final String vehicleSafety;
  final String driverSafety;
  final String electricalMaintenance;
  final String mechanicalMaintenance;
  final String inspectionResult;
  final String maintenanceType;
  final double maintenanceCost;
  final List<MaintenanceInvoice> maintenanceInvoices;
  final String tankInspection;
  final String tiresInspection;
  final String brakesInspection;
  final String lightsInspection;
  final String fluidsCheck;
  final String emergencyEquipment;
  final String notes;
  final String checkedById;
  final String checkedByName;
  final String status;
  final String supervisorNotes;
  final String supervisorAction;
  final DateTime? createdAt;
  // ======================
  // 🚗 Odometer
  // ======================
  final int? odometerReading; // قراءة عداد اليوم
  final int? previousOdometer; // قراءة اليوم السابق
  final int? dailyDistance; // المسافة المقطوعة اليوم

  // ======================
  // 🛢️ Oil
  // ======================
  final String? oilStatus; // طبيعي | قارب على التغيير | يحتاج تغيير
  final bool oilChanged; // هل تم تغيير الزيت اليوم

  DailyCheck({
    required this.id,
    required this.date,
    required this.vehicleSafety,
    required this.driverSafety,
    required this.electricalMaintenance,
    required this.mechanicalMaintenance,
    required this.tankInspection,
    required this.tiresInspection,
    required this.brakesInspection,
    required this.lightsInspection,
    required this.fluidsCheck,
    required this.emergencyEquipment,
    required this.notes,
    required this.checkedById,
    required this.checkedByName,
    required this.status,
    this.supervisorNotes = '',
    this.supervisorAction = 'none',
    this.createdAt,
    required this.inspectionResult,
    required this.maintenanceType,
    required this.maintenanceCost,
    required this.maintenanceInvoices,
    this.odometerReading,
    this.previousOdometer,
    this.dailyDistance,
    this.oilStatus,
    this.oilChanged = false,
  });

  factory DailyCheck.fromJson(Map<String, dynamic> json) {
    return DailyCheck(
      id: json['_id'] ?? json['id'] ?? '',
      date: DateTime.parse(json['date']),
      vehicleSafety: json['vehicleSafety'] ?? 'لم يتم',
      driverSafety: json['driverSafety'] ?? 'لم يتم',
      electricalMaintenance: json['electricalMaintenance'] ?? 'لم يتم',
      mechanicalMaintenance: json['mechanicalMaintenance'] ?? 'لم يتم',
      inspectionResult: json['inspectionResult'] ?? 'تم الفحص ولا يوجد ملاحظات',
      maintenanceType: json['maintenanceType'] ?? '',
      maintenanceCost: (json['maintenanceCost'] is num)
          ? (json['maintenanceCost'] as num).toDouble()
          : double.tryParse(json['maintenanceCost']?.toString() ?? '0') ?? 0.0,
      maintenanceInvoices: (json['maintenanceInvoices'] as List<dynamic>? ?? [])
          .map((e) => MaintenanceInvoice.fromJson(e))
          .toList(),
      tankInspection: json['tankInspection'] ?? 'لم يتم',
      tiresInspection: json['tiresInspection'] ?? 'لم يتم',
      brakesInspection: json['brakesInspection'] ?? 'لم يتم',
      lightsInspection: json['lightsInspection'] ?? 'لم يتم',
      fluidsCheck: json['fluidsCheck'] ?? 'لم يتم',
      emergencyEquipment: json['emergencyEquipment'] ?? 'لم يتم',
      notes: json['notes'] ?? '',
      checkedById: json['checkedBy'] is String
          ? json['checkedBy']
          : json['checkedBy']?['_id'] ?? '',
      checkedByName: json['checkedByName'] ?? json['checkedBy']?['name'] ?? '',
      status: json['status'] ?? 'pending',
      supervisorNotes: json['supervisorNotes'] ?? '',
      supervisorAction: json['supervisorAction'] ?? 'none',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      odometerReading: json['odometerReading'],
      previousOdometer: json['previousOdometer'],
      dailyDistance: json['dailyDistance'],
      oilStatus: json['oilStatus'],
      oilChanged: json['oilChanged'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'vehicleSafety': vehicleSafety,
      'driverSafety': driverSafety,
      'electricalMaintenance': electricalMaintenance,
      'mechanicalMaintenance': mechanicalMaintenance,
      'inspectionResult': inspectionResult,
      'maintenanceType': maintenanceType,
      'maintenanceCost': maintenanceCost,
      'maintenanceInvoices': maintenanceInvoices
          .map((e) => e.toJson())
          .toList(),
      'tankInspection': tankInspection,
      'tiresInspection': tiresInspection,
      'brakesInspection': brakesInspection,
      'lightsInspection': lightsInspection,
      'fluidsCheck': fluidsCheck,
      'emergencyEquipment': emergencyEquipment,
      'notes': notes,
      'odometerReading': odometerReading,
      'previousOdometer': previousOdometer,
      'dailyDistance': dailyDistance,
      'oilStatus': oilStatus,
      'oilChanged': oilChanged,
    };
  }

  String get formattedDate => DateFormat('yyyy/MM/dd').format(date);

  String get formattedCreatedAt => createdAt != null
      ? DateFormat('yyyy/MM/dd HH:mm').format(createdAt!)
      : '';

  int get completedChecksCount {
    final checks = [
      vehicleSafety,
      driverSafety,
      electricalMaintenance,
      mechanicalMaintenance,
      tankInspection,
      tiresInspection,
      brakesInspection,
      lightsInspection,
      fluidsCheck,
      emergencyEquipment,
    ];
    return checks.where((check) => check == 'تم').length;
  }

  int get totalChecksCount => 10;

  double get completionRate => (completedChecksCount / totalChecksCount) * 100;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
  bool get isUnderReview => status == 'under_review';
  bool get isOilWarning => oilStatus == 'قارب على التغيير';
  bool get isOilCritical => oilStatus == 'يحتاج تغيير';
}

class MaintenanceInvoice {
  final String title;
  final String url;

  MaintenanceInvoice({required this.title, required this.url});

  factory MaintenanceInvoice.fromJson(Map<String, dynamic> json) {
    return MaintenanceInvoice(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'url': url};
  }
}

class SupervisorAction {
  final String id;
  final DateTime date;
  final String actionType;
  final String message;
  final List<String> sentToIds;
  final List<String> sentToNames;
  final String sentByName;
  final List<ReadReceipt> readReceipts;

  SupervisorAction({
    required this.id,
    required this.date,
    required this.actionType,
    required this.message,
    required this.sentToIds,
    required this.sentToNames,
    required this.sentByName,
    required this.readReceipts,
  });

  factory SupervisorAction.fromJson(Map<String, dynamic> json) {
    return SupervisorAction(
      id: json['_id'] ?? json['id'] ?? '',
      date: DateTime.parse(json['date']),
      actionType: json['actionType'] ?? 'note',
      message: json['message'] ?? '',
      sentToIds: (json['sentTo'] as List<dynamic>? ?? [])
          .map((e) => e is String ? e : e['_id']?.toString() ?? '')
          .toList(),
      sentToNames: (json['sentTo'] as List<dynamic>? ?? [])
          .map((e) => e is Map ? e['name']?.toString() ?? '' : '')
          .toList(),
      sentByName: json['sentByName'] ?? '',
      readReceipts: (json['readBy'] as List<dynamic>? ?? [])
          .map((e) => ReadReceipt.fromJson(e))
          .toList(),
    );
  }

  String get formattedDate => DateFormat('yyyy/MM/dd HH:mm').format(date);

  String get actionTypeInArabic {
    switch (actionType) {
      case 'warning':
        return 'تحذير';
      case 'note':
        return 'ملاحظة';
      case 'approval':
        return 'موافقة';
      case 'rejection':
        return 'رفض';
      case 'maintenance_scheduled':
        return 'جدولة صيانة';
      default:
        return actionType;
    }
  }

  IconData get actionIcon {
    switch (actionType) {
      case 'warning':
        return Icons.warning;
      case 'note':
        return Icons.note;
      case 'approval':
        return Icons.check_circle;
      case 'rejection':
        return Icons.cancel;
      case 'maintenance_scheduled':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  Color get actionColor {
    switch (actionType) {
      case 'warning':
        return Colors.orange;
      case 'note':
        return Colors.blue;
      case 'approval':
        return Colors.green;
      case 'rejection':
        return Colors.red;
      case 'maintenance_scheduled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class ReadReceipt {
  final String userId;
  final String userName;
  final DateTime readAt;

  ReadReceipt({
    required this.userId,
    required this.userName,
    required this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      userId: json['user'] is String
          ? json['user']
          : json['user']?['_id'] ?? '',
      userName: json['user'] is Map ? json['user']['name'] ?? '' : '',
      readAt: DateTime.parse(json['readAt']),
    );
  }

  String get formattedReadAt => DateFormat('yyyy/MM/dd HH:mm').format(readAt);
}

class MaintenanceNotification {
  final String id;
  final String maintenanceId;
  final String type;
  final String title;
  final String message;
  final String priority;
  final List<NotificationRecipient> recipients;
  final String sentById;
  final String sentByName;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final DateTime expiresAt;

  MaintenanceNotification({
    required this.id,
    required this.maintenanceId,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.recipients,
    required this.sentById,
    required this.sentByName,
    this.data,
    required this.createdAt,
    required this.expiresAt,
  });

  factory MaintenanceNotification.fromJson(Map<String, dynamic> json) {
    return MaintenanceNotification(
      id: json['_id'] ?? json['id'],
      maintenanceId: json['maintenanceId'] is String
          ? json['maintenanceId']
          : json['maintenanceId']?['_id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      priority: json['priority'] ?? 'medium',
      recipients: (json['recipients'] as List<dynamic>? ?? [])
          .map((e) => NotificationRecipient.fromJson(e))
          .toList(),
      sentById: json['sentBy'] is String
          ? json['sentBy']
          : json['sentBy']?['_id'] ?? '',
      sentByName: json['sentByName'] ?? json['sentBy']?['name'] ?? '',
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  String get formattedCreatedAt =>
      DateFormat('yyyy/MM/dd HH:mm').format(createdAt);

  String get typeInArabic {
    switch (type) {
      case 'daily_check_missing':
        return 'فحص يومي مفقود';
      case 'supervisor_warning':
        return 'تحذير من المشرف';
      case 'license_expiry':
        return 'انتهاء الرخصة';
      case 'insurance_expiry':
        return 'انتهاء التأمين';
      case 'maintenance_due':
        return 'موعد صيانة';
      case 'supervisor_note':
        return 'ملاحظة من المشرف';
      case 'check_approved':
        return 'تمت الموافقة على الفحص';
      case 'check_rejected':
        return 'تم رفض الفحص';
      default:
        return type;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool isReadForUser(String userId) {
    return recipients.any(
      (recipient) => recipient.userId == userId && recipient.read,
    );
  }
}

class NotificationRecipient {
  final String userId;
  final String email;
  final bool read;
  final DateTime? readAt;

  NotificationRecipient({
    required this.userId,
    required this.email,
    required this.read,
    this.readAt,
  });

  factory NotificationRecipient.fromJson(Map<String, dynamic> json) {
    return NotificationRecipient(
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      read: json['read'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
    );
  }
}

// Enums for better type safety
enum VehicleType {
  fuelTank('صهريج وقود'),
  gasTanker('ناقلة غاز'),
  lightVehicle('مركبة خفيفة'),
  heavyVehicle('مركبة ثقيلة');

  final String arabicName;
  const VehicleType(this.arabicName);

  static VehicleType fromString(String value) {
    return VehicleType.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => VehicleType.fuelTank,
    );
  }
}

enum FuelType {
  gasoline('بنزين'),
  diesel('ديزل'),
  naturalGas('غاز طبيعي'),
  electric('كهرباء');

  final String arabicName;
  const FuelType(this.arabicName);

  static FuelType fromString(String value) {
    return FuelType.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => FuelType.diesel,
    );
  }
}

enum CheckStatus {
  done('تم'),
  notDone('لم يتم'),
  notRequired('غير مطلوب');

  final String arabicName;
  const CheckStatus(this.arabicName);

  static CheckStatus fromString(String value) {
    return CheckStatus.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => CheckStatus.notDone,
    );
  }
}

enum MaintenanceStatus {
  active('نشط'),
  inactive('غير نشط'),
  underMaintenance('تحت الصيانة'),
  outOfService('خارج الخدمة');

  final String arabicName;
  const MaintenanceStatus(this.arabicName);

  static MaintenanceStatus fromString(String value) {
    return MaintenanceStatus.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => MaintenanceStatus.active,
    );
  }
}

enum MonthlyStatus {
  completed('مكتمل'),
  incomplete('غير مكتمل'),
  underReview('تحت المراجعة'),
  rejected('مرفوض');

  final String arabicName;
  const MonthlyStatus(this.arabicName);

  static MonthlyStatus fromString(String value) {
    return MonthlyStatus.values.firstWhere(
      (e) => e.arabicName == value,
      orElse: () => MonthlyStatus.incomplete,
    );
  }
}

// Response models
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic error;
  final PaginationInfo? pagination;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
    this.pagination,
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
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'])
          : null,
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 1,
    );
  }
}

class MonthlyStats {
  final int totalVehicles;
  final int totalDays;
  final int completedDays;
  final int pendingDays;
  final double completionRate;
  final Map<String, int> vehiclesByStatus;
  final Map<String, Map<String, int>> checksByType;

  MonthlyStats({
    required this.totalVehicles,
    required this.totalDays,
    required this.completedDays,
    required this.pendingDays,
    required this.completionRate,
    required this.vehiclesByStatus,
    required this.checksByType,
  });

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      totalVehicles: json['totalVehicles'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
      completedDays: json['completedDays'] ?? 0,
      pendingDays: json['pendingDays'] ?? 0,
      completionRate: (json['completionRate'] is num)
          ? (json['completionRate'] as num).toDouble()
          : double.tryParse(json['completionRate']?.toString() ?? '0') ?? 0.0,

      vehiclesByStatus: Map<String, int>.from(json['vehiclesByStatus'] ?? {}),
      checksByType: (json['checksByType'] as Map<String, dynamic>? ?? {}).map(
        (key, value) =>
            MapEntry(key, Map<String, int>.from(value as Map<String, dynamic>)),
      ),
    );
  }
}
