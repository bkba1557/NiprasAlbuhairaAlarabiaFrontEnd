import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/utils/constants.dart';
import '../models/driver_model.dart';
import '../utils/api_service.dart';

class DriverProvider with ChangeNotifier {
  List<Driver> _drivers = [];
  List<Driver> _filteredDrivers = [];
  Map<String, Driver> _driversCache = {};
  Driver? _selectedDriver;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  List<Driver> get drivers =>
      _filteredDrivers.isNotEmpty ? _filteredDrivers : _drivers;
  Driver? get selectedDriver => _selectedDriver;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchDrivers({
    int page = 1,
    String? search,
    String? status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/drivers?page=$page';
      if (search != null && search.isNotEmpty) {
        url += '&search=$search';
      }
      if (status != null && status.isNotEmpty) {
        url += '&status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        // معالجة مختلف أشكال الاستجابة
        List<dynamic> driversData = [];
        if (data['drivers'] is List) {
          driversData = data['drivers'];
        } else if (data['data'] is List) {
          driversData = data['data'];
        } else if (data is List) {
          driversData = data;
        }

        _drivers = driversData.map((e) => Driver.fromJson(e)).toList();

        // تحديث الكاش
        for (var driver in _drivers) {
          _driversCache[driver.id] = driver;
        }

        _currentPage = data['pagination']?['page'] ?? 1;
        _totalPages = data['pagination']?['pages'] ?? 1;
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب السائقين');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Driver>> fetchActiveDrivers() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/drivers/active'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> driversData = [];
        if (data is List) {
          driversData = data;
        } else if (data['drivers'] is List) {
          driversData = data['drivers'];
        } else if (data['data'] is List) {
          driversData = data['data'];
        }

        final drivers = driversData.map((e) => Driver.fromJson(e)).toList();

        // تحديث الكاش
        for (var driver in drivers) {
          _driversCache[driver.id] = driver;
        }

        return drivers;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching active drivers: $e');
      return [];
    }
  }

  void searchDrivers(String query) {
    if (query.isEmpty) {
      _filteredDrivers = _drivers;
    } else {
      _filteredDrivers = _drivers.where((driver) {
        return driver.name.toLowerCase().contains(query.toLowerCase()) ||
            driver.licenseNumber.toLowerCase().contains(query.toLowerCase()) ||
            driver.phone.toLowerCase().contains(query.toLowerCase()) ||
            (driver.vehicleNumber?.toLowerCase().contains(
                  query.toLowerCase(),
                ) ??
                false);
      }).toList();
    }
    notifyListeners();
  }

  Future<bool> createDriver(Map<String, dynamic> driverData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/drivers'),
        headers: ApiService.headers,
        body: json.encode(driverData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Driver newDriver;
        if (data['driver'] != null) {
          newDriver = Driver.fromJson(data['driver']);
        } else if (data['data'] != null) {
          newDriver = Driver.fromJson(data['data']);
        } else {
          newDriver = Driver.fromJson(data);
        }

        _drivers.insert(0, newDriver);
        _driversCache[newDriver.id] = newDriver;
        _selectedDriver = newDriver;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل إنشاء السائق';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDriver(String id, Map<String, dynamic> driverData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}/drivers/$id'),
        headers: ApiService.headers,
        body: json.encode(driverData),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Driver updatedDriver;
        if (data['driver'] != null) {
          updatedDriver = Driver.fromJson(data['driver']);
        } else if (data['data'] != null) {
          updatedDriver = Driver.fromJson(data['data']);
        } else {
          updatedDriver = Driver.fromJson(data);
        }

        final index = _drivers.indexWhere((d) => d.id == id);
        if (index != -1) {
          _drivers[index] = updatedDriver;
        }

        // تحديث الكاش
        _driversCache[id] = updatedDriver;
        _selectedDriver = updatedDriver;

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل تحديث السائق';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchDriverById(String id) async {
    // التحقق من الكاش أولاً
    if (_driversCache.containsKey(id)) {
      _selectedDriver = _driversCache[id];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/drivers/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        Driver driver;
        if (data['driver'] != null) {
          driver = Driver.fromJson(data['driver']);
        } else if (data['data'] != null) {
          driver = Driver.fromJson(data['data']);
        } else {
          driver = Driver.fromJson(data);
        }

        _selectedDriver = driver;
        _driversCache[id] = driver;
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات السائق');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // طريقة للحصول على سائق من الكاش أو القائمة
  Driver? getDriverById(String id) {
    // البحث في الكاش أولاً
    if (_driversCache.containsKey(id)) {
      return _driversCache[id];
    }

    // البحث في القائمة
    final driver = _drivers.firstWhere(
      (driver) => driver.id == id,
      orElse: () => Driver.empty(),
    );

    if (driver.id.isNotEmpty) {
      _driversCache[id] = driver;
      return driver;
    }

    return null;
  }

  Future<List<Driver>> searchDriversAutoComplete(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/drivers/search?q=$query'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);

        List<dynamic> driversData = [];
        if (data is List) {
          driversData = data;
        } else if (data['drivers'] is List) {
          driversData = data['drivers'];
        } else if (data['data'] is List) {
          driversData = data['data'];
        } else if (data['results'] is List) {
          driversData = data['results'];
        }

        final drivers = driversData.map((e) => Driver.fromJson(e)).toList();

        // تحديث الكاش
        for (var driver in drivers) {
          _driversCache[driver.id] = driver;
        }

        return drivers;
      }
      return [];
    } catch (e) {
      debugPrint('Error in searchDriversAutoComplete: $e');
      return [];
    }
  }

  Future<bool> deleteDriver(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/drivers/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // إزالة من القائمة
        _drivers.removeWhere((driver) => driver.id == id);
        _filteredDrivers.removeWhere((driver) => driver.id == id);

        // إزالة من الكاش
        _driversCache.remove(id);

        if (_selectedDriver?.id == id) {
          _selectedDriver = null;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? errorData['message'] ?? 'فشل حذف السائق';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSelectedDriver() {
    _selectedDriver = null;
    notifyListeners();
  }

  void clearCache() {
    _driversCache.clear();
  }

  // طريقة لتحميل سائق مباشرة من API إذا لم يكن في الكاش
  Future<Driver?> loadDriver(String id) async {
    final cachedDriver = getDriverById(id);
    if (cachedDriver != null) {
      return cachedDriver;
    }

    await fetchDriverById(id);
    return _selectedDriver;
  }
}
