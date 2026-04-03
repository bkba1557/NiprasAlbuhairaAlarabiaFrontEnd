import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:order_tracker/models/transport_pricing_rule_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class OrderPricingPreview {
  final double quantity;
  final double fuelPricePerLiter;
  final double fuelSubtotal;
  final double transportCharge;
  final double returnCharge;
  final double subtotal;
  final double unitPricePerLiter;
  final double vatRate;
  final double vatAmount;
  final double totalWithVat;
  final String? sourceCity;
  final int? capacityLiters;
  final String? transportMode;
  final double? transportValue;
  final String? returnMode;
  final double? returnValue;
  final bool hasFuelPricing;
  final bool hasTransportPricing;
  final bool usedManualTransportOverride;
  final bool usedTransportRule;

  const OrderPricingPreview({
    required this.quantity,
    required this.fuelPricePerLiter,
    required this.fuelSubtotal,
    required this.transportCharge,
    required this.returnCharge,
    required this.subtotal,
    required this.unitPricePerLiter,
    required this.vatRate,
    required this.vatAmount,
    required this.totalWithVat,
    required this.sourceCity,
    required this.capacityLiters,
    required this.transportMode,
    required this.transportValue,
    required this.returnMode,
    required this.returnValue,
    required this.hasFuelPricing,
    required this.hasTransportPricing,
    required this.usedManualTransportOverride,
    required this.usedTransportRule,
  });

  Map<String, dynamic> toPricingSnapshot({
    required String requestType,
    required String fuelType,
  }) {
    return {
      'requestType': requestType,
      'fuelType': fuelType,
      'quantity': quantity,
      'fuelPricePerLiter': fuelPricePerLiter,
      'fuelSubtotal': fuelSubtotal,
      'transportCharge': transportCharge,
      'returnCharge': returnCharge,
      'subtotal': subtotal,
      'unitPricePerLiter': unitPricePerLiter,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'totalWithVat': totalWithVat,
      'sourceCity': sourceCity,
      'capacityLiters': capacityLiters,
      'transportMode': transportMode,
      'transportValue': transportValue,
      'returnMode': returnMode,
      'returnValue': returnValue,
      'usedManualTransportOverride': usedManualTransportOverride,
      'usedTransportRule': usedTransportRule,
    };
  }
}

class OrderManagementPricingService {
  static const List<int> supportedCapacities = <int>[20000, 32000];

  static TransportPricingRule? matchRule({
    required List<TransportPricingRule> rules,
    required String? fuelType,
    required String? sourceCity,
    required int? capacityLiters,
  }) {
    final normalizedFuelType = fuelType?.trim() ?? '';
    final normalizedSourceCity = sourceCity?.trim().toLowerCase() ?? '';

    if (normalizedFuelType.isEmpty ||
        normalizedSourceCity.isEmpty ||
        capacityLiters == null) {
      return null;
    }

    for (final rule in rules) {
      if (!rule.isActive) continue;
      if (rule.fuelType.trim() != normalizedFuelType) continue;
      if (rule.capacityLiters != capacityLiters) continue;
      if (rule.sourceCity.trim().toLowerCase() != normalizedSourceCity) {
        continue;
      }
      return rule;
    }

    return null;
  }

  static OrderPricingPreview buildPreview({
    required bool isTransport,
    required double quantity,
    required double vatRate,
    required double? fuelPricePerLiter,
    required String? sourceCity,
    required int? capacityLiters,
    TransportPricingRule? matchedRule,
    Map<String, dynamic>? transportOverride,
  }) {
    final normalizedQuantity = quantity < 0 ? 0.0 : quantity;
    final normalizedFuelPrice = fuelPricePerLiter ?? 0.0;
    final hasFuelPricing = fuelPricePerLiter != null && fuelPricePerLiter >= 0;

    String? readMode(String key) {
      final raw = transportOverride?[key]?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    }

    double? readNumber(String key) {
      final raw = transportOverride?[key];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    final overrideTransportMode = readMode('transportMode');
    final overrideTransportValue = readNumber('transportValue');
    final overrideReturnMode = readMode('returnMode');
    final overrideReturnValue = readNumber('returnValue');

    final usedManualTransportOverride =
        overrideTransportMode != null && overrideTransportValue != null;
    final usedTransportRule = !usedManualTransportOverride && matchedRule != null;

    final effectiveTransportMode =
        overrideTransportMode ??
        matchedRule?.transportMode ??
        (isTransport ? 'fixed' : null);
    final effectiveTransportValue =
        overrideTransportValue ?? matchedRule?.transportValue;
    final effectiveReturnMode =
        overrideReturnMode ??
        matchedRule?.returnMode ??
        (isTransport ? 'fixed' : null);
    final effectiveReturnValue = overrideReturnValue ?? matchedRule?.returnValue;

    double transportCharge = 0;
    double returnCharge = 0;
    var hasTransportPricing = !isTransport;

    if (isTransport &&
        effectiveTransportMode != null &&
        effectiveTransportValue != null) {
      hasTransportPricing = true;
      transportCharge = effectiveTransportMode == 'per_liter'
          ? effectiveTransportValue * normalizedQuantity
          : effectiveTransportValue;

      if (effectiveReturnMode != null && effectiveReturnValue != null) {
        returnCharge = effectiveReturnMode == 'per_liter'
            ? effectiveReturnValue * normalizedQuantity
            : effectiveReturnValue;
      }
    }

    final fuelSubtotal = normalizedFuelPrice * normalizedQuantity;
    final subtotal = fuelSubtotal + transportCharge + returnCharge;
    final unitPricePerLiter =
        normalizedQuantity > 0 ? subtotal / normalizedQuantity : 0.0;
    final normalizedVatRate = vatRate < 0 ? 0.0 : vatRate;
    final vatAmount = subtotal * normalizedVatRate;
    final totalWithVat = subtotal + vatAmount;

    return OrderPricingPreview(
      quantity: normalizedQuantity,
      fuelPricePerLiter: normalizedFuelPrice,
      fuelSubtotal: fuelSubtotal,
      transportCharge: transportCharge,
      returnCharge: returnCharge,
      subtotal: subtotal,
      unitPricePerLiter: unitPricePerLiter,
      vatRate: normalizedVatRate,
      vatAmount: vatAmount,
      totalWithVat: totalWithVat,
      sourceCity:
          (transportOverride?['sourceCity']?.toString().trim().isNotEmpty ??
                  false)
              ? transportOverride!['sourceCity'].toString().trim()
              : sourceCity?.trim(),
      capacityLiters:
          transportOverride?['capacityLiters'] is int
              ? transportOverride!['capacityLiters'] as int
              : int.tryParse(
                    transportOverride?['capacityLiters']?.toString() ?? '',
                  ) ??
                  capacityLiters,
      transportMode: effectiveTransportMode,
      transportValue: effectiveTransportValue,
      returnMode: effectiveReturnMode,
      returnValue: effectiveReturnValue,
      hasFuelPricing: hasFuelPricing,
      hasTransportPricing: hasTransportPricing,
      usedManualTransportOverride: usedManualTransportOverride,
      usedTransportRule: usedTransportRule,
    );
  }

  static Future<List<TransportPricingRule>> fetchTransportPricingRules({
    String? sourceCity,
    String? fuelType,
    int? capacityLiters,
    bool? isActive,
  }) async {
    await ApiService.loadToken();

    final uri = Uri.parse('${ApiEndpoints.baseUrl}/transport-pricing').replace(
      queryParameters: {
        if (sourceCity?.trim().isNotEmpty == true)
          'sourceCity': sourceCity!.trim(),
        if (fuelType?.trim().isNotEmpty == true) 'fuelType': fuelType!.trim(),
        if (capacityLiters != null) 'capacityLiters': capacityLiters.toString(),
        if (isActive != null) 'isActive': isActive.toString(),
      },
    );

    final response = await http.get(uri, headers: ApiService.headers);
    if (response.statusCode != 200) {
      throw Exception('فشل تحميل تسعيرة النقل');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final list = decoded is Map ? decoded['rules'] : decoded;
    return (list as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (entry) => TransportPricingRule.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList();
  }

  static Future<TransportPricingRule> saveTransportPricingRule({
    String? id,
    required Map<String, dynamic> payload,
  }) async {
    await ApiService.loadToken();

    final uri = id == null || id.trim().isEmpty
        ? Uri.parse('${ApiEndpoints.baseUrl}/transport-pricing')
        : Uri.parse('${ApiEndpoints.baseUrl}/transport-pricing/${id.trim()}');

    final body = json.encode(payload);
    final response = id == null || id.trim().isEmpty
        ? await http.post(uri, headers: ApiService.headers, body: body)
        : await http.put(uri, headers: ApiService.headers, body: body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر حفظ تسعيرة النقل');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final data = decoded is Map
        ? decoded['rule'] ?? decoded['transportPricingRule'] ?? decoded
        : decoded;

    return TransportPricingRule.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> deleteTransportPricingRule(String id) async {
    await ApiService.loadToken();
    final uri = Uri.parse('${ApiEndpoints.baseUrl}/transport-pricing/$id');
    final response = await http.delete(uri, headers: ApiService.headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر حذف تسعيرة النقل');
    }
  }
}
