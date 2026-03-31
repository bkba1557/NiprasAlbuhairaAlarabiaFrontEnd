import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/fuel_station_model.dart';
import '../utils/constants.dart';
import '../utils/api_service.dart';

class FuelStationProvider with ChangeNotifier {
  List<FuelStation> _stations = [];
  List<FuelStation> _filteredStations = [];
  FuelStation? _selectedStation;
  List<MaintenanceRecord> _maintenanceRecords = [];
  List<TechnicianReport> _technicianReports = [];
  List<AlertNotification> _alerts = [];
  List<ApprovalRequest> _approvalRequests = [];
  List<TechnicianLocation> _technicianLocations = [];

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _filters = {};
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalStations = 0;
  bool _isCreatingStation = false;
  bool _isFetchingStations = false;

  bool get isCreatingStation => _isCreatingStation;
  bool get isFetchingStations => _isFetchingStations;

  // Getters
  List<FuelStation> get stations =>
      _filteredStations.isNotEmpty ? _filteredStations : _stations;
  FuelStation? get selectedStation => _selectedStation;
  List<MaintenanceRecord> get maintenanceRecords => _maintenanceRecords;
  List<TechnicianReport> get technicianReports => _technicianReports;
  List<AlertNotification> get alerts => _alerts;
  List<ApprovalRequest> get approvalRequests => _approvalRequests;
  List<TechnicianLocation> get technicianLocations => _technicianLocations;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get filters => _filters;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalStations => _totalStations;

  // Stations Management
  Future<void> fetchStations({
    int page = 1,
    Map<String, dynamic>? filters,
    int? limit,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/fuel-stations?page=$page';

      if (limit != null) {
        url += '&limit=$limit';
      } else {
        url += '&limit=0';
      }

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
        _stations = (data['stations'] as List)
            .map((e) => FuelStation.fromJson(e))
            .toList();
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['pages'];
        _totalStations = data['pagination']['total'];

        _applyLocalFilters();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب محطات الوقود');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyLocalFilters() {
    if (_filters.isEmpty) {
      _filteredStations = _stations;
      return;
    }

    _filteredStations = _stations.where((station) {
      bool matches = true;

      if (_filters['status'] != null && _filters['status'].isNotEmpty) {
        matches = matches && station.status == _filters['status'];
      }

      if (_filters['stationType'] != null &&
          _filters['stationType'].isNotEmpty) {
        matches = matches && station.stationType == _filters['stationType'];
      }

      if (_filters['region'] != null && _filters['region'].isNotEmpty) {
        matches = matches && station.region.contains(_filters['region']);
      }

      if (_filters['city'] != null && _filters['city'].isNotEmpty) {
        matches = matches && station.city.contains(_filters['city']);
      }

      if (_filters['stationName'] != null &&
          _filters['stationName'].isNotEmpty) {
        matches =
            matches && station.stationName.contains(_filters['stationName']);
      }

      return matches;
    }).toList();
  }

  // ===============================
  // Delete Station
  // ===============================
  Future<void> deleteStation(String stationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/fuel-stations/$stationId'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // حذف من القوائم المحلية
        _stations.removeWhere((s) => s.id == stationId);
        _filteredStations.removeWhere((s) => s.id == stationId);

        notifyListeners();
      } else {
        final data = ApiService.decodeJson(response);
        throw Exception(data['error'] ?? 'فشل حذف المحطة');
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStationById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/fuel-stations/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _selectedStation = FuelStation.fromJson(data['station']);
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات المحطة');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetCreateStationLoading() {
    _isCreatingStation = false;
    notifyListeners();
  }

  Future<bool> createStation(
    FuelStation station,
    List<String>? attachmentPaths,
  ) async {
    if (_isCreatingStation) {
      debugPrint('⛔ [createStation] BLOCKED → already creating');
      return false;
    }

    debugPrint('🟡 [createStation] START');

    _isCreatingStation = true;
    _error = null;
    // ملاحظة مهمة: لا نستدعي notifyListeners هنا

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}/fuel-stations'),
      );

      // إضافة الـ Authorization فقط
      final authHeader = ApiService.headers['Authorization'];
      if (authHeader != null && authHeader.isNotEmpty) {
        request.headers['Authorization'] = authHeader;
        debugPrint('🟢 [createStation] Authorization header added');
      }

      // =============================
      // الحقول الأساسية
      // =============================
      request.fields.addAll({
        'stationName': station.stationName,
        'stationCode': station.stationCode,
        'address': station.address,
        'latitude': station.latitude.toString(),
        'longitude': station.longitude.toString(),
        'stationType': station.stationType,
        'status': station.status,
        'capacity': station.capacity.toString(),
        'managerName': station.managerName,
        'managerPhone': station.managerPhone,
        'region': station.region,
        'city': station.city,
        'establishedDate': station.establishedDate.toIso8601String(),
        'lastMaintenanceDate': station.lastMaintenanceDate.toIso8601String(),
        'nextMaintenanceDate': station.nextMaintenanceDate.toIso8601String(),
      });

      if (station.googleMapsLink?.isNotEmpty == true) {
        request.fields['googleMapsLink'] = station.googleMapsLink!;
      }
      if (station.wazeLink?.isNotEmpty == true) {
        request.fields['wazeLink'] = station.wazeLink!;
      }
      if (station.managerEmail?.isNotEmpty == true) {
        request.fields['managerEmail'] = station.managerEmail!;
      }

      debugPrint('🟡 [createStation] Basic fields added');

      // إضافة المعدات والوقود كـ JSON
      if (station.equipment.isNotEmpty) {
        request.fields['equipment'] = jsonEncode(
          station.equipment.map((e) => e.toJson()).toList(),
        );
      }

      if (station.fuelTypes.isNotEmpty) {
        request.fields['fuelTypes'] = jsonEncode(
          station.fuelTypes.map((e) => e.toJson()).toList(),
        );
      }

      // =============================
      // إضافة المرفقات (إن وجدت)
      // =============================
      if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
        debugPrint(
          '📎 [createStation] Adding ${attachmentPaths.length} attachments...',
        );

        for (final path in attachmentPaths) {
          if (path.isNotEmpty) {
            final file = File(path);
            if (await file.exists()) {
              request.files.add(
                await http.MultipartFile.fromPath(
                  'attachments', // ← اسم الحقل الذي يتوقعه الـ backend
                  path,
                  filename: path.split('/').last,
                ),
              );
            } else {
              debugPrint('⚠️ File not found: $path');
            }
          }
        }
      }

      debugPrint('🚀 [createStation] Sending multipart request...');

      // زيادة المهلة الزمنية بشكل معقول (خاصة مع المرفقات)
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60), // ← يمكنك تعديلها حسب حجم الملفات المتوقع
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint(
        '🟢 [createStation] Response received → statusCode=${response.statusCode}',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final data = ApiService.decodeJson(response);
          final newStation = FuelStation.fromJson(data['station'] ?? data);

          // إضافة المحطة الجديدة للقائمة المحلية (اختياري)
          _stations.insert(0, newStation);

          _error = null;
          debugPrint('🎉 [createStation] Station created successfully');
          return true;
        } catch (parseError) {
          debugPrint('⚠️ Error parsing success response: $parseError');
          _error = 'تم الإنشاء لكن حدث خطأ في معالجة البيانات';
          return false;
        }
      } else {
        String errorMsg = 'فشل إنشاء المحطة (${response.statusCode})';

        try {
          final errorData = ApiService.decodeJson(response);
          errorMsg = errorData['error'] ?? errorData['message'] ?? errorMsg;
        } catch (_) {
          // في حالة عدم وجود json صالح
        }

        _error = errorMsg;
        debugPrint('❌ [createStation] Server error: $errorMsg');
        return false;
      }
    } on TimeoutException {
      _error = 'انتهت مهلة الاتصال بالخادم (Timeout)';
      debugPrint('⌛ [createStation] Request timeout');
      return false;
    } on SocketException catch (e) {
      _error = 'مشكلة في الاتصال بالإنترنت';
      debugPrint('🌐 [createStation] Network error: $e');
      return false;
    } catch (e, stack) {
      _error = 'حدث خطأ غير متوقع أثناء إنشاء المحطة';
      debugPrint('💥 [createStation] Unexpected exception: $e');
      debugPrint('📚 Stack trace:\n$stack');
      return false;
    } finally {
      _isCreatingStation = false;

      // ملاحظة: نترك الـ notifyListeners خارج الدالة
      // يفضل أن يتم استدعاؤه من الـ Widget بعد معرفة النتيجة
      debugPrint('🔵 [createStation] FINALLY → _isCreatingStation reset');
    }
  }

  // Maintenance Records
  Future<void> fetchMaintenanceRecords({
    String? stationId,
    String? status,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/maintenance-records';
      final params = <String, String>{};

      if (stationId != null) params['stationId'] = stationId;
      if (status != null) params['status'] = status;

      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _maintenanceRecords = (data['records'] as List)
            .map((e) => MaintenanceRecord.fromJson(e))
            .toList();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب سجلات الصيانة');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createMaintenanceRecord(MaintenanceRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/maintenance-records'),
        headers: ApiService.headers,
        body: json.encode(record.toJson()),
      );

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final newRecord = MaintenanceRecord.fromJson(data['record']);
        _maintenanceRecords.insert(0, newRecord);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل إنشاء سجل الصيانة';
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

  // Technician Reports
  Future<void> fetchTechnicianReports({
    String? stationId,
    String? technicianId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/technician-reports';
      final params = <String, String>{};

      if (stationId != null) params['stationId'] = stationId;
      if (technicianId != null) params['technicianId'] = technicianId;

      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _technicianReports = (data['reports'] as List)
            .map((e) => TechnicianReport.fromJson(e))
            .toList();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب تقارير الفنيين');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTechnicianReport(
    TechnicianReport report,
    List<String>? attachmentPaths,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}/technician-reports'),
      );

      request.headers.addAll(ApiService.headers);

      // Add fields
      request.fields['stationId'] = report.stationId;
      request.fields['stationName'] = report.stationName;
      request.fields['technicianId'] = report.technicianId;
      request.fields['reportType'] = report.reportType;
      request.fields['reportTitle'] = report.reportTitle;
      request.fields['description'] = report.description;
      request.fields['recommendations'] = report.recommendations;
      request.fields['status'] = report.status;
      request.fields['reportDate'] = report.reportDate.toIso8601String();

      if (report.issues.isNotEmpty) {
        request.fields['issues'] = json.encode(
          report.issues.map((e) => e.toJson()).toList(),
        );
      }

      // Add attachments
      if (attachmentPaths != null) {
        for (var path in attachmentPaths) {
          request.files.add(
            await http.MultipartFile.fromPath('attachments', path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final newReport = TechnicianReport.fromJson(data['report']);
        _technicianReports.insert(0, newReport);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل إنشاء التقرير';
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

  // Alerts and Notifications
  Future<void> fetchAlerts({String? stationId, String? technicianId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/alerts';
      final params = <String, String>{};

      if (stationId != null) params['stationId'] = stationId;
      if (technicianId != null) params['technicianId'] = technicianId;

      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _alerts = (data['alerts'] as List)
            .map((e) => AlertNotification.fromJson(e))
            .toList();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جبل التحذيرات');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendAlert(AlertNotification alert) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/alerts'),
        headers: ApiService.headers,
        body: json.encode(alert.toJson()),
      );

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final newAlert = AlertNotification.fromJson(data['alert']);
        _alerts.insert(0, newAlert);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل إرسال التحذير';
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

  // Approval Requests
  Future<void> fetchApprovalRequests({
    String? stationId,
    String? status,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/approval-requests';
      final params = <String, String>{};

      if (stationId != null) params['stationId'] = stationId;
      if (status != null) params['status'] = status;

      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _approvalRequests = (data['requests'] as List)
            .map((e) => ApprovalRequest.fromJson(e))
            .toList();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب طلبات الموافقة');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createApprovalRequest(
    ApprovalRequest request,
    List<String>? attachmentPaths,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var multipartRequest = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}/approval-requests'),
      );

      multipartRequest.headers.addAll(ApiService.headers);

      // Add fields
      multipartRequest.fields['requestType'] = request.requestType;
      multipartRequest.fields['stationId'] = request.stationId;
      multipartRequest.fields['stationName'] = request.stationName;
      multipartRequest.fields['title'] = request.title;
      multipartRequest.fields['description'] = request.description;
      multipartRequest.fields['amount'] = request.amount.toString();
      multipartRequest.fields['currency'] = request.currency;
      multipartRequest.fields['status'] = request.status;

      // Add attachments
      if (attachmentPaths != null) {
        for (var path in attachmentPaths) {
          multipartRequest.files.add(
            await http.MultipartFile.fromPath('attachments', path),
          );
        }
      }

      final streamedResponse = await multipartRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = ApiService.decodeJson(response);
        final newRequest = ApprovalRequest.fromJson(data['request']);
        _approvalRequests.insert(0, newRequest);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = ApiService.decodeJson(response);
        _error = errorData['error'] ?? 'فشل إنشاء طلب الموافقة';
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

  // Technician Live Tracking
  Future<void> fetchTechnicianLocations({String? stationId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/technician-locations';
      if (stationId != null) {
        url += '?stationId=$stationId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        _technicianLocations = (data['locations'] as List)
            .map((e) => TechnicianLocation.fromJson(e))
            .toList();
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب مواقع الفنيين');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper methods
  void clearFilters() {
    _filters.clear();
    _filteredStations = _stations;
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

  void clearSelectedStation() {
    _selectedStation = null;
    notifyListeners();
  }
}
