class FuelStation {
  final String id;

  final String stationName;

  final String stationCode;

  final String address;

  final double latitude;

  final double longitude;

  final String? googleMapsLink;

  final String? wazeLink;

  final String stationType; // رئيسية، فرعية، متنقلة

  final String status; // نشطة، متوقفة، صيانة، مغلقة

  final double capacity; // السعة باللتر

  final String managerName;

  final String managerPhone;

  final String? managerEmail;

  final String region;

  final String city;

  final List<StationEquipment> equipment;

  final List<StationFuelType> fuelTypes;

  final List<StationAttachment> attachments;

  final DateTime establishedDate;

  final DateTime lastMaintenanceDate;

  final DateTime nextMaintenanceDate;

  final int totalTechnicians;

  final String createdBy;

  final String createdByName;

  final DateTime createdAt;

  final DateTime updatedAt;

  FuelStation({
    required this.id,

    required this.stationName,

    required this.stationCode,

    required this.address,

    required this.latitude,

    required this.longitude,

    this.googleMapsLink,

    this.wazeLink,

    required this.stationType,

    required this.status,

    required this.capacity,

    required this.managerName,

    required this.managerPhone,

    this.managerEmail,

    required this.region,

    required this.city,

    required this.equipment,

    required this.fuelTypes,

    required this.attachments,

    required this.establishedDate,

    required this.lastMaintenanceDate,

    required this.nextMaintenanceDate,

    required this.totalTechnicians,

    required this.createdBy,

    required this.createdByName,

    required this.createdAt,

    required this.updatedAt,
  });

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    return FuelStation(
      id: json['_id'] ?? json['id'],

      stationName: json['stationName'],

      stationCode: json['stationCode'],

      address: json['address'],

      latitude: json['latitude']?.toDouble() ?? 0.0,

      longitude: json['longitude']?.toDouble() ?? 0.0,

      googleMapsLink: json['googleMapsLink'],

      wazeLink: json['wazeLink'],

      stationType: json['stationType'],

      status: json['status'],

      capacity: json['capacity']?.toDouble() ?? 0.0,

      managerName: json['managerName'],

      managerPhone: json['managerPhone'],

      managerEmail: json['managerEmail'],

      region: json['region'],

      city: json['city'],

      equipment: (json['equipment'] as List<dynamic>? ?? [])
          .map((e) => StationEquipment.fromJson(e))
          .toList(),

      fuelTypes: (json['fuelTypes'] as List<dynamic>? ?? [])
          .map((e) => StationFuelType.fromJson(e))
          .toList(),

      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => StationAttachment.fromJson(e))
          .toList(),

      establishedDate: DateTime.parse(json['establishedDate']),

      lastMaintenanceDate: DateTime.parse(json['lastMaintenanceDate']),

      nextMaintenanceDate: DateTime.parse(json['nextMaintenanceDate']),

      totalTechnicians: json['totalTechnicians'] ?? 0,

      createdBy: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id'] ?? '',

      createdByName: json['createdBy'] is Map
          ? json['createdBy']['name'] ?? ''
          : '',

      createdAt: DateTime.parse(json['createdAt']),

      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationName': stationName,

      'stationCode': stationCode,

      'address': address,

      'latitude': latitude,

      'longitude': longitude,

      'googleMapsLink': googleMapsLink,

      'wazeLink': wazeLink,

      'stationType': stationType,

      'status': status,

      'capacity': capacity,

      'managerName': managerName,

      'managerPhone': managerPhone,

      'managerEmail': managerEmail,

      'region': region,

      'city': city,

      'equipment': equipment.map((e) => e.toJson()).toList(),

      'fuelTypes': fuelTypes.map((e) => e.toJson()).toList(),

      'attachments': attachments.map((e) => e.toJson()).toList(),

      'establishedDate': establishedDate.toIso8601String(),

      'lastMaintenanceDate': lastMaintenanceDate.toIso8601String(),

      'nextMaintenanceDate': nextMaintenanceDate.toIso8601String(),
    };
  }
}

class StationEquipment {
  final String id;

  final String equipmentName;

  final String equipmentType; // مضخة، خزان، نظام أمن، نظام حريق

  final String serialNumber;

  final String manufacturer;

  final DateTime installationDate;

  final DateTime lastServiceDate;

  final DateTime nextServiceDate;

  final String status; // نشط، معطل، تحت الصيانة

  final String? notes;

  StationEquipment({
    required this.id,

    required this.equipmentName,

    required this.equipmentType,

    required this.serialNumber,

    required this.manufacturer,

    required this.installationDate,

    required this.lastServiceDate,

    required this.nextServiceDate,

    required this.status,

    this.notes,
  });

  factory StationEquipment.fromJson(Map<String, dynamic> json) {
    return StationEquipment(
      id: json['_id'] ?? json['id'] ?? '',

      equipmentName: json['equipmentName'],

      equipmentType: json['equipmentType'],

      serialNumber: json['serialNumber'],

      manufacturer: json['manufacturer'],

      installationDate: DateTime.parse(json['installationDate']),

      lastServiceDate: DateTime.parse(json['lastServiceDate']),

      nextServiceDate: DateTime.parse(json['nextServiceDate']),

      status: json['status'],

      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'equipmentName': equipmentName,

      'equipmentType': equipmentType,

      'serialNumber': serialNumber,

      'manufacturer': manufacturer,

      'installationDate': installationDate.toIso8601String(),

      'lastServiceDate': lastServiceDate.toIso8601String(),

      'nextServiceDate': nextServiceDate.toIso8601String(),

      'status': status,

      'notes': notes,
    };
  }
}

class StationFuelType {
  final String id;

  final String fuelName; // بنزين 91، ديزل، إلخ

  final double pricePerLiter;

  final double availableQuantity;

  final double capacity;

  final String tankNumber;

  final DateTime lastDeliveryDate;

  final DateTime nextDeliveryDate;

  final String status; // متوفر، منخفض، فارغ

  StationFuelType({
    required this.id,

    required this.fuelName,

    required this.pricePerLiter,

    required this.availableQuantity,

    required this.capacity,

    required this.tankNumber,

    required this.lastDeliveryDate,

    required this.nextDeliveryDate,

    required this.status,
  });

  factory StationFuelType.fromJson(Map<String, dynamic> json) {
    return StationFuelType(
      id: json['_id'] ?? json['id'] ?? '',

      fuelName: json['fuelName'],

      pricePerLiter: json['pricePerLiter']?.toDouble() ?? 0.0,

      availableQuantity: json['availableQuantity']?.toDouble() ?? 0.0,

      capacity: json['capacity']?.toDouble() ?? 0.0,

      tankNumber: json['tankNumber'],

      lastDeliveryDate: DateTime.parse(json['lastDeliveryDate']),

      nextDeliveryDate: DateTime.parse(json['nextDeliveryDate']),

      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelName': fuelName,

      'pricePerLiter': pricePerLiter,

      'availableQuantity': availableQuantity,

      'capacity': capacity,

      'tankNumber': tankNumber,

      'lastDeliveryDate': lastDeliveryDate.toIso8601String(),

      'nextDeliveryDate': nextDeliveryDate.toIso8601String(),

      'status': status,
    };
  }
}

class StationAttachment {
  final String id;

  final String filename;

  final String fileType; // صورة، مخطط، عقد، رخصة

  final String path;

  final String uploadedBy;

  final DateTime uploadedAt;

  StationAttachment({
    required this.id,

    required this.filename,

    required this.fileType,

    required this.path,

    required this.uploadedBy,

    required this.uploadedAt,
  });

  factory StationAttachment.fromJson(Map<String, dynamic> json) {
    return StationAttachment(
      id: json['_id'] ?? json['id'] ?? '',

      filename: json['filename'],

      fileType: json['fileType'],

      path: json['path'],

      uploadedBy: json['uploadedBy'],

      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'filename': filename, 'fileType': fileType, 'path': path};
  }
}

class MaintenanceRecord {
  final String id;

  final String stationId;

  final String stationName;

  final String maintenanceType; // وقائية، طارئة، روتينية

  final String priority; // عالي، متوسط، منخفض

  final String status; // مطلوب، تحت التنفيذ، مكتمل، ملغى

  final String description;

  final String? technicianId;

  final String? technicianName;

  final DateTime scheduledDate;

  final DateTime? completedDate;

  final double estimatedCost;

  final double actualCost;

  final List<MaintenanceTask> tasks;

  final List<MaintenanceAttachment> attachments;

  final String? notes;

  final String createdBy;

  final String createdByName;

  final DateTime createdAt;

  MaintenanceRecord({
    required this.id,

    required this.stationId,

    required this.stationName,

    required this.maintenanceType,

    required this.priority,

    required this.status,

    required this.description,

    this.technicianId,

    this.technicianName,

    required this.scheduledDate,

    this.completedDate,

    required this.estimatedCost,

    required this.actualCost,

    required this.tasks,

    required this.attachments,

    this.notes,

    required this.createdBy,

    required this.createdByName,

    required this.createdAt,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['_id'] ?? json['id'],

      stationId: json['stationId'],

      stationName: json['stationName'],

      maintenanceType: json['maintenanceType'],

      priority: json['priority'],

      status: json['status'],

      description: json['description'],

      technicianId: json['technicianId'],

      technicianName: json['technicianName'],

      scheduledDate: DateTime.parse(json['scheduledDate']),

      completedDate: json['completedDate'] != null
          ? DateTime.parse(json['completedDate'])
          : null,

      estimatedCost: json['estimatedCost']?.toDouble() ?? 0.0,

      actualCost: json['actualCost']?.toDouble() ?? 0.0,

      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((e) => MaintenanceTask.fromJson(e))
          .toList(),

      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => MaintenanceAttachment.fromJson(e))
          .toList(),

      notes: json['notes'],

      createdBy: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id'] ?? '',

      createdByName: json['createdBy'] is Map
          ? json['createdBy']['name'] ?? ''
          : '',

      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,

      'stationName': stationName,

      'maintenanceType': maintenanceType,

      'priority': priority,

      'status': status,

      'description': description,

      'technicianId': technicianId,

      'scheduledDate': scheduledDate.toIso8601String(),

      'estimatedCost': estimatedCost,

      'actualCost': actualCost,

      'tasks': tasks.map((e) => e.toJson()).toList(),

      'notes': notes,
    };
  }
}

class MaintenanceTask {
  final String id;

  final String taskName;

  final String description;

  final String status; // منتظر، قيد التنفيذ، مكتمل

  final String? technicianId;

  final String? technicianName;

  final DateTime? startTime;

  final DateTime? endTime;

  final int estimatedHours;

  final int actualHours;

  final String? notes;

  MaintenanceTask({
    required this.id,

    required this.taskName,

    required this.description,

    required this.status,

    this.technicianId,

    this.technicianName,

    this.startTime,

    this.endTime,

    required this.estimatedHours,

    required this.actualHours,

    this.notes,
  });

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    return MaintenanceTask(
      id: json['_id'] ?? json['id'] ?? '',

      taskName: json['taskName'],

      description: json['description'],

      status: json['status'],

      technicianId: json['technicianId'],

      technicianName: json['technicianName'],

      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,

      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,

      estimatedHours: json['estimatedHours'] ?? 0,

      actualHours: json['actualHours'] ?? 0,

      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskName': taskName,

      'description': description,

      'status': status,

      'technicianId': technicianId,

      'estimatedHours': estimatedHours,

      'notes': notes,
    };
  }
}

class TechnicianReport {
  final String id;

  final String stationId;

  final String stationName;

  final String technicianId;

  final String technicianName;

  final String reportType; // يومي، أسبوعي، شهري، طارئ

  final String reportTitle;

  final String description;

  final List<ReportIssue> issues;

  final List<ReportAttachment> attachments;

  final String recommendations;

  final String status; // مسودة، مرفوع، معتمد، مرفوض

  final DateTime reportDate;

  final DateTime? approvalDate;

  final String? approvedBy;

  final String? approvedByName;

  final String? approvalNotes;

  final DateTime createdAt;

  TechnicianReport({
    required this.id,

    required this.stationId,

    required this.stationName,

    required this.technicianId,

    required this.technicianName,

    required this.reportType,

    required this.reportTitle,

    required this.description,

    required this.issues,

    required this.attachments,

    required this.recommendations,

    required this.status,

    required this.reportDate,

    this.approvalDate,

    this.approvedBy,

    this.approvedByName,

    this.approvalNotes,

    required this.createdAt,
  });

  factory TechnicianReport.fromJson(Map<String, dynamic> json) {
    return TechnicianReport(
      id: json['_id'] ?? json['id'],

      stationId: json['stationId'],

      stationName: json['stationName'],

      technicianId: json['technicianId'],

      technicianName: json['technicianName'],

      reportType: json['reportType'],

      reportTitle: json['reportTitle'],

      description: json['description'],

      issues: (json['issues'] as List<dynamic>? ?? [])
          .map((e) => ReportIssue.fromJson(e))
          .toList(),

      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => ReportAttachment.fromJson(e))
          .toList(),

      recommendations: json['recommendations'],

      status: json['status'],

      reportDate: DateTime.parse(json['reportDate']),

      approvalDate: json['approvalDate'] != null
          ? DateTime.parse(json['approvalDate'])
          : null,

      approvedBy: json['approvedBy'],

      approvedByName: json['approvedByName'],

      approvalNotes: json['approvalNotes'],

      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,

      'stationName': stationName,

      'technicianId': technicianId,

      'reportType': reportType,

      'reportTitle': reportTitle,

      'description': description,

      'issues': issues.map((e) => e.toJson()).toList(),

      'recommendations': recommendations,

      'status': status,

      'reportDate': reportDate.toIso8601String(),
    };
  }
}

class ReportIssue {
  final String id;

  final String issueType; // فني، كهربائي، ميكانيكي، أمني

  final String severity; // حرج، عالي، متوسط، منخفض

  final String description;

  final String status; // مكتشف، تحت الإصلاح، مكتمل

  final DateTime discoveryDate;

  final DateTime? resolutionDate;

  final String? resolutionNotes;

  ReportIssue({
    required this.id,

    required this.issueType,

    required this.severity,

    required this.description,

    required this.status,

    required this.discoveryDate,

    this.resolutionDate,

    this.resolutionNotes,
  });

  factory ReportIssue.fromJson(Map<String, dynamic> json) {
    return ReportIssue(
      id: json['_id'] ?? json['id'] ?? '',

      issueType: json['issueType'],

      severity: json['severity'],

      description: json['description'],

      status: json['status'],

      discoveryDate: DateTime.parse(json['discoveryDate']),

      resolutionDate: json['resolutionDate'] != null
          ? DateTime.parse(json['resolutionDate'])
          : null,

      resolutionNotes: json['resolutionNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issueType': issueType,

      'severity': severity,

      'description': description,

      'status': status,

      'discoveryDate': discoveryDate.toIso8601String(),

      'resolutionNotes': resolutionNotes,
    };
  }
}

class AlertNotification {
  final String id;

  final String alertType; // تحذير، إشعار، توجيه، تنبيه

  final String priority; // عالي، متوسط، منخفض

  final String target; // جميع الفنيين، فني معين، مدير المحطة

  final String? technicianId;

  final String? technicianName;

  final String stationId;

  final String stationName;

  final String title;

  final String message;

  final bool sendEmail;

  final bool sendSMS;

  final bool sendPush;

  final String status; // مرسل، مقروء، معالج

  final String sentBy;

  final String sentByName;

  final DateTime sentAt;

  final DateTime? readAt;

  final String? actionTaken;

  final DateTime? actionTakenAt;

  AlertNotification({
    required this.id,

    required this.alertType,

    required this.priority,

    required this.target,

    this.technicianId,

    this.technicianName,

    required this.stationId,

    required this.stationName,

    required this.title,

    required this.message,

    required this.sendEmail,

    required this.sendSMS,

    required this.sendPush,

    required this.status,

    required this.sentBy,

    required this.sentByName,

    required this.sentAt,

    this.readAt,

    this.actionTaken,

    this.actionTakenAt,
  });

  factory AlertNotification.fromJson(Map<String, dynamic> json) {
    return AlertNotification(
      id: json['_id'] ?? json['id'],

      alertType: json['alertType'],

      priority: json['priority'],

      target: json['target'],

      technicianId: json['technicianId'],

      technicianName: json['technicianName'],

      stationId: json['stationId'],

      stationName: json['stationName'],

      title: json['title'],

      message: json['message'],

      sendEmail: json['sendEmail'] ?? false,

      sendSMS: json['sendSMS'] ?? false,

      sendPush: json['sendPush'] ?? false,

      status: json['status'],

      sentBy: json['sentBy'],

      sentByName: json['sentByName'],

      sentAt: DateTime.parse(json['sentAt']),

      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,

      actionTaken: json['actionTaken'],

      actionTakenAt: json['actionTakenAt'] != null
          ? DateTime.parse(json['actionTakenAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alertType': alertType,

      'priority': priority,

      'target': target,

      'technicianId': technicianId,

      'stationId': stationId,

      'stationName': stationName,

      'title': title,

      'message': message,

      'sendEmail': sendEmail,

      'sendSMS': sendSMS,

      'sendPush': sendPush,
    };
  }
}

class TechnicianLocation {
  final String id;

  final String technicianId;

  final String technicianName;

  final String stationId;

  final String stationName;

  final double latitude;

  final double longitude;

  final double accuracy; // دقة الموقع بالأمتار

  final double speed; // السرعة كم/ساعة

  final String activity; // متحرك، ثابت، في الطريق

  final DateTime timestamp;

  final String? notes;

  TechnicianLocation({
    required this.id,

    required this.technicianId,

    required this.technicianName,

    required this.stationId,

    required this.stationName,

    required this.latitude,

    required this.longitude,

    required this.accuracy,

    required this.speed,

    required this.activity,

    required this.timestamp,

    this.notes,
  });

  factory TechnicianLocation.fromJson(Map<String, dynamic> json) {
    return TechnicianLocation(
      id: json['_id'] ?? json['id'],

      technicianId: json['technicianId'],

      technicianName: json['technicianName'],

      stationId: json['stationId'],

      stationName: json['stationName'],

      latitude: json['latitude']?.toDouble() ?? 0.0,

      longitude: json['longitude']?.toDouble() ?? 0.0,

      accuracy: json['accuracy']?.toDouble() ?? 0.0,

      speed: json['speed']?.toDouble() ?? 0.0,

      activity: json['activity'],

      timestamp: DateTime.parse(json['timestamp']),

      notes: json['notes'],
    );
  }
}

class MaintenanceAttachment {
  final String id;
  final String filename;
  final String fileType;
  final String path;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;

  MaintenanceAttachment({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.path,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  factory MaintenanceAttachment.fromJson(Map<String, dynamic> json) {
    return MaintenanceAttachment(
      id: json['_id'] ?? json['id'] ?? '',
      filename: json['filename'],
      fileType: json['fileType'],
      path: json['path'],
      uploadedBy: json['uploadedBy'],
      uploadedByName: json['uploadedByName'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'fileType': fileType,
      'path': path,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

class ReportAttachment {
  final String id;
  final String filename;
  final String fileType;
  final String path;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;

  ReportAttachment({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.path,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  factory ReportAttachment.fromJson(Map<String, dynamic> json) {
    return ReportAttachment(
      id: json['_id'] ?? json['id'] ?? '',
      filename: json['filename'],
      fileType: json['fileType'],
      path: json['path'],
      uploadedBy: json['uploadedBy'],
      uploadedByName: json['uploadedByName'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'fileType': fileType,
      'path': path,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

class ApprovalAttachment {
  final String id;
  final String filename;
  final String fileType;
  final String path;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;

  ApprovalAttachment({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.path,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  factory ApprovalAttachment.fromJson(Map<String, dynamic> json) {
    return ApprovalAttachment(
      id: json['_id'] ?? json['id'] ?? '',
      filename: json['filename'],
      fileType: json['fileType'],
      path: json['path'],
      uploadedBy: json['uploadedBy'],
      uploadedByName: json['uploadedByName'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'fileType': fileType,
      'path': path,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

class ApprovalRequest {
  final String id;

  final String requestType; // صيانة، شراء، إصلاح، بدل سفر

  final String stationId;

  final String stationName;

  final String title;

  final String description;

  final double amount;

  final String currency;

  final List<ApprovalAttachment> attachments;

  final String status; // منتظر، قيد المراجعة، معتمد، مرفوض

  final String requestedBy;

  final String requestedByName;

  final DateTime requestedAt;

  final String? reviewedBy;

  final String? reviewedByName;

  final DateTime? reviewedAt;

  final String? reviewNotes;

  final String? approvedBy;

  final String? approvedByName;

  final DateTime? approvedAt;

  final String? approvalNotes;

  ApprovalRequest({
    required this.id,

    required this.requestType,

    required this.stationId,

    required this.stationName,

    required this.title,

    required this.description,

    required this.amount,

    required this.currency,

    required this.attachments,

    required this.status,

    required this.requestedBy,

    required this.requestedByName,

    required this.requestedAt,

    this.reviewedBy,

    this.reviewedByName,

    this.reviewedAt,

    this.reviewNotes,

    this.approvedBy,

    this.approvedByName,

    this.approvedAt,

    this.approvalNotes,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['_id'] ?? json['id'],

      requestType: json['requestType'],

      stationId: json['stationId'],

      stationName: json['stationName'],

      title: json['title'],

      description: json['description'],

      amount: json['amount']?.toDouble() ?? 0.0,

      currency: json['currency'] ?? 'SAR',

      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => ApprovalAttachment.fromJson(e))
          .toList(),

      status: json['status'],

      requestedBy: json['requestedBy'],

      requestedByName: json['requestedByName'],

      requestedAt: DateTime.parse(json['requestedAt']),

      reviewedBy: json['reviewedBy'],

      reviewedByName: json['reviewedByName'],

      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'])
          : null,

      reviewNotes: json['reviewNotes'],

      approvedBy: json['approvedBy'],

      approvedByName: json['approvedByName'],

      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,

      approvalNotes: json['approvalNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestType': requestType,

      'stationId': stationId,

      'stationName': stationName,

      'title': title,

      'description': description,

      'amount': amount,

      'currency': currency,

      'attachments': attachments.map((e) => e?.toJson()).toList(),

      'status': status,
    };
  }
}
