import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

class DevicePerformance {
  static const int _lowMemoryClassThresholdMb = 256;
  static const MethodChannel _channel =
      MethodChannel('com.albuhaira.nipras/device_performance');

  static bool _initialized = false;
  static bool _isLowRamDevice = false;
  static int? _memoryClassMb;

  static bool get isInitialized => _initialized;
  static bool get isLowRamDevice => _isLowRamDevice;
  static int? get memoryClassMb => _memoryClassMb;

  static bool get reduceEffects =>
      _isLowRamDevice ||
      (_memoryClassMb != null && _memoryClassMb! <= _lowMemoryClassThresholdMb);

  static Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      _isLowRamDevice =
          (await _channel.invokeMethod<bool>('isLowRamDevice')) ?? false;
      _memoryClassMb = await _channel.invokeMethod<int>('memoryClassMb');
    } catch (error) {
      debugPrint('DevicePerformance init failed: $error');
    } finally {
      _initialized = true;
    }
  }

  static void tuneFlutterCaches() {
    if (!_initialized) return;

    if (reduceEffects) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 30 << 20; // 30 MB
      PaintingBinding.instance.imageCache.maximumSize = 200;
    }
  }
}
