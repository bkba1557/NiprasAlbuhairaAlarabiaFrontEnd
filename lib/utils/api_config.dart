import 'package:flutter/foundation.dart';



// https://system-albuhairaalarabia.cloud/api

class ApiConfig {
  static const String productionBaseUrl =
      'https://system-albuhairaalarabia.cloud/api';

  // Local/LAN API URL used in development (so mobile devices can reach it too).
  static const String devLanBaseUrl = 'http://192.168.8.212:6030/api';

  static const String _envKey = 'API_BASE_URL';

  static String get baseUrl {
    const override = String.fromEnvironment(_envKey, defaultValue: '');
    if (override.trim().isNotEmpty) {
      return _normalize(override);
    }

    if (kReleaseMode) {
      return productionBaseUrl;
    }

    return _defaultDevBaseUrl();
  }

  static String _defaultDevBaseUrl() {
    // Web:
    // - In debug/profile, it's usually safe to use the LAN backend (served over
    //   HTTP) because Flutter's dev server is also HTTP.
    // - In release, keep using the production HTTPS backend to avoid mixed
    //   content / network policy issues.
    if (kIsWeb) {
      return kReleaseMode ? productionBaseUrl : devLanBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Use LAN by default so it works on real devices.
        // If you're using an Android emulator with a localhost-bound backend,
        // you can override via `--dart-define=API_BASE_URL=http://10.0.2.2:6030`.
        return devLanBaseUrl;
      case TargetPlatform.iOS:
        return devLanBaseUrl;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return devLanBaseUrl;
      default:
        return devLanBaseUrl;
    }
  }

  static String _normalize(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (!url.endsWith('/api')) {
      url = '$url/api';
    }

    return url;
  }
}
