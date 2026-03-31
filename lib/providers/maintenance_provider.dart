import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart'; // تأكد من استيراد ApiService

class MaintenanceProvider with ChangeNotifier {
  List<dynamic> _maintenanceRecords = [];
  dynamic _currentRecord;
  Map<String, dynamic>? _monthlyStats;
  bool _isLoading = false;
  String? _error;
  bool _isLoadingRecords = false;
  bool _isLoadingStats = false;

  bool get isLoadingRecords => _isLoadingRecords;
  bool get isLoadingStats => _isLoadingStats;

  List<dynamic> get maintenanceRecords => _maintenanceRecords;
  dynamic get currentRecord => _currentRecord;
  Map<String, dynamic>? get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? _token;

  Future<void> _initializeToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
    }
    // تحديث التوكن في ApiService
    if (_token != null) {
      ApiService.setToken(_token);
    }
  }

  // Fetch all maintenance records
  Future<void> fetchMaintenanceRecords({
    String? month,
    int page = 1,
    int limit = 20,
  }) async {
    _isLoadingRecords = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      String endpoint = '/maintenance?page=$page&limit=$limit';
      if (month != null) {
        endpoint += '&month=$month';
      }

      final response = await ApiService.get(endpoint);

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        if (data['success'] == true) {
          _maintenanceRecords = data['data'];
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingRecords = false;
      notifyListeners();
    }
  }

  // Fetch single maintenance record
  Future<void> fetchMaintenanceRecordById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.get('/maintenance/$id');

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        if (data['success'] == true) {
          _currentRecord = data['data'];
        } else {
          throw Exception(data['message'] ?? 'حدث خطأ غير معروف');
        }
      } else {
        throw Exception('فشل في جلب البيانات: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new maintenance record
  Future<void> createMaintenanceRecord(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.post('/maintenance', data);

      if (response.statusCode == 201) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          // Add to list
          _maintenanceRecords.insert(0, result['data']);
        } else {
          throw Exception(result['message'] ?? 'حدث خطأ غير معروف');
        }
      } else {
        throw Exception('فشل في إنشاء السجل: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update maintenance record
  Future<void> updateMaintenanceRecord(
    String id,
    Map<String, dynamic> data,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.put('/maintenance/$id', data);

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          // Update in list
          final index = _maintenanceRecords.indexWhere(
            (record) => record['_id'] == id,
          );
          if (index != -1) {
            _maintenanceRecords[index] = result['data'];
          }
          // Update current record if it's the same
          if (_currentRecord != null && _currentRecord['_id'] == id) {
            _currentRecord = result['data'];
          }
        } else {
          throw Exception(result['message'] ?? 'حدث خطأ غير معروف');
        }
      } else {
        throw Exception('فشل في تحديث السجل: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add daily check
  Future<void> addDailyCheck(
    String maintenanceId,
    Map<String, dynamic> checkData,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.post(
        '/maintenance/$maintenanceId/daily-check',
        checkData,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          // Update current record
          _currentRecord = result['data'];
        } else {
          throw Exception(result['message'] ?? 'حدث خطأ غير معروف');
        }
      } else {
        throw Exception('فشل في إضافة الفحص: ${response.statusCode}');
      }
    } on TimeoutException {
      _error = 'تعذر الاتصال بالخادم، حاول مرة أخرى.';
      throw Exception(_error);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve daily check
  Future<void> approveDailyCheck(
    String maintenanceId,
    String checkId, {
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.post(
        '/maintenance/$maintenanceId/approve-check/$checkId',
        {'notes': notes ?? ''},
      );

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          _currentRecord = result['data'];
        } else {
          throw Exception(result['message'] ?? 'فشل اعتماد الفحص');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reject daily check
  Future<void> rejectDailyCheck(
    String maintenanceId,
    String checkId, {
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.post(
        '/maintenance/$maintenanceId/reject-check/$checkId',
        {'notes': notes ?? ''},
      );

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          _currentRecord = result['data'];
        } else {
          throw Exception(result['message'] ?? 'فشل رفض الفحص');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send warning
  Future<void> sendWarning(String maintenanceId, String message) async {
    try {
      await _initializeToken();

      final response = await ApiService.post(
        '/maintenance/$maintenanceId/send-warning',
        {'message': message},
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في إرسال التحذير');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Send note
  Future<void> sendNote(String maintenanceId, String message) async {
    try {
      await _initializeToken();

      final response = await ApiService.post(
        '/maintenance/$maintenanceId/send-note',
        {'message': message},
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في إرسال الملاحظة');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Export to PDF
  Future<void> exportToPDF(String maintenanceId) async {
    try {
      await _initializeToken();

      final response = await ApiService.download(
        '/maintenance/$maintenanceId/export/pdf',
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تصدير PDF');
      }

      // Handle file download
      // This would typically involve saving the file locally
      print('PDF exported successfully');
    } catch (e) {
      rethrow;
    }
  }

  // Export to Excel
  Future<void> exportToExcel(String maintenanceId) async {
    try {
      await _initializeToken();

      final response = await ApiService.download(
        '/maintenance/$maintenanceId/export/excel',
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تصدير Excel');
      }

      // Handle file download
      print('Excel exported successfully');
    } catch (e) {
      rethrow;
    }
  }

  // Export monthly report
  Future<void> exportMonthlyReport(String month) async {
    try {
      await _initializeToken();

      final response = await ApiService.download(
        '/maintenance/export/monthly/$month',
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في تصدير التقرير الشهري');
      }

      // Handle file download
      print('Monthly report exported successfully');
    } catch (e) {
      rethrow;
    }
  }

  // Approve oil change (Manager)
  Future<void> approveOilChange({
    required String maintenanceId,
    required String dailyCheckId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.post(
        '/maintenance/$maintenanceId/approve-oil-change',
        {'dailyCheckId': dailyCheckId},
      );

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          // تحديث السجل الحالي بعد الاعتماد
          _currentRecord = result['data'];
        } else {
          throw Exception(result['message'] ?? 'فشل اعتماد تغيير الزيت');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===============================
  // 🆕 Generate maintenance month
  // ===============================
  Future<void> generateMaintenanceMonth(String month) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.post('/maintenance/generate-month', {
        'month': month,
      });

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] != true) {
          throw Exception(result['message'] ?? 'فشل إنشاء الشهر');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch monthly statistics
  Future<void> fetchMonthlyStats(String month) async {
    _isLoadingStats = true;
    notifyListeners();

    try {
      await _initializeToken();

      final response = await ApiService.get(
        '/maintenance/stats/monthly/$month',
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        if (data['success'] == true) {
          _monthlyStats = data['data'];
        } else {
          _monthlyStats = null;
        }
      } else {
        _monthlyStats = null;
      }
    } catch (e) {
      _monthlyStats = null;
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear current record
  void clearCurrentRecord() {
    _currentRecord = null;
    notifyListeners();
  }
}
