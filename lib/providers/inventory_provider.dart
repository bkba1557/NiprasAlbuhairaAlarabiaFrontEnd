import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/inventory_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class InventoryProvider extends ChangeNotifier {
  List<InventoryBranch> _branches = [];
  List<InventoryWarehouse> _warehouses = [];
  List<InventorySupplier> _suppliers = [];
  List<InventoryInvoice> _invoices = [];
  List<InventoryStockItem> _stockItems = [];

  bool _isLoading = false;
  bool _isStockLoading = false;
  String? _error;

  List<InventoryBranch> get branches => _branches;
  List<InventoryWarehouse> get warehouses => _warehouses;
  List<InventorySupplier> get suppliers => _suppliers;
  List<InventoryInvoice> get invoices => _invoices;
  List<InventoryStockItem> get stockItems => _stockItems;

  bool get isLoading => _isLoading;
  bool get isStockLoading => _isStockLoading;
  String? get error => _error;

  List<InventoryWarehouse> warehousesByBranch(String? branchId) {
    if (branchId == null || branchId.isEmpty) return warehouses;
    return _warehouses.where((w) => w.branchId == branchId).toList();
  }

  InventoryBranch? findBranch(String id) =>
      _branches.where((b) => b.id == id).firstOrNull;

  InventoryWarehouse? findWarehouse(String id) =>
      _warehouses.where((w) => w.id == id).firstOrNull;

  InventorySupplier? findSupplier(String id) =>
      _suppliers.where((s) => s.id == id).firstOrNull;

  String branchName(String id) => findBranch(id)?.name ?? 'غير معروف';
  String warehouseName(String id) => findWarehouse(id)?.name ?? 'غير معروف';
  String supplierName(String id) => findSupplier(id)?.name ?? 'غير معروف';

  Future<void> fetchDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _fetchBranches(),
        _fetchWarehouses(),
        _fetchSuppliers(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchBranches() async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventoryBranches}'),
      headers: ApiService.headers,
    );

    if (response.statusCode == 200) {
      final data = ApiService.decodeJson(response);
      _branches = (data['data'] as List<dynamic>? ?? [])
          .map((e) => InventoryBranch.fromJson(e))
          .toList();
      return;
    }

    throw Exception('فشل جلب الفروع');
  }

  Future<void> _fetchWarehouses() async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventoryWarehouses}'),
      headers: ApiService.headers,
    );

    if (response.statusCode == 200) {
      final data = ApiService.decodeJson(response);
      _warehouses = (data['data'] as List<dynamic>? ?? [])
          .map((e) => InventoryWarehouse.fromJson(e))
          .toList();
      return;
    }

    throw Exception('فشل جلب المخازن');
  }

  Future<void> _fetchSuppliers() async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventorySuppliers}'),
      headers: ApiService.headers,
    );

    if (response.statusCode == 200) {
      final data = ApiService.decodeJson(response);
      _suppliers = (data['data'] as List<dynamic>? ?? [])
          .map((e) => InventorySupplier.fromJson(e))
          .toList();
      return;
    }

    throw Exception('فشل جلب الموردين');
  }

  Future<void> fetchStock({
    String? branchId,
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    _isStockLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (branchId != null && branchId.isNotEmpty) {
        params['branchId'] = branchId;
      }
      if (warehouseId != null && warehouseId.isNotEmpty) {
        params['warehouseId'] = warehouseId;
      }
      if (from != null) {
        params['startDate'] = from.toIso8601String();
      }
      if (to != null) {
        params['endDate'] = to.toIso8601String();
      }

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.inventoryStock}',
      ).replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _stockItems = (data['data'] as List<dynamic>? ?? [])
            .map((e) => InventoryStockItem.fromJson(e))
            .toList();
      } else {
        throw Exception('فشل جلب المخزون');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isStockLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createBranch(String name) async {
    _error = null;
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventoryBranches}'),
        headers: ApiService.headers,
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final branch = InventoryBranch.fromJson(data['data']);
        _branches = [branch, ..._branches];
        notifyListeners();
        return true;
      }
      _error =
          ApiService.decodeJsonMap(response)['message'] ?? 'فشل إنشاء الفرع';
      return false;
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر';
      return false;
    }
  }

  Future<bool> createWarehouse({
    required String name,
    required String branchId,
  }) async {
    _error = null;
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventoryWarehouses}'),
        headers: ApiService.headers,
        body: json.encode({'name': name, 'branchId': branchId}),
      );

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final warehouse = InventoryWarehouse.fromJson(data['data']);
        _warehouses = [warehouse, ..._warehouses];
        notifyListeners();
        return true;
      }
      _error =
          ApiService.decodeJsonMap(response)['message'] ?? 'فشل إنشاء المخزن';
      return false;
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر';
      return false;
    }
  }

  Future<bool> createSupplier({
    required String name,
    required String taxNumber,
    required String address,
    String? phone,
  }) async {
    _error = null;
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventorySuppliers}'),
        headers: ApiService.headers,
        body: json.encode({
          'name': name,
          'taxNumber': taxNumber,
          'address': address,
          'phone': phone,
        }),
      );

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final supplier = InventorySupplier.fromJson(data['data']);
        _suppliers = [supplier, ..._suppliers];
        notifyListeners();
        return true;
      }
      _error =
          ApiService.decodeJsonMap(response)['message'] ?? 'فشل إنشاء المورد';
      return false;
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر';
      return false;
    }
  }

  Future<bool> createInvoice({
    required String supplierId,
    required String branchId,
    required String warehouseId,
    required DateTime date,
    required List<InventoryLineItem> items,
  }) async {
    _error = null;
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.inventoryInvoices}'),
        headers: ApiService.headers,
        body: json.encode({
          'supplierId': supplierId,
          'branchId': branchId,
          'warehouseId': warehouseId,
          'invoiceDate': date.toIso8601String(),
          'items': items.map((item) => item.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final invoice = InventoryInvoice.fromJson(data['data']['invoice']);
        _invoices = [invoice, ..._invoices];
        await fetchStock();
        notifyListeners();
        return true;
      }
      _error =
          ApiService.decodeJsonMap(response)['message'] ?? 'فشل إنشاء الفاتورة';
      return false;
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر';
      return false;
    }
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
