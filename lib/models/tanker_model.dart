class Tanker {
  final String id;
  final String number;
  final String status;
  final int? capacityLiters;
  final String? fuelType;
  final String? linkedDriverId;
  final String? linkedDriverName;
  final String? linkedVehicleId;
  final String? linkedVehicleNumber;
  final String? linkedVehicleType;
  final String? aramcoStickerMode;
  final String? aramcoUnifiedSticker;
  final DateTime? aramcoUnifiedStickerExpiryDate;
  final String? aramcoHeadSticker;
  final DateTime? aramcoHeadStickerExpiryDate;
  final String? aramcoTankerSticker;
  final DateTime? aramcoTankerStickerExpiryDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tanker({
    required this.id,
    required this.number,
    required this.status,
    this.capacityLiters,
    this.fuelType,
    this.linkedDriverId,
    this.linkedDriverName,
    this.linkedVehicleId,
    this.linkedVehicleNumber,
    this.linkedVehicleType,
    this.aramcoStickerMode,
    this.aramcoUnifiedSticker,
    this.aramcoUnifiedStickerExpiryDate,
    this.aramcoHeadSticker,
    this.aramcoHeadStickerExpiryDate,
    this.aramcoTankerSticker,
    this.aramcoTankerStickerExpiryDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasAramcoStickerData =>
      (aramcoUnifiedSticker?.trim().isNotEmpty ?? false) ||
      (aramcoHeadSticker?.trim().isNotEmpty ?? false) ||
      (aramcoTankerSticker?.trim().isNotEmpty ?? false);

  factory Tanker.empty() {
    final now = DateTime.now();
    return Tanker(
      id: '',
      number: '',
      status: 'فاضي',
      capacityLiters: null,
      fuelType: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Tanker.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      return parsed ?? fallback ?? DateTime.now();
    }

    int? parseCapacity(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }

    String? parseOptionalString(dynamic value) {
      if (value == null) return null;
      final normalized = value.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }

    final rawDriver = json['linkedDriver'];
    final rawVehicle = json['linkedVehicle'];

    final aramcoUnifiedSticker = parseOptionalString(
      json['aramcoUnifiedSticker'],
    );
    final aramcoUnifiedStickerExpiryDate = json['aramcoUnifiedStickerExpiryDate'] !=
            null
        ? DateTime.tryParse(json['aramcoUnifiedStickerExpiryDate'].toString())
        : null;
    final aramcoHeadSticker = parseOptionalString(json['aramcoHeadSticker']);
    final aramcoHeadStickerExpiryDate = json['aramcoHeadStickerExpiryDate'] != null
        ? DateTime.tryParse(json['aramcoHeadStickerExpiryDate'].toString())
        : null;
    final aramcoTankerSticker = parseOptionalString(
      json['aramcoTankerSticker'],
    );
    final aramcoTankerStickerExpiryDate =
        json['aramcoTankerStickerExpiryDate'] != null
            ? DateTime.tryParse(json['aramcoTankerStickerExpiryDate'].toString())
            : null;
    final aramcoStickerMode =
        parseOptionalString(json['aramcoStickerMode']) ??
        (aramcoUnifiedSticker != null
            ? 'موحد'
            : (aramcoHeadSticker != null || aramcoTankerSticker != null)
            ? 'منفصل'
            : null);

    return Tanker(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      number: (json['number'] ?? json['tankerNumber'] ?? '').toString(),
      status: (json['status'] ?? 'فاضي').toString(),
      capacityLiters: parseCapacity(json['capacityLiters'] ?? json['capacity']),
      fuelType: parseOptionalString(json['fuelType']),
      linkedDriverId:
          (rawDriver is Map ? rawDriver['_id']?.toString() : null) ??
          json['linkedDriverId']?.toString() ??
          json['driverId']?.toString(),
      linkedDriverName:
          (rawDriver is Map ? rawDriver['name']?.toString() : null) ??
          json['linkedDriverName']?.toString() ??
          json['driverName']?.toString(),
      linkedVehicleId:
          json['linkedVehicleId']?.toString() ??
          (rawVehicle is Map ? rawVehicle['_id']?.toString() : null),
      linkedVehicleNumber:
          json['linkedVehicleNumber']?.toString() ??
          (rawVehicle is Map ? rawVehicle['plateNumber']?.toString() : null) ??
          json['vehicleNumber']?.toString(),
      linkedVehicleType:
          json['linkedVehicleType']?.toString() ??
          (rawVehicle is Map ? rawVehicle['vehicleType']?.toString() : null) ??
          json['vehicleType']?.toString(),
      aramcoStickerMode: aramcoStickerMode,
      aramcoUnifiedSticker: aramcoUnifiedSticker,
      aramcoUnifiedStickerExpiryDate: aramcoUnifiedStickerExpiryDate,
      aramcoHeadSticker: aramcoHeadSticker,
      aramcoHeadStickerExpiryDate: aramcoHeadStickerExpiryDate,
      aramcoTankerSticker: aramcoTankerSticker,
      aramcoTankerStickerExpiryDate: aramcoTankerStickerExpiryDate,
      notes: parseOptionalString(json['notes']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'status': status,
      'capacityLiters': capacityLiters,
      'fuelType': fuelType,
      'linkedVehicleId': linkedVehicleId,
      'aramcoStickerMode': aramcoStickerMode,
      'aramcoUnifiedSticker': aramcoUnifiedSticker,
      'aramcoUnifiedStickerExpiryDate':
          aramcoUnifiedStickerExpiryDate?.toIso8601String(),
      'aramcoHeadSticker': aramcoHeadSticker,
      'aramcoHeadStickerExpiryDate':
          aramcoHeadStickerExpiryDate?.toIso8601String(),
      'aramcoTankerSticker': aramcoTankerSticker,
      'aramcoTankerStickerExpiryDate':
          aramcoTankerStickerExpiryDate?.toIso8601String(),
      'notes': notes,
    };
  }
}
