import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/supplier_model.dart';
import '../utils/constants.dart';
import '../utils/api_service.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  Supplier? _selectedSupplier;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _filters = {};
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalSuppliers = 0;
  Map<String, dynamic> _statistics = {};

  List<Supplier> get suppliers =>
      _filteredSuppliers.isNotEmpty ? _filteredSuppliers : _suppliers;
  Supplier? get selectedSupplier => _selectedSupplier;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get filters => _filters;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalSuppliers => _totalSuppliers;
  Map<String, dynamic> get statistics => _statistics;

  Future<void> fetchSuppliers({
    int page = 1,
    Map<String, dynamic>? filters,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/suppliers?page=$page';

      if (filters != null) {
        _filters = {...filters};
        filters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            url += '&$key=$value';
          }
        });
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _suppliers = (data['suppliers'] as List)
            .map((e) => Supplier.fromJson(e))
            .toList();
        _statistics = data['statistics'] ?? {};
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['pages'];
        _totalSuppliers = data['pagination']['total'];

        _applyLocalFilters();

        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات الموردين');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyLocalFilters() {
    if (_filters.isEmpty) {
      _filteredSuppliers = _suppliers;
      return;
    }

    _filteredSuppliers = _suppliers.where((supplier) {
      bool matches = true;

      if (_filters['name'] != null && _filters['name'].isNotEmpty) {
        matches = matches && supplier.name.contains(_filters['name']);
      }

      if (_filters['company'] != null && _filters['company'].isNotEmpty) {
        matches = matches && supplier.company.contains(_filters['company']);
      }

      if (_filters['supplierType'] != null &&
          _filters['supplierType'].isNotEmpty) {
        matches = matches && supplier.supplierType == _filters['supplierType'];
      }

      if (_filters['isActive'] != null) {
        matches =
            matches && supplier.isActive == (_filters['isActive'] == 'true');
      }

      return matches;
    }).toList();
  }

  Future<void> fetchSupplierById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/suppliers/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _selectedSupplier = Supplier.fromJson(data['supplier']);
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات المورد');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSupplier(
    Supplier supplier,
    List<String>? documentPaths,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}/suppliers'),
      );

      // Add headers
      request.headers.addAll(ApiService.headers);

      // Add fields
      request.fields['name'] = supplier.name;
      request.fields['company'] = supplier.company;
      request.fields['contactPerson'] = supplier.contactPerson;
      request.fields['phone'] = supplier.phone;
      request.fields['supplierType'] = supplier.supplierType;
      request.fields['isActive'] = supplier.isActive.toString();
      request.fields['rating'] = supplier.rating.toString();

      if (supplier.email != null) {
        request.fields['email'] = supplier.email!;
      }
      if (supplier.secondaryPhone != null) {
        request.fields['secondaryPhone'] = supplier.secondaryPhone!;
      }
      if (supplier.address != null) {
        request.fields['address'] = supplier.address!;
      }
      if (supplier.city != null) {
        request.fields['city'] = supplier.city!;
      }
      if (supplier.country != null) {
        request.fields['country'] = supplier.country!;
      }
      if (supplier.taxNumber != null) {
        request.fields['taxNumber'] = supplier.taxNumber!;
      }
      if (supplier.commercialNumber != null) {
        request.fields['commercialNumber'] = supplier.commercialNumber!;
      }
      if (supplier.bankName != null) {
        request.fields['bankName'] = supplier.bankName!;
      }
      if (supplier.bankAccountNumber != null) {
        request.fields['bankAccountNumber'] = supplier.bankAccountNumber!;
      }
      if (supplier.bankAccountName != null) {
        request.fields['bankAccountName'] = supplier.bankAccountName!;
      }
      if (supplier.iban != null) {
        request.fields['iban'] = supplier.iban!;
      }
      if (supplier.notes != null) {
        request.fields['notes'] = supplier.notes!;
      }
      if (supplier.contractStartDate != null) {
        request.fields['contractStartDate'] = supplier.contractStartDate!
            .toIso8601String();
      }
      if (supplier.contractEndDate != null) {
        request.fields['contractEndDate'] = supplier.contractEndDate!
            .toIso8601String();
      }

      // Add documents
      if (documentPaths != null) {
        for (var path in documentPaths) {
          request.files.add(
            await http.MultipartFile.fromPath('documents', path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final newSupplier = Supplier.fromJson(data['supplier']);
        _suppliers.insert(0, newSupplier);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل إنشاء المورد';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier(
    String id,
    Supplier supplier,
    List<String>? newDocumentPaths,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiEndpoints.baseUrl}/suppliers/$id'),
      );

      // Add headers
      request.headers.addAll(ApiService.headers);

      // Add fields
      request.fields['name'] = supplier.name;
      request.fields['company'] = supplier.company;
      request.fields['contactPerson'] = supplier.contactPerson;
      request.fields['phone'] = supplier.phone;
      request.fields['supplierType'] = supplier.supplierType;
      request.fields['isActive'] = supplier.isActive.toString();
      request.fields['rating'] = supplier.rating.toString();

      if (supplier.email != null) {
        request.fields['email'] = supplier.email!;
      }
      if (supplier.secondaryPhone != null) {
        request.fields['secondaryPhone'] = supplier.secondaryPhone!;
      }
      if (supplier.address != null) {
        request.fields['address'] = supplier.address!;
      }
      if (supplier.city != null) {
        request.fields['city'] = supplier.city!;
      }
      if (supplier.country != null) {
        request.fields['country'] = supplier.country!;
      }
      if (supplier.taxNumber != null) {
        request.fields['taxNumber'] = supplier.taxNumber!;
      }
      if (supplier.commercialNumber != null) {
        request.fields['commercialNumber'] = supplier.commercialNumber!;
      }
      if (supplier.bankName != null) {
        request.fields['bankName'] = supplier.bankName!;
      }
      if (supplier.bankAccountNumber != null) {
        request.fields['bankAccountNumber'] = supplier.bankAccountNumber!;
      }
      if (supplier.bankAccountName != null) {
        request.fields['bankAccountName'] = supplier.bankAccountName!;
      }
      if (supplier.iban != null) {
        request.fields['iban'] = supplier.iban!;
      }
      if (supplier.notes != null) {
        request.fields['notes'] = supplier.notes!;
      }
      if (supplier.contractStartDate != null) {
        request.fields['contractStartDate'] = supplier.contractStartDate!
            .toIso8601String();
      }
      if (supplier.contractEndDate != null) {
        request.fields['contractEndDate'] = supplier.contractEndDate!
            .toIso8601String();
      }

      // Add new documents
      if (newDocumentPaths != null) {
        for (var path in newDocumentPaths) {
          request.files.add(
            await http.MultipartFile.fromPath('documents', path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updatedSupplier = Supplier.fromJson(data['supplier']);

        // Update in list
        final index = _suppliers.indexWhere((s) => s.id == id);
        if (index != -1) {
          _suppliers[index] = updatedSupplier;
        }

        // Update selected supplier if it's the same
        if (_selectedSupplier?.id == id) {
          _selectedSupplier = updatedSupplier;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل تحديث بيانات المورد';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSupplier(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/suppliers/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        // Remove from lists
        _suppliers.removeWhere((supplier) => supplier.id == id);
        _filteredSuppliers.removeWhere((supplier) => supplier.id == id);

        if (_selectedSupplier?.id == id) {
          _selectedSupplier = null;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل حذف المورد';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDocument(String supplierId, String documentId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/suppliers/$supplierId/documents/$documentId',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        // Remove document from supplier
        final supplier = _suppliers.firstWhere((s) => s.id == supplierId);
        supplier.documents.removeWhere((d) => d.id == documentId);

        if (_selectedSupplier?.id == supplierId) {
          _selectedSupplier!.documents.removeWhere((d) => d.id == documentId);
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Supplier>> searchSuppliers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/suppliers/search?query=$query'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        return (data['suppliers'] as List)
            .map((e) => Supplier.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/suppliers/statistics'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        return ApiService.decodeJson(response);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  void clearFilters() {
    _filters.clear();
    _filteredSuppliers = _suppliers;
    notifyListeners();
  }

  void setFilters(Map<String, dynamic> filters) {
    _filters = filters;
    _applyLocalFilters();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSelectedSupplier() {
    _selectedSupplier = null;
    notifyListeners();
  }
}
