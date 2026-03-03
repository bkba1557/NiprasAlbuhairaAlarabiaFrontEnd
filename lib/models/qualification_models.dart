class QualificationStation {
  final String id;
  final String name;
  final String? ownerName;
  final String? ownerPhone;
  final String city;
  final String region;
  final String address;
  final QualificationStatus status;
  final QualificationLocation location;
  final String? createdByName;
  final DateTime createdAt;
  final String? notes;
  final QualificationAssignee? assignedTo;
  final List<QualificationAttachment> attachments;
  final List<QualificationStatusChange> statusHistory;

  QualificationStation({
    required this.id,
    required this.name,
    this.ownerName,
    this.ownerPhone,
    required this.city,
    required this.region,
    required this.address,
    required this.status,
    required this.location,
    required this.createdAt,
    this.createdByName,
    this.notes,
    this.assignedTo,
    this.attachments = const [],
    this.statusHistory = const [],
  });

  factory QualificationStation.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt']?.toString();
    return QualificationStation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ownerName: json['ownerName']?.toString(),
      ownerPhone: json['ownerPhone']?.toString(),
      city: json['city']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      status: qualificationStatusFromString(json['status']?.toString()),
      location: json['location'] is Map<String, dynamic>
          ? QualificationLocation.fromJson(
              Map<String, dynamic>.from(json['location']),
            )
          : const QualificationLocation(lat: 0, lng: 0),
      createdByName: json['createdByName']?.toString() ??
          (json['createdBy'] is Map
              ? json['createdBy']['name']?.toString()
              : null),
      createdAt: createdAtValue != null
          ? DateTime.tryParse(createdAtValue)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes']?.toString(),
      assignedTo: json['assignedTo'] is Map<String, dynamic>
          ? QualificationAssignee.fromJson(
              Map<String, dynamic>.from(json['assignedTo']),
            )
          : null,
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) =>
              QualificationAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      statusHistory: (json['statusHistory'] as List<dynamic>? ?? [])
          .map((e) =>
              QualificationStatusChange.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson({
    bool includeId = false,
    bool includeAttachments = true,
  }) {
    return {
      if (includeId && id.isNotEmpty) '_id': id,
      'name': name,
      if (ownerName != null && ownerName!.trim().isNotEmpty)
        'ownerName': ownerName!.trim(),
      if (ownerPhone != null && ownerPhone!.trim().isNotEmpty)
        'ownerPhone': ownerPhone!.trim(),
      'city': city,
      'region': region,
      'address': address,
      'status': qualificationStatusToString(status),
      'location': location.toJson(),
      'notes': notes,
      if (assignedTo != null) 'assignedTo': assignedTo!.toJson(),
      if (includeAttachments && attachments.isNotEmpty)
        'attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }
}

class QualificationLocation {
  final double lat;
  final double lng;

  const QualificationLocation({required this.lat, required this.lng});

  factory QualificationLocation.fromJson(Map<String, dynamic> json) {
    return QualificationLocation(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class QualificationAttachment {
  final String url;
  final String type;
  final String name;
  final DateTime? createdAt;

  const QualificationAttachment({
    required this.url,
    required this.type,
    required this.name,
    this.createdAt,
  });

  factory QualificationAttachment.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt']?.toString();
    return QualificationAttachment(
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
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

class QualificationAssignee {
  final String? id;
  final String? name;

  const QualificationAssignee({this.id, this.name});

  factory QualificationAssignee.fromJson(Map<String, dynamic> json) {
    return QualificationAssignee(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      if (name != null && name!.isNotEmpty) 'name': name,
    };
  }
}

class QualificationStatusChange {
  final QualificationStatus status;
  final String reason;
  final List<QualificationAttachment> attachments;
  final String? changedByName;
  final QualificationAssignee? assignedTo;
  final DateTime createdAt;

  QualificationStatusChange({
    required this.status,
    required this.reason,
    required this.attachments,
    required this.createdAt,
    this.changedByName,
    this.assignedTo,
  });

  factory QualificationStatusChange.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt']?.toString();
    return QualificationStatusChange(
      status: qualificationStatusFromString(json['status']?.toString()),
      reason: json['reason']?.toString() ?? '',
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) =>
              QualificationAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: createdAtValue != null
          ? DateTime.tryParse(createdAtValue)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      changedByName: json['changedByName']?.toString(),
      assignedTo: json['assignedTo'] is Map<String, dynamic>
          ? QualificationAssignee.fromJson(
              Map<String, dynamic>.from(json['assignedTo']),
            )
          : null,
    );
  }
}

enum QualificationStatus { underReview, negotiating, agreed, notAgreed }

QualificationStatus qualificationStatusFromString(String? value) {
  switch (value) {
    case 'negotiating':
      return QualificationStatus.negotiating;
    case 'agreed':
      return QualificationStatus.agreed;
    case 'not_agreed':
      return QualificationStatus.notAgreed;
    case 'under_review':
    default:
      return QualificationStatus.underReview;
  }
}

String qualificationStatusToString(QualificationStatus status) {
  switch (status) {
    case QualificationStatus.negotiating:
      return 'negotiating';
    case QualificationStatus.agreed:
      return 'agreed';
    case QualificationStatus.notAgreed:
      return 'not_agreed';
    case QualificationStatus.underReview:
      return 'under_review';
  }
}
