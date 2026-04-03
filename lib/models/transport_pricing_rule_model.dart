class TransportPricingRule {
  final String id;
  final String sourceCity;
  final int capacityLiters;
  final String fuelType;
  final String transportMode;
  final double transportValue;
  final String returnMode;
  final double returnValue;
  final bool isActive;
  final String? notes;

  const TransportPricingRule({
    required this.id,
    required this.sourceCity,
    required this.capacityLiters,
    required this.fuelType,
    required this.transportMode,
    required this.transportValue,
    required this.returnMode,
    required this.returnValue,
    required this.isActive,
    this.notes,
  });

  factory TransportPricingRule.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TransportPricingRule(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      sourceCity: json['sourceCity']?.toString() ?? '',
      capacityLiters: parseInt(json['capacityLiters']),
      fuelType: json['fuelType']?.toString() ?? '',
      transportMode: json['transportMode']?.toString() ?? 'per_liter',
      transportValue: parseDouble(json['transportValue']),
      returnMode: json['returnMode']?.toString() ?? 'fixed',
      returnValue: parseDouble(json['returnValue']),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'sourceCity': sourceCity,
      'capacityLiters': capacityLiters,
      'fuelType': fuelType,
      'transportMode': transportMode,
      'transportValue': transportValue,
      'returnMode': returnMode,
      'returnValue': returnValue,
      'isActive': isActive,
      'notes': notes,
    };
  }

  double transportChargeFor(double quantity) {
    return transportMode == 'fixed' ? transportValue : transportValue * quantity;
  }

  double returnChargeFor(double quantity) {
    return returnMode == 'fixed' ? returnValue : returnValue * quantity;
  }
}

