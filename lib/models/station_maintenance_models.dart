class StationMaintenanceAttachment {
  final String filename;
  final String path;
  final String? fileType;
  final DateTime? uploadedAt;

  const StationMaintenanceAttachment({
    required this.filename,
    required this.path,
    this.fileType,
    this.uploadedAt,
  });

  factory StationMaintenanceAttachment.fromJson(Map<String, dynamic> json) {
    return StationMaintenanceAttachment(
      filename: json['filename']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      fileType: json['fileType']?.toString(),
      uploadedAt: _parseDate(json['uploadedAt']),
    );
  }
}

class StationMaintenanceInvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  const StationMaintenanceInvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory StationMaintenanceInvoiceItem.fromJson(Map<String, dynamic> json) {
    return StationMaintenanceInvoiceItem(
      description: json['description']?.toString() ?? '',
      quantity: _toDouble(json['quantity']),
      unitPrice: _toDouble(json['unitPrice']),
      subtotal: _toDouble(json['subtotal']),
    );
  }
}

class StationMaintenanceInvoice {
  final String invoiceNumber;
  final String vendorName;
  final DateTime? issuedAt;
  final List<StationMaintenanceInvoiceItem> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final String? fileName;
  final String? filePath;
  final String? notes;

  const StationMaintenanceInvoice({
    required this.invoiceNumber,
    required this.vendorName,
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    this.issuedAt,
    this.fileName,
    this.filePath,
    this.notes,
  });

  factory StationMaintenanceInvoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return StationMaintenanceInvoice(
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? '',
      issuedAt: _parseDate(json['issuedAt']),
      items: rawItems
          .map((item) => StationMaintenanceInvoiceItem.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      subtotal: _toDouble(json['subtotal']),
      taxRate: _toDouble(json['taxRate']),
      taxAmount: _toDouble(json['taxAmount']),
      total: _toDouble(json['total']),
      fileName: json['fileName']?.toString(),
      filePath: json['filePath']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class StationMaintenanceSummary {
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;

  const StationMaintenanceSummary({
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
  });

  factory StationMaintenanceSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StationMaintenanceSummary(
        subtotal: 0,
        taxRate: 0,
        taxAmount: 0,
        total: 0,
      );
    }
    return StationMaintenanceSummary(
      subtotal: _toDouble(json['subtotal']),
      taxRate: _toDouble(json['taxRate']),
      taxAmount: _toDouble(json['taxAmount']),
      total: _toDouble(json['total']),
    );
  }
}

class StationMaintenanceReview {
  final String decision;
  final String? notes;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  const StationMaintenanceReview({
    required this.decision,
    this.notes,
    this.reviewedByName,
    this.reviewedAt,
  });

  factory StationMaintenanceReview.fromJson(Map<String, dynamic> json) {
    return StationMaintenanceReview(
      decision: json['decision']?.toString() ?? '',
      notes: json['notes']?.toString(),
      reviewedByName: json['reviewedByName']?.toString(),
      reviewedAt: _parseDate(json['reviewedAt']),
    );
  }
}

class StationMaintenanceRating {
  final double score;
  final String? note;
  final String? ratedByName;
  final DateTime? ratedAt;

  const StationMaintenanceRating({
    required this.score,
    this.note,
    this.ratedByName,
    this.ratedAt,
  });

  factory StationMaintenanceRating.fromJson(Map<String, dynamic> json) {
    return StationMaintenanceRating(
      score: _toDouble(json['score']),
      note: json['note']?.toString(),
      ratedByName: json['ratedByName']?.toString(),
      ratedAt: _parseDate(json['ratedAt']),
    );
  }
}

class StationMaintenanceLocation {
  final double? lat;
  final double? lng;
  final String? address;
  final String? googleMapsUrl;

  const StationMaintenanceLocation({
    this.lat,
    this.lng,
    this.address,
    this.googleMapsUrl,
  });

  factory StationMaintenanceLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StationMaintenanceLocation();
    }
    return StationMaintenanceLocation(
      lat: _toNullableDouble(json['lat']),
      lng: _toNullableDouble(json['lng']),
      address: json['address']?.toString(),
      googleMapsUrl: json['googleMapsUrl']?.toString(),
    );
  }
}

class StationMaintenanceRequest {
  final String id;
  final String? requestNumber;
  final String? stationId;
  final String stationName;
  final StationMaintenanceLocation? stationLocation;
  final String type;
  final String title;
  final String description;
  final String status;
  final String? createdBy;
  final String? createdByName;
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? assignedAt;
  final DateTime? openedAt;
  final DateTime? submittedAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? technicianNotes;
  final List<StationMaintenanceAttachment> beforePhotos;
  final List<StationMaintenanceAttachment> afterPhotos;
  final List<StationMaintenanceAttachment> videos;
  final List<StationMaintenanceAttachment> invoiceFiles;
  final List<StationMaintenanceInvoice> invoices;
  final StationMaintenanceSummary summary;
  final StationMaintenanceReview? review;
  final StationMaintenanceRating? rating;
  final int elapsedSeconds;

  const StationMaintenanceRequest({
    required this.id,
    this.requestNumber,
    required this.stationName,
    this.stationLocation,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.beforePhotos,
    required this.afterPhotos,
    required this.videos,
    required this.invoiceFiles,
    required this.invoices,
    required this.summary,
    required this.elapsedSeconds,
    this.stationId,
    this.createdBy,
    this.createdByName,
    this.assignedTo,
    this.assignedToName,
    this.assignedAt,
    this.openedAt,
    this.submittedAt,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.technicianNotes,
    this.review,
    this.rating,
  });

  factory StationMaintenanceRequest.fromJson(Map<String, dynamic> json) {
    return StationMaintenanceRequest(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      requestNumber: json['requestNumber']?.toString(),
      stationId: _extractId(json['stationId']),
      stationName: json['stationName']?.toString() ?? '',
      stationLocation: StationMaintenanceLocation.fromJson(
        json['stationLocation'] is Map
            ? Map<String, dynamic>.from(json['stationLocation'])
            : null,
      ),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdBy: _extractId(json['createdBy']),
      createdByName: json['createdByName']?.toString(),
      assignedTo: _extractId(json['assignedTo']),
      assignedToName: json['assignedToName']?.toString(),
      assignedAt: _parseDate(json['assignedAt']),
      openedAt: _parseDate(json['openedAt']),
      submittedAt: _parseDate(json['submittedAt']),
      closedAt: _parseDate(json['closedAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      technicianNotes: json['technicianNotes']?.toString(),
      beforePhotos: _parseAttachments(json['beforePhotos']),
      afterPhotos: _parseAttachments(json['afterPhotos']),
      videos: _parseAttachments(json['videos']),
      invoiceFiles: _parseAttachments(json['invoiceFiles']),
      invoices: _parseInvoices(json['invoices']),
      summary: StationMaintenanceSummary.fromJson(
        json['summary'] is Map ? Map<String, dynamic>.from(json['summary']) : null,
      ),
      review: json['review'] is Map
          ? StationMaintenanceReview.fromJson(
              Map<String, dynamic>.from(json['review']),
            )
          : null,
      rating: json['rating'] is Map
          ? StationMaintenanceRating.fromJson(
              Map<String, dynamic>.from(json['rating']),
            )
          : null,
      elapsedSeconds: _toInt(json['elapsedSeconds']),
    );
  }
}

List<StationMaintenanceAttachment> _parseAttachments(dynamic value) {
  final rawList = value is List ? value : <dynamic>[];
  return rawList
      .map((item) => StationMaintenanceAttachment.fromJson(
            Map<String, dynamic>.from(item as Map),
          ))
      .toList();
}

List<StationMaintenanceInvoice> _parseInvoices(dynamic value) {
  final rawList = value is List ? value : <dynamic>[];
  return rawList
      .map((item) => StationMaintenanceInvoice.fromJson(
            Map<String, dynamic>.from(item as Map),
          ))
      .toList();
}

String? _extractId(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map) {
    return value['_id']?.toString() ?? value['\$oid']?.toString();
  }
  return value.toString();
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
