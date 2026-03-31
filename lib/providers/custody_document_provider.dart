import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custody_document_model.dart';
import '../utils/api_service.dart';

class CustodyDocumentProvider with ChangeNotifier {
  final List<CustodyDocument> _documents = [];
  bool _isLoading = true;
  String? _token;

  CustodyDocumentProvider() {
    fetchDocuments();
  }

  bool get isLoading => _isLoading;
  List<CustodyDocument> get documents => List.unmodifiable(_documents);
  List<CustodyDocument> get pendingDocuments => _documents
      .where((doc) => doc.status == CustodyDocumentStatus.pending)
      .toList();

  Future<void> _initializeToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
    }
    if (_token != null) {
      ApiService.setToken(_token);
    }
  }

  Future<void> fetchDocuments() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _initializeToken();
      final response = await ApiService.get('/custody-documents');

      if (response.statusCode == 200) {
        final data = ApiService.decodeJson(response);
        if (data['success'] == true) {
          final list = (data['data'] as List<dynamic>? ?? []);
          _documents
            ..clear()
            ..addAll(
              list
                  .map(
                    (item) => CustodyDocument.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ),
                  )
                  .toList(),
            );
        } else {
          throw Exception(
            data['message'] ?? 'Failed to load custody documents',
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('CustodyDocumentProvider.fetchDocuments error: $error');
      _documents.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDocuments() => fetchDocuments();

  Future<void> addDocument(CustodyDocument document) async {
    try {
      await _initializeToken();
      final payload = {
        'documentNumber': document.documentNumber,
        'documentTitle': document.documentTitle,
        'documentDate': document.documentDate.toIso8601String(),
        'custodianName': document.custodianName,
        'destinationType': document.destinationType,
        'destinationName': document.destinationName,
        'reason': document.reason,
        'notes': document.notes,
        'rows': document.rows.map((row) => row.toJson()).toList(),
        'vehicleNumber': document.vehicleNumber,
        'amount': document.amount,
      };

      final response = await ApiService.post('/custody-documents', payload);
      if (response.statusCode == 201) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          _documents.insert(
            0,
            CustodyDocument.fromJson(
              Map<String, dynamic>.from(result['data'] as Map),
            ),
          );
          notifyListeners();
          return;
        }
        throw Exception(result['message'] ?? 'Failed to create document');
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('CustodyDocumentProvider.addDocument error: $error');
      rethrow;
    }
  }

  Future<void> updateStatus(
    String id,
    CustodyDocumentStatus status, {
    String? reviewedBy,
  }) async {
    try {
      await _initializeToken();
      final response = await ApiService.patch('/custody-documents/$id/status', {
        'status': status.value,
      });

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          final updated = CustodyDocument.fromJson(
            Map<String, dynamic>.from(result['data'] as Map),
          );
          final index = _documents.indexWhere((doc) => doc.id == id);
          if (index != -1) {
            _documents[index] = updated;
            notifyListeners();
          }
          return;
        }
        throw Exception(result['message'] ?? 'Failed to update document');
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('CustodyDocumentProvider.updateStatus error: $error');
      rethrow;
    }
  }

  Future<void> requestReturn(String id, double returnAmount) async {
    try {
      await _initializeToken();
      final response = await ApiService.patch(
        '/custody-documents/$id/return-request',
        {'returnAmount': returnAmount},
      );

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          final updated = CustodyDocument.fromJson(
            Map<String, dynamic>.from(result['data'] as Map),
          );
          final index = _documents.indexWhere((doc) => doc.id == id);
          if (index != -1) {
            _documents[index] = updated;
            notifyListeners();
          }
          return;
        }
        throw Exception(result['message'] ?? 'Failed to request return');
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('CustodyDocumentProvider.requestReturn error: $error');
      rethrow;
    }
  }

  Future<void> updateReturnStatus(String id, CustodyReturnStatus status) async {
    try {
      await _initializeToken();
      final response = await ApiService.patch(
        '/custody-documents/$id/return-status',
        {'status': status.value},
      );

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          final updated = CustodyDocument.fromJson(
            Map<String, dynamic>.from(result['data'] as Map),
          );
          final index = _documents.indexWhere((doc) => doc.id == id);
          if (index != -1) {
            _documents[index] = updated;
            notifyListeners();
          }
          return;
        }
        throw Exception(result['message'] ?? 'Failed to update return status');
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('CustodyDocumentProvider.updateReturnStatus error: $error');
      rethrow;
    }
  }

  Future<void> updateFinanceStatus(
    String id,
    CustodyFinanceStatus status, {
    String? reason,
  }) async {
    try {
      await _initializeToken();
      final payload = {'status': status.value};
      if (reason != null) {
        payload['reason'] = reason;
      }
      final response = await ApiService.patch(
        '/custody-documents/$id/finance-status',
        payload,
      );

      if (response.statusCode == 200) {
        final result = ApiService.decodeJson(response);
        if (result['success'] == true) {
          final updated = CustodyDocument.fromJson(
            Map<String, dynamic>.from(result['data'] as Map),
          );
          final index = _documents.indexWhere((doc) => doc.id == id);
          if (index != -1) {
            _documents[index] = updated;
            notifyListeners();
          }
          return;
        }
        throw Exception(result['message'] ?? 'Failed to update finance status');
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('CustodyDocumentProvider.updateFinanceStatus error: $error');
      rethrow;
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _initializeToken();
      final response = await ApiService.delete('/custody-documents/$id');

      if (response.statusCode == 200) {
        final index = _documents.indexWhere((doc) => doc.id == id);
        if (index != -1) {
          _documents.removeAt(index);
          notifyListeners();
        }
        return;
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('CustodyDocumentProvider.deleteDocument error: $error');
      rethrow;
    }
  }
}
