// station_model.dart
import 'dart:convert';

class Station {
  final String id;
  final String stationCode;
  final String stationName;
  final String location;
  final String city;
  final String managerName;
  final String managerPhone;
  final List<String> fuelTypes;
  final List<Pump> pumps;
  final List<FuelPrice> fuelPrices;
  final String createdById;
  final String? createdByName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Station({
    required this.id,
    required this.stationCode,
    required this.stationName,
    required this.location,
    required this.city,
    required this.managerName,
    required this.managerPhone,
    required this.fuelTypes,
    required this.pumps,
    required this.createdById,
    this.createdByName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.fuelPrices,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    String? getCreatedByName(dynamic createdBy) {
      if (createdBy is Map<String, dynamic>) {
        return createdBy['name']?.toString();
      }
      return null;
    }

    return Station(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      stationCode: json['stationCode']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      managerName: json['managerName']?.toString() ?? '',
      managerPhone: json['managerPhone']?.toString() ?? '',
      fuelTypes: List<String>.from(json['fuelTypes'] ?? []),
      pumps: (json['pumps'] as List<dynamic>? ?? [])
          .map((e) => Pump.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      fuelPrices: (json['fuelPrices'] as List<dynamic>? ?? [])
          .map((e) => FuelPrice.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdById: json['createdBy'] is String
          ? json['createdBy'].toString()
          : json['createdBy']?['_id']?.toString() ?? '',
      createdByName: getCreatedByName(json['createdBy']),
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString()).toLocal()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'stationCode': stationCode,
      'stationName': stationName,
      'location': location,
      'city': city,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'fuelTypes': fuelTypes,
      'pumps': pumps.map((pump) => pump.toJson()).toList(),
      'dailyPrices': fuelPrices.map((price) => price.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Station copyWith({
    String? id,
    String? stationCode,
    String? stationName,
    String? location,
    String? city,
    String? managerName,
    String? managerPhone,
    List<String>? fuelTypes,
    List<Pump>? pumps,
    List<FuelPrice>? dailyPrices,
    String? createdById,
    String? createdByName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Station(
      id: id ?? this.id,
      stationCode: stationCode ?? this.stationCode,
      stationName: stationName ?? this.stationName,
      location: location ?? this.location,
      city: city ?? this.city,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      pumps: pumps ?? this.pumps,
      fuelPrices: dailyPrices ?? this.fuelPrices,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FuelBalanceReportRow {
  final DateTime date;
  final String arabicDate;
  final String fuelType;
  final double openingBalance;
  final double received;
  final double sales;
  final double? calculatedBalance;
  final double? actualBalance;
  final double? difference;
  final double? differencePercentage;
  final String status;

  FuelBalanceReportRow({
    required this.date,
    required this.arabicDate,
    required this.fuelType,
    required this.openingBalance,
    required this.received,
    required this.sales,
    this.calculatedBalance,
    this.actualBalance,
    this.difference,
    this.differencePercentage,
    required this.status,
  });

  factory FuelBalanceReportRow.fromJson(Map<String, dynamic> json) {
    DateTime _parseDateOnly(dynamic value) {
      if (value == null) return DateTime.now();
      final raw = value.toString();
      final datePart = raw.split('T').first;
      final parts = datePart.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
      return DateTime.parse(raw).toLocal();
    }

    return FuelBalanceReportRow(
      date: _parseDateOnly(json['date'] ?? json['inventoryDate']),
      arabicDate: json['arabicDate']?.toString() ?? '',
      fuelType: json['fuelType']?.toString() ?? '',
      openingBalance: _parseDouble(json['openingBalance']),
      received: _parseDouble(json['received']),
      sales: _parseDouble(json['sales']),
      calculatedBalance: json['calculatedBalance'] != null
          ? _parseDouble(json['calculatedBalance'])
          : null,
      actualBalance: json['actualBalance'] != null
          ? _parseDouble(json['actualBalance'])
          : null,
      difference: json['difference'] != null
          ? _parseDouble(json['difference'])
          : null,
      differencePercentage: json['differencePercentage'] != null
          ? _parseDouble(json['differencePercentage'])
          : null,
      status: json['status']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }
}

class Pump {
  String id;
  String pumpNumber;
  String fuelType; // للـ UI فقط
  int nozzleCount; // للـ UI فقط
  bool isActive;
  DateTime createdAt; // للعرض فقط
  List<Nozzle> nozzles;
  double availableStock;
  double yesterdaySalesLiters;

  Pump({
    required this.id,
    required this.pumpNumber,
    required this.fuelType,
    required this.nozzleCount,
    required this.isActive,
    required this.createdAt,
    required this.nozzles,
    double? availableStock,
    double? yesterdaySalesLiters,
  })  : availableStock = availableStock ?? 0,
        yesterdaySalesLiters = yesterdaySalesLiters ?? 0;

  factory Pump.fromJson(Map<String, dynamic> json) {
    List<Nozzle> nozzlesList = [];
    if (json['nozzles'] != null && json['nozzles'] is List) {
      nozzlesList = (json['nozzles'] as List)
          .map((item) => Nozzle.fromJson(item))
          .toList();
    }

    return Pump(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      pumpNumber: json['pumpNumber']?.toString() ?? '',
      fuelType: '', // السيرفر مابيخزنش fuelType في Pump
      nozzleCount: nozzlesList.length, // محسوبة من الليات
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString()).toLocal()
          : DateTime.now().toLocal(),
      nozzles: nozzlesList,

      availableStock: _extractStockValue(
        json,
        ['availableQuantity', 'availableStock', 'availableLiters', 'stock', 'quantity'],
      ),
      yesterdaySalesLiters: _extractStockValue(
        json,
        ['yesterdayLiters', 'yesterdaySales', 'soldYesterday', 'yesterdaySoldLiters'],
      ),
    );
  }

  /// ✅ أهم جزء
  /// نرسل فقط ما يتوافق مع Mongo Schema
  Map<String, dynamic> toJson({bool forCreate = true}) {
    final map = <String, dynamic>{
      'pumpNumber': pumpNumber,
      'isActive': isActive,
      'availableStock': availableStock,
      'yesterdaySalesLiters': yesterdaySalesLiters,

      // ✔️ ده المهم
      'nozzles': nozzles
          .map((nozzle) => nozzle.toJson(forCreate: forCreate))
          .toList(),
    };

    // في حالة التعديل فقط
    if (!forCreate && id.isNotEmpty) {
      map['_id'] = id;
    }

    return map;
  }

  Pump copyWith({
    String? id,
    String? pumpNumber,
    String? fuelType,
    int? nozzleCount,
    bool? isActive,
    DateTime? createdAt,
    List<Nozzle>? nozzles,
    double? availableStock,
    double? yesterdaySalesLiters,
  }) {
    return Pump(
      id: id ?? this.id,
      pumpNumber: pumpNumber ?? this.pumpNumber,
      fuelType: fuelType ?? this.fuelType,
      nozzleCount: nozzleCount ?? this.nozzleCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      nozzles: nozzles ?? this.nozzles,
      availableStock: availableStock ?? this.availableStock,
      yesterdaySalesLiters:
          yesterdaySalesLiters ?? this.yesterdaySalesLiters,
    );
  }

  static double _parseDynamicDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static double _extractStockValue(
    Map<String, dynamic> json,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value == null) continue;
      return _parseDynamicDouble(value, fallback: fallback);
    }
    return fallback;
  }
}

class FuelPrice {
  final String id;
  final String fuelType;
  final double price;
  final DateTime effectiveDate;

  FuelPrice({
    required this.id,
    required this.fuelType,
    required this.price,
    required this.effectiveDate,
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    return FuelPrice(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      fuelType: json['fuelType']?.toString() ?? '',
      price: (json['price'] is double)
          ? json['price']
          : (json['price'] is int)
          ? json['price'].toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      effectiveDate: json['effectiveDate'] != null
          ? DateTime.parse(json['effectiveDate'].toString()).toLocal()
          : DateTime.now().toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fuelType': fuelType,
      'price': price,
      'effectiveDate': effectiveDate.toIso8601String(),
    };
  }
}

// pump_session_model.dart
class PumpSession {
  final String id;
  final String sessionNumber;
  final String stationId;
  final String stationName;
  final List<Expense>? expenses;
  final double? expensesTotal;
  final double? netSales;

  // ================= OLD (لم نلمسهم) =================
  final String pumpId;
  final String pumpNumber;
  final String fuelType;
  final List<PumpReading>? pumps;

  // ================= NEW =================
  final int? pumpsCount;

  final String shiftType;
  final DateTime sessionDate;

  // Opening data
  final String? openingEmployeeId;
  final String? openingEmployeeName;
  final double openingReading;
  final DateTime openingTime;
  final bool openingApproved;
  final String? openingApprovedBy;
  final DateTime? openingApprovedAt;

  // Closing data
  final String? closingEmployeeId;
  final String? closingEmployeeName;
  final double? closingReading;
  final DateTime? closingTime;
  final bool closingApproved;
  final String? closingApprovedBy;
  final DateTime? closingApprovedAt;

  // Sales data
  final double? totalLiters;
  final double? unitPrice;
  final double? totalAmount;
  final PaymentTypes paymentTypes;
  final double? totalSales;

  // Fuel supply
  final FuelSupply? fuelSupply;
  final FuelReturn? fuelReturn;
  final List<FuelReturn> fuelReturns;
  final List<NozzleReading>? nozzleReadings;

  // Balance
  final double carriedForwardBalance;

  // Differences
  final double? calculatedDifference;
  final double? actualDifference;
  final String? differenceReason;

  final String? notes;

  /// ✅ مهم: خليها متوافقة مع UI (مفتوحة/مغلقة/معتمدة/ملغاة)
  final String status;

  final DateTime createdAt;
  final DateTime updatedAt;

  PumpSession({
    required this.id,
    required this.sessionNumber,
    required this.stationId,
    required this.stationName,
    this.expenses,
    this.expensesTotal,
    this.netSales,

    // OLD
    required this.pumpId,
    required this.pumpNumber,
    required this.fuelType,
    this.pumps,

    // NEW
    this.pumpsCount,

    required this.shiftType,
    required this.sessionDate,

    this.openingEmployeeId,
    this.openingEmployeeName,
    required this.openingReading,
    required this.openingTime,
    required this.openingApproved,
    this.openingApprovedBy,
    this.openingApprovedAt,

    this.closingEmployeeId,
    this.closingEmployeeName,
    this.closingReading,
    this.closingTime,
    required this.closingApproved,
    this.closingApprovedBy,
    this.closingApprovedAt,

    this.totalLiters,
    this.unitPrice,
    this.totalAmount,
    required this.paymentTypes,
    this.totalSales,

    this.fuelSupply,
    this.fuelReturn,
    this.fuelReturns = const [],
    this.nozzleReadings,

    required this.carriedForwardBalance,

    this.calculatedDifference,
    this.actualDifference,
    this.differenceReason,

    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // =========================
  // ✅ Helpers (private)
  // =========================

  static String _safeId(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map && v['_id'] != null) return v['_id'].toString();
    if (v is Map && v['id'] != null) return v['id'].toString();
    return v.toString();
  }

  static double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static int? _toIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static DateTime _toLocalDate(dynamic v, {DateTime? fallback}) {
    if (v == null) return (fallback ?? DateTime.now()).toLocal();
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return (fallback ?? DateTime.now()).toLocal();
    }
  }

  /// ✅ توحيد status عشان الـ UI
  static String _normalizeStatus(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();

    // لو جاية عربي
    if (s.contains('مفتوحة')) return 'مفتوحة';
    if (s.contains('مغلقة')) return 'مغلقة';
    if (s.contains('معتمدة')) return 'معتمدة';
    if (s.contains('ملغاة') || s.contains('ملغيه')) return 'ملغاة';

    // لو جاية انجليزي من الباك
    if (s == 'open' || s == 'opened') return 'مفتوحة';
    if (s == 'closed') return 'مغلقة';
    if (s == 'approved') return 'معتمدة';
    if (s == 'cancelled' || s == 'canceled') return 'ملغاة';

    // default
    return raw?.toString() ?? 'مفتوحة';
  }

  /// ✅ توحيد side/position لليّات إلى left/right
  static String _normalizeSide(dynamic sideOrPos) {
    final s = (sideOrPos ?? '').toString().trim();

    // رموز/قيم قديمة عندك
    if (s == 'USU.USU+' || s.toLowerCase() == 'right' || s == 'يمين')
      return 'right';
    if (s == 'USO3O\u0015Oñ' || s.toLowerCase() == 'left' || s == 'يسار')
      return 'left';

    // لو جاية side مباشرة
    if (s.toLowerCase() == 'left' || s.toLowerCase() == 'right')
      return s.toLowerCase();

    // fallback: لو أي شيء غير معروف → right
    return 'right';
  }

  static List<NozzleReading>? _parseNozzleReadings(dynamic v) {
    if (v is! List) return null;

    final List<NozzleReading> out = [];
    for (final item in v) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);

        // ✅ توحيد side من (side/position)
        final rawSide = map['side'] ?? map['position'];
        map['side'] = _normalizeSide(rawSide);

        // ✅ كمان نحط position لو في UI محتاجه
        map['position'] = map['side'];

        out.add(NozzleReading.fromJson(map));
      }
    }
    return out.isEmpty ? null : out;
  }

  static List<PumpReading>? _parsePumps(dynamic v) {
    if (v is! List) return null;
    final list = v
        .whereType<Map>()
        .map((e) => PumpReading.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list.isEmpty ? null : list;
  }

  factory PumpSession.fromJson(Map<String, dynamic> json) {
    final nozzleReadings = _parseNozzleReadings(json['nozzleReadings']);
    final pumps = _parsePumps(json['pumps']);

    return PumpSession(
      id: _safeId(json['_id'] ?? json['id']),
      sessionNumber: (json['sessionNumber'] ?? '').toString(),

      stationId: _safeId(json['stationId']),
      stationName: (json['stationName'] ?? '').toString(),

      // OLD
      pumpId: _safeId(json['pumpId']),
      pumpNumber: (json['pumpNumber'] ?? '').toString(),
      fuelType: (json['fuelType'] ?? '').toString(),

      expenses: (json['expenses'] as List<dynamic>?)
          ?.map((e) => Expense.fromJson(Map<String, dynamic>.from(e)))
          .toList(),

      expensesTotal: json['expensesTotal'] != null
          ? _toDouble(json['expensesTotal'])
          : null,
      netSales: json['netSales'] != null ? _toDouble(json['netSales']) : null,

      pumps: pumps,

      // NEW
      pumpsCount: _toIntNullable(json['pumpsCount']),

      shiftType: (json['shiftType'] ?? '').toString(),
      sessionDate: _toLocalDate(json['sessionDate']),

      openingEmployeeId: json['openingEmployeeId']?.toString(),
      openingEmployeeName: json['openingEmployeeName']?.toString(),
      openingReading: _toDouble(json['openingReading'], fallback: 0),
      openingTime: _toLocalDate(json['openingTime']),
      openingApproved: json['openingApproved'] == true,
      openingApprovedBy: json['openingApprovedBy']?.toString(),
      openingApprovedAt: json['openingApprovedAt'] != null
          ? _toLocalDate(json['openingApprovedAt'])
          : null,

      closingEmployeeId: json['closingEmployeeId']?.toString(),
      closingEmployeeName: json['closingEmployeeName']?.toString(),
      closingReading: json['closingReading'] != null
          ? _toDouble(json['closingReading'])
          : null,
      closingTime: json['closingTime'] != null
          ? _toLocalDate(json['closingTime'])
          : null,
      closingApproved: json['closingApproved'] == true,
      closingApprovedBy: json['closingApprovedBy']?.toString(),
      closingApprovedAt: json['closingApprovedAt'] != null
          ? _toLocalDate(json['closingApprovedAt'])
          : null,

      totalLiters: json['totalLiters'] != null
          ? _toDouble(json['totalLiters'])
          : null,
      unitPrice: json['unitPrice'] != null
          ? _toDouble(json['unitPrice'])
          : null,
      totalAmount: json['totalAmount'] != null
          ? _toDouble(json['totalAmount'])
          : null,

      paymentTypes: PaymentTypes.fromJson(
        Map<String, dynamic>.from(json['paymentTypes'] ?? {}),
      ),
      totalSales: json['totalSales'] != null
          ? _toDouble(json['totalSales'])
          : null,

      fuelSupply: json['fuelSupply'] != null
          ? FuelSupply.fromJson(Map<String, dynamic>.from(json['fuelSupply']))
          : null,
      fuelReturn: json['fuelReturn'] != null
          ? FuelReturn.fromJson(Map<String, dynamic>.from(json['fuelReturn']))
          : null,
      fuelReturns: (json['fuelReturns'] is List)
          ? (json['fuelReturns'] as List)
              .whereType<Map>()
              .map(
                (e) => FuelReturn.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : (json['fuelReturn'] != null
              ? [
                  FuelReturn.fromJson(
                    Map<String, dynamic>.from(json['fuelReturn']),
                  ),
                ]
              : const []),

      nozzleReadings: nozzleReadings,

      carriedForwardBalance: _toDouble(
        json['carriedForwardBalance'],
        fallback: 0,
      ),

      calculatedDifference: json['calculatedDifference'] != null
          ? _toDouble(json['calculatedDifference'])
          : null,
      actualDifference: json['actualDifference'] != null
          ? _toDouble(json['actualDifference'])
          : null,
      differenceReason: json['differenceReason']?.toString(),

      notes: json['notes']?.toString(),

      // ✅ توحيد الحالة
      status: _normalizeStatus(json['status']),

      createdAt: _toLocalDate(json['createdAt']),
      updatedAt: _toLocalDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sessionNumber': sessionNumber,
      'stationId': stationId,
      'stationName': stationName,

      // OLD
      'pumpId': pumpId,
      'pumpNumber': pumpNumber,
      'fuelType': fuelType,
      'expenses': expenses?.map((e) => e.toJson()).toList(),
      'expensesTotal': expensesTotal,

      'pumpsCount': pumpsCount,
      'netSales': netSales,

      'shiftType': shiftType,
      'sessionDate': sessionDate.toIso8601String(),

      'openingEmployeeId': openingEmployeeId,
      'openingEmployeeName': openingEmployeeName,
      'openingReading': openingReading,
      'openingTime': openingTime.toIso8601String(),
      'openingApproved': openingApproved,
      'openingApprovedBy': openingApprovedBy,
      'openingApprovedAt': openingApprovedAt?.toIso8601String(),

      'closingEmployeeId': closingEmployeeId,
      'closingEmployeeName': closingEmployeeName,
      'closingReading': closingReading,
      'closingTime': closingTime?.toIso8601String(),
      'closingApproved': closingApproved,
      'closingApprovedBy': closingApprovedBy,
      'closingApprovedAt': closingApprovedAt?.toIso8601String(),

      'totalLiters': totalLiters,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,

      'paymentTypes': paymentTypes.toJson(),
      'totalSales': totalSales,

      'fuelSupply': fuelSupply?.toJson(),
      'fuelReturn': fuelReturn?.toJson(),
      'fuelReturns': fuelReturns.map((e) => e.toJson()).toList(),
      'nozzleReadings': nozzleReadings?.map((e) => e.toJson()).toList(),

      'carriedForwardBalance': carriedForwardBalance,
      'calculatedDifference': calculatedDifference,
      'actualDifference': actualDifference,
      'differenceReason': differenceReason,

      'notes': notes,
      'status': status,

      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),

      // pumps optional
      'pumps': pumps?.map((e) => e.toJson()).toList(),
    };
  }
}

class Nozzle {
  String id;
  String nozzleNumber;
  String position; // ✅ left / right فقط
  String fuelType;
  bool isActive;
  double currentReading;
  DateTime createdAt;

  Nozzle({
    required this.id,
    required this.nozzleNumber,
    required this.position, // left / right
    required this.fuelType,
    required this.isActive,
    required this.currentReading,
    required this.createdAt,
  });

  // =========================
  // 🎯 UI helper
  // =========================
  String get uiPosition => position == 'left' ? 'يسار' : 'يمين';

  factory Nozzle.fromJson(Map<String, dynamic> json) {
    final side = json['side']?.toString().toLowerCase();

    return Nozzle(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      nozzleNumber: json['nozzleNumber']?.toString() ?? '',
      position: side == 'left' ? 'left' : 'right', // ✅ ثابت
      fuelType: json['fuelType'] ?? '',
      isActive: json['isActive'] ?? true,
      currentReading: (json['currentReading'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool forCreate = true}) {
    final map = <String, dynamic>{
      'nozzleNumber': int.tryParse(nozzleNumber) ?? 0,
      'side': position, // left / right
      'fuelType': fuelType,
      'isActive': isActive,
    };

    if (!forCreate && id.isNotEmpty) {
      map['_id'] = id;
    }

    return map;
  }

  Nozzle copyWith({
    String? id,
    String? nozzleNumber,
    String? position,
    String? fuelType,
    bool? isActive,
    double? currentReading,
    DateTime? createdAt,
  }) {
    return Nozzle(
      id: id ?? this.id,
      nozzleNumber: nozzleNumber ?? this.nozzleNumber,
      position: position ?? this.position,
      fuelType: fuelType ?? this.fuelType,
      isActive: isActive ?? this.isActive,
      currentReading: currentReading ?? this.currentReading,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NozzleReading {
  // ========================
  // 🔗 Identifiers
  // ========================
  final String nozzleId;
  final String nozzleNumber;

  /// ✅ left / right فقط
  final String position;

  final String fuelType;

  // ========================
  // 🔗 Pump Info
  // ========================
  final String pumpId;
  final String pumpNumber;

  // ========================
  // 📊 Readings
  // ========================
  final double openingReading;
  double? closingReading;

  // ========================
  // 💰 Calculations
  // ========================
  double? unitPrice;
  double? totalLiters;
  double? totalAmount;
  double? postSalesBalance;

  // ========================
  // 🖼 Attachments
  // ========================
  final String? openingImageUrl;
  final String? closingImageUrl;
  final String? attachmentPath;

  // ========================
  // 📝 Notes
  // ========================
  String? differenceReason;
  String? notes;

  NozzleReading({
    required this.nozzleId,
    required this.nozzleNumber,
    required this.position, // left / right
    required this.fuelType,
    required this.pumpId,
    required this.pumpNumber,
    required this.openingReading,
    this.openingImageUrl,
    this.closingReading,
    this.closingImageUrl,
    this.unitPrice,
    this.totalLiters,
    this.totalAmount,
    this.postSalesBalance,
    this.attachmentPath,
    this.differenceReason,
    this.notes,
  });

  // ========================
  // 🎯 UI helpers
  // ========================
  String get uiSide => position == 'left' ? 'يسار' : 'يمين';
  double get reading => openingReading;
  String? get imageUrl => openingImageUrl;
  String get side => position;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory NozzleReading.fromJson(Map<String, dynamic> json) {
    final side = (json['side'] ?? json['position'])?.toString().toLowerCase();

    return NozzleReading(
      nozzleId: json['nozzleId']?.toString() ?? '',
      nozzleNumber: json['nozzleNumber']?.toString() ?? '',
      position: side == 'left' ? 'left' : 'right',
      fuelType: json['fuelType']?.toString() ?? '',
      pumpId: json['pumpId']?.toString() ?? '',
      pumpNumber: json['pumpNumber']?.toString() ?? '',
      openingReading: _toDouble(json['openingReading'] ?? json['reading']),
      openingImageUrl: (json['openingImageUrl'] ?? json['imageUrl'])
          ?.toString(),
      closingReading: json['closingReading'] != null
          ? _toDouble(json['closingReading'])
          : null,
      closingImageUrl: json['closingImageUrl']?.toString(),
      unitPrice: json['unitPrice'] != null
          ? _toDouble(json['unitPrice'])
          : null,
      totalLiters: json['totalLiters'] != null
          ? _toDouble(json['totalLiters'])
          : null,
      totalAmount: json['totalAmount'] != null
          ? _toDouble(json['totalAmount'])
          : null,
      postSalesBalance: json['postSalesBalance'] != null
          ? _toDouble(json['postSalesBalance'])
          : null,
      attachmentPath: json['attachmentPath']?.toString(),
      differenceReason: json['differenceReason']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nozzleId': nozzleId,
      'nozzleNumber': nozzleNumber,
      'side': position, // left / right
      'fuelType': fuelType,
      'pumpId': pumpId,
      'pumpNumber': pumpNumber,
      'openingReading': openingReading,
      'openingImageUrl': openingImageUrl,
      'closingReading': closingReading,
      'closingImageUrl': closingImageUrl,
      'unitPrice': unitPrice,
      'totalLiters': totalLiters,
      'totalAmount': totalAmount,
      'postSalesBalance': postSalesBalance,
      'attachmentPath': attachmentPath,
      'differenceReason': differenceReason,
      'notes': notes,

      // توافق قديم
      'reading': openingReading,
      'imageUrl': openingImageUrl,
      'position': position,
    };
  }
}

class PaymentTypes {
  final double cash;
  final double card;
  final double mada;
  final double other;

  PaymentTypes({
    required this.cash,
    required this.card,
    required this.mada,
    required this.other,
  });

  factory PaymentTypes.fromJson(Map<String, dynamic> json) {
    return PaymentTypes(
      cash: (json['cash'] is double)
          ? json['cash']
          : (json['cash'] is int)
          ? json['cash'].toDouble()
          : double.tryParse(json['cash']?.toString() ?? '0') ?? 0,
      card: (json['card'] is double)
          ? json['card']
          : (json['card'] is int)
          ? json['card'].toDouble()
          : double.tryParse(json['card']?.toString() ?? '0') ?? 0,
      mada: (json['mada'] is double)
          ? json['mada']
          : (json['mada'] is int)
          ? json['mada'].toDouble()
          : double.tryParse(json['mada']?.toString() ?? '0') ?? 0,
      other: (json['other'] is double)
          ? json['other']
          : (json['other'] is int)
          ? json['other'].toDouble()
          : double.tryParse(json['other']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'cash': cash, 'card': card, 'mada': mada, 'other': other};
  }

  double get total => cash + card + mada + other;
}

class FuelSupply {
  final String fuelType;
  final double quantity;
  final String? tankerNumber;
  final String? supplierName;

  FuelSupply({
    required this.fuelType,
    required this.quantity,
    this.tankerNumber,
    this.supplierName,
  });

  factory FuelSupply.fromJson(Map<String, dynamic> json) {
    return FuelSupply(
      fuelType: json['fuelType']?.toString() ?? '',
      quantity: (json['quantity'] is double)
          ? json['quantity']
          : (json['quantity'] is int)
          ? json['quantity'].toDouble()
          : double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      tankerNumber: json['tankerNumber']?.toString(),
      supplierName: json['supplierName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelType': fuelType,
      'quantity': quantity,
      'tankerNumber': tankerNumber,
      'supplierName': supplierName,
    };
  }
}

class FuelReturn {
  final String fuelType;
  final double quantity;
  final String? reason;
  final double? amount;

  FuelReturn({
    required this.fuelType,
    required this.quantity,
    this.reason,
    this.amount,
  });

  factory FuelReturn.fromJson(Map<String, dynamic> json) {
    return FuelReturn(
      fuelType: json['fuelType']?.toString() ?? '',
      quantity: (json['quantity'] is double)
          ? json['quantity']
          : (json['quantity'] is int)
          ? json['quantity'].toDouble()
          : double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      reason: json['reason']?.toString(),
      amount: json['amount'] != null
          ? (json['amount'] is num
              ? (json['amount'] as num).toDouble()
              : double.tryParse(json['amount'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelType': fuelType,
      'quantity': quantity,
      'reason': reason,
      'amount': amount,
    };
  }
}

// daily_inventory_model.dart
class DailyInventory {
  final String id;
  final String stationId;
  final String stationName;
  final DateTime inventoryDate;
  final String arabicDate;
  final String fuelType;

  final double previousBalance;
  final double receivedQuantity;
  final int tankerCount;

  final double totalSales;
  final int pumpCount;

  final double? calculatedBalance;
  final double? actualBalance;
  final double? difference;
  final double? differencePercentage;
  final String? differenceReason;

  final List<Expense> expenses;
  final double totalExpenses;
  final double totalRevenue;
  final double? netRevenue;

  final String status;
  final String? preparedById;
  final String? preparedByName;
  final String? approvedById;
  final String? approvedByName;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyInventory({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.inventoryDate,
    required this.arabicDate,
    required this.fuelType,
    required this.previousBalance,
    required this.receivedQuantity,
    required this.tankerCount,
    required this.totalSales,
    required this.pumpCount,
    this.calculatedBalance,
    this.actualBalance,
    this.difference,
    this.differencePercentage,
    this.differenceReason,
    required this.expenses,
    required this.totalExpenses,
    required this.totalRevenue,
    this.netRevenue,
    required this.status,
    this.preparedById,
    this.preparedByName,
    this.approvedById,
    this.approvedByName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // =====================================================
  // 📥 FROM JSON (كما هو – بدون أي حذف)
  // =====================================================
  factory DailyInventory.fromJson(Map<String, dynamic> json) {
    String? _getName(dynamic v) {
      if (v is Map<String, dynamic>) {
        return v['name']?.toString();
      }
      return null;
    }

    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '0') ?? 0;
    }

    int _toInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    return DailyInventory(
      id: json['_id']?.toString() ?? '',
      stationId: json['stationId'] is String
          ? json['stationId']
          : json['stationId']?['_id']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      inventoryDate: DateTime.parse(json['inventoryDate']).toLocal(),
      arabicDate: json['arabicDate']?.toString() ?? '',
      fuelType: json['fuelType']?.toString() ?? '',
      previousBalance: _toDouble(json['previousBalance']),
      receivedQuantity: _toDouble(json['receivedQuantity']),
      tankerCount: _toInt(json['tankerCount']),
      totalSales: _toDouble(json['totalSales']),
      pumpCount: _toInt(json['pumpCount']),
      calculatedBalance: json['calculatedBalance'] != null
          ? _toDouble(json['calculatedBalance'])
          : null,
      actualBalance: json['actualBalance'] != null
          ? _toDouble(json['actualBalance'])
          : null,
      difference: json['difference'] != null
          ? _toDouble(json['difference'])
          : null,
      differencePercentage: json['differencePercentage'] != null
          ? _toDouble(json['differencePercentage'])
          : null,
      differenceReason: json['differenceReason']?.toString(),
      expenses: (json['expenses'] as List<dynamic>? ?? [])
          .map((e) => Expense.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalExpenses: _toDouble(json['totalExpenses']),
      totalRevenue: _toDouble(json['totalRevenue']),
      netRevenue: json['netRevenue'] != null
          ? _toDouble(json['netRevenue'])
          : null,
      status: json['status']?.toString() ?? '',
      preparedById: json['preparedBy'] is String
          ? json['preparedBy']
          : json['preparedBy']?['_id']?.toString(),
      preparedByName: _getName(json['preparedBy']),
      approvedById: json['approvedBy'] is String
          ? json['approvedBy']
          : json['approvedBy']?['_id']?.toString(),
      approvedByName: _getName(json['approvedBy']),
      notes: json['notes']?.toString(),
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt']).toLocal(),
    );
  }

  // =====================================================
  // 📤 JSON كامل (للعرض / التخزين المحلي)
  // ❗ لا نستخدمه للإرسال للباك
  // =====================================================
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'stationId': stationId,
      'stationName': stationName,
      'inventoryDate': inventoryDate.toIso8601String(),
      'arabicDate': arabicDate,
      'fuelType': fuelType,
      'previousBalance': previousBalance,
      'receivedQuantity': receivedQuantity,
      'tankerCount': tankerCount,
      'totalSales': totalSales,
      'pumpCount': pumpCount,
      'calculatedBalance': calculatedBalance,
      'actualBalance': actualBalance,
      'difference': difference,
      'differencePercentage': differencePercentage,
      'differenceReason': differenceReason,
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'totalExpenses': totalExpenses,
      'totalRevenue': totalRevenue,
      'netRevenue': netRevenue,
      'status': status,
      'preparedById': preparedById,
      'preparedByName': preparedByName,
      'approvedById': approvedById,
      'approvedByName': approvedByName,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // =====================================================
  // ✅ JSON خاص بإنشاء الجرد (الحل النهائي)
  // =====================================================
  Map<String, dynamic> toCreateJson() {
    return {
      'stationId': stationId,
      'inventoryDate': inventoryDate.toIso8601String(),
      'fuelType': fuelType,
      'previousBalance': previousBalance,
      'receivedQuantity': receivedQuantity,
      'tankerCount': tankerCount,
      'actualBalance': actualBalance,
      'differenceReason': differenceReason,
      'expenses': expenses
          .map(
            (e) => {
              'amount': e.amount,
              'description': e.description,
              'category': e.category,
            },
          )
          .toList(),
      'notes': notes,
    };
  }
}



class Expense {
  final String id;
  final double amount;
  final String description;
  final String category;
  final String? approvedById;
  final String? approvedByName;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    this.approvedById,
    this.approvedByName,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    String? getApprovedByName(dynamic approvedBy) {
      if (approvedBy is Map<String, dynamic>) {
        return approvedBy['name']?.toString();
      }
      return null;
    }

    return Expense(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      amount: (json['amount'] is double)
          ? json['amount']
          : (json['amount'] is int)
          ? json['amount'].toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      approvedById: json['approvedBy']?.toString(),
      approvedByName: getApprovedByName(json['approvedBy']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'approvedById': approvedById,
      'approvedByName': approvedByName,
    };
  }
}

// station_stats_model.dart
class StationStats {
  final int totalSessions;
  final double totalLiters;
  final double totalAmount;
  final double totalSales;
  final PaymentBreakdown paymentBreakdown;
  final Map<String, FuelTypeStats> fuelTypeBreakdown;
  final double totalExpenses;
  final double netRevenue;

  StationStats({
    required this.totalSessions,
    required this.totalLiters,
    required this.totalAmount,
    required this.totalSales,
    required this.paymentBreakdown,
    required this.fuelTypeBreakdown,
    required this.totalExpenses,
    required this.netRevenue,
  });

  factory StationStats.fromJson(Map<String, dynamic> json) {
    final fuelTypeMap = <String, FuelTypeStats>{};
    final fuelBreakdown =
        json['fuelTypeBreakdown'] as Map<String, dynamic>? ?? {};

    fuelBreakdown.forEach((key, value) {
      fuelTypeMap[key] = FuelTypeStats.fromJson(
        Map<String, dynamic>.from(value),
      );
    });

    return StationStats(
      totalSessions: json['totalSessions'] is int
          ? json['totalSessions']
          : int.tryParse(json['totalSessions']?.toString() ?? '0') ?? 0,
      totalLiters: (json['totalLiters'] is double)
          ? json['totalLiters']
          : (json['totalLiters'] is int)
          ? json['totalLiters'].toDouble()
          : double.tryParse(json['totalLiters']?.toString() ?? '0') ?? 0,
      totalAmount: (json['totalAmount'] is double)
          ? json['totalAmount']
          : (json['totalAmount'] is int)
          ? json['totalAmount'].toDouble()
          : double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      totalSales: (json['totalSales'] is double)
          ? json['totalSales']
          : (json['totalSales'] is int)
          ? json['totalSales'].toDouble()
          : double.tryParse(json['totalSales']?.toString() ?? '0') ?? 0,
      paymentBreakdown: PaymentBreakdown.fromJson(
        Map<String, dynamic>.from(json['paymentBreakdown'] ?? {}),
      ),
      fuelTypeBreakdown: fuelTypeMap,
      totalExpenses: (json['totalExpenses'] is double)
          ? json['totalExpenses']
          : (json['totalExpenses'] is int)
          ? json['totalExpenses'].toDouble()
          : double.tryParse(json['totalExpenses']?.toString() ?? '0') ?? 0,
      netRevenue: (json['netRevenue'] is double)
          ? json['netRevenue']
          : (json['netRevenue'] is int)
          ? json['netRevenue'].toDouble()
          : double.tryParse(json['netRevenue']?.toString() ?? '0') ?? 0,
    );
  }
}

class PaymentBreakdown {
  final double cash;
  final double card;
  final double mada;
  final double other;

  PaymentBreakdown({
    required this.cash,
    required this.card,
    required this.mada,
    required this.other,
  });

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentBreakdown(
      cash: (json['cash'] is double)
          ? json['cash']
          : (json['cash'] is int)
          ? json['cash'].toDouble()
          : double.tryParse(json['cash']?.toString() ?? '0') ?? 0,
      card: (json['card'] is double)
          ? json['card']
          : (json['card'] is int)
          ? json['card'].toDouble()
          : double.tryParse(json['card']?.toString() ?? '0') ?? 0,
      mada: (json['mada'] is double)
          ? json['mada']
          : (json['mada'] is int)
          ? json['mada'].toDouble()
          : double.tryParse(json['mada']?.toString() ?? '0') ?? 0,
      other: (json['other'] is double)
          ? json['other']
          : (json['other'] is int)
          ? json['other'].toDouble()
          : double.tryParse(json['other']?.toString() ?? '0') ?? 0,
    );
  }

  double get total => cash + card + mada + other;
}

class PumpReading {
  final String pumpId;
  final String pumpNumber;
  final String fuelType;
  final double openingReading;
  final double? closingReading;

  PumpReading({
    required this.pumpId,
    required this.pumpNumber,
    required this.fuelType,
    required this.openingReading,
    this.closingReading,
  });

  factory PumpReading.fromJson(Map<String, dynamic> json) {
    return PumpReading(
      pumpId: json['pumpId']?.toString() ?? '',
      pumpNumber: json['pumpNumber']?.toString() ?? '',
      fuelType: json['fuelType']?.toString() ?? '',
      openingReading:
          double.tryParse(json['openingReading']?.toString() ?? '0') ?? 0,
      closingReading: json['closingReading'] != null
          ? double.tryParse(json['closingReading'].toString())
          : null,
    );
  }

  // ✅ الحل هنا
  Map<String, dynamic> toJson() {
    return {
      'pumpId': pumpId,
      'pumpNumber': pumpNumber,
      'fuelType': fuelType,
      'openingReading': openingReading,
      'closingReading': closingReading,
    };
  }
}

class FuelTypeStats {
  final double liters;
  final double amount;
  final int sessions;

  FuelTypeStats({
    required this.liters,
    required this.amount,
    required this.sessions,
  });

  factory FuelTypeStats.fromJson(Map<String, dynamic> json) {
    return FuelTypeStats(
      liters: (json['liters'] is double)
          ? json['liters']
          : (json['liters'] is int)
          ? json['liters'].toDouble()
          : double.tryParse(json['liters']?.toString() ?? '0') ?? 0,
      amount: (json['amount'] is double)
          ? json['amount']
          : (json['amount'] is int)
          ? json['amount'].toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      sessions: json['sessions'] is int
          ? json['sessions']
          : int.tryParse(json['sessions']?.toString() ?? '0') ?? 0,
    );
  }
}
