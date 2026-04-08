import 'package:order_tracker/models/driver_tracking_models.dart';

class VehicleLinkDriver {
  final String id;
  final String name;
  final String? nationalId;
  final String licenseNumber;
  final String phone;
  final String status;
  final DateTime? licenseExpiryDate;

  const VehicleLinkDriver({
    required this.id,
    required this.name,
    this.nationalId,
    required this.licenseNumber,
    required this.phone,
    required this.status,
    this.licenseExpiryDate,
  });

  factory VehicleLinkDriver.fromJson(Map<String, dynamic> json) {
    return VehicleLinkDriver(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nationalId: json['nationalId']?.toString(),
      licenseNumber: (json['licenseNumber'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      licenseExpiryDate: json['licenseExpiryDate'] != null
          ? DateTime.tryParse(json['licenseExpiryDate'].toString())
          : null,
    );
  }
}

class VehicleLinkTanker {
  final String id;
  final String number;
  final String status;
  final int? capacityLiters;
  final String? fuelType;

  const VehicleLinkTanker({
    required this.id,
    required this.number,
    required this.status,
    this.capacityLiters,
    this.fuelType,
  });

  factory VehicleLinkTanker.fromJson(Map<String, dynamic> json) {
    int? parseCapacity(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }

    return VehicleLinkTanker(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      capacityLiters: parseCapacity(json['capacityLiters']),
      fuelType: json['fuelType']?.toString(),
    );
  }
}

class Vehicle {
  final String id;
  final String plateNumber;
  final String vehicleType;
  final String status;
  final String model;
  final int? year;
  final String? fuelType;
  final String vehicleLicenseNumber;
  final DateTime? vehicleLicenseIssueDate;
  final DateTime? vehicleLicenseExpiry;
  final String vehicleOperatingCardNumber;
  final DateTime? vehicleOperatingCardIssueDate;
  final DateTime? vehicleOperatingCardExpiryDate;
  final String vehicleRegistrationSerialNumber;
  final String vehicleRegistrationNumber;
  final DateTime? vehicleRegistrationIssueDate;
  final DateTime? vehicleRegistrationExpiryDate;
  final String vehicleInsurancePolicyNumber;
  final DateTime? vehicleInsuranceIssueDate;
  final DateTime? vehicleInsuranceExpiryDate;
  final DateTime? vehiclePeriodicInspectionIssueDate;
  final DateTime? vehiclePeriodicInspectionExpiryDate;
  final String vehiclePeriodicInspectionDocumentNumber;
  final String notes;
  final String? linkedDriverId;
  final String? linkedTankerId;
  final VehicleLinkDriver? linkedDriver;
  final VehicleLinkTanker? linkedTanker;
  final bool hasActiveOrder;
  final TrackedOrderSummary? activeOrder;
  final DriverLocationSnapshot? lastLocation;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vehicle({
    required this.id,
    required this.plateNumber,
    required this.vehicleType,
    required this.status,
    this.model = '',
    this.year,
    this.fuelType,
    this.vehicleLicenseNumber = '',
    this.vehicleLicenseIssueDate,
    this.vehicleLicenseExpiry,
    this.vehicleOperatingCardNumber = '',
    this.vehicleOperatingCardIssueDate,
    this.vehicleOperatingCardExpiryDate,
    this.vehicleRegistrationSerialNumber = '',
    this.vehicleRegistrationNumber = '',
    this.vehicleRegistrationIssueDate,
    this.vehicleRegistrationExpiryDate,
    this.vehicleInsurancePolicyNumber = '',
    this.vehicleInsuranceIssueDate,
    this.vehicleInsuranceExpiryDate,
    this.vehiclePeriodicInspectionIssueDate,
    this.vehiclePeriodicInspectionExpiryDate,
    this.vehiclePeriodicInspectionDocumentNumber = '',
    this.notes = '',
    this.linkedDriverId,
    this.linkedTankerId,
    this.linkedDriver,
    this.linkedTanker,
    this.hasActiveOrder = false,
    this.activeOrder,
    this.lastLocation,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vehicle.empty() {
    final now = DateTime.now();
    return Vehicle(
      id: '',
      plateNumber: '',
      vehicleType: 'شاحنة كبيرة',
      status: 'فاضي',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed ?? fallback ?? DateTime.now();
    }

    int? parseYear(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }

    final rawDriver = json['linkedDriver'];
    final rawTanker = json['linkedTanker'];
    final rawOrder = json['activeOrder'];
    final rawLocation = json['lastLocation'];

    return Vehicle(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      plateNumber: (json['plateNumber'] ?? '').toString(),
      vehicleType: (json['vehicleType'] ?? 'شاحنة كبيرة').toString(),
      status: (json['status'] ?? 'فاضي').toString(),
      model: (json['model'] ?? '').toString(),
      year: parseYear(json['year']),
      fuelType: json['fuelType']?.toString(),
      vehicleLicenseNumber: (json['vehicleLicenseNumber'] ?? '').toString(),
      vehicleLicenseIssueDate: json['vehicleLicenseIssueDate'] != null
          ? DateTime.tryParse(json['vehicleLicenseIssueDate'].toString())
          : null,
      vehicleLicenseExpiry: json['vehicleLicenseExpiry'] != null
          ? DateTime.tryParse(json['vehicleLicenseExpiry'].toString())
          : null,
      vehicleOperatingCardNumber:
          (json['vehicleOperatingCardNumber'] ?? '').toString(),
      vehicleOperatingCardIssueDate: json['vehicleOperatingCardIssueDate'] != null
          ? DateTime.tryParse(json['vehicleOperatingCardIssueDate'].toString())
          : null,
      vehicleOperatingCardExpiryDate:
          json['vehicleOperatingCardExpiryDate'] != null
          ? DateTime.tryParse(json['vehicleOperatingCardExpiryDate'].toString())
          : null,
      vehicleRegistrationSerialNumber:
          (json['vehicleRegistrationSerialNumber'] ?? '').toString(),
      vehicleRegistrationNumber:
          (json['vehicleRegistrationNumber'] ?? '').toString(),
      vehicleRegistrationIssueDate:
          json['vehicleRegistrationIssueDate'] != null
          ? DateTime.tryParse(json['vehicleRegistrationIssueDate'].toString())
          : null,
      vehicleRegistrationExpiryDate:
          json['vehicleRegistrationExpiryDate'] != null
          ? DateTime.tryParse(json['vehicleRegistrationExpiryDate'].toString())
          : null,
      vehicleInsurancePolicyNumber:
          (json['vehicleInsurancePolicyNumber'] ?? '').toString(),
      vehicleInsuranceIssueDate: json['vehicleInsuranceIssueDate'] != null
          ? DateTime.tryParse(json['vehicleInsuranceIssueDate'].toString())
          : null,
      vehicleInsuranceExpiryDate: json['vehicleInsuranceExpiryDate'] != null
          ? DateTime.tryParse(json['vehicleInsuranceExpiryDate'].toString())
          : null,
      vehiclePeriodicInspectionIssueDate:
          json['vehiclePeriodicInspectionIssueDate'] != null
          ? DateTime.tryParse(
              json['vehiclePeriodicInspectionIssueDate'].toString(),
            )
          : null,
      vehiclePeriodicInspectionExpiryDate:
          json['vehiclePeriodicInspectionExpiryDate'] != null
          ? DateTime.tryParse(
              json['vehiclePeriodicInspectionExpiryDate'].toString(),
            )
          : null,
      vehiclePeriodicInspectionDocumentNumber:
          (json['vehiclePeriodicInspectionDocumentNumber'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      linkedDriverId:
          json['linkedDriverId']?.toString() ??
          (rawDriver is Map ? rawDriver['_id']?.toString() : null),
      linkedTankerId:
          json['linkedTankerId']?.toString() ??
          (rawTanker is Map ? rawTanker['_id']?.toString() : null),
      linkedDriver: rawDriver is Map
          ? VehicleLinkDriver.fromJson(Map<String, dynamic>.from(rawDriver))
          : null,
      linkedTanker: rawTanker is Map
          ? VehicleLinkTanker.fromJson(Map<String, dynamic>.from(rawTanker))
          : null,
      hasActiveOrder: json['hasActiveOrder'] == true,
      activeOrder: rawOrder is Map
          ? TrackedOrderSummary.fromJson(Map<String, dynamic>.from(rawOrder))
          : null,
      lastLocation: rawLocation is Map
          ? DriverLocationSnapshot.fromJson(
              Map<String, dynamic>.from(rawLocation),
            )
          : null,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plateNumber': plateNumber,
      'vehicleType': vehicleType,
      'status': status,
      'model': model,
      'year': year,
      'fuelType': fuelType,
      'vehicleLicenseNumber': vehicleLicenseNumber,
      'vehicleLicenseIssueDate': vehicleLicenseIssueDate?.toIso8601String(),
      'vehicleLicenseExpiry': vehicleLicenseExpiry?.toIso8601String(),
      'vehicleOperatingCardNumber': vehicleOperatingCardNumber,
      'vehicleOperatingCardIssueDate':
          vehicleOperatingCardIssueDate?.toIso8601String(),
      'vehicleOperatingCardExpiryDate':
          vehicleOperatingCardExpiryDate?.toIso8601String(),
      'vehicleRegistrationSerialNumber': vehicleRegistrationSerialNumber,
      'vehicleRegistrationNumber': vehicleRegistrationNumber,
      'vehicleRegistrationIssueDate':
          vehicleRegistrationIssueDate?.toIso8601String(),
      'vehicleRegistrationExpiryDate':
          vehicleRegistrationExpiryDate?.toIso8601String(),
      'vehicleInsurancePolicyNumber': vehicleInsurancePolicyNumber,
      'vehicleInsuranceIssueDate':
          vehicleInsuranceIssueDate?.toIso8601String(),
      'vehicleInsuranceExpiryDate':
          vehicleInsuranceExpiryDate?.toIso8601String(),
      'vehiclePeriodicInspectionIssueDate':
          vehiclePeriodicInspectionIssueDate?.toIso8601String(),
      'vehiclePeriodicInspectionExpiryDate':
          vehiclePeriodicInspectionExpiryDate?.toIso8601String(),
      'vehiclePeriodicInspectionDocumentNumber':
          vehiclePeriodicInspectionDocumentNumber,
      'notes': notes,
      'linkedDriverId': linkedDriverId,
      'linkedTankerId': linkedTankerId,
    };
  }

  Vehicle copyWith({
    String? id,
    String? plateNumber,
    String? vehicleType,
    String? status,
    String? model,
    int? year,
    String? fuelType,
    String? vehicleLicenseNumber,
    DateTime? vehicleLicenseIssueDate,
    DateTime? vehicleLicenseExpiry,
    String? vehicleOperatingCardNumber,
    DateTime? vehicleOperatingCardIssueDate,
    DateTime? vehicleOperatingCardExpiryDate,
    String? vehicleRegistrationSerialNumber,
    String? vehicleRegistrationNumber,
    DateTime? vehicleRegistrationIssueDate,
    DateTime? vehicleRegistrationExpiryDate,
    String? vehicleInsurancePolicyNumber,
    DateTime? vehicleInsuranceIssueDate,
    DateTime? vehicleInsuranceExpiryDate,
    DateTime? vehiclePeriodicInspectionIssueDate,
    DateTime? vehiclePeriodicInspectionExpiryDate,
    String? vehiclePeriodicInspectionDocumentNumber,
    String? notes,
    String? linkedDriverId,
    String? linkedTankerId,
    VehicleLinkDriver? linkedDriver,
    VehicleLinkTanker? linkedTanker,
    bool? hasActiveOrder,
    TrackedOrderSummary? activeOrder,
    DriverLocationSnapshot? lastLocation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      model: model ?? this.model,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      vehicleLicenseNumber: vehicleLicenseNumber ?? this.vehicleLicenseNumber,
      vehicleLicenseIssueDate:
          vehicleLicenseIssueDate ?? this.vehicleLicenseIssueDate,
      vehicleLicenseExpiry: vehicleLicenseExpiry ?? this.vehicleLicenseExpiry,
      vehicleOperatingCardNumber:
          vehicleOperatingCardNumber ?? this.vehicleOperatingCardNumber,
      vehicleOperatingCardIssueDate: vehicleOperatingCardIssueDate ??
          this.vehicleOperatingCardIssueDate,
      vehicleOperatingCardExpiryDate: vehicleOperatingCardExpiryDate ??
          this.vehicleOperatingCardExpiryDate,
      vehicleRegistrationSerialNumber:
          vehicleRegistrationSerialNumber ??
          this.vehicleRegistrationSerialNumber,
      vehicleRegistrationNumber:
          vehicleRegistrationNumber ?? this.vehicleRegistrationNumber,
      vehicleRegistrationIssueDate:
          vehicleRegistrationIssueDate ?? this.vehicleRegistrationIssueDate,
      vehicleRegistrationExpiryDate:
          vehicleRegistrationExpiryDate ?? this.vehicleRegistrationExpiryDate,
      vehicleInsurancePolicyNumber:
          vehicleInsurancePolicyNumber ?? this.vehicleInsurancePolicyNumber,
      vehicleInsuranceIssueDate:
          vehicleInsuranceIssueDate ?? this.vehicleInsuranceIssueDate,
      vehicleInsuranceExpiryDate:
          vehicleInsuranceExpiryDate ?? this.vehicleInsuranceExpiryDate,
      vehiclePeriodicInspectionIssueDate:
          vehiclePeriodicInspectionIssueDate ??
          this.vehiclePeriodicInspectionIssueDate,
      vehiclePeriodicInspectionExpiryDate:
          vehiclePeriodicInspectionExpiryDate ??
          this.vehiclePeriodicInspectionExpiryDate,
      vehiclePeriodicInspectionDocumentNumber:
          vehiclePeriodicInspectionDocumentNumber ??
          this.vehiclePeriodicInspectionDocumentNumber,
      notes: notes ?? this.notes,
      linkedDriverId: linkedDriverId ?? this.linkedDriverId,
      linkedTankerId: linkedTankerId ?? this.linkedTankerId,
      linkedDriver: linkedDriver ?? this.linkedDriver,
      linkedTanker: linkedTanker ?? this.linkedTanker,
      hasActiveOrder: hasActiveOrder ?? this.hasActiveOrder,
      activeOrder: activeOrder ?? this.activeOrder,
      lastLocation: lastLocation ?? this.lastLocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get optionLabel {
    final parts = <String>[plateNumber];
    if (model.trim().isNotEmpty) parts.add(model.trim());
    if (linkedDriver?.name.trim().isNotEmpty == true) {
      parts.add(linkedDriver!.name.trim());
    }
    return parts.join(' • ');
  }
}
