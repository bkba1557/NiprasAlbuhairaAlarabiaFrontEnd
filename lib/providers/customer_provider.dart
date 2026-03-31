import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/services/firebase_storage_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

const Map<String, String> _customerDocumentTypeLabels = {
  'commercialRecord': 'السجل التجاري',
  'energyCertificate': 'شهادة الطاقة',
  'taxCertificate': 'شهادة الضريبة',
  'safetyCertificate': 'شهادة السلامة',
  'municipalLicense': 'رخصة بلدي',
  'additionalDocument': 'مرفق إضافي',
};

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _hasSearchFilter = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  List<Customer> get customers =>
      _hasSearchFilter ? _filteredCustomers : _customers;
  Customer? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCustomers({
    int page = 1,
    String? search,
    bool fetchAll = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (fetchAll) {
        final allCustomers = <Customer>[];
        var currentPage = page;
        var totalPages = 1;

        while (currentPage <= totalPages) {
          final response = await http.get(
            _customersUri(page: currentPage, search: search),
            headers: ApiService.headers,
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to fetch customers.');
          }

          final data = _decodeMap(response);
          final pageCustomers = (data['customers'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(Customer.fromJson)
              .toList();
          allCustomers.addAll(pageCustomers);

          final pagination = data['pagination'] as Map<String, dynamic>?;
          totalPages = pagination?['pages'] is int
              ? pagination!['pages'] as int
              : int.tryParse(pagination?['pages']?.toString() ?? '') ??
                    totalPages;
          currentPage += 1;
        }

        _customers = allCustomers;
        _currentPage = page;
        _totalPages = totalPages;
      } else {
        final response = await http.get(
          _customersUri(page: page, search: search),
          headers: ApiService.headers,
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch customers.');
        }

        final data = _decodeMap(response);
        _customers = (data['customers'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Customer.fromJson)
            .toList();

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        _currentPage = pagination['page'] is int
            ? pagination['page'] as int
            : int.tryParse(pagination['page']?.toString() ?? '') ?? page;
        _totalPages = pagination['pages'] is int
            ? pagination['pages'] as int
            : int.tryParse(pagination['pages']?.toString() ?? '') ?? 1;
      }

      _filteredCustomers = List<Customer>.from(_customers);
      _hasSearchFilter = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchCustomers(String query) {
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isEmpty) {
      _hasSearchFilter = false;
      _filteredCustomers = List<Customer>.from(_customers);
    } else {
      _hasSearchFilter = true;
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(trimmedQuery) ||
            customer.code.toLowerCase().contains(trimmedQuery) ||
            (customer.phone?.toLowerCase().contains(trimmedQuery) ?? false);
      }).toList();
    }
    notifyListeners();
  }

  Future<Customer?> createCustomer(Map<String, dynamic> customerData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/customers'),
        headers: ApiService.headers,
        body: json.encode(customerData),
      );

      final data = _decodeMap(response);
      if (response.statusCode == 201) {
        final newCustomer = Customer.fromJson(data['customer']);
        _upsertCustomer(newCustomer);
        return newCustomer;
      }

      _error = data['error']?.toString() ?? 'فشل إنشاء العميل';
      return null;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadCustomerDocuments(
    String customerId,
    List<CustomerDocumentUpload> documents,
  ) async {
    if (documents.isEmpty) return true;

    try {
      final uploadedDocuments = <Map<String, dynamic>>[];
      for (final document in documents) {
        final uploaded = await FirebaseStorageService.uploadCustomerDocument(
          customerKey: customerId,
          docType: document.docType,
          file: document.file,
        );
        uploadedDocuments.add({
          'filename': uploaded['filename']?.toString() ?? document.fileName,
          'url': uploaded['url']?.toString() ?? '',
          'storagePath': uploaded['storagePath']?.toString() ?? '',
          'docType': document.docType,
          'label': _customerDocumentTypeLabels[document.docType],
        });
      }

      final response = await http.post(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.customerDocuments(customerId)}',
        ),
        headers: ApiService.headers,
        body: json.encode({'documents': uploadedDocuments}),
      );
      final responseBody = _decodeMap(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final customerJson = responseBody['customer'];
        if (customerJson is Map<String, dynamic>) {
          _upsertCustomer(Customer.fromJson(customerJson));
        }
        notifyListeners();
        return true;
      }

      _error = responseBody['error']?.toString() ?? 'فشل رفع المستندات';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Customer?> replaceCustomerDocument({
    required String customerId,
    required CustomerDocument document,
    required PlatformFile file,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final uploaded = await FirebaseStorageService.uploadCustomerDocument(
        customerKey: customerId,
        docType: document.docType,
        file: file,
      );

      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.customerDocument(customerId, document.id)}',
        ),
        headers: ApiService.headers,
        body: json.encode({
          'filename': uploaded['filename']?.toString() ?? file.name,
          'url': uploaded['url']?.toString() ?? '',
          'storagePath': uploaded['storagePath']?.toString() ?? '',
          'docType': document.docType,
          'label': document.label ?? _customerDocumentTypeLabels[document.docType],
        }),
      );

      final responseBody = _decodeMap(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final customerJson = responseBody['customer'];
        if (customerJson is Map<String, dynamic>) {
          final updatedCustomer = Customer.fromJson(customerJson);
          _upsertCustomer(updatedCustomer);
          notifyListeners();
          return updatedCustomer;
        }
        return null;
      }

      _error =
          responseBody['error']?.toString() ?? 'فشل استبدال المستند';
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Customer?> deleteCustomerDocument({
    required String customerId,
    required String documentId,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.customerDocument(customerId, documentId)}',
        ),
        headers: ApiService.headers,
      );

      final responseBody = _decodeMap(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final customerJson = responseBody['customer'];
        if (customerJson is Map<String, dynamic>) {
          final updatedCustomer = Customer.fromJson(customerJson);
          _upsertCustomer(updatedCustomer);
          notifyListeners();
          return updatedCustomer;
        }
        return null;
      }

      _error =
          responseBody['error']?.toString() ?? 'فشل حذف المستند';
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCustomer(
    String id,
    Map<String, dynamic> customerData,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}/customers/$id'),
        headers: ApiService.headers,
        body: json.encode(customerData),
      );

      final data = _decodeMap(response);
      if (response.statusCode == 200) {
        final updatedCustomer = Customer.fromJson(data['customer']);
        _upsertCustomer(updatedCustomer);
        return true;
      }

      _error = data['error']?.toString() ?? 'فشل تحديث العميل';
      return false;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomerById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/customers/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = _decodeMap(response);
        _selectedCustomer = Customer.fromJson(data['customer']);
      } else {
        throw Exception('فشل في جلب بيانات العميل');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCustomer(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/customers/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _customers.removeWhere((customer) => customer.id == id);
        _filteredCustomers.removeWhere((customer) => customer.id == id);
        if (_selectedCustomer?.id == id) {
          _selectedCustomer = null;
        }
        return true;
      }

      final data = _decodeMap(response);
      _error = data['error']?.toString() ?? 'فشل حذف العميل';
      return false;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Customer>> searchCustomersAutoComplete(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/customers/search?q=$query'),
        headers: ApiService.headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Customer.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSelectedCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  Uri _customersUri({
    required int page,
    String? search,
  }) {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}/customers');
    final query = <String, String>{'page': '$page'};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    return uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  void _upsertCustomer(Customer customer) {
    final index = _customers.indexWhere((item) => item.id == customer.id);
    if (index == -1) {
      _customers.insert(0, customer);
    } else {
      _customers[index] = customer;
    }

    final filteredIndex = _filteredCustomers.indexWhere(
      (item) => item.id == customer.id,
    );
    if (filteredIndex == -1) {
      _filteredCustomers.insert(0, customer);
    } else {
      _filteredCustomers[filteredIndex] = customer;
    }

    if (_selectedCustomer?.id == customer.id) {
      _selectedCustomer = customer;
    }
  }
}

class CustomerDocumentUpload {
  final String docType;
  final String fileName;
  final PlatformFile file;

  CustomerDocumentUpload({
    required this.docType,
    required this.fileName,
    required this.file,
  });
}
