import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/vehicle_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class VehicleProvider with ChangeNotifier {
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Vehicle? findById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final vehicle in _vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  Future<void> fetchVehicles({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.vehicles}'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final raw = data is List
            ? List<dynamic>.from(data)
            : data is Map && data['vehicles'] is List
            ? List<dynamic>.from(data['vehicles'] as List)
            : data is Map && data['data'] is List
            ? List<dynamic>.from(data['data'] as List)
            : <dynamic>[];

        _vehicles = raw
            .whereType<Map>()
            .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _error = null;
      } else {
        _error = 'فشل في جلب السيارات';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.vehicles}'),
        headers: ApiService.headers,
        body: json.encode(vehicle.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final raw = data is Map && data['vehicle'] != null
            ? data['vehicle']
            : data is Map && data['data'] != null
            ? data['data']
            : data;
        final created = Vehicle.fromJson(Map<String, dynamic>.from(raw));
        _vehicles.insert(0, created);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final errorData = json.decode(utf8.decode(response.bodyBytes));
      _error = errorData['error']?.toString() ?? 'فشل في إضافة السيارة';
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateVehicle(String id, Vehicle vehicle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.vehicles}/$id'),
        headers: ApiService.headers,
        body: json.encode(vehicle.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final raw = data is Map && data['vehicle'] != null
            ? data['vehicle']
            : data is Map && data['data'] != null
            ? data['data']
            : data;
        final updated = Vehicle.fromJson(Map<String, dynamic>.from(raw));
        final index = _vehicles.indexWhere((item) => item.id == id);
        if (index != -1) {
          _vehicles[index] = updated;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final errorData = json.decode(utf8.decode(response.bodyBytes));
      _error = errorData['error']?.toString() ?? 'فشل في تحديث السيارة';
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteVehicle(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.vehicles}/$id'),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _vehicles.removeWhere((item) => item.id == id);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final errorData = json.decode(utf8.decode(response.bodyBytes));
      _error = errorData['error']?.toString() ?? 'فشل في حذف السيارة';
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
