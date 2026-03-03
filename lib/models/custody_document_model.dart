import 'package:flutter/material.dart';

enum CustodyDocumentStatus { pending, approved, rejected }

extension CustodyDocumentStatusExtension on CustodyDocumentStatus {
  String get value {
    switch (this) {
      case CustodyDocumentStatus.pending:
        return 'pending';
      case CustodyDocumentStatus.approved:
        return 'approved';
      case CustodyDocumentStatus.rejected:
        return 'rejected';
    }
  }

  String get displayTitle {
    switch (this) {
      case CustodyDocumentStatus.pending:
        return 'قيد المراجعة';
      case CustodyDocumentStatus.approved:
        return 'معتمد';
      case CustodyDocumentStatus.rejected:
        return 'مرفوض';
    }
  }

  Color get badgeColor {
    switch (this) {
      case CustodyDocumentStatus.pending:
        return Colors.orange;
      case CustodyDocumentStatus.approved:
        return Colors.green;
      case CustodyDocumentStatus.rejected:
        return Colors.red;
    }
  }

  static CustodyDocumentStatus fromValue(String value) {
    switch (value) {
      case 'approved':
        return CustodyDocumentStatus.approved;
      case 'rejected':
        return CustodyDocumentStatus.rejected;
      case 'pending':
      default:
        return CustodyDocumentStatus.pending;
    }
  }
}

enum CustodyReturnStatus { none, pending, approved, rejected }

extension CustodyReturnStatusExtension on CustodyReturnStatus {
  String get value {
    switch (this) {
      case CustodyReturnStatus.none:
        return 'none';
      case CustodyReturnStatus.pending:
        return 'pending';
      case CustodyReturnStatus.approved:
        return 'approved';
      case CustodyReturnStatus.rejected:
        return 'rejected';
    }
  }

  String get displayTitle {
    switch (this) {
      case CustodyReturnStatus.none:
        return 'بدون مردود';
      case CustodyReturnStatus.pending:
        return 'قيد مراجعة المردود';
      case CustodyReturnStatus.approved:
        return 'مردود معتمد';
      case CustodyReturnStatus.rejected:
        return 'مردود مرفوض';
    }
  }

  Color get badgeColor {
    switch (this) {
      case CustodyReturnStatus.none:
        return Colors.grey;
      case CustodyReturnStatus.pending:
        return Colors.orange;
      case CustodyReturnStatus.approved:
        return Colors.green;
      case CustodyReturnStatus.rejected:
        return Colors.red;
    }
  }

  static CustodyReturnStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return CustodyReturnStatus.pending;
      case 'approved':
        return CustodyReturnStatus.approved;
      case 'rejected':
        return CustodyReturnStatus.rejected;
      case 'none':
      default:
        return CustodyReturnStatus.none;
    }
  }
}

enum CustodyFinanceStatus { none, disbursed, rejected }

extension CustodyFinanceStatusExtension on CustodyFinanceStatus {
  String get value {
    switch (this) {
      case CustodyFinanceStatus.none:
        return 'none';
      case CustodyFinanceStatus.disbursed:
        return 'disbursed';
      case CustodyFinanceStatus.rejected:
        return 'rejected';
    }
  }

  String get displayTitle {
    switch (this) {
      case CustodyFinanceStatus.none:
        return 'لم يتم الصرف';
      case CustodyFinanceStatus.disbursed:
        return 'معتمد (تم صرف العهدة)';
      case CustodyFinanceStatus.rejected:
        return 'تم رفض الصرف';
    }
  }

  Color get badgeColor {
    switch (this) {
      case CustodyFinanceStatus.none:
        return Colors.grey;
      case CustodyFinanceStatus.disbursed:
        return Colors.green;
      case CustodyFinanceStatus.rejected:
        return Colors.red;
    }
  }

  static CustodyFinanceStatus fromValue(String value) {
    switch (value) {
      case 'disbursed':
        return CustodyFinanceStatus.disbursed;
      case 'rejected':
        return CustodyFinanceStatus.rejected;
      case 'none':
      default:
        return CustodyFinanceStatus.none;
    }
  }
}

class CustodyDocumentRow {
  final String label;
  final String value;

  CustodyDocumentRow({required this.label, required this.value});

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  factory CustodyDocumentRow.fromJson(Map<String, dynamic> json) {
    return CustodyDocumentRow(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class CustodyDocument {
  final String id;
  final String documentNumber;
  final String documentTitle;
  final DateTime documentDate;
  final String custodianName;
  final String destinationType;
  final String destinationName;
  final String reason;
  final String notes;
  final List<CustodyDocumentRow> rows;
  final CustodyDocumentStatus status;
  final String createdBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String vehicleNumber;
  final double amount;
  final CustodyFinanceStatus financeStatus;
  final String? financeReviewedBy;
  final DateTime? financeReviewedAt;
  final String? financeRejectReason;
  final double returnAmount;
  final CustodyReturnStatus returnStatus;
  final String? returnRequestedBy;
  final DateTime? returnRequestedAt;
  final String? returnReviewedBy;
  final DateTime? returnReviewedAt;

  CustodyDocument({
    required this.id,
    required this.documentNumber,
    required this.documentTitle,
    required this.documentDate,
    required this.custodianName,
    required this.destinationType,
    required this.destinationName,
    required this.reason,
    required this.notes,
    required this.rows,
    required this.status,
    required this.createdBy,
    this.reviewedBy,
    this.reviewedAt,
    this.vehicleNumber = '',
    this.amount = 0,
    this.financeStatus = CustodyFinanceStatus.none,
    this.financeReviewedBy,
    this.financeReviewedAt,
    this.financeRejectReason,
    this.returnAmount = 0,
    this.returnStatus = CustodyReturnStatus.none,
    this.returnRequestedBy,
    this.returnRequestedAt,
    this.returnReviewedBy,
    this.returnReviewedAt,
  });

  CustodyDocument copyWith({
    String? id,
    String? documentNumber,
    String? documentTitle,
    DateTime? documentDate,
    String? custodianName,
    String? destinationType,
    String? destinationName,
    String? reason,
    String? notes,
    List<CustodyDocumentRow>? rows,
    CustodyDocumentStatus? status,
    String? createdBy,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? vehicleNumber,
    double? amount,
    CustodyFinanceStatus? financeStatus,
    String? financeReviewedBy,
    DateTime? financeReviewedAt,
    String? financeRejectReason,
    double? returnAmount,
    CustodyReturnStatus? returnStatus,
    String? returnRequestedBy,
    DateTime? returnRequestedAt,
    String? returnReviewedBy,
    DateTime? returnReviewedAt,
  }) {
    return CustodyDocument(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      documentTitle: documentTitle ?? this.documentTitle,
      documentDate: documentDate ?? this.documentDate,
      custodianName: custodianName ?? this.custodianName,
      destinationType: destinationType ?? this.destinationType,
      destinationName: destinationName ?? this.destinationName,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      rows: rows ?? this.rows,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      amount: amount ?? this.amount,
      financeStatus: financeStatus ?? this.financeStatus,
      financeReviewedBy: financeReviewedBy ?? this.financeReviewedBy,
      financeReviewedAt: financeReviewedAt ?? this.financeReviewedAt,
      financeRejectReason: financeRejectReason ?? this.financeRejectReason,
      returnAmount: returnAmount ?? this.returnAmount,
      returnStatus: returnStatus ?? this.returnStatus,
      returnRequestedBy: returnRequestedBy ?? this.returnRequestedBy,
      returnRequestedAt: returnRequestedAt ?? this.returnRequestedAt,
      returnReviewedBy: returnReviewedBy ?? this.returnReviewedBy,
      returnReviewedAt: returnReviewedAt ?? this.returnReviewedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentNumber': documentNumber,
      'documentTitle': documentTitle,
      'documentDate': documentDate.toIso8601String(),
      'custodianName': custodianName,
      'destinationType': destinationType,
      'destinationName': destinationName,
      'reason': reason,
      'notes': notes,
      'rows': rows.map((row) => row.toJson()).toList(),
      'status': status.value,
      'createdBy': createdBy,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'vehicleNumber': vehicleNumber,
      'amount': amount,
      'financeStatus': financeStatus.value,
      'financeReviewedBy': financeReviewedBy,
      'financeReviewedAt': financeReviewedAt?.toIso8601String(),
      'financeRejectReason': financeRejectReason,
      'returnAmount': returnAmount,
      'returnStatus': returnStatus.value,
      'returnRequestedBy': returnRequestedBy,
      'returnRequestedAt': returnRequestedAt?.toIso8601String(),
      'returnReviewedBy': returnReviewedBy,
      'returnReviewedAt': returnReviewedAt?.toIso8601String(),
    };
  }

  factory CustodyDocument.fromJson(Map<String, dynamic> json) {
    final rowsData =
        (json['rows'] as List<dynamic>?)
            ?.map(
              (e) => CustodyDocumentRow.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];

    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';

    return CustodyDocument(
      id: id,
      documentNumber: json['documentNumber']?.toString() ?? '',
      documentTitle: json['documentTitle']?.toString() ?? '',
      documentDate:
          DateTime.tryParse(json['documentDate']?.toString() ?? '') ??
          DateTime.now(),
      custodianName: json['custodianName']?.toString() ?? '',
      destinationType: json['destinationType']?.toString() ?? '',
      destinationName: json['destinationName']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      rows: rowsData,
      status: CustodyDocumentStatusExtension.fromValue(
        json['status']?.toString() ?? 'pending',
      ),
      createdBy: json['createdBy']?.toString() ?? '',
      reviewedBy: json['reviewedBy']?.toString(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt']!.toString())
          : null,
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      financeStatus: CustodyFinanceStatusExtension.fromValue(
        json['financeStatus']?.toString() ?? 'none',
      ),
      financeReviewedBy: json['financeReviewedBy']?.toString(),
      financeReviewedAt: json['financeReviewedAt'] != null
          ? DateTime.tryParse(json['financeReviewedAt']!.toString())
          : null,
      financeRejectReason: json['financeRejectReason']?.toString(),
      returnAmount: double.tryParse(json['returnAmount']?.toString() ?? '') ?? 0,
      returnStatus: CustodyReturnStatusExtension.fromValue(
        json['returnStatus']?.toString() ?? 'none',
      ),
      returnRequestedBy: json['returnRequestedBy']?.toString(),
      returnRequestedAt: json['returnRequestedAt'] != null
          ? DateTime.tryParse(json['returnRequestedAt']!.toString())
          : null,
      returnReviewedBy: json['returnReviewedBy']?.toString(),
      returnReviewedAt: json['returnReviewedAt'] != null
          ? DateTime.tryParse(json['returnReviewedAt']!.toString())
          : null,
    );
  }
}
