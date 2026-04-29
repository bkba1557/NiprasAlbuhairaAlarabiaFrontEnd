import 'package:flutter/foundation.dart';
import 'package:order_tracker/utils/web_env.dart';
// https://system-albuhairaalarabia.cloud/api
class ApiConfig {
  static const String productionBaseUrl =
      'https://system-albuhairaalarabia.cloud/api';
  static const String devLanBaseUrl = 'http://192.168.8.235:6030/api';
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
    if (kIsWeb) {
      if (kReleaseMode) return productionBaseUrl;
      if ((webProtocol ?? '').toLowerCase() == 'https:') {
        return productionBaseUrl;
      }
      return devLanBaseUrl;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
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
