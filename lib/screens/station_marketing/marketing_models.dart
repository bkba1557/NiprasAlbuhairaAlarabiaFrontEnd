class MarketingStation {
  final String id;
  final String name;
  final String city;
  final String address;
  final StationMarketingStatus status;
  final String? tenantName;
  final String? createdByName;
  final DateTime createdAt;
  final StationLocation? location;
  final StationOwner? owner;
  final List<MarketingPump> pumps;
  final String? notes;
  final List<String> attachments;
  final LeaseContract? lease;
  final MarketingAccounting accounting;
  final HandoverReport? handoverReport;
  final List<StationExpense> expenseVouchers;
  final List<StationReceipt> receiptVouchers;

  MarketingStation({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.status,
    required this.createdAt,
    required this.pumps,
    this.tenantName,
    this.createdByName,
    this.location,
    this.owner,
    this.notes,
    this.attachments = const [],
    this.lease,
    this.accounting = const MarketingAccounting(),
    this.handoverReport,
    this.expenseVouchers = const [],
    this.receiptVouchers = const [],
  });

  MarketingStation copyWith({
    String? id,
    String? name,
    String? city,
    String? address,
    StationMarketingStatus? status,
    String? tenantName,
    String? createdByName,
    DateTime? createdAt,
    StationLocation? location,
    StationOwner? owner,
    List<MarketingPump>? pumps,
    String? notes,
    List<String>? attachments,
    LeaseContract? lease,
    MarketingAccounting? accounting,
    HandoverReport? handoverReport,
    List<StationExpense>? expenseVouchers,
    List<StationReceipt>? receiptVouchers,
  }) {
    return MarketingStation(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      status: status ?? this.status,
      tenantName: tenantName ?? this.tenantName,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      owner: owner ?? this.owner,
      pumps: pumps ?? this.pumps,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      lease: lease ?? this.lease,
      accounting: accounting ?? this.accounting,
      handoverReport: handoverReport ?? this.handoverReport,
      expenseVouchers: expenseVouchers ?? this.expenseVouchers,
      receiptVouchers: receiptVouchers ?? this.receiptVouchers,
    );
  }

  factory MarketingStation.fromJson(Map<String, dynamic> json) {
    final rawLocation = json['location'] as Map<String, dynamic>?;
    final createdAtValue = json['createdAt']?.toString();
    return MarketingStation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      status: stationStatusFromString(json['status']?.toString()),
      tenantName: json['tenantName']?.toString(),
      createdByName: json['createdByName']?.toString() ??
          (json['createdBy'] is Map
              ? json['createdBy']['name']?.toString()
              : null),
      createdAt: createdAtValue != null
          ? DateTime.tryParse(createdAtValue)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      location:
          rawLocation == null ? null : StationLocation.fromJson(rawLocation),
      owner: json['owner'] is Map<String, dynamic>
          ? StationOwner.fromJson(Map<String, dynamic>.from(json['owner']))
          : null,
      pumps: (json['pumps'] as List<dynamic>? ?? [])
          .map((e) => MarketingPump.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      notes: json['notes']?.toString(),
      attachments:
          (json['attachments'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      lease: json['lease'] is Map<String, dynamic>
          ? LeaseContract.fromJson(Map<String, dynamic>.from(json['lease']))
          : null,
      accounting: json['accounting'] is Map<String, dynamic>
          ? MarketingAccounting.fromJson(
              Map<String, dynamic>.from(json['accounting']),
            )
          : const MarketingAccounting(),
      handoverReport: json['handoverReport'] is Map<String, dynamic>
          ? HandoverReport.fromJson(
              Map<String, dynamic>.from(json['handoverReport']),
            )
          : null,
      expenseVouchers: (json['expenseVouchers'] as List<dynamic>? ?? [])
          .map((e) => StationExpense.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      receiptVouchers: (json['receiptVouchers'] as List<dynamic>? ?? [])
          .map((e) => StationReceipt.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    return {
      if (includeId && id.isNotEmpty) '_id': id,
      'name': name,
      'city': city,
      'address': address,
      'status': stationStatusToString(status),
      'tenantName': tenantName,
      'location': location?.toJson(),
      'owner': owner?.toJson(),
      'pumps': pumps.map((p) => p.toJson(includeId: includeId)).toList(),
      'notes': notes,
      'attachments': attachments,
      'lease': lease?.toJson(),
      'accounting': accounting.toJson(),
      'handoverReport': handoverReport?.toJson(),
      'expenseVouchers': expenseVouchers.map((e) => e.toJson()).toList(),
      'receiptVouchers': receiptVouchers.map((e) => e.toJson()).toList(),
    };
  }
}

class StationLocation {
  final double lat;
  final double lng;

  const StationLocation({required this.lat, required this.lng});

  factory StationLocation.fromJson(Map<String, dynamic> json) {
    return StationLocation(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class StationOwner {
  final String name;
  final String phone;
  final String idNumber;
  final String address;
  final String ejarContractNumber;

  const StationOwner({
    required this.name,
    required this.phone,
    required this.idNumber,
    required this.address,
    required this.ejarContractNumber,
  });

  factory StationOwner.fromJson(Map<String, dynamic> json) {
    return StationOwner(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      idNumber: json['idNumber']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      ejarContractNumber: json['ejarContractNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'idNumber': idNumber,
      'address': address,
      'ejarContractNumber': ejarContractNumber,
    };
  }
}

class MarketingPump {
  final String id;
  final String type;
  final int nozzleCount;
  final PumpCondition status;
  final List<MarketingNozzle> nozzles;
  final double openingReading;
  final DateTime openingReadingDate;
  final double? closingReading;
  final DateTime? closingReadingDate;

  MarketingPump({
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

  factory MarketingPump.fromJson(Map<String, dynamic> json) {
    final rawNozzles = json['nozzles'] as List<dynamic>? ?? [];
    final parsedNozzles = rawNozzles.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      if (value is Map) {
        final nozzle =
            MarketingNozzle.fromJson(Map<String, dynamic>.from(value));
        return nozzle.nozzleNumber == 0
            ? nozzle.copyWith(nozzleNumber: index + 1)
            : nozzle;
      }
      final status = nozzleStatusFromString(value?.toString());
      return MarketingNozzle(
        nozzleNumber: index + 1,
        status: status,
        fuelType: FuelType.gas91,
        openingReading: 0,
      );
    }).toList();
    return MarketingPump(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      nozzleCount: (json['nozzleCount'] as num?)?.toInt() ??
          (parsedNozzles.isNotEmpty ? parsedNozzles.length : 0),
      status: pumpConditionFromString(json['status']?.toString()),
      nozzles: parsedNozzles.isNotEmpty
          ? parsedNozzles
          : List.generate(
              (json['nozzleCount'] as num?)?.toInt() ?? 0,
              (index) => MarketingNozzle(
                nozzleNumber: index + 1,
                status: NozzleStatus.good,
                fuelType: FuelType.gas91,
                openingReading: 0,
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

  MarketingPump copyWith({
    String? id,
    String? type,
    int? nozzleCount,
    PumpCondition? status,
    List<MarketingNozzle>? nozzles,
    double? openingReading,
    DateTime? openingReadingDate,
    double? closingReading,
    DateTime? closingReadingDate,
  }) {
    return MarketingPump(
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

class MarketingNozzle {
  final int nozzleNumber;
  final NozzleStatus status;
  final FuelType fuelType;
  final double openingReading;
  final double? closingReading;

  const MarketingNozzle({
    required this.nozzleNumber,
    required this.status,
    required this.fuelType,
    required this.openingReading,
    this.closingReading,
  });

  factory MarketingNozzle.fromJson(Map<String, dynamic> json) {
    return MarketingNozzle(
      nozzleNumber: (json['nozzleNumber'] as num?)?.toInt() ?? 0,
      status: nozzleStatusFromString(json['status']?.toString()),
      fuelType: fuelTypeFromString(json['fuelType']?.toString()),
      openingReading: (json['openingReading'] as num?)?.toDouble() ?? 0,
      closingReading: json['closingReading'] != null
          ? (json['closingReading'] as num?)?.toDouble()
          : null,
    );
  }

  MarketingNozzle copyWith({
    int? nozzleNumber,
    NozzleStatus? status,
    FuelType? fuelType,
    double? openingReading,
    double? closingReading,
  }) {
    return MarketingNozzle(
      nozzleNumber: nozzleNumber ?? this.nozzleNumber,
      status: status ?? this.status,
      fuelType: fuelType ?? this.fuelType,
      openingReading: openingReading ?? this.openingReading,
      closingReading: closingReading ?? this.closingReading,
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
      'closingReading': closingReading,
    };
  }
}

class LeaseContract {
  final String tenantName;
  final String tenantId;
  final String phone;
  final String address;
  final String notes;
  final DateTime startDate;
  final DateTime endDate;
  final int years;
  final double? leaseAmount;
  final String paymentPlan;
  final int paymentCount;
  final List<double> paymentAmounts;

  LeaseContract({
    required this.tenantName,
    required this.tenantId,
    required this.phone,
    required this.address,
    required this.notes,
    required this.startDate,
    required this.endDate,
    required this.years,
    this.leaseAmount,
    this.paymentPlan = 'oneTime',
    this.paymentCount = 1,
    this.paymentAmounts = const [],
  });

  factory LeaseContract.fromJson(Map<String, dynamic> json) {
    return LeaseContract(
      tenantName: json['tenantName']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      startDate: DateTime.parse(json['startDate'].toString()).toLocal(),
      endDate: DateTime.parse(json['endDate'].toString()).toLocal(),
      years: (json['years'] as num?)?.toInt() ?? 1,
      leaseAmount: (json['leaseAmount'] as num?)?.toDouble(),
      paymentPlan: json['paymentPlan']?.toString() ?? 'oneTime',
      paymentCount: (json['paymentCount'] as num?)?.toInt() ?? 1,
      paymentAmounts: (json['paymentAmounts'] as List<dynamic>? ?? [])
          .map((e) => (e as num?)?.toDouble() ?? 0)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenantName': tenantName,
      'tenantId': tenantId,
      'phone': phone,
      'address': address,
      'notes': notes,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'years': years,
      'leaseAmount': leaseAmount,
      'paymentPlan': paymentPlan,
      'paymentCount': paymentCount,
      'paymentAmounts': paymentAmounts,
    };
  }
}

class MarketingAccounting {
  final double stationCost;
  final double leaseAmount;
  final double expenses;
  final double revenue;

  const MarketingAccounting({
    this.stationCost = 0,
    this.leaseAmount = 0,
    this.expenses = 0,
    this.revenue = 0,
  });

  double get profitLoss => revenue - (stationCost + expenses);

  factory MarketingAccounting.fromJson(Map<String, dynamic> json) {
    return MarketingAccounting(
      stationCost: (json['stationCost'] as num?)?.toDouble() ?? 0,
      leaseAmount: (json['leaseAmount'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationCost': stationCost,
      'leaseAmount': leaseAmount,
      'expenses': expenses,
      'revenue': revenue,
    };
  }
}

class StationExpense {
  final String reason;
  final double amount;
  final DateTime createdAt;
  final String? notes;
  final String? createdBy;

  StationExpense({
    required this.reason,
    required this.amount,
    required this.createdAt,
    this.notes,
    this.createdBy,
  });

  factory StationExpense.fromJson(Map<String, dynamic> json) {
    return StationExpense(
      reason: json['reason']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString()).toLocal()
          : DateTime.now(),
      notes: json['notes']?.toString(),
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'createdBy': createdBy,
    };
  }
}

class StationReceipt {
  final String reason;
  final double amount;
  final DateTime createdAt;
  final String? notes;
  final String? createdBy;

  StationReceipt({
    required this.reason,
    required this.amount,
    required this.createdAt,
    this.notes,
    this.createdBy,
  });

  factory StationReceipt.fromJson(Map<String, dynamic> json) {
    return StationReceipt(
      reason: json['reason']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString()).toLocal()
          : DateTime.now(),
      notes: json['notes']?.toString(),
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'createdBy': createdBy,
    };
  }
}

class HandoverReport {
  final String reportNumber;
  final String dayName;
  final String hijriDate;
  final String gregorianDate;
  final String stationName;
  final String city;
  final String district;
  final String street;
  final String civilLicenseNumber;
  final String civilLicenseDate;
  final String municipalityLicenseNumber;
  final String municipalityLicenseDate;
  final String ownerName;
  final String representativeName;
  final String authorizationNumber;
  final String companyName;
  final String companyRepresentativeName;
  final String contractReference;
  final String dispensersCount;
  final String doubleDispensersCount;
  final List<FuelDispenserRow> fuelDispensers;
  final List<FuelTankRow> fuelTanks;
  final List<SubmersiblePumpRow> submersiblePumps;
  final List<StationEquipmentRow> equipment;

  HandoverReport({
    required this.reportNumber,
    required this.dayName,
    required this.hijriDate,
    required this.gregorianDate,
    required this.stationName,
    required this.city,
    required this.district,
    required this.street,
    required this.civilLicenseNumber,
    required this.civilLicenseDate,
    required this.municipalityLicenseNumber,
    required this.municipalityLicenseDate,
    required this.ownerName,
    required this.representativeName,
    required this.authorizationNumber,
    required this.companyName,
    required this.companyRepresentativeName,
    required this.contractReference,
    required this.dispensersCount,
    required this.doubleDispensersCount,
    required this.fuelDispensers,
    required this.fuelTanks,
    required this.submersiblePumps,
    required this.equipment,
  });

  HandoverReport copyWith({
    String? reportNumber,
    String? dayName,
    String? hijriDate,
    String? gregorianDate,
    String? stationName,
    String? city,
    String? district,
    String? street,
    String? civilLicenseNumber,
    String? civilLicenseDate,
    String? municipalityLicenseNumber,
    String? municipalityLicenseDate,
    String? ownerName,
    String? representativeName,
    String? authorizationNumber,
    String? companyName,
    String? companyRepresentativeName,
    String? contractReference,
    String? dispensersCount,
    String? doubleDispensersCount,
    List<FuelDispenserRow>? fuelDispensers,
    List<FuelTankRow>? fuelTanks,
    List<SubmersiblePumpRow>? submersiblePumps,
    List<StationEquipmentRow>? equipment,
  }) {
    return HandoverReport(
      reportNumber: reportNumber ?? this.reportNumber,
      dayName: dayName ?? this.dayName,
      hijriDate: hijriDate ?? this.hijriDate,
      gregorianDate: gregorianDate ?? this.gregorianDate,
      stationName: stationName ?? this.stationName,
      city: city ?? this.city,
      district: district ?? this.district,
      street: street ?? this.street,
      civilLicenseNumber: civilLicenseNumber ?? this.civilLicenseNumber,
      civilLicenseDate: civilLicenseDate ?? this.civilLicenseDate,
      municipalityLicenseNumber:
          municipalityLicenseNumber ?? this.municipalityLicenseNumber,
      municipalityLicenseDate:
          municipalityLicenseDate ?? this.municipalityLicenseDate,
      ownerName: ownerName ?? this.ownerName,
      representativeName: representativeName ?? this.representativeName,
      authorizationNumber: authorizationNumber ?? this.authorizationNumber,
      companyName: companyName ?? this.companyName,
      companyRepresentativeName:
          companyRepresentativeName ?? this.companyRepresentativeName,
      contractReference: contractReference ?? this.contractReference,
      dispensersCount: dispensersCount ?? this.dispensersCount,
      doubleDispensersCount:
          doubleDispensersCount ?? this.doubleDispensersCount,
      fuelDispensers: fuelDispensers ?? this.fuelDispensers,
      fuelTanks: fuelTanks ?? this.fuelTanks,
      submersiblePumps: submersiblePumps ?? this.submersiblePumps,
      equipment: equipment ?? this.equipment,
    );
  }

  factory HandoverReport.empty() {
    return HandoverReport(
      reportNumber: '',
      dayName: '',
      hijriDate: '',
      gregorianDate: '',
      stationName: '',
      city: '',
      district: '',
      street: '',
      civilLicenseNumber: '',
      civilLicenseDate: '',
      municipalityLicenseNumber: '',
      municipalityLicenseDate: '',
      ownerName: '',
      representativeName: '',
      authorizationNumber: '',
      companyName: '',
      companyRepresentativeName: '',
      contractReference: '',
      dispensersCount: '',
      doubleDispensersCount: '',
      fuelDispensers: [],
      fuelTanks: [],
      submersiblePumps: [],
      equipment: [],
    );
  }

  factory HandoverReport.fromJson(Map<String, dynamic> json) {
    return HandoverReport(
      reportNumber: json['reportNumber']?.toString() ?? '',
      dayName: json['dayName']?.toString() ?? '',
      hijriDate: json['hijriDate']?.toString() ?? '',
      gregorianDate: json['gregorianDate']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      civilLicenseNumber: json['civilLicenseNumber']?.toString() ?? '',
      civilLicenseDate: json['civilLicenseDate']?.toString() ?? '',
      municipalityLicenseNumber:
          json['municipalityLicenseNumber']?.toString() ?? '',
      municipalityLicenseDate:
          json['municipalityLicenseDate']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      representativeName: json['representativeName']?.toString() ?? '',
      authorizationNumber: json['authorizationNumber']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      companyRepresentativeName:
          json['companyRepresentativeName']?.toString() ?? '',
      contractReference: json['contractReference']?.toString() ?? '',
      dispensersCount: json['dispensersCount']?.toString() ?? '',
      doubleDispensersCount:
          json['doubleDispensersCount']?.toString() ?? '',
      fuelDispensers: (json['fuelDispensers'] as List<dynamic>? ?? [])
          .map((e) => FuelDispenserRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      fuelTanks: (json['fuelTanks'] as List<dynamic>? ?? [])
          .map((e) => FuelTankRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      submersiblePumps:
          (json['submersiblePumps'] as List<dynamic>? ?? [])
              .map((e) =>
                  SubmersiblePumpRow.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      equipment: (json['equipment'] as List<dynamic>? ?? [])
          .map(
            (e) => StationEquipmentRow.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportNumber': reportNumber,
      'dayName': dayName,
      'hijriDate': hijriDate,
      'gregorianDate': gregorianDate,
      'stationName': stationName,
      'city': city,
      'district': district,
      'street': street,
      'civilLicenseNumber': civilLicenseNumber,
      'civilLicenseDate': civilLicenseDate,
      'municipalityLicenseNumber': municipalityLicenseNumber,
      'municipalityLicenseDate': municipalityLicenseDate,
      'ownerName': ownerName,
      'representativeName': representativeName,
      'authorizationNumber': authorizationNumber,
      'companyName': companyName,
      'companyRepresentativeName': companyRepresentativeName,
      'contractReference': contractReference,
      'dispensersCount': dispensersCount,
      'doubleDispensersCount': doubleDispensersCount,
      'fuelDispensers': fuelDispensers.map((e) => e.toJson()).toList(),
      'fuelTanks': fuelTanks.map((e) => e.toJson()).toList(),
      'submersiblePumps': submersiblePumps.map((e) => e.toJson()).toList(),
      'equipment': equipment.map((e) => e.toJson()).toList(),
    };
  }
}

class FuelDispenserRow {
  String pumpType;
  String count;
  String meterReading;
  String technicalStatus;

  FuelDispenserRow({
    required this.pumpType,
    required this.count,
    required this.meterReading,
    required this.technicalStatus,
  });

  factory FuelDispenserRow.empty() {
    return FuelDispenserRow(
      pumpType: '',
      count: '',
      meterReading: '',
      technicalStatus: '',
    );
  }

  factory FuelDispenserRow.fromJson(Map<String, dynamic> json) {
    return FuelDispenserRow(
      pumpType: json['pumpType']?.toString() ?? '',
      count: json['count']?.toString() ?? '',
      meterReading: json['meterReading']?.toString() ?? '',
      technicalStatus: json['technicalStatus']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pumpType': pumpType,
      'count': count,
      'meterReading': meterReading,
      'technicalStatus': technicalStatus,
    };
  }
}

class FuelTankRow {
  String tankNumber;
  String fuelType;
  String operatingCapacity;
  String technicalStatus;

  FuelTankRow({
    required this.tankNumber,
    required this.fuelType,
    required this.operatingCapacity,
    required this.technicalStatus,
  });

  factory FuelTankRow.empty({String tankNumber = ''}) {
    return FuelTankRow(
      tankNumber: tankNumber,
      fuelType: '',
      operatingCapacity: '',
      technicalStatus: '',
    );
  }

  factory FuelTankRow.fromJson(Map<String, dynamic> json) {
    return FuelTankRow(
      tankNumber: json['tankNumber']?.toString() ?? '',
      fuelType: json['fuelType']?.toString() ?? '',
      operatingCapacity: json['operatingCapacity']?.toString() ?? '',
      technicalStatus: json['technicalStatus']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tankNumber': tankNumber,
      'fuelType': fuelType,
      'operatingCapacity': operatingCapacity,
      'technicalStatus': technicalStatus,
    };
  }
}

class SubmersiblePumpRow {
  String brand;
  String count;
  String power;
  String technicalStatus;

  SubmersiblePumpRow({
    required this.brand,
    required this.count,
    required this.power,
    required this.technicalStatus,
  });

  factory SubmersiblePumpRow.empty() {
    return SubmersiblePumpRow(
      brand: '',
      count: '',
      power: '',
      technicalStatus: '',
    );
  }

  factory SubmersiblePumpRow.fromJson(Map<String, dynamic> json) {
    return SubmersiblePumpRow(
      brand: json['brand']?.toString() ?? '',
      count: json['count']?.toString() ?? '',
      power: json['power']?.toString() ?? '',
      technicalStatus: json['technicalStatus']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'count': count,
      'power': power,
      'technicalStatus': technicalStatus,
    };
  }
}

class StationEquipmentRow {
  String equipmentType;
  String count;
  String specifications;
  String technicalStatus;
  String notes;

  StationEquipmentRow({
    required this.equipmentType,
    required this.count,
    required this.specifications,
    required this.technicalStatus,
    required this.notes,
  });

  factory StationEquipmentRow.empty({String equipmentType = ''}) {
    return StationEquipmentRow(
      equipmentType: equipmentType,
      count: '',
      specifications: '',
      technicalStatus: '',
      notes: '',
    );
  }

  factory StationEquipmentRow.fromJson(Map<String, dynamic> json) {
    return StationEquipmentRow(
      equipmentType: json['equipmentType']?.toString() ?? '',
      count: json['count']?.toString() ?? '',
      specifications: json['specifications']?.toString() ?? '',
      technicalStatus: json['technicalStatus']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'equipmentType': equipmentType,
      'count': count,
      'specifications': specifications,
      'technicalStatus': technicalStatus,
      'notes': notes,
    };
  }
}

enum StationMarketingStatus {
  pendingReview,
  readyForLease,
  rented,
  rentedToNasserMotairi,
  cancelled,
  maintenance,
  study,
}

enum PumpCondition {
  good,
  damaged,
  needsMaintenance,
}

enum NozzleStatus {
  good,
  damaged,
  needsMaintenance,
}

enum FuelType {
  gas91,
  gas95,
  diesel,
  kerosene,
}

StationMarketingStatus stationStatusFromString(String? value) {
  switch (value) {
    case 'readyForLease':
      return StationMarketingStatus.readyForLease;
    case 'rented':
      return StationMarketingStatus.rented;
    case 'rentedToNasserMotairi':
      return StationMarketingStatus.rentedToNasserMotairi;
    case 'cancelled':
      return StationMarketingStatus.cancelled;
    case 'maintenance':
      return StationMarketingStatus.maintenance;
    case 'study':
      return StationMarketingStatus.study;
    case 'pendingReview':
    default:
      return StationMarketingStatus.pendingReview;
  }
}

String stationStatusToString(StationMarketingStatus status) {
  switch (status) {
    case StationMarketingStatus.readyForLease:
      return 'readyForLease';
    case StationMarketingStatus.rented:
      return 'rented';
    case StationMarketingStatus.rentedToNasserMotairi:
      return 'rentedToNasserMotairi';
    case StationMarketingStatus.cancelled:
      return 'cancelled';
    case StationMarketingStatus.maintenance:
      return 'maintenance';
    case StationMarketingStatus.study:
      return 'study';
    case StationMarketingStatus.pendingReview:
      return 'pendingReview';
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
