import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:order_tracker/screens/station_inspections/inspection_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class StationInspectionProvider with ChangeNotifier {
  final List<StationInspection> _inspections = [];
  StationInspection? _selectedInspection;
  bool _isLoading = false;
  String? _error;

  List<StationInspection> get inspections => List.unmodifiable(_inspections);
  StationInspection? get selectedInspection => _selectedInspection;
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

  Future<void> fetchInspections({
    String? search,
    InspectionStatus? status,
    String? city,
    String? region,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final params = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (status != null) {
        params['status'] = inspectionStatusToString(status);
      }
      if (city != null && city.trim().isNotEmpty) {
        params['city'] = city.trim();
      }
      if (region != null && region.trim().isNotEmpty) {
        params['region'] = region.trim();
      }

      final query = params.isNotEmpty
          ? '?${Uri(queryParameters: params).query}'
          : '';

      final response = await http.get(
        Uri.parse(_baseUrl('${ApiEndpoints.stationInspections}$query')),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final inspections = (data['inspections'] as List<dynamic>? ?? [])
            .map((e) => StationInspection.fromJson(e))
            .toList();
        _inspections
          ..clear()
          ..addAll(inspections);
      } else {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? '??? ????? ?????????');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<StationInspection?> fetchInspectionById(String id) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.get(
        Uri.parse(_baseUrl(ApiEndpoints.stationInspectionById(id))),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final inspection = StationInspection.fromJson(data['inspection']);
        _selectedInspection = inspection;
        _updateLocalInspection(inspection);
        return inspection;
      } else {
        final data = json.decode(response.body);
        throw Exception(data['error'] ?? '??? ????? ????????');
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<StationInspection?> createInspection(StationInspection inspection) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.post(
        Uri.parse(_baseUrl(ApiEndpoints.stationInspections)),
        headers: ApiService.headers,
        body: json.encode(inspection.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final created = StationInspection.fromJson(data['inspection']);
        _inspections.insert(0, created);
        return created;
      }
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? '??? ????? ????????');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<StationInspection?> updateInspection(StationInspection inspection) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.put(
        Uri.parse(_baseUrl(ApiEndpoints.stationInspectionById(inspection.id))),
        headers: ApiService.headers,
        body: json.encode(inspection.toJson(includeId: true)),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updated = StationInspection.fromJson(data['inspection']);
        _selectedInspection = updated;
        _updateLocalInspection(updated);
        return updated;
      }
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? '??? ????? ????????');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<StationInspection?> updateStatus(
    String id,
    InspectionStatus status,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.put(
        Uri.parse(_baseUrl(ApiEndpoints.stationInspectionStatus(id))),
        headers: ApiService.headers,
        body: json.encode({'status': inspectionStatusToString(status)}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updated = StationInspection.fromJson(data['inspection']);
        _selectedInspection = updated;
        _updateLocalInspection(updated);
        return updated;
      }
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? '??? ????? ??????');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteInspection(String id) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.delete(
        Uri.parse(_baseUrl(ApiEndpoints.stationInspectionById(id))),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _inspections.removeWhere((inspection) => inspection.id == id);
        if (_selectedInspection?.id == id) _selectedInspection = null;
        return true;
      }
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? '??? ??? ????????');
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<InspectionAttachment>> uploadAttachments(
    String inspectionId,
    List<XFile> files, {
    required String type,
  }) async {
    final storage = FirebaseStorage.instance;
    final attachments = <InspectionAttachment>[];

    for (final file in files) {
      final safeName = file.name.replaceAll(' ', '_');
      final ref = storage.ref().child(
          'station_inspections/$inspectionId/$type/${DateTime.now().millisecondsSinceEpoch}_$safeName');

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes);
      } else {
        await ref.putFile(File(file.path));
      }

      final url = await ref.getDownloadURL();
      attachments.add(
        InspectionAttachment(
          url: url,
          type: type,
          name: safeName,
          createdAt: DateTime.now(),
        ),
      );
    }

    return attachments;
  }

  Future<StationInspection?> addAttachments(
    String inspectionId,
    List<InspectionAttachment> attachments,
  ) async {
    if (attachments.isEmpty) return _selectedInspection;
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.post(
        Uri.parse(
            _baseUrl(ApiEndpoints.stationInspectionAttachments(inspectionId))),
        headers: ApiService.headers,
        body: json.encode({
          'attachments': attachments.map((e) => e.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final inspection = await fetchInspectionById(inspectionId);
        return inspection;
      }
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? '??? ????? ????????');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void _updateLocalInspection(StationInspection inspection) {
    final index = _inspections.indexWhere((i) => i.id == inspection.id);
    if (index == -1) {
      _inspections.insert(0, inspection);
    } else {
      _inspections[index] = inspection;
    }
    notifyListeners();
  }
}
