import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:order_tracker/utils/api_service.dart';

class WorkshopFuelProvider with ChangeNotifier {
  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _supplies = [];
  List<Map<String, dynamic>> _refuels = [];
  List<Map<String, dynamic>> _readings = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get settings => _settings;
  List<Map<String, dynamic>> get supplies => _supplies;
  List<Map<String, dynamic>> get refuels => _refuels;
  List<Map<String, dynamic>> get readings => _readings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get currentBalance => _readDouble(_settings?['currentBalance']);
  double get capacity => _readDouble(_settings?['capacity']);
  double get unitPrice => _readDouble(_settings?['unitPrice']);
  double get lowThresholdPercent =>
      _readDouble(_settings?['lowThresholdPercent'], 10);

  double _readDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> _decodeResponse(dynamic response) {
    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  String _buildQuery(Map<String, String> params) {
    if (params.isEmpty) return '';
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  String _formatDate(DateTime date) => date.toIso8601String();

  Future<void> fetchSettings(String stationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.get(
        '/workshop-fuel/settings?stationId=$stationId',
      );
      final data = _decodeResponse(response);
      final payload = data['data'] ?? data['settings'] ?? data;
      _settings = payload is Map
          ? Map<String, dynamic>.from(payload as Map)
          : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSettings({
    required String stationId,
    String? stationName,
    double? capacity,
    double? currentBalance,
    double? unitPrice,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = {
        'stationId': stationId,
        if (stationName != null) 'stationName': stationName,
        if (capacity != null) 'capacity': capacity,
        if (currentBalance != null) 'currentBalance': currentBalance,
        if (unitPrice != null) 'unitPrice': unitPrice,
      };
      final response = await ApiService.put('/workshop-fuel/settings', payload);
      final data = _decodeResponse(response);
      final settings = data['data'] ?? data['settings'] ?? data;
      _settings = settings is Map
          ? Map<String, dynamic>.from(settings as Map)
          : _settings;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSupplies({
    required String stationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'stationId': stationId};
      if (startDate != null) params['startDate'] = _formatDate(startDate);
      if (endDate != null) params['endDate'] = _formatDate(endDate);
      final query = _buildQuery(params);
      final response = await ApiService.get('/workshop-fuel/supplies?$query');
      final data = _decodeResponse(response);
      final list = data['data'] ?? data['supplies'] ?? [];
      _supplies = (list as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSupply(Map<String, dynamic> payload) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/workshop-fuel/supplies', payload);
      final data = _decodeResponse(response);
      final created = data['data'] ?? {};
      if (created is Map && created['supply'] is Map) {
        _supplies.insert(0, Map<String, dynamic>.from(created['supply']));
      }
      if (created is Map && created['tank'] is Map) {
        _settings = Map<String, dynamic>.from(created['tank']);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRefuels({
    required String stationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'stationId': stationId};
      if (startDate != null) params['startDate'] = _formatDate(startDate);
      if (endDate != null) params['endDate'] = _formatDate(endDate);
      final query = _buildQuery(params);
      final response = await ApiService.get('/workshop-fuel/refuels?$query');
      final data = _decodeResponse(response);
      final list = data['data'] ?? data['refuels'] ?? [];
      _refuels = (list as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRefuel(Map<String, dynamic> payload) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/workshop-fuel/refuels', payload);
      final data = _decodeResponse(response);
      final created = data['data'] ?? {};
      if (created is Map && created['refuel'] is Map) {
        _refuels.insert(0, Map<String, dynamic>.from(created['refuel']));
      }
      if (created is Map && created['tank'] is Map) {
        _settings = Map<String, dynamic>.from(created['tank']);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRefuel(String refuelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.delete('/workshop-fuel/refuels/$refuelId');
      final data = _decodeResponse(response);
      final payload = data['data'];

      _refuels.removeWhere(
        (item) =>
            item['_id']?.toString() == refuelId ||
            item['id']?.toString() == refuelId,
      );

      if (payload is Map && payload['tank'] is Map) {
        _settings = Map<String, dynamic>.from(payload['tank']);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReadings({
    required String stationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, String>{'stationId': stationId};
      if (startDate != null) params['startDate'] = _formatDate(startDate);
      if (endDate != null) params['endDate'] = _formatDate(endDate);
      final query = _buildQuery(params);
      final response = await ApiService.get('/workshop-fuel/readings?$query');
      final data = _decodeResponse(response);
      final list = data['data'] ?? data['readings'] ?? [];
      _readings = (list as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createReading(Map<String, dynamic> payload) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/workshop-fuel/readings', payload);
      final data = _decodeResponse(response);
      final created = data['data'] ?? {};
      if (created is Map) {
        _readings.insert(0, Map<String, dynamic>.from(created));
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
