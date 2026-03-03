class StationInspection {
  final String id;
  final String name;
  final String city;
  final String region;
  final String address;
  final InspectionStatus status;
  final String? createdByName;
  final DateTime createdAt;
  final InspectionLocation? location;
  final InspectionOwner? owner;
  final List<InspectionPump> pumps;
  final String? notes;
  final List<InspectionAttachment> attachments;

  StationInspection({
    required this.id,
    required this.name,
    required this.city,
    required this.region,
    required this.address,
    required this.status,
    required this.createdAt,
    required this.pumps,
    this.createdByName,
    this.location,
    this.owner,
    this.notes,
    this.attachments = const [],
  });

  StationInspection copyWith({
    String? id,
    String? name,
    String? city,
    String? region,
    String? address,
    InspectionStatus? status,
    String? createdByName,
    DateTime? createdAt,
    InspectionLocation? location,
    InspectionOwner? owner,
    List<InspectionPump>? pumps,
    String? notes,
    List<InspectionAttachment>? attachments,
  }) {
    return StationInspection(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      region: region ?? this.region,
      address: address ?? this.address,
      status: status ?? this.status,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      owner: owner ?? this.owner,
      pumps: pumps ?? this.pumps,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
    );
  }

  factory StationInspection.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt']?.toString();
    return StationInspection(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      status: inspectionStatusFromString(json['status']?.toString()),
      createdByName: json['createdByName']?.toString() ??
          (json['createdBy'] is Map
              ? json['createdBy']['name']?.toString()
              : null),
      createdAt: createdAtValue != null
          ? DateTime.tryParse(createdAtValue)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      location: json['location'] is Map<String, dynamic>
          ? InspectionLocation.fromJson(
              Map<String, dynamic>.from(json['location']),
            )
          : null,
      owner: json['owner'] is Map<String, dynamic>
          ? InspectionOwner.fromJson(Map<String, dynamic>.from(json['owner']))
          : null,
      pumps: (json['pumps'] as List<dynamic>? ?? [])
          .map((e) => InspectionPump.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      notes: json['notes']?.toString(),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => InspectionAttachment.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    return {
      if (includeId && id.isNotEmpty) '_id': id,
      'name': name,
      'city': city,
      'region': region,
      'address': address,
      'status': inspectionStatusToString(status),
      'location': location?.toJson(),
      'owner': owner?.toJson(),
      'pumps': pumps.map((p) => p.toJson(includeId: includeId)).toList(),
      'notes': notes,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}

class InspectionLocation {
  final double lat;
  final double lng;

  const InspectionLocation({required this.lat, required this.lng});

  factory InspectionLocation.fromJson(Map<String, dynamic> json) {
    return InspectionLocation(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class InspectionOwner {
  final String name;
  final String phone;
  final String address;

  const InspectionOwner({
    required this.name,
    required this.phone,
    required this.address,
  });

  factory InspectionOwner.fromJson(Map<String, dynamic> json) {
    return InspectionOwner(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
    };
  }
}

class InspectionAttachment {
  final String url;
  final String type;
  final String name;
  final DateTime? createdAt;

  const InspectionAttachment({
    required this.url,
    required this.type,
    required this.name,
    this.createdAt,
  });

  factory InspectionAttachment.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt']?.toString();
    return InspectionAttachment(
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? 'image',
      name: json['name']?.toString() ?? '',
      createdAt: createdAtValue != null
          ? DateTime.tryParse(createdAtValue)?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'name': name,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class InspectionPump {
  final String id;
  final String type;
  final int nozzleCount;
  final PumpCondition status;
  final List<InspectionNozzle> nozzles;
  final double openingReading;
  final DateTime openingReadingDate;
  final double? closingReading;
  final DateTime? closingReadingDate;

  InspectionPump({
    required this.id,
    required this.type,
    required this.nozzleCount,
    required this.status,
    required this.nozzles,
    required this.openingReading,
    required this.openingReadingDate,
    this.closingReading,
    this.closingReadingDate,
  });

  factory InspectionPump.fromJson(Map<String, dynamic> json) {
    final rawNozzles = json['nozzles'] as List<dynamic>? ?? [];
    final parsedNozzles = rawNozzles.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      if (value is Map) {
        final nozzle =
            InspectionNozzle.fromJson(Map<String, dynamic>.from(value));
        return nozzle.nozzleNumber == 0
            ? nozzle.copyWith(nozzleNumber: index + 1)
            : nozzle;
      }
      final status = nozzleStatusFromString(value?.toString());
      return InspectionNozzle(
        nozzleNumber: index + 1,
        status: status,
        fuelType: FuelType.gas91,
        openingReading: 0,
        openingReadingDate: DateTime.now(),
      );
    }).toList();

    return InspectionPump(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      nozzleCount: (json['nozzleCount'] as num?)?.toInt() ??
          (parsedNozzles.isNotEmpty ? parsedNozzles.length : 0),
      status: pumpConditionFromString(json['status']?.toString()),
      nozzles: parsedNozzles.isNotEmpty
          ? parsedNozzles
          : List.generate(
              (json['nozzleCount'] as num?)?.toInt() ?? 0,
              (index) => InspectionNozzle(
                nozzleNumber: index + 1,
                status: NozzleStatus.good,
                fuelType: FuelType.gas91,
                openingReading: 0,
                openingReadingDate: DateTime.now(),
              ),
            ),
      openingReading: (json['openingReading'] as num?)?.toDouble() ?? 0,
      openingReadingDate: json['openingReadingDate'] != null
          ? DateTime.parse(json['openingReadingDate'].toString()).toLocal()
          : DateTime.now(),
      closingReading: json['closingReading'] != null
          ? (json['closingReading'] as num?)?.toDouble()
          : null,
      closingReadingDate: json['closingReadingDate'] != null
          ? DateTime.parse(json['closingReadingDate'].toString()).toLocal()
          : null,
    );
  }

  double get soldLiters {
    final hasNozzleReadings = nozzles.any(
      (nozzle) =>
          nozzle.openingReading != 0 ||
          (nozzle.closingReading ?? 0) != 0,
    );
    if (hasNozzleReadings) {
      return nozzles.fold<double>(
        0,
        (total, nozzle) => total + nozzle.soldLiters,
      );
    }
    if (closingReading == null) return 0;
    final diff = closingReading! - openingReading;
    return diff < 0 ? 0 : diff;
  }

  double get totalOpeningReading {
    if (nozzles.isEmpty) return openingReading;
    return nozzles.fold<double>(
      0,
      (total, nozzle) => total + nozzle.openingReading,
    );
  }

  double get totalClosingReading {
    if (nozzles.isEmpty) return closingReading ?? 0;
    return nozzles.fold<double>(
      0,
      (total, nozzle) => total + (nozzle.closingReading ?? 0),
    );
  }

  InspectionPump copyWith({
    String? id,
    String? type,
    int? nozzleCount,
    PumpCondition? status,
    List<InspectionNozzle>? nozzles,
    double? openingReading,
    DateTime? openingReadingDate,
    double? closingReading,
    DateTime? closingReadingDate,
  }) {
    return InspectionPump(
      id: id ?? this.id,
      type: type ?? this.type,
      nozzleCount: nozzleCount ?? this.nozzleCount,
      status: status ?? this.status,
      nozzles: nozzles ?? this.nozzles,
      openingReading: openingReading ?? this.openingReading,
      openingReadingDate: openingReadingDate ?? this.openingReadingDate,
      closingReading: closingReading ?? this.closingReading,
      closingReadingDate: closingReadingDate ?? this.closingReadingDate,
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    return {
      if (includeId && id.isNotEmpty) '_id': id,
      'type': type,
      'nozzleCount': nozzleCount,
      'status': pumpConditionToString(status),
      'nozzles': nozzles.map((nozzle) => nozzle.toJson()).toList(),
      'openingReading': openingReading,
      'openingReadingDate': openingReadingDate.toIso8601String(),
      'closingReading': closingReading,
      'closingReadingDate': closingReadingDate?.toIso8601String(),
    };
  }
}

class InspectionNozzle {
  final int nozzleNumber;
  final NozzleStatus status;
  final FuelType fuelType;
  final double openingReading;
  final DateTime openingReadingDate;
  final double? closingReading;
  final DateTime? closingReadingDate;

  const InspectionNozzle({
    required this.nozzleNumber,
    required this.status,
    required this.fuelType,
    required this.openingReading,
    required this.openingReadingDate,
    this.closingReading,
    this.closingReadingDate,
  });

  factory InspectionNozzle.fromJson(Map<String, dynamic> json) {
    return InspectionNozzle(
      nozzleNumber: (json['nozzleNumber'] as num?)?.toInt() ?? 0,
      status: nozzleStatusFromString(json['status']?.toString()),
      fuelType: fuelTypeFromString(json['fuelType']?.toString()),
      openingReading: (json['openingReading'] as num?)?.toDouble() ?? 0,
      openingReadingDate: json['openingReadingDate'] != null
          ? DateTime.parse(json['openingReadingDate'].toString()).toLocal()
          : DateTime.now(),
      closingReading: json['closingReading'] != null
          ? (json['closingReading'] as num?)?.toDouble()
          : null,
      closingReadingDate: json['closingReadingDate'] != null
          ? DateTime.parse(json['closingReadingDate'].toString()).toLocal()
          : null,
    );
  }

  InspectionNozzle copyWith({
    int? nozzleNumber,
    NozzleStatus? status,
    FuelType? fuelType,
    double? openingReading,
    DateTime? openingReadingDate,
    double? closingReading,
    DateTime? closingReadingDate,
  }) {
    return InspectionNozzle(
      nozzleNumber: nozzleNumber ?? this.nozzleNumber,
      status: status ?? this.status,
      fuelType: fuelType ?? this.fuelType,
      openingReading: openingReading ?? this.openingReading,
      openingReadingDate: openingReadingDate ?? this.openingReadingDate,
      closingReading: closingReading ?? this.closingReading,
      closingReadingDate: closingReadingDate ?? this.closingReadingDate,
    );
  }

  double get soldLiters {
    if (closingReading == null) return 0;
    final diff = closingReading! - openingReading;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toJson() {
    return {
      'nozzleNumber': nozzleNumber,
      'status': nozzleStatusToString(status),
      'fuelType': fuelTypeToString(fuelType),
      'openingReading': openingReading,
      'openingReadingDate': openingReadingDate.toIso8601String(),
      'closingReading': closingReading,
      'closingReadingDate': closingReadingDate?.toIso8601String(),
    };
  }
}

enum InspectionStatus { pending, accepted, rejected }

enum PumpCondition { good, damaged, needsMaintenance }

enum NozzleStatus { good, damaged, needsMaintenance }

enum FuelType { gas91, gas95, diesel, kerosene }

InspectionStatus inspectionStatusFromString(String? value) {
  switch (value) {
    case 'accepted':
      return InspectionStatus.accepted;
    case 'rejected':
      return InspectionStatus.rejected;
    case 'pending':
    default:
      return InspectionStatus.pending;
  }
}

String inspectionStatusToString(InspectionStatus status) {
  switch (status) {
    case InspectionStatus.accepted:
      return 'accepted';
    case InspectionStatus.rejected:
      return 'rejected';
    case InspectionStatus.pending:
    default:
      return 'pending';
  }
}

PumpCondition pumpConditionFromString(String? value) {
  switch (value) {
    case 'damaged':
      return PumpCondition.damaged;
    case 'needsMaintenance':
      return PumpCondition.needsMaintenance;
    case 'good':
    default:
      return PumpCondition.good;
  }
}

String pumpConditionToString(PumpCondition status) {
  switch (status) {
    case PumpCondition.damaged:
      return 'damaged';
    case PumpCondition.needsMaintenance:
      return 'needsMaintenance';
    case PumpCondition.good:
      return 'good';
  }
}

NozzleStatus nozzleStatusFromString(String? value) {
  switch (value) {
    case 'damaged':
      return NozzleStatus.damaged;
    case 'needsMaintenance':
      return NozzleStatus.needsMaintenance;
    case 'good':
    default:
      return NozzleStatus.good;
  }
}

String nozzleStatusToString(NozzleStatus status) {
  switch (status) {
    case NozzleStatus.damaged:
      return 'damaged';
    case NozzleStatus.needsMaintenance:
      return 'needsMaintenance';
    case NozzleStatus.good:
      return 'good';
  }
}

FuelType fuelTypeFromString(String? value) {
  switch (value) {
    case 'gas95':
      return FuelType.gas95;
    case 'diesel':
      return FuelType.diesel;
    case 'kerosene':
      return FuelType.kerosene;
    case 'gas91':
    default:
      return FuelType.gas91;
  }
}

String fuelTypeToString(FuelType type) {
  switch (type) {
    case FuelType.gas95:
      return 'gas95';
    case FuelType.diesel:
      return 'diesel';
    case FuelType.kerosene:
      return 'kerosene';
    case FuelType.gas91:
      return 'gas91';
  }
}
