import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/customer_model.dart';
import '../utils/constants.dart';
import '../utils/api_service.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  List<Customer> get customers =>
      _filteredCustomers.isNotEmpty ? _filteredCustomers : _customers;
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
        final List<Customer> allCustomers = [];
        int currentPage = page;
        int totalPages = 1;

        while (currentPage <= totalPages) {
          String url = '${ApiEndpoints.baseUrl}/customers?page=$currentPage';
          if (search != null && search.isNotEmpty) {
            url += '&search=$search';
          }

          final response = await http.get(
            Uri.parse(url),
            headers: ApiService.headers,
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to fetch customers.');
          }

          final data = json.decode(response.body);
          final pageCustomers = (data['customers'] as List)
              .map((e) => Customer.fromJson(e))
              .toList();
          allCustomers.addAll(pageCustomers);

          totalPages = data['pagination']?['pages'] ?? totalPages;
          currentPage++;
        }

        _customers = allCustomers;
        _currentPage = page;
        _totalPages = totalPages;
      } else {
        String url = '${ApiEndpoints.baseUrl}/customers?page=$page';
        if (search != null && search.isNotEmpty) {
          url += '&search=$search';
        }

        final response = await http.get(
          Uri.parse(url),
          headers: ApiService.headers,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _customers = (data['customers'] as List)
              .map((e) => Customer.fromJson(e))
              .toList();
          _currentPage = data['pagination']['page'];
          _totalPages = data['pagination']['pages'];
        } else {
          throw Exception('Failed to fetch customers.');
        }
      }

      _filteredCustomers = _customers;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchCustomers(String query) {
    if (query.isEmpty) {
      _filteredCustomers = _customers;
    } else {
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(query.toLowerCase()) ||
            customer.code.toLowerCase().contains(query.toLowerCase()) ||
            (customer.phone?.toLowerCase().contains(query.toLowerCase()) ??
                false);
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

      print(response.body);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newCustomer = Customer.fromJson(data['customer']);
        _customers.insert(0, newCustomer);
        _isLoading = false;
        notifyListeners();
        return newCustomer;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل إنشاء العميل';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> uploadCustomerDocuments(
    String customerId,
    List<CustomerDocumentUpload> documents,
  ) async {
    if (documents.isEmpty) return true;

    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.customerDocuments(customerId)}',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(ApiService.headers);

    for (final document in documents) {
      if (!document.file.existsSync()) continue;

      final multipartFile = await http.MultipartFile.fromPath(
        document.docType,
        document.file.path,
        filename: document.fileName,
      );
      request.files.add(multipartFile);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = response.body.isNotEmpty
          ? json.decode(response.body) as Map<String, dynamic>?
          : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      _error = responseBody?['error'] ?? 'فشل رفع المستندات';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedCustomer = Customer.fromJson(data['customer']);

        final index = _customers.indexWhere((c) => c.id == id);
        if (index != -1) {
          _customers[index] = updatedCustomer;
        }

        if (_selectedCustomer?.id == id) {
          _selectedCustomer = updatedCustomer;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل تحديث العميل';
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
        final data = json.decode(response.body);
        _selectedCustomer = Customer.fromJson(data['customer']);
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات العميل');
      }
    } catch (e) {
      _error = e.toString();
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
        // إزالة العميل من القائمة
        _customers.removeWhere((c) => c.id == id);
        _filteredCustomers.removeWhere((c) => c.id == id);

        // لو العميل المحذوف هو المختار حاليًا
        if (_selectedCustomer?.id == id) {
          _selectedCustomer = null;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = json.decode(response.body);
        _error = data['error'] ?? 'فشل حذف العميل';
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

  Future<List<Customer>> searchCustomersAutoComplete(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/customers/search?q=$query'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((e) => Customer.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
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
}

class CustomerDocumentUpload {
  final String docType;
  final String fileName;
  final File file;

  CustomerDocumentUpload({
    required this.docType,
    required this.fileName,
    required this.file,
  });
}
