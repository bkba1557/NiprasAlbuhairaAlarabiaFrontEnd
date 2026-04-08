class Driver {
  final String id;
  final String name;
  final String? nationalId;
  final String licenseNumber;
  final String phone;
  final String? email;
  final String? address;
  final String vehicleType;
  final String? vehicleNumber;
  final String vehicleStatus;
  final String? linkedVehicleId;
  final String? linkedVehiclePlateNumber;
  final String? linkedTankerId;
  final String? linkedTankerNumber;
  final DateTime? licenseExpiryDate;
  final DateTime? iqamaIssueDate;
  final DateTime? iqamaExpiryDate;
  final DateTime? insuranceExpiryDate;
  final DateTime? operationCardExpiryDate;
  final String status;
  final bool isActive;
  final String? notes;
  final String createdById;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Driver({
    required this.id,
    required this.name,
    this.nationalId,
    required this.licenseNumber,
    required this.phone,
    this.email,
    this.address,
    required this.vehicleType,
    this.vehicleNumber,
    this.vehicleStatus = 'فاضي',
    this.linkedVehicleId,
    this.linkedVehiclePlateNumber,
    this.linkedTankerId,
    this.linkedTankerNumber,
    this.licenseExpiryDate,
    this.iqamaIssueDate,
    this.iqamaExpiryDate,
    this.insuranceExpiryDate,
    this.operationCardExpiryDate,
    required this.status,
    required this.isActive,
    this.notes,
    required this.createdById,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Driver.empty() {
    return Driver(
      id: '',
      name: '',
      nationalId: null,
      licenseNumber: '',
      phone: '',
      vehicleType: 'غير محدد',
      vehicleStatus: 'فاضي',
      status: 'نشط',
      isActive: true,
      createdById: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    final rawLinkedVehicle = json['linkedVehicle'];
    final rawLinkedTanker = json['linkedTanker'];

    final linkedVehiclePlate = rawLinkedVehicle is Map
        ? rawLinkedVehicle['plateNumber']?.toString()
        : null;
    final linkedVehicleId = json['linkedVehicleId']?.toString() ??
        (rawLinkedVehicle is Map ? rawLinkedVehicle['_id']?.toString() : null);

    return Driver(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nationalId: json['nationalId']?.toString(),
      licenseNumber: json['licenseNumber']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      isActive: json['isActive'] ?? true,
      vehicleType:
          json['vehicleType']?.toString() ??
          rawLinkedVehicle?['vehicleType']?.toString() ??
          'غير محدد',
      vehicleNumber:
          json['vehicleNumber']?.toString() ?? linkedVehiclePlate,
      vehicleStatus: json['vehicleStatus']?.toString() ??
          rawLinkedVehicle?['status']?.toString() ??
          'فاضي',
      linkedVehicleId: linkedVehicleId,
      linkedVehiclePlateNumber: linkedVehiclePlate,
      linkedTankerId: json['linkedTankerId']?.toString() ??
          (rawLinkedTanker is Map ? rawLinkedTanker['_id']?.toString() : null),
      linkedTankerNumber: json['linkedTankerNumber']?.toString() ??
          (rawLinkedTanker is Map ? rawLinkedTanker['number']?.toString() : null),
      licenseExpiryDate: json['licenseExpiryDate'] != null
          ? DateTime.tryParse(json['licenseExpiryDate'].toString())
          : null,
      status: json['status']?.toString() ?? 'نشط',
      iqamaIssueDate: json['iqamaIssueDate'] != null
          ? DateTime.tryParse(json['iqamaIssueDate'].toString())
          : null,
      iqamaExpiryDate: json['iqamaExpiryDate'] != null
          ? DateTime.tryParse(json['iqamaExpiryDate'].toString())
          : null,
      insuranceExpiryDate: json['insuranceExpiryDate'] != null
          ? DateTime.tryParse(json['insuranceExpiryDate'].toString())
          : null,
      operationCardExpiryDate: json['operationCardExpiryDate'] != null
          ? DateTime.tryParse(json['operationCardExpiryDate'].toString())
          : null,
      notes: json['notes']?.toString(),
      createdById: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id']?.toString() ?? '',
      createdByName: json['createdBy'] is Map
          ? json['createdBy']['name']?.toString()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'nationalId': nationalId,
      'licenseNumber': licenseNumber,
      'phone': phone,
      'email': email,
      'address': address,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'vehicleStatus': vehicleStatus,
      'linkedVehicleId': linkedVehicleId,
      'licenseExpiryDate': licenseExpiryDate?.toIso8601String(),
      'iqamaIssueDate': iqamaIssueDate?.toIso8601String(),
      'iqamaExpiryDate': iqamaExpiryDate?.toIso8601String(),
      'insuranceExpiryDate': insuranceExpiryDate?.toIso8601String(),
      'operationCardExpiryDate': operationCardExpiryDate?.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  String get displayName =>
      licenseNumber.isNotEmpty ? '$name ($licenseNumber)' : name;

  String get displayInfo {
    final parts = <String>[
      name,
      if ((nationalId ?? '').trim().isNotEmpty) nationalId!.trim(),
      if (phone.isNotEmpty) phone,
      if ((vehicleNumber ?? '').trim().isNotEmpty) vehicleNumber!.trim(),
    ];
    return parts.join(' - ');
  }

  bool get isEmpty => id.isEmpty && name.isEmpty;
  bool get isNotEmpty => !isEmpty;
}
