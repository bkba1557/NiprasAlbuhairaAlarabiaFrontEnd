import 'package:flutter/foundation.dart';
import 'package:order_tracker/models/statement_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class StatementProvider with ChangeNotifier {
  StatementModel? _statement;

  bool _isFetching = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  String? _error;

  StatementModel? get statement => _statement;
  bool get hasStatement => _statement != null;
  bool get isFetching => _isFetching;
  bool get isSubmitting => _isSubmitting;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading({
    bool fetching = false,
    bool submitting = false,
    bool loading = false,
  }) {
    _isFetching = fetching;
    _isSubmitting = submitting;
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchStatement({bool silent = false}) async {
    if (!silent) _setLoading(fetching: true, loading: true);
    try {
      final response = await ApiService.get(ApiEndpoints.statements);
      final data = ApiService.decodeJson(response) as Map<String, dynamic>;
      final raw = data['statement'];
      if (raw == null) {
        _statement = null;
      } else {
        _statement = StatementModel.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!silent) _setLoading(fetching: false, loading: false);
    }
  }

  Future<bool> createStatement({
    required DateTime issueDate,
    required DateTime expiryDate,
  }) async {
    _setLoading(submitting: true, loading: true);
    try {
      final response = await ApiService.post(ApiEndpoints.statements, {
        'issueDate': issueDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
      });

      final data = ApiService.decodeJson(response) as Map<String, dynamic>;
      final raw = data['statement'];
      if (raw != null) {
        _statement = StatementModel.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(submitting: false, loading: false);
    }
  }

  Future<bool> renewStatement({required DateTime expiryDate}) async {
    _setLoading(submitting: true, loading: true);
    try {
      final response = await ApiService.post(ApiEndpoints.statementRenew, {
        'expiryDate': expiryDate.toIso8601String(),
      });

      final data = ApiService.decodeJson(response) as Map<String, dynamic>;
      final raw = data['statement'];
      if (raw != null) {
        _statement = StatementModel.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(submitting: false, loading: false);
    }
  }

  Future<bool> updateRenewal({
    required String renewalId,
    required DateTime expiryDate,
  }) async {
    _setLoading(submitting: true, loading: true);
    try {
      final response = await ApiService.patch(
        ApiEndpoints.statementRenewalById(renewalId),
        <String, dynamic>{'expiryDate': expiryDate.toIso8601String()},
      );

      final data = ApiService.decodeJson(response) as Map<String, dynamic>;
      final raw = data['statement'];
      if (raw != null) {
        _statement = StatementModel.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(submitting: false, loading: false);
    }
  }
}

