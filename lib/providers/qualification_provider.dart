import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class QualificationProvider with ChangeNotifier {
  final List<QualificationStation> _stations = [];
  QualificationStation? _selectedStation;
  bool _isLoading = false;
  String? _error;

  List<QualificationStation> get stations => List.unmodifiable(_stations);
  QualificationStation? get selectedStation => _selectedStation;
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
    QualificationStatus? status,
    String? city,
    String? region,
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
        params['status'] = qualificationStatusToString(status);
      }
      if (city != null && city.trim().isNotEmpty) {
        params['city'] = city.trim();
      }
      if (region != null && region.trim().isNotEmpty) {
        params['region'] = region.trim();
      }
      if (limit != null) {
        params['limit'] = limit.toString();
      }

      final query = params.isNotEmpty
          ? '?${Uri(queryParameters: params).query}'
          : '';

      final response = await http.get(
        Uri.parse(_baseUrl('${ApiEndpoints.qualificationStations}$query')),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final stations = (data['stations'] as List<dynamic>? ?? [])
            .map((e) => QualificationStation.fromJson(e))
            .toList();
        _stations
          ..clear()
          ..addAll(stations);
      } else {
        final data = ApiService.decodeJson(response);
        throw Exception(data['error'] ?? 'تعذر تحميل المحطات');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<QualificationStation?> fetchStationById(String id) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.get(
        Uri.parse(_baseUrl(ApiEndpoints.qualificationStationById(id))),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final station = QualificationStation.fromJson(data['station']);
        _selectedStation = station;
        _updateLocalStation(station);
        return station;
      } else {
        final data = ApiService.decodeJson(response);
        throw Exception(data['error'] ?? 'تعذر تحميل المحطة');
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<QualificationStation?> createStation(
    QualificationStation station,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.post(
        Uri.parse(_baseUrl(ApiEndpoints.qualificationStations)),
        headers: ApiService.headers,
        body: json.encode(station.toJson(includeAttachments: true)),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final created = QualificationStation.fromJson(data['station']);
        _stations.insert(0, created);
        return created;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'تعذر إنشاء المحطة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<QualificationStation?> updateStation(
    QualificationStation station,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.put(
        Uri.parse(_baseUrl(ApiEndpoints.qualificationStationById(station.id))),
        headers: ApiService.headers,
        body: json.encode(
          station.toJson(includeId: true, includeAttachments: true),
        ),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updated = QualificationStation.fromJson(data['station']);
        _selectedStation = updated;
        _updateLocalStation(updated);
        return updated;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'تعذر تحديث المحطة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<QualificationStation?> updateStatus(
    String id,
    QualificationStatus status, {
    required String reason,
    QualificationAssignee? assignedTo,
    List<QualificationAttachment> attachments = const [],
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.put(
        Uri.parse(_baseUrl(ApiEndpoints.qualificationStationStatus(id))),
        headers: ApiService.headers,
        body: json.encode({
          'status': qualificationStatusToString(status),
          'reason': reason.trim(),
          if (assignedTo != null) 'assignedTo': assignedTo.toJson(),
          if (attachments.isNotEmpty)
            'attachments': attachments.map((e) => e.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        final updated = QualificationStation.fromJson(data['station']);
        _selectedStation = updated;
        _updateLocalStation(updated);
        return updated;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'تعذر تحديث الحالة');
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<QualificationAttachment>> uploadAttachments(
    List<PlatformFile> files,
  ) async {
    if (files.isEmpty) return [];
    final storage = FirebaseStorage.instance;
    final attachments = <QualificationAttachment>[];

    for (final file in files) {
      final safeName = (file.name).replaceAll(' ', '_');
      final ref = storage.ref().child(
        'qualification_stations/${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );

      if (kIsWeb && file.bytes != null) {
        await ref.putData(file.bytes!);
      } else if (file.path != null) {
        await ref.putFile(File(file.path!));
      } else if (file.bytes != null) {
        await ref.putData(file.bytes!);
      } else {
        continue;
      }

      final url = await ref.getDownloadURL();
      attachments.add(
        QualificationAttachment(
          url: url,
          type: _guessAttachmentType(file.extension),
          name: safeName,
          createdAt: DateTime.now(),
        ),
      );
    }

    return attachments;
  }

  static String _guessAttachmentType(String? extension) {
    if (extension == null) return 'file';
    final ext = extension.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
      return 'image';
    }
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return 'video';
    }
    if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) {
      return 'audio';
    }
    return 'file';
  }

  Future<bool> deleteStation(String id) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.delete(
        Uri.parse(_baseUrl(ApiEndpoints.qualificationStationById(id))),
        headers: ApiService.headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _stations.removeWhere((station) => station.id == id);
        if (_selectedStation?.id == id) _selectedStation = null;
        return true;
      }
      final data = ApiService.decodeJson(response);
      throw Exception(data['error'] ?? 'تعذر حذف المحطة');
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _updateLocalStation(QualificationStation station) {
    final index = _stations.indexWhere((s) => s.id == station.id);
    if (index == -1) {
      _stations.insert(0, station);
    } else {
      _stations[index] = station;
    }
    notifyListeners();
  }
}
