class StatementRenewalModel {
  final String id;
  final DateTime expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  StatementRenewalModel({
    required this.id,
    required this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StatementRenewalModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is DateTime) return value;
      if (value == null) return fallback ?? DateTime.now();
      return DateTime.tryParse(value.toString()) ?? fallback ?? DateTime.now();
    }

    return StatementRenewalModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      expiryDate: parseDate(json['expiryDate'], fallback: DateTime.now()),
      createdAt: parseDate(json['createdAt'], fallback: DateTime.now()),
      updatedAt: parseDate(json['updatedAt'], fallback: DateTime.now()),
    );
  }
}

class StatementModel {
  final String id;
  final DateTime issueDate;
  final List<StatementRenewalModel> renewals;
  final DateTime createdAt;
  final DateTime updatedAt;

  StatementModel({
    required this.id,
    required this.issueDate,
    required this.renewals,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StatementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is DateTime) return value;
      if (value == null) return fallback ?? DateTime.now();
      return DateTime.tryParse(value.toString()) ?? fallback ?? DateTime.now();
    }

    final renewalsRaw = (json['renewals'] ?? json['entries'] ?? []) as List;
    final parsedRenewals = renewalsRaw
        .map(
          (e) => StatementRenewalModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    return StatementModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      issueDate: parseDate(json['issueDate'], fallback: DateTime.now()),
      renewals: parsedRenewals,
      createdAt: parseDate(json['createdAt'], fallback: DateTime.now()),
      updatedAt: parseDate(json['updatedAt'], fallback: DateTime.now()),
    );
  }

  StatementRenewalModel? get latestRenewal =>
      renewals.isEmpty ? null : renewals.last;
}

