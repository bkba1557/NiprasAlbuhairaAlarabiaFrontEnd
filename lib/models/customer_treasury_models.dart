double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '0') ?? 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;

  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

class CustomerTreasuryBranch {
  final String id;
  final String name;
  final String code;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerTreasuryBranch({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerTreasuryBranch.fromJson(Map<String, dynamic> json) {
    return CustomerTreasuryBranch(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }
}

class CustomerTreasurySummary {
  final double totalBilled;
  final double totalCollected;
  final double totalRemaining;
  final int customersCount;
  final int receiptsCount;
  final DateTime? computedAt;

  const CustomerTreasurySummary({
    required this.totalBilled,
    required this.totalCollected,
    required this.totalRemaining,
    required this.customersCount,
    required this.receiptsCount,
    this.computedAt,
  });

  factory CustomerTreasurySummary.fromJson(Map<String, dynamic> json) {
    return CustomerTreasurySummary(
      totalBilled: _asDouble(json['totalBilled']),
      totalCollected: _asDouble(json['totalCollected']),
      totalRemaining: _asDouble(json['totalRemaining']),
      customersCount: _asInt(json['customersCount']),
      receiptsCount: _asInt(json['receiptsCount']),
      computedAt: _asDateTime(json['computedAt']),
    );
  }
}

class CustomerTreasuryCustomerBalance {
  final String customerId;
  final String customerName;
  final String customerCode;
  final int ordersCount;
  final double billed;
  final double collected;
  final double remaining;
  final DateTime? lastOrderAt;
  final DateTime? lastReceiptAt;

  const CustomerTreasuryCustomerBalance({
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.ordersCount,
    required this.billed,
    required this.collected,
    required this.remaining,
    this.lastOrderAt,
    this.lastReceiptAt,
  });

  factory CustomerTreasuryCustomerBalance.fromJson(Map<String, dynamic> json) {
    return CustomerTreasuryCustomerBalance(
      customerId:
          json['customerId']?.toString() ??
          json['_id']?.toString() ??
          '',
      customerName: json['customerName']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      ordersCount: _asInt(json['ordersCount'] ?? json['totalOrders']),
      billed: _asDouble(json['billed'] ?? json['totalBilled']),
      collected: _asDouble(json['collected'] ?? json['totalCollected']),
      remaining: _asDouble(json['remaining'] ?? json['totalRemaining']),
      lastOrderAt: _asDateTime(json['lastOrderAt']),
      lastReceiptAt: _asDateTime(json['lastReceiptAt']),
    );
  }
}

class CustomerTreasuryReceipt {
  final String id;
  final String voucherNumber;
  final String branchId;
  final String branchName;
  final String branchCode;
  final String customerId;
  final String customerName;
  final String customerCode;
  final double amount;
  final String paymentMethod;
  final String notes;
  final String status;
  final String createdByName;
  final DateTime? createdAt;

  const CustomerTreasuryReceipt({
    required this.id,
    required this.voucherNumber,
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
    required this.status,
    required this.createdByName,
    this.createdAt,
  });

  factory CustomerTreasuryReceipt.fromJson(Map<String, dynamic> json) {
    return CustomerTreasuryReceipt(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      voucherNumber: json['voucherNumber']?.toString() ?? '',
      branchId: json['branchId'] is Map<String, dynamic>
          ? json['branchId']['_id']?.toString() ?? ''
          : json['branchId']?.toString() ?? '',
      branchName: json['branchName']?.toString() ?? '',
      branchCode: json['branchCode']?.toString() ?? '',
      customerId: json['customerId'] is Map<String, dynamic>
          ? json['customerId']['_id']?.toString() ?? ''
          : json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      paymentMethod: json['paymentMethod']?.toString() ?? 'نقداً',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
      createdAt: _asDateTime(json['createdAt']),
    );
  }
}

