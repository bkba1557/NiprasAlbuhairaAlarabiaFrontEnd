import 'package:intl/intl.dart';

const List<String> kSupportedFuelTypes = <String>[
  'بنزين 91',
  'بنزين 95',
  'ديزل',
  'كيروسين',
];

double? _parseCustomerDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<CustomerFuelPrice> _parseCustomerFuelPricing(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((entry) => CustomerFuelPrice.fromJson(Map<String, dynamic>.from(entry)))
        .where((entry) => entry.fuelType.trim().isNotEmpty)
        .toList();
  }

  if (value is Map) {
    return value.entries.map((entry) {
      return CustomerFuelPrice(
        fuelType: entry.key,
        pricePerLiter: _parseCustomerDouble(entry.value) ?? 0,
      );
    }).toList();
  }

  return const <CustomerFuelPrice>[];
}

class CustomerFuelPrice {
  final String fuelType;
  final double pricePerLiter;

  const CustomerFuelPrice({
    required this.fuelType,
    required this.pricePerLiter,
  });

  factory CustomerFuelPrice.fromJson(Map<String, dynamic> json) {
    return CustomerFuelPrice(
      fuelType: json['fuelType']?.toString() ?? '',
      pricePerLiter: _parseCustomerDouble(
            json['pricePerLiter'] ?? json['price'] ?? json['value'],
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelType': fuelType,
      'pricePerLiter': pricePerLiter,
    };
  }
}

class Customer {
  final String id;
  final String name;
  final String code;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? area;
  final String? street;
  final String? postalCode;
  final String? contactPerson;
  final String? contactPersonPhone;
  final String? supplierId;
  final String? supplierName;
  final List<String> supplierStationIds;
  final String? notes;
  final String? company;
  final String? taxNumber;
  final String? commercialRecord;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final String status;
  final String createdById;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CustomerDocument> documents;

  // ⭐ إحصائيات العميل
  final int? totalOrders;
  final double? totalSpent;
  final DateTime? lastOrderDate;
  final String? customerType;

  /// ⭐ تسعيرة الوقود للعميل (ريال/لتر)
  final double? fuelPricePerLiter;

  /// ⭐ تسعير الوقود حسب نوع الوقود
  final List<CustomerFuelPrice> fuelPricing;

  Customer({
    required this.id,
    required this.name,
    required this.code,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.area,
    this.street,
    this.postalCode,
    this.contactPerson,
    this.contactPersonPhone,
    this.supplierId,
    this.supplierName,
    this.supplierStationIds = const [],
    this.notes,
    this.company,
    this.taxNumber,
    this.commercialRecord,
    this.latitude,
    this.longitude,
    required this.isActive,
    required this.status,
    required this.createdById,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.totalOrders,
    this.totalSpent,
    this.lastOrderDate,
    this.customerType,
    this.fuelPricePerLiter,
    this.fuelPricing = const [],
    this.documents = const [],
  });

  factory Customer.empty() {
    return Customer(
      id: '',
      name: '',
      code: '',
      isActive: true,
      status: 'active',
      createdById: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documents: const [],
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    // ===== منشئ السجل =====
    String createdById = '';
    String? createdByName;

    if (json['createdBy'] is String) {
      createdById = json['createdBy'];
    } else if (json['createdBy'] is Map<String, dynamic>) {
      createdById = json['createdBy']['_id']?.toString() ?? '';
      createdByName = json['createdBy']['name']?.toString();
    }

    // ===== الإحصائيات =====
    int? totalOrders;
    double? totalSpent;
    DateTime? lastOrderDate;

    if (json['stats'] is Map<String, dynamic>) {
      final stats = json['stats'];

      totalOrders = stats['totalOrders'] is int
          ? stats['totalOrders']
          : int.tryParse(stats['totalOrders']?.toString() ?? '');

      totalSpent = stats['totalSpent'] is num
          ? (stats['totalSpent'] as num).toDouble()
          : double.tryParse(stats['totalSpent']?.toString() ?? '');

      lastOrderDate = DateTime.tryParse(
        stats['lastOrderDate']?.toString() ?? '',
      );
    }

    // fallback لو الإحصائيات على root
    totalOrders ??= json['totalOrders'] is int
        ? json['totalOrders']
        : int.tryParse(json['totalOrders']?.toString() ?? '');

    totalSpent ??= json['totalSpent'] is num
        ? (json['totalSpent'] as num).toDouble()
        : double.tryParse(json['totalSpent']?.toString() ?? '');

    lastOrderDate ??= DateTime.tryParse(
      json['lastOrderDate']?.toString() ?? '',
    );

    final dynamic isActiveField = json['isActive'];
    final bool isActiveValue;
    if (isActiveField is bool) {
      isActiveValue = isActiveField;
    } else if (isActiveField != null) {
      isActiveValue = isActiveField.toString().toLowerCase() == 'true';
    } else {
      isActiveValue = true;
    }
    final String? statusField = json['status']?.toString();
    final String statusValue = (statusField?.trim().isNotEmpty == true)
        ? statusField!
        : (isActiveValue ? 'active' : 'blocked');

    final documents = (json['documents'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CustomerDocument.fromJson)
        .toList();

    return Customer(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      area: json['area']?.toString(),
      street: json['street']?.toString(),
      postalCode: json['postalCode']?.toString(),
      contactPerson: json['contactPerson']?.toString(),
      contactPersonPhone: json['contactPersonPhone']?.toString(),
      supplierId: json['supplier'] is Map
          ? json['supplier']['_id']?.toString()
          : json['supplier']?.toString(),
      supplierName: json['supplier'] is Map
          ? json['supplier']['name']?.toString()
          : json['supplierName']?.toString(),
      supplierStationIds: (json['supplierStationIds'] as List<dynamic>? ?? [])
          .map((entry) {
            if (entry is Map<String, dynamic>) {
              return entry['_id']?.toString() ?? '';
            }
            return entry?.toString() ?? '';
          })
          .where((entry) => entry.trim().isNotEmpty)
          .toList(),
      notes: json['notes']?.toString(),
      company: json['company']?.toString(),
      taxNumber: json['taxNumber']?.toString(),
      commercialRecord: json['commercialRecord']?.toString(),
      latitude: _parseCustomerDouble(json['latitude']),
      longitude: _parseCustomerDouble(json['longitude']),
      isActive: isActiveValue,
      status: statusValue,
      createdById: createdById,
      createdByName: createdByName ?? json['createdByName']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      totalOrders: totalOrders,
      totalSpent: totalSpent,
      lastOrderDate: lastOrderDate,
      customerType: json['customerType']?.toString(),
      fuelPricePerLiter: _parseCustomerDouble(
        json['fuelPricePerLiter'] ?? json['fuelPrice'],
      ),
      fuelPricing: _parseCustomerFuelPricing(json['fuelPricing']),
      documents: documents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'area': area,
      'street': street,
      'postalCode': postalCode,
      'contactPerson': contactPerson,
      'contactPersonPhone': contactPersonPhone,
      'supplier': supplierId,
      'supplierName': supplierName,
      'supplierStationIds': supplierStationIds,
      'notes': notes,
      'company': company,
      'taxNumber': taxNumber,
      'commercialRecord': commercialRecord,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'status': status,
      if (id.isNotEmpty) '_id': id,
      'createdBy': createdById,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      'lastOrderDate': lastOrderDate?.toIso8601String(),
      'customerType': customerType,
      'fuelPricePerLiter': fuelPricePerLiter,
      'fuelPricing': fuelPricing.map((entry) => entry.toJson()).toList(),
      'documents': documents.map((doc) => doc.toJson()).toList(),
    };
  }

  // ================= Helpers =================

  String get displayName =>
      name.isNotEmpty && code.isNotEmpty ? '$name ($code)' : name;

  double? fuelPriceFor(String? fuelType) {
    final normalizedFuelType = fuelType?.trim() ?? '';
    if (normalizedFuelType.isNotEmpty) {
      for (final entry in fuelPricing) {
        if (entry.fuelType.trim() == normalizedFuelType) {
          return entry.pricePerLiter;
        }
      }
    }
    return fuelPricePerLiter;
  }

  bool get hasFuelPricing => fuelPricing.isNotEmpty || fuelPricePerLiter != null;

  String get fullLocation {
    final parts = <String>[];
    if (city?.isNotEmpty == true) parts.add(city!);
    if (area?.isNotEmpty == true) parts.add(area!);
    if (address?.isNotEmpty == true) parts.add(address!);
    return parts.isEmpty ? 'غير محدد' : parts.join(' - ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String? get googleMapsQueryUrl =>
      hasCoordinates ? 'https://www.google.com/maps?q=$latitude,$longitude' : null;

  String? get googleMapsDirectionsUrl => hasCoordinates
      ? 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude'
      : null;

  String get contactInfo {
    final parts = <String>[];
    if (phone?.isNotEmpty == true) parts.add('📞 $phone');
    if (email?.isNotEmpty == true) parts.add('✉️ $email');
    return parts.isEmpty ? 'لا يوجد' : parts.join(' | ');
  }

  bool get isNewCustomer {
    if (lastOrderDate == null) return true;
    return lastOrderDate!.isBefore(
      DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  bool get isRepeatCustomer {
    if (lastOrderDate == null) return false;
    return lastOrderDate!.isAfter(
      DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  int get customerStatusColor {
    if (totalOrders == null || totalOrders == 0) return 0xFF757575;
    if (totalOrders! < 5) return 0xFF4CAF50;
    if (totalOrders! < 10) return 0xFF2196F3;
    return 0xFFFF9800;
  }

  String get customerStatusText {
    if (totalOrders == null || totalOrders == 0) return 'جديد';
    if (totalOrders! < 5) return 'عادي';
    if (totalOrders! < 10) return 'متكرر';
    return 'VIP';
  }

  Map<String, dynamic> get displayInfo {
    return {
      'id': id,
      'name': name,
      'code': code,
      'displayName': displayName,
      'phone': phone,
      'email': email,
      'location': fullLocation,
      'contactInfo': contactInfo,
      'isActive': isActive,
      'status': status,
      'totalOrders': totalOrders ?? 0,
      'totalSpent': totalSpent ?? 0.0,
      'lastOrder': lastOrderDate != null
          ? DateFormat('yyyy/MM/dd').format(lastOrderDate!)
          : 'لا يوجد',
      'customerStatus': customerStatusText,
      'customerStatusColor': customerStatusColor,
    };
  }
}

class CustomerDocument {
  final String id;
  final String filename;
  final String url;
  final String storagePath;
  final String docType;
  final String? label;
  final String? uploadedById;
  final String? uploadedByName;
  final DateTime uploadedAt;

  CustomerDocument({
    required this.id,
    required this.filename,
    required this.url,
    required this.storagePath,
    required this.docType,
    this.label,
    this.uploadedById,
    this.uploadedByName,
    required this.uploadedAt,
  });

  factory CustomerDocument.fromJson(Map<String, dynamic> json) {
    String? uploadedById;
    if (json['uploadedBy'] is String) {
      uploadedById = json['uploadedBy'].toString();
    } else if (json['uploadedBy'] is Map<String, dynamic>) {
      uploadedById = json['uploadedBy']['_id']?.toString();
    }

    return CustomerDocument(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      filename: json['filename']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      storagePath: json['storagePath']?.toString() ?? '',
      docType: json['docType']?.toString() ?? '',
      label: json['label']?.toString(),
      uploadedById: uploadedById,
      uploadedByName: json['uploadedByName']?.toString(),
      uploadedAt:
          DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'filename': filename,
      'url': url,
      'storagePath': storagePath,
      'docType': docType,
      'label': label,
      'uploadedBy': uploadedById,
      'uploadedByName': uploadedByName,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}
