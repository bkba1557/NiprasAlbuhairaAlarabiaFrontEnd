class InventoryBranch {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  InventoryBranch({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  factory InventoryBranch.fromJson(Map<String, dynamic> json) {
    return InventoryBranch(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'name': name,
      'isActive': isActive,
    };
  }
}

class InventoryWarehouse {
  final String id;
  final String name;
  final String branchId;
  final String branchName;
  final bool isActive;
  final DateTime createdAt;

  InventoryWarehouse({
    required this.id,
    required this.name,
    required this.branchId,
    required this.branchName,
    required this.isActive,
    required this.createdAt,
  });

  factory InventoryWarehouse.fromJson(Map<String, dynamic> json) {
    return InventoryWarehouse(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      branchId: json['branch'] is String
          ? json['branch']
          : json['branch']?['_id'] ?? '',
      branchName: json['branchName'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'name': name,
      'branchId': branchId,
      'branchName': branchName,
      'isActive': isActive,
    };
  }
}

class InventorySupplier {
  final String id;
  final String name;
  final String taxNumber;
  final String address;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  InventorySupplier({
    required this.id,
    required this.name,
    required this.taxNumber,
    required this.address,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });

  factory InventorySupplier.fromJson(Map<String, dynamic> json) {
    return InventorySupplier(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      taxNumber: json['taxNumber'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'name': name,
      'taxNumber': taxNumber,
      'address': address,
      'phone': phone,
      'isActive': isActive,
    };
  }
}

class InventoryLineItem {
  final String description;
  final double quantity;
  final double unitPrice;

  InventoryLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;
  double get tax => subtotal * InventoryTax.rate;
  double get total => subtotal + tax;

  factory InventoryLineItem.fromJson(Map<String, dynamic> json) {
    return InventoryLineItem(
      description: json['description'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

class InventoryInvoice {
  final String id;
  final String invoiceNumber;
  final String supplierId;
  final String supplierName;
  final String supplierTaxNumber;
  final String supplierAddress;
  final String branchId;
  final String branchName;
  final String warehouseId;
  final String warehouseName;
  final DateTime date;
  final List<InventoryLineItem> items;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;

  InventoryInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.supplierTaxNumber,
    required this.supplierAddress,
    required this.branchId,
    required this.branchName,
    required this.warehouseId,
    required this.warehouseName,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
  });

  factory InventoryInvoice.fromJson(Map<String, dynamic> json) {
    return InventoryInvoice(
      id: json['_id'] ?? json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      supplierId: json['supplier'] is String
          ? json['supplier']
          : json['supplier']?['_id'] ?? '',
      supplierName: json['supplierName'] ?? '',
      supplierTaxNumber: json['supplierTaxNumber'] ?? '',
      supplierAddress: json['supplierAddress'] ?? '',
      branchId: json['branch'] is String
          ? json['branch']
          : json['branch']?['_id'] ?? '',
      branchName: json['branchName'] ?? '',
      warehouseId: json['warehouse'] is String
          ? json['warehouse']
          : json['warehouse']?['_id'] ?? '',
      warehouseName: json['warehouseName'] ?? '',
      date: json['invoiceDate'] != null
          ? DateTime.parse(json['invoiceDate'])
          : DateTime.now(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => InventoryLineItem.fromJson(e))
          .toList(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'invoiceNumber': invoiceNumber,
      'supplierId': supplierId,
      'branchId': branchId,
      'warehouseId': warehouseId,
      'invoiceDate': date.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class InventoryStockItem {
  final String id;
  final String invoiceId;
  final String invoiceNumber;
  final String supplierId;
  final String supplierName;
  final String supplierTaxNumber;
  final String supplierAddress;
  final String branchId;
  final String branchName;
  final String warehouseId;
  final String warehouseName;
  final String description;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final DateTime date;

  InventoryStockItem({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.supplierTaxNumber,
    required this.supplierAddress,
    required this.branchId,
    required this.branchName,
    required this.warehouseId,
    required this.warehouseName,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.date,
  });

  factory InventoryStockItem.fromJson(Map<String, dynamic> json) {
    return InventoryStockItem(
      id: json['_id'] ?? json['id'] ?? '',
      invoiceId: json['invoice'] is String
          ? json['invoice']
          : json['invoice']?['_id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      supplierId: json['supplier'] is String
          ? json['supplier']
          : json['supplier']?['_id'] ?? '',
      supplierName: json['supplierName'] ?? '',
      supplierTaxNumber: json['supplierTaxNumber'] ?? '',
      supplierAddress: json['supplierAddress'] ?? '',
      branchId: json['branch'] is String
          ? json['branch']
          : json['branch']?['_id'] ?? '',
      branchName: json['branchName'] ?? '',
      warehouseId: json['warehouse'] is String
          ? json['warehouse']
          : json['warehouse']?['_id'] ?? '',
      warehouseName: json['warehouseName'] ?? '',
      description: json['description'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      taxRate: (json['taxRate'] ?? InventoryTax.rate).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      date: json['invoiceDate'] != null
          ? DateTime.parse(json['invoiceDate'])
          : DateTime.now(),
    );
  }
}

class InventoryTax {
  static const double rate = 0.15;
}
