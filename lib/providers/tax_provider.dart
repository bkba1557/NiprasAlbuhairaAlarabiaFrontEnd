import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxProvider with ChangeNotifier {
  static const String _vatRateKey = 'vat_rate';
  static const double defaultVatRate = 0.15;

  double _vatRate = defaultVatRate;
  bool _isInitialized = false;
  bool _isSaving = false;
  String? _error;

  double get vatRate => _vatRate;
  bool get isInitialized => _isInitialized;
  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_vatRateKey);
      if (stored != null && stored >= 0 && stored <= 1) {
        _vatRate = stored;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> setVatRate(double value) async {
    final normalized = value.clamp(0.0, 1.0);

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setDouble(_vatRateKey, normalized);
      if (!ok) {
        _error = 'تعذر حفظ قيمة الضريبة';
        return false;
      }
      _vatRate = normalized;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> resetVatRate() => setVatRate(defaultVatRate);
}

