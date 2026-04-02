import 'package:flutter/foundation.dart';
import 'package:order_tracker/models/circular_model.dart';
import 'package:order_tracker/utils/api_service.dart';

class CircularProvider with ChangeNotifier {
  CircularModel? _pendingCircular;
  bool _checking = false;
  bool _accepting = false;
  Object? _lastError;

  CircularModel? get pendingCircular => _pendingCircular;
  bool get hasPendingCircular => _pendingCircular != null;
  bool get isChecking => _checking;
  bool get isAccepting => _accepting;
  Object? get lastError => _lastError;

  void reset() {
    _pendingCircular = null;
    _checking = false;
    _accepting = false;
    _lastError = null;
    notifyListeners();
  }

  Future<void> checkPendingCircular() async {
    if (_checking) return;
    _checking = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/circulars/pending');
      final decoded = ApiService.decodeJson(response);
      final circularJson = decoded is Map ? decoded['circular'] : null;

      if (circularJson == null) {
        _pendingCircular = null;
      } else {
        _pendingCircular = CircularModel.fromJson(
          Map<String, dynamic>.from(circularJson as Map),
        );
      }
    } catch (e) {
      _lastError = e;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<void> acceptPendingCircular() async {
    final pending = _pendingCircular;
    if (pending == null) return;
    if (_accepting) return;

    _accepting = true;
    _lastError = null;
    notifyListeners();

    try {
      await ApiService.post('/circulars/${pending.id}/accept', {});
      _pendingCircular = null;
      notifyListeners();
      await checkPendingCircular();
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _accepting = false;
      notifyListeners();
    }
  }
}

