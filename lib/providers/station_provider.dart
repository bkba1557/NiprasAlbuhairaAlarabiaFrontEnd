import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/station_models.dart';
import '../utils/constants.dart';
import '../utils/api_service.dart';

class StationProvider with ChangeNotifier {
  List<Station> _stations = [];
  List<PumpSession> _sessions = [];
  List<DailyInventory> _inventories = [];
  List<FuelBalanceReportRow> _fuelBalanceReport = [];
  Station? _selectedStation;
  List<PumpSession> _inventorySessions = [];
  Map<String, double> _sessionTotalsByFuel = {};

  List<Map<String, dynamic>> _currentStock = [];
  List<Map<String, dynamic>> get currentStock => _currentStock;

  PumpSession? _selectedSession;
  PumpSession? _lastAutoOpenedSession;
  DailyInventory? _selectedInventory;
  StationStats? _stationStats;
  Map<String, double> _fuelTankCapacities = {};
  final Map<String, Station> _stationCache = {};

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _filters = {};
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  List<Station> get stations => _stations;
  List<PumpSession> get sessions => _sessions;
  List<DailyInventory> get inventories => _inventories;
  List<FuelBalanceReportRow> get fuelBalanceReport => _fuelBalanceReport;
  Station? get selectedStation => _selectedStation;
  Station? getCachedStation(String stationId) => _stationCache[stationId];
  PumpSession? get selectedSession => _selectedSession;
  PumpSession? get lastAutoOpenedSession => _lastAutoOpenedSession;
  List<PumpSession> get selectedInventorySessions => _inventorySessions;
  DailyInventory? get selectedInventory => _selectedInventory;
  StationStats? get stationStats => _stationStats;
  Map<String, double> get fuelTankCapacities => _fuelTankCapacities;
  Map<String, double> get sessionTotalsByFuel => _sessionTotalsByFuel;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get filters => _filters;
  bool _isStationsLoading = false;
  bool get isStationsLoading => _isStationsLoading;

  PumpSession? getPreviousSession(PumpSession currentSession) {
    if (_sessions.isEmpty) return null;

    // فلترة الجلسات لنفس المحطة وأقدم من الحالية
    final previousSessions = _sessions.where((s) {
      return s.stationId == currentSession.stationId &&
          s.sessionDate.isBefore(currentSession.sessionDate);
    }).toList();

    if (previousSessions.isEmpty) return null;

    // ترتيب تنازلي (الأحدث أولًا)
    previousSessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    // أول واحدة = جلسة الأمس
    return previousSessions.first;
  }

  Future<List<Map<String, dynamic>>> getOpeningBalancesFromInventory(
    String stationId,
  ) async {
    await fetchFuelBalanceReport(stationId: stationId);

    final Map<String, FuelBalanceReportRow> latestByFuel = {};

    for (final row in fuelBalanceReport) {
      final existing = latestByFuel[row.fuelType];
      if (existing == null || row.date.isAfter(existing.date)) {
        latestByFuel[row.fuelType] = row;
      }
    }

    return latestByFuel.values.map((row) {
      final balance =
          row.actualBalance ??
          row.calculatedBalance ??
          (row.openingBalance + row.received - row.sales);

      return {'fuelType': row.fuelType, 'balance': balance};
    }).toList();
  }

  Future<void> fetchCurrentStock(String stationId, {DateTime? asOfDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParameters = <String, String>{};
      if (asOfDate != null) {
        queryParameters['asOfDate'] = asOfDate.toIso8601String();
      }

      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/$stationId/current-stock')
            .replace(queryParameters: queryParameters),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final decoded = ApiService.decodeJson(response);

        if (decoded is List) {
          _currentStock = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          _currentStock = [];
        }
      } else {
        _currentStock = [];
        _error = 'فشل جلب المخزون الحالي';
      }
    } catch (e) {
      _currentStock = [];
      _error = 'خطأ في الاتصال بالسيرفر';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStockDisbursement({
    required String stationId,
    required String fuelType,
    required double quantity,
    required String reason,
    DateTime? movementDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'fuelType': fuelType,
        'quantity': quantity,
        'reason': reason,
        if (movementDate != null) 'movementDate': movementDate.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/$stationId/stock-disbursements'),
        headers: ApiService.headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final errorData = ApiService.decodeJson(response);
      _error = errorData['error'] ?? 'فشل صرف المخزون';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createStockTransfer({
    required String fromStationId,
    required String toStationId,
    required String fuelType,
    required double quantity,
    DateTime? movementDate,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'toStationId': toStationId,
        'fuelType': fuelType,
        'quantity': quantity,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (movementDate != null) 'movementDate': movementDate.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/$fromStationId/stock-transfers'),
        headers: ApiService.headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final errorData = json.decode(response.body);
      _error = errorData['error'] ?? 'فشل تحويل المخزون';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveClosingSession(String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/sessions/$sessionId/approve-closing',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedSession = PumpSession.fromJson(data['session']);

        // تحديث الجلسة في الليست
        final index = _sessions.indexWhere((s) => s.id == sessionId);
        if (index != -1) {
          _sessions[index] = updatedSession;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل اعتماد الجلسة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'فشل الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveOpeningSession(String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/sessions/$sessionId/approve-opening',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        await fetchStationById(_selectedStation!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل اعتماد قراءة الفتح';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'فشل الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$sessionId'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _sessions.removeWhere((s) => s.id == sessionId);
        if (_selectedSession?.id == sessionId) {
          _selectedSession = null;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل حذف الجلسة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'فشل الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Stations
  Future<void> fetchStations({
    int page = 1,
    Map<String, dynamic>? filters,
    String? forceStationId,
    int? limit,
  }) async {
    _isStationsLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/stations/stations?page=$page';

      if (limit != null) {
        url += '&limit=$limit';
      } else {
        url += '&limit=0';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final allStations = (data['stations'] as List)
            .map((e) => Station.fromJson(e))
            .toList();

        if (forceStationId != null) {
          final matchedStations = allStations
              .where((s) => s.id == forceStationId)
              .toList();

          _stations = matchedStations;
          _selectedStation = matchedStations.isNotEmpty
              ? matchedStations.first
              : null;
        } else {
          _stations = allStations;
          _selectedStation = null;
        }
      } else {
        throw Exception('فشل في جلب المحطات');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isStationsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateFuelPrices(
    String stationId,
    List<Map<String, dynamic>> prices,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/stations/$stationId/prices',
        ),
        headers: ApiService.headers,
        body: jsonEncode({'prices': prices}),
      );

      if (response.statusCode == 200) {
        await fetchStationById(stationId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'فشل حفظ التسعيرة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'خطأ في الاتصال بالسيرفر';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> _fetchStationPayload(
    String stationId, {
    String? query,
  }) async {
    final queryPart = query ?? '';
    final response = await http.get(
      Uri.parse(
        '${ApiEndpoints.baseUrl}/stations/stations/$stationId$queryPart',
      ),
      headers: ApiService.headers,
    );

    if (response.statusCode == 200) {
      return ApiService.decodeJsonMap(response);
    }

    throw Exception('فشل في جلب بيانات المحطة');
  }

  Future<Station?> fetchStationDetails(String stationId) async {
    if (_stationCache.containsKey(stationId)) {
      return _stationCache[stationId];
    }

    try {
      final data = await _fetchStationPayload(stationId);
      final station = Station.fromJson(data['station']);
      _stationCache[stationId] = station;
      return station;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchStationById(String id, {DateTime? inventoryDate}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _fuelTankCapacities = {};
    try {
      final query = inventoryDate != null
          ? '?inventoryDate=${inventoryDate.toIso8601String().split('T')[0]}'
          : '';
      final data = await _fetchStationPayload(id, query: query);
      final station = Station.fromJson(data['station']);
      _stationCache[id] = station;
      _selectedStation = station;
      _sessions = (data['todaysSessions'] as List)
          .map((e) => PumpSession.fromJson(e))
          .toList();
      _sessionTotalsByFuel = {};
      if (data['sessionTotalsByFuel'] is Map) {
        final raw = Map<String, dynamic>.from(data['sessionTotalsByFuel']);
        raw.forEach((key, value) {
          final v = value is num
              ? value.toDouble()
              : double.tryParse(value.toString()) ?? 0;
          _sessionTotalsByFuel[key.toString()] = v;
        });
      }
      _selectedInventory = data['todaysInventory'] != null
          ? DailyInventory.fromJson(data['todaysInventory'])
          : null;
      _fuelTankCapacities = _parseFuelCapacities(data['fuelTankCapacities']);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFuelBalanceReport({
    required String stationId,
    DateTime? startDate,
    DateTime? endDate,
    String? fuelType,
  }) async {
    final params = <String>['stationId=${Uri.encodeComponent(stationId)}'];

    String _formatDate(DateTime date) =>
        date.toIso8601String().split('T').first;

    if (fuelType != null && fuelType.isNotEmpty) {
      params.add('fuelType=${Uri.encodeComponent(fuelType)}');
    }

    if (startDate != null) {
      params.add('startDate=${Uri.encodeComponent(_formatDate(startDate))}');
    }

    if (endDate != null) {
      params.add('endDate=${Uri.encodeComponent(_formatDate(endDate))}');
    }

    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final url = '${ApiEndpoints.baseUrl}/stations/inventory/fuel-balance$query';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          _fuelBalanceReport = decoded
              .whereType<Map>()
              .map(
                (item) => FuelBalanceReportRow.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        } else {
          _fuelBalanceReport = [];
        }
      } else {
        _fuelBalanceReport = [];
      }
    } catch (e) {
      debugPrint('Fuel balance report error: $e');
      _fuelBalanceReport = [];
    } finally {
      notifyListeners();
    }
  }

  Future<bool> createStation(Station station) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/stations'),
        headers: ApiService.headers,
        body: json.encode(station.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newStation = Station.fromJson(data['station']);
        _stations.insert(0, newStation);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل إنشاء المحطة';
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

  Future<bool> deleteStation(String stationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/stations/$stationId'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _stations.removeWhere((s) => s.id == stationId);
        if (_selectedStation?.id == stationId) {
          _selectedStation = null;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? '??? ??? ??????';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '??? ??? ?? ??????? ????????';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  bool validatePumpPayload(Map<String, dynamic> payload, Station station) {
    final nozzles = payload['nozzles'] as List<dynamic>? ?? [];

    // 1️⃣ تحقق من الوقود
    for (final n in nozzles) {
      if (!station.fuelTypes.contains(n['fuelType'])) {
        throw Exception('نوع وقود غير موجود في المحطة');
      }
    }

    // 3️⃣ عدد الليّات
    if (nozzles.length != payload['nozzleCount']) {
      throw Exception('عدد الليّات لا يطابق المحدد');
    }

    return true;
  }

  Future<bool> addPump(
    String stationId,
    Map<String, dynamic> pumpPayload,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ✅ validation قبل الإرسال
      final station = _stations.firstWhere((s) => s.id == stationId);
      validatePumpPayload(pumpPayload, station);

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/stations/$stationId/pumps'),
        headers: {...ApiService.headers, 'Content-Type': 'application/json'},
        body: json.encode(pumpPayload),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final updatedStation = Station.fromJson(data['station']);

        final index = _stations.indexWhere((s) => s.id == stationId);
        if (index != -1) {
          _stations[index] = updatedStation;
        }

        if (_selectedStation?.id == stationId) {
          _selectedStation = updatedStation;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل إضافة الطلمبة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString(); // 👈 يظهر رسالة validation للمستخدم
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== دوال الطلمبات الجديدة ====================

  Future<bool> updatePump(String stationId, Pump pump) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/stations/$stationId/pumps/${pump.id}',
        ),
        headers: {...ApiService.headers, 'Content-Type': 'application/json'},
        body: json.encode(pump.toJson(forCreate: false)),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedStation = Station.fromJson(data['station']);

        // تحديث القائمة
        final index = _stations.indexWhere((s) => s.id == stationId);
        if (index != -1) {
          _stations[index] = updatedStation;
        }

        // تحديث المحطة المختارة
        if (_selectedStation?.id == stationId) {
          _selectedStation = updatedStation;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل تحديث الطلمبة';
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

  Future<bool> togglePumpStatus(
    String stationId,
    String pumpId,
    bool newStatus,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/stations/$stationId/pumps/$pumpId/status',
        ),
        headers: {...ApiService.headers, 'Content-Type': 'application/json'},
        body: json.encode({'isActive': newStatus}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedStation = Station.fromJson(data['station']);

        // تحديث القائمة
        final index = _stations.indexWhere((s) => s.id == stationId);
        if (index != -1) {
          _stations[index] = updatedStation;
        }

        // تحديث المحطة المختارة
        if (_selectedStation?.id == stationId) {
          _selectedStation = updatedStation;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل تغيير حالة الطلمبة';
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

  Future<bool> deletePump(String stationId, String pumpId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/stations/$stationId/pumps/$pumpId',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final data = json.decode(response.body);
        final updatedStation = Station.fromJson(data['station']);

        // تحديث القائمة
        final index = _stations.indexWhere((s) => s.id == stationId);
        if (index != -1) {
          _stations[index] = updatedStation;
        }

        // تحديث المحطة المختارة
        if (_selectedStation?.id == stationId) {
          _selectedStation = updatedStation;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل حذف الطلمبة';
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

  Future<void> fetchStationStats(
    String stationId, {
    String? startDate,
    String? endDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/stations/stations/$stationId/stats';
      if (startDate != null) url += '?startDate=$startDate';
      if (endDate != null) url += '&endDate=$endDate';

      final response = await http.get(
        Uri.parse(url),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _stationStats = StationStats.fromJson(data);
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب الإحصائيات');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Pump Sessions
  Future<void> fetchSessions({
    int page = 1,
    Map<String, dynamic>? filters,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParameters = <String, String>{'page': '$page'};

      if (filters != null) {
        filters.forEach((key, value) {
          if (value == null) return;

          if (value is Iterable) {
            final joinedValue = value
                .where((item) => item != null && item.toString().isNotEmpty)
                .map((item) => item.toString())
                .join(',');
            if (joinedValue.isNotEmpty) {
              queryParameters[key] = joinedValue;
            }
            return;
          }

          final stringValue = value.toString();
          if (stringValue.isNotEmpty) {
            queryParameters[key] = stringValue;
          }
        });
      }

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/stations/sessions',
      ).replace(queryParameters: queryParameters);

      final response = await http.get(uri, headers: ApiService.headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _sessions = (data['sessions'] as List)
            .map((e) => PumpSession.fromJson(e))
            .toList();
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['pages'];
        _totalItems = data['pagination']['total'];

        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب الجلسات');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> openSession(PumpSession session) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/open'),
        headers: ApiService.headers,
        body: json.encode(session.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newSession = PumpSession.fromJson(data['session']);
        _sessions.insert(0, newSession);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل فتح الجلسة';
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

  Future<bool> closeSession(
    String sessionId,
    Map<String, dynamic> closingData,
  ) async {
    _isLoading = true;
    _error = null;
    _lastAutoOpenedSession = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$sessionId/close'),
        headers: ApiService.headers,
        body: json.encode(closingData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedSession = PumpSession.fromJson(data['session']);

        // Update in list
        final index = _sessions.indexWhere((s) => s.id == sessionId);
        if (index != -1) {
          _sessions[index] = updatedSession;
        }

        // Update selected session
        if (_selectedSession?.id == sessionId) {
          _selectedSession = updatedSession;
        }

        // Auto-opened session (if returned)
        if (data['autoOpenedSession'] != null) {
          final autoSession = PumpSession.fromJson(data['autoOpenedSession']);
          _lastAutoOpenedSession = autoSession;
          final alreadyExists = _sessions.any((s) => s.id == autoSession.id);
          if (!alreadyExists) {
            _sessions.insert(0, autoSession);
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل إغلاق الجلسة';
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

  Future<bool> emailSessionReportPdf({
    required String sessionId,
    required Uint8List pdfBytes,
    String? fileName,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'pdfBase64': base64Encode(pdfBytes),
        if (fileName != null && fileName.trim().isNotEmpty)
          'fileName': fileName.trim(),
      };

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$sessionId/report/email'),
        headers: ApiService.headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        return true;
      }

      try {
        final decoded = json.decode(response.body);
        _error = decoded is Map ? decoded['error']?.toString() : null;
      } catch (_) {
        _error = response.body;
      }

      _error = _error ?? 'فشل إرسال تقرير PDF';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ أثناء إرسال تقرير PDF';
      notifyListeners();
      return false;
    }
  }

  Future<bool> editSession(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$sessionId'),
        headers: ApiService.headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedSession = PumpSession.fromJson(data['session']);

        final index = _sessions.indexWhere((s) => s.id == sessionId);
        if (index != -1) {
          _sessions[index] = updatedSession;
        }

        if (_selectedSession?.id == sessionId) {
          _selectedSession = updatedSession;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل تحديث الجلسة';
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

  Future<void> fetchSessionById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _selectedSession = PumpSession.fromJson(data['session']);
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات الجلسة');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Daily Inventory
  Future<void> fetchInventories({
    int page = 1,
    Map<String, dynamic>? filters,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '${ApiEndpoints.baseUrl}/stations/inventory?page=$page';

      if (filters != null) {
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
        final data = json.decode(response.body);
        _inventories = (data['inventories'] as List)
            .map((e) => DailyInventory.fromJson(e))
            .toList();
        _currentPage = data['pagination']['page'];
        _totalPages = data['pagination']['pages'];
        _totalItems = data['pagination']['total'];

        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب الجرد اليومي');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createInventory(DailyInventory inventory) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/inventory'), // ✅ هنا
        headers: ApiService.headers,
        body: json.encode(inventory.toCreateJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newInventory = DailyInventory.fromJson(data['inventory']);
        _inventories.insert(0, newInventory);

        if (inventory.totalSales > 0) {
          final calculatedBalance =
              inventory.previousBalance +
              inventory.receivedQuantity -
              inventory.totalSales;
          final actualBalance = inventory.actualBalance;
          final difference = actualBalance == null
              ? null
              : (actualBalance - calculatedBalance);
          final differencePercentage =
              (difference != null && calculatedBalance != 0)
              ? (difference / calculatedBalance) * 100
              : null;

          final updates = <String, dynamic>{
            'totalSales': inventory.totalSales,
            'calculatedBalance': calculatedBalance,
            if (actualBalance != null) 'actualBalance': actualBalance,
            'difference': difference,
            'differencePercentage': differencePercentage,
            if (inventory.differenceReason != null)
              'differenceReason': inventory.differenceReason,
            if (inventory.notes != null) 'notes': inventory.notes,
            'updatedAt': DateTime.now().toIso8601String(),
          };

          try {
            final patchResponse = await http.put(
              Uri.parse(
                '${ApiEndpoints.baseUrl}/stations/inventory/${newInventory.id}',
              ),
              headers: ApiService.headers,
              body: json.encode(updates),
            );

            if (patchResponse.statusCode == 200) {
              final patchedData = json.decode(patchResponse.body);
              final updatedInventory = DailyInventory.fromJson(
                patchedData['inventory'],
              );

              final index = _inventories.indexWhere(
                (inv) => inv.id == updatedInventory.id,
              );
              if (index != -1) {
                _inventories[index] = updatedInventory;
              }
              if (_selectedInventory?.id == updatedInventory.id) {
                _selectedInventory = updatedInventory;
              }
            }
          } catch (_) {}
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل إنشاء الجرد';
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

  Future<bool> approveInventory(String inventoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/stations/inventory/$inventoryId/approve',
        ),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedInventory = DailyInventory.fromJson(data['inventory']);
        final index = _inventories.indexWhere(
          (inventory) => inventory.id == inventoryId,
        );
        if (index != -1) {
          _inventories[index] = updatedInventory;
        }
        if (_selectedInventory?.id == inventoryId) {
          _selectedInventory = updatedInventory;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error =
            errorData['error'] ?? errorData['message'] ?? 'فشل اعتماد الجرد';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ في الاعتماد';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateInventory(
    String inventoryId,
    Map<String, dynamic> updates,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/inventory/$inventoryId'),
        headers: ApiService.headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedInventory = DailyInventory.fromJson(data['inventory']);

        final index = _inventories.indexWhere(
          (inventory) => inventory.id == inventoryId,
        );
        if (index != -1) {
          _inventories[index] = updatedInventory;
        }
        if (_selectedInventory?.id == inventoryId) {
          _selectedInventory = updatedInventory;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل تحديث الجرد';
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

  Future<bool> deleteInventory(String inventoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/inventory/$inventoryId'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _inventories.removeWhere((inventory) => inventory.id == inventoryId);
        if (_selectedInventory?.id == inventoryId) {
          _selectedInventory = null;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل حذف الجرد';
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

  Future<void> fetchInventoryById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/stations/inventory/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _selectedInventory = DailyInventory.fromJson(data['inventory']);
        _inventorySessions =
            (data['sessions'] as List<dynamic>?)
                ?.whereType<Map>()
                .map(
                  (session) =>
                      PumpSession.fromJson(Map<String, dynamic>.from(session)),
                )
                .toList() ??
            [];
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('فشل في جلب بيانات الجرد');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Map<String, double> _parseFuelCapacities(dynamic raw) {
    if (raw is! Map<String, dynamic>) return {};

    final map = <String, double>{};
    raw.forEach((key, value) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '0') ?? 0;
      map[key] = parsed;
    });
    return map;
  }

  void clearSelected() {
    _selectedStation = null;
    _selectedSession = null;
    _lastAutoOpenedSession = null;
    _selectedInventory = null;
    _sessions = [];
    _inventorySessions = [];
    _fuelBalanceReport = [];
    notifyListeners();
  }
}

// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import '../models/station_models.dart';
// import '../utils/constants.dart';
// import '../utils/api_service.dart';

// class StationProvider with ChangeNotifier {
//   List<Station> _stations = [];
//   List<PumpSession> _sessions = [];
//   List<DailyInventory> _inventories = [];
//   Station? _selectedStation;
//   PumpSession? _selectedSession;
//   DailyInventory? _selectedInventory;
//   StationStats? _stationStats;

//   bool _isLoading = false;
//   String? _error;
//   Map<String, dynamic> _filters = {};
//   int _currentPage = 1;
//   int _totalPages = 1;
//   int _totalItems = 0;

//   List<Station> get stations => _stations;
//   List<PumpSession> get sessions => _sessions;
//   List<DailyInventory> get inventories => _inventories;
//   Station? get selectedStation => _selectedStation;
//   PumpSession? get selectedSession => _selectedSession;
//   DailyInventory? get selectedInventory => _selectedInventory;
//   StationStats? get stationStats => _stationStats;
//   bool get isLoading => _isLoading;
//   String? get error => _error;
//   Map<String, dynamic> get filters => _filters;

//   // Stations
//   Future<void> fetchStations({
//     int page = 1,
//     Map<String, dynamic>? filters,
//   }) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       String url = '${ApiEndpoints.baseUrl}/stations/stations?page=$page';

//       if (filters != null) {
//         _filters = {...filters};
//         filters.forEach((key, value) {
//           if (value != null && value.toString().isNotEmpty) {
//             url += '&$key=$value';
//           }
//         });
//       }

//       final response = await http.get(
//         Uri.parse(url),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _stations = (data['stations'] as List)
//             .map((e) => Station.fromJson(e))
//             .toList();
//         _currentPage = data['pagination']['page'];
//         _totalPages = data['pagination']['pages'];
//         _totalItems = data['pagination']['total'];

//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب المحطات');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Future<bool> addOrUpdateFuelPrice({
//   //   required String stationId,
//   //   required String fuelType,
//   //   required double price,
//   //   DateTime? date,
//   // }) async {
//   //   _isLoading = true;
//   //   _error = null;
//   //   notifyListeners();

//   //   try {
//   //     final response = await http.put(
//   //       Uri.parse(
//   //         '${ApiEndpoints.baseUrl}/stations/stations/$stationId/prices',
//   //       ),
//   //       headers: ApiService.headers,
//   //       body: json.encode({
//   //         'fuelType': fuelType,
//   //         'price': price,
//   //         'effectiveDate': (date ?? DateTime.now()).toIso8601String(),
//   //       }),
//   //     );

//   //     if (response.statusCode == 200) {
//   //       final data = json.decode(response.body);

//   //       final updatedStation = Station.fromJson(data['station']);

//   //       // تحديث المحطة المختارة
//   //       if (_selectedStation?.id == stationId) {
//   //         _selectedStation = updatedStation;
//   //       }

//   //       // تحديث القائمة
//   //       final index = _stations.indexWhere((s) => s.id == stationId);
//   //       if (index != -1) {
//   //         _stations[index] = updatedStation;
//   //       }

//   //       _isLoading = false;
//   //       notifyListeners();
//   //       return true;
//   //     } else {
//   //       final errorData = json.decode(response.body);
//   //       _error = errorData['error'] ?? 'فشل تحديث سعر الوقود';
//   //       _isLoading = false;
//   //       notifyListeners();
//   //       return false;
//   //     }
//   //   } catch (e) {
//   //     _error = 'خطأ في الاتصال بالسيرفر';
//   //     _isLoading = false;
//   //     notifyListeners();
//   //     return false;
//   //   }
//   // }

//   Future<bool> updateFuelPrices(
//     String stationId,
//     List<Map<String, dynamic>> prices,
//   ) async {
//     _isLoading = true;
//     notifyListeners();

//     try {
//       final response = await http.put(
//         Uri.parse(
//           '${ApiEndpoints.baseUrl}/stations/stations/$stationId/prices',
//         ),
//         headers: ApiService.headers,
//         body: jsonEncode({'prices': prices}),
//       );

//       if (response.statusCode == 200) {
//         await fetchStationById(stationId);
//         _isLoading = false;
//         notifyListeners();
//         return true;
//       } else {
//         _error = 'فشل حفظ التسعيرة';
//         _isLoading = false;
//         notifyListeners();
//         return false;
//       }
//     } catch (e) {
//       _error = 'خطأ في الاتصال بالسيرفر';
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<void> fetchStationById(String id) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.get(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/stations/$id'),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _selectedStation = Station.fromJson(data['station']);
//         _sessions = (data['todaysSessions'] as List)
//             .map((e) => PumpSession.fromJson(e))
//             .toList();
//         _selectedInventory = data['todaysInventory'] != null
//             ? DailyInventory.fromJson(data['todaysInventory'])
//             : null;

//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب بيانات المحطة');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<bool> createStation(Station station) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.post(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/stations'),
//         headers: ApiService.headers,
//         body: json.encode(station.toJson()),
//       );

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);
//         final newStation = Station.fromJson(data['station']);
//         _stations.insert(0, newStation);

//         _isLoading = false;
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error = errorData['error'] ?? 'فشل إنشاء المحطة';
//         _isLoading = false;
//         notifyListeners();
//         return false;
//       }
//     } catch (e) {
//       _error = 'حدث خطأ في الاتصال بالسيرفر';
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<bool> addPump(String stationId, Pump pump) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.post(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/stations/$stationId/pumps'),
//         headers: {...ApiService.headers, 'Content-Type': 'application/json'},

//         /// ✅ مهم جدًا: forCreate = true
//         body: json.encode(pump.toJson(forCreate: true)),
//       );

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);

//         final updatedStation = Station.fromJson(data['station']);

//         // تحديث القائمة
//         final index = _stations.indexWhere((s) => s.id == stationId);
//         if (index != -1) {
//           _stations[index] = updatedStation;
//         }

//         // تحديث المحطة المختارة
//         if (_selectedStation?.id == stationId) {
//           _selectedStation = updatedStation;
//         }

//         _isLoading = false;
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error =
//             errorData['error'] ?? errorData['message'] ?? 'فشل إضافة الطلمبة';

//         _isLoading = false;
//         notifyListeners();
//         return false;
//       }
//     } catch (e) {
//       _error = 'حدث خطأ في الاتصال بالسيرفر';
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<void> fetchStationStats(
//     String stationId, {
//     String? startDate,
//     String? endDate,
//   }) async {
//     _isLoading = true;
//     notifyListeners();

//     try {
//       String url = '${ApiEndpoints.baseUrl}/stations/stations/$stationId/stats';
//       if (startDate != null) url += '?startDate=$startDate';
//       if (endDate != null) url += '&endDate=$endDate';

//       final response = await http.get(
//         Uri.parse(url),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _stationStats = StationStats.fromJson(data);
//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب الإحصائيات');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Pump Sessions
//   Future<void> fetchSessions({
//     int page = 1,
//     Map<String, dynamic>? filters,
//   }) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       String url = '${ApiEndpoints.baseUrl}/stations/sessions?page=$page';

//       if (filters != null) {
//         filters.forEach((key, value) {
//           if (value != null && value.toString().isNotEmpty) {
//             url += '&$key=$value';
//           }
//         });
//       }

//       final response = await http.get(
//         Uri.parse(url),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _sessions = (data['sessions'] as List)
//             .map((e) => PumpSession.fromJson(e))
//             .toList();
//         _currentPage = data['pagination']['page'];
//         _totalPages = data['pagination']['pages'];
//         _totalItems = data['pagination']['total'];

//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب الجلسات');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<bool> openSession(PumpSession session) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.post(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/open'),
//         headers: ApiService.headers,
//         body: json.encode(session.toJson()),
//       );

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);
//         final newSession = PumpSession.fromJson(data['session']);
//         _sessions.insert(0, newSession);

//         _isLoading = false;
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error = errorData['error'] ?? 'فشل فتح الجلسة';
//         _isLoading = false;
//         notifyListeners();
//         return false;
//       }
//     } catch (e) {
//       _error = 'حدث خطأ في الاتصال بالسيرفر';
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<bool> closeSession(
//     String sessionId,
//     Map<String, dynamic> closingData,
//   ) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.put(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$sessionId/close'),
//         headers: ApiService.headers,
//         body: json.encode(closingData),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final updatedSession = PumpSession.fromJson(data['session']);

//         // Update in list
//         final index = _sessions.indexWhere((s) => s.id == sessionId);
//         if (index != -1) {
//           _sessions[index] = updatedSession;
//         }

//         // Update selected session
//         if (_selectedSession?.id == sessionId) {
//           _selectedSession = updatedSession;
//         }

//         _isLoading = false;
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error = errorData['error'] ?? 'فشل إغلاق الجلسة';
//         _isLoading = false;
//         notifyListeners();
//         return false;
//       }
//     } catch (e) {
//       _error = 'حدث خطأ في الاتصال بالسيرفر';
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<void> fetchSessionById(String id) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.get(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/sessions/$id'),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _selectedSession = PumpSession.fromJson(data['session']);
//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب بيانات الجلسة');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Daily Inventory
//   Future<void> fetchInventories({
//     int page = 1,
//     Map<String, dynamic>? filters,
//   }) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       String url = '${ApiEndpoints.baseUrl}/stations/inventory?page=$page';

//       if (filters != null) {
//         filters.forEach((key, value) {
//           if (value != null && value.toString().isNotEmpty) {
//             url += '&$key=$value';
//           }
//         });
//       }

//       final response = await http.get(
//         Uri.parse(url),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _inventories = (data['inventories'] as List)
//             .map((e) => DailyInventory.fromJson(e))
//             .toList();
//         _currentPage = data['pagination']['page'];
//         _totalPages = data['pagination']['pages'];
//         _totalItems = data['pagination']['total'];

//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب الجرد اليومي');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<bool> createInventory(DailyInventory inventory) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.post(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/inventory'),
//         headers: ApiService.headers,
//         body: json.encode(inventory.toJson()),
//       );

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);
//         final newInventory = DailyInventory.fromJson(data['inventory']);
//         _inventories.insert(0, newInventory);

//         _isLoading = false;
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error = errorData['error'] ?? 'فشل إنشاء الجرد';
//         _isLoading = false;
//         notifyListeners();
//         return false;
//       }
//     } catch (e) {
//       _error = 'حدث خطأ في الاتصال بالسيرفر';
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   Future<void> fetchInventoryById(String id) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();

//     try {
//       final response = await http.get(
//         Uri.parse('${ApiEndpoints.baseUrl}/stations/inventory/$id'),
//         headers: ApiService.headers,
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         _selectedInventory = DailyInventory.fromJson(data['inventory']);
//         _isLoading = false;
//         notifyListeners();
//       } else {
//         throw Exception('فشل في جلب بيانات الجرد');
//       }
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   void clearError() {
//     _error = null;
//     notifyListeners();
//   }

//   void clearSelected() {
//     _selectedStation = null;
//     _selectedSession = null;
//     _selectedInventory = null;
//     _sessions = [];
//     notifyListeners();
//   }
// }
