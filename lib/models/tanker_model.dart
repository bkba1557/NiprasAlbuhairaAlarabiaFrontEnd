class Tanker {
  final String id;
  final String number;
  final String status;
  final int? capacityLiters;
  final String? fuelType;
  final String? linkedDriverId;
  final String? linkedDriverName;
  final String? linkedVehicleNumber;
  final String? linkedVehicleType;
  final String? aramcoStickerMode;
  final String? aramcoUnifiedSticker;
  final String? aramcoHeadSticker;
  final String? aramcoTankerSticker;
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
    this.linkedVehicleNumber,
    this.linkedVehicleType,
    this.aramcoStickerMode,
    this.aramcoUnifiedSticker,
    this.aramcoHeadSticker,
    this.aramcoTankerSticker,
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
    final linkedDriver = rawDriver is Map<String, dynamic>
        ? rawDriver
        : rawDriver is Map
        ? Map<String, dynamic>.from(rawDriver)
        : null;

    final aramcoUnifiedSticker = parseOptionalString(
      json['aramcoUnifiedSticker'],
    );
    final aramcoHeadSticker = parseOptionalString(json['aramcoHeadSticker']);
    final aramcoTankerSticker = parseOptionalString(
      json['aramcoTankerSticker'],
    );
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
          linkedDriver?['_id']?.toString() ??
          linkedDriver?['id']?.toString() ??
          json['linkedDriverId']?.toString() ??
          json['driverId']?.toString(),
      linkedDriverName:
          linkedDriver?['name']?.toString() ??
          json['linkedDriverName']?.toString() ??
          json['driverName']?.toString(),
      linkedVehicleNumber:
          linkedDriver?['vehicleNumber']?.toString() ??
          json['vehicleNumber']?.toString(),
      linkedVehicleType:
          linkedDriver?['vehicleType']?.toString() ??
          json['vehicleType']?.toString(),
      aramcoStickerMode: aramcoStickerMode,
      aramcoUnifiedSticker: aramcoUnifiedSticker,
      aramcoHeadSticker: aramcoHeadSticker,
      aramcoTankerSticker: aramcoTankerSticker,
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
      'linkedDriverId': linkedDriverId,
      'aramcoStickerMode': aramcoStickerMode,
      'aramcoUnifiedSticker': aramcoUnifiedSticker,
      'aramcoHeadSticker': aramcoHeadSticker,
      'aramcoTankerSticker': aramcoTankerSticker,
      'notes': notes,
    };
  }
}
