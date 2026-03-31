import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:order_tracker/screens/station_marketing/marketing_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class MarketingStationProvider with ChangeNotifier {
  final List<MarketingStation> _stations = [];
  MarketingStation? _selectedStation;
  bool _isLoading = false;
  String? _error;

  List<MarketingStation> get stations => List.unmodifiable(_stations);
  MarketingStation? get selectedStation => _selectedStation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  String _baseUrl(String path) => '${ApiEndpoints.baseUrl}$path';

  Future<void> fetchStations({
    String? search,
    StationMarketingStatus? status,
    String? city,
    int? limit,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final params = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (status != null) {
        params['status'] = stationStatusToString(status);
      }
      if (city != null && city.trim().isNotEmpty) {
        params['city'] = city.trim();
      }
      if (limit != null) {
        params['limit'] = limit.toString();
      } else {
        params['limit'] = '0';
      }

      final query = params.isNotEmpty
          ? '?${Uri(queryParameters: params).query}'
          : '';

      final response = await http.get(
        Uri.parse(_baseUrl('/station-marketing/stations$query')),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final stations = (data['stations'] as List<dynamic>? ?? [])
            .map((e) => MarketingStation.fromJson(e))
            .toList();
        _stations
          ..clear()
          ..addAll(stations);
      } else {
        final data = ApiService.decodeJson(response);
        throw Exception(data['error'] ?? 'فشل تحميل المحطات');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> fetchStationById(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.get(
        Uri.parse(_baseUrl('/station-marketing/stations/$id')),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final station = MarketingStation.fromJson(data['station']);
        _selectedStation = station;
        _updateLocalStation(station);
        return station;
      } else {
        final data = ApiService.decodeJson(response);
        throw Exception(data['error'] ?? 'فشل تحميل المحطة');
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> createStation(MarketingStation station) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl('/station-marketing/stations')),
        headers: ApiService.headers,
        body: json.encode(station.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final created = MarketingStation.fromJson(data['station']);
        _stations.insert(0, created);
        return created;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل إنشاء المحطة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> updateStation(MarketingStation station) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.put(
        Uri.parse(_baseUrl('/station-marketing/stations/${station.id}')),
        headers: ApiService.headers,
        body: json.encode(station.toJson(includeId: true)),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updated = MarketingStation.fromJson(data['station']);
        _selectedStation = updated;
        _updateLocalStation(updated);
        return updated;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل تحديث المحطة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteStation(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.delete(
        Uri.parse(_baseUrl('/station-marketing/stations/$id')),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _stations.removeWhere((s) => s.id == id);
        if (_selectedStation?.id == id) _selectedStation = null;
        return true;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل حذف المحطة');
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> updateStatus(
    String id,
    StationMarketingStatus status,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.put(
        Uri.parse(_baseUrl('/station-marketing/stations/$id/status')),
        headers: ApiService.headers,
        body: json.encode({'status': stationStatusToString(status)}),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updated = MarketingStation.fromJson(data['station']);
        _selectedStation = updated;
        _updateLocalStation(updated);
        return updated;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل تحديث الحالة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> setLease(String id, LeaseContract lease) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.put(
        Uri.parse(_baseUrl('/station-marketing/stations/$id/lease')),
        headers: ApiService.headers,
        body: json.encode(lease.toJson()),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updated = MarketingStation.fromJson(data['station']);
        _selectedStation = updated;
        _updateLocalStation(updated);
        return updated;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل حفظ عقد التأجير');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> terminateLease(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.put(
        Uri.parse(_baseUrl('/station-marketing/stations/$id/lease/terminate')),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updated = MarketingStation.fromJson(data['station']);
        _selectedStation = updated;
        _updateLocalStation(updated);
        return updated;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل فسخ العقد');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> addPump(String id, MarketingPump pump) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl('/station-marketing/stations/$id/pumps')),
        headers: ApiService.headers,
        body: json.encode(pump.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final station = await fetchStationById(id);
        return station;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل إضافة المضخة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> updatePump(String id, MarketingPump pump) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.put(
        Uri.parse(_baseUrl('/station-marketing/stations/$id/pumps/${pump.id}')),
        headers: ApiService.headers,
        body: json.encode(pump.toJson(includeId: true)),
      );

      if (response.statusCode == 200) {
        final station = await fetchStationById(id);
        return station;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل تحديث المضخة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> setClosingReading({
    required String stationId,
    required String pumpId,
    required double closingReading,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.put(
        Uri.parse(
          _baseUrl(
            '/station-marketing/stations/$stationId/pumps/$pumpId/closing',
          ),
        ),
        headers: ApiService.headers,
        body: json.encode({'closingReading': closingReading}),
      );

      if (response.statusCode == 200) {
        final station = await fetchStationById(stationId);
        return station;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل تسجيل قراءة الإقفال');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<String>> uploadAttachments(
    String stationId,
    List<XFile> files,
  ) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];

    for (final file in files) {
      final safeName = file.name.replaceAll(' ', '_');
      final ref = storage.ref().child(
        'station_marketing/$stationId/${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(file.path));
      }

      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  Future<MarketingStation?> addAttachments(
    String stationId,
    List<String> attachments,
  ) async {
    if (attachments.isEmpty) return _selectedStation;
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.post(
        Uri.parse(
          _baseUrl('/station-marketing/stations/$stationId/attachments'),
        ),
        headers: ApiService.headers,
        body: json.encode({'attachments': attachments}),
      );

      if (response.statusCode == 200) {
        final station = await fetchStationById(stationId);
        return station;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل إضافة المرفقات');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> addExpenseVoucher(
    String stationId,
    StationExpense expense,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl('/station-marketing/stations/$stationId/expenses')),
        headers: ApiService.headers,
        body: json.encode(expense.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final station = await fetchStationById(stationId);
        return station;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل إضافة المصروف');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MarketingStation?> addReceiptVoucher(
    String stationId,
    StationReceipt receipt,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl('/station-marketing/stations/$stationId/receipts')),
        headers: ApiService.headers,
        body: json.encode(receipt.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final station = await fetchStationById(stationId);
        return station;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'فشل إضافة سند القبض');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void _updateLocalStation(MarketingStation station) {
    final index = _stations.indexWhere((s) => s.id == station.id);
    if (index == -1) {
      _stations.insert(0, station);
    } else {
      _stations[index] = station;
    }
    notifyListeners();
  }
}
