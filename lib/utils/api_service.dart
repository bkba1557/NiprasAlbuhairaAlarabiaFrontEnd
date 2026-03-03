
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _token;

  static const String _baseUrl = 'https://system-albuhairaalarabia.cloud/api';
  // static const String _baseUrl = 'http://192.168.8.165:6030/api';
  static const String _tokenKey = 'auth_token';

  // ===============================
  // 🔐 Headers
  // ===============================
  static Map<String, String> get headers {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // ===============================
  // 💾 Token Persistence
  // ===============================

  /// تحميل التوكن عند تشغيل التطبيق
  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  /// حفظ التوكن لفترة طويلة
  static Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();

    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  /// مسح التوكن (Logout)
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ===============================
  // 🌐 HTTP Methods
  // ===============================

  static Future<http.Response> get(String endpoint) async {
    _ensureTokenLoaded();

    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    return _handleResponse(response);
  }

  static Future<http.Response> post(String endpoint, dynamic data) async {
    _ensureTokenLoaded();

    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<http.Response> put(String endpoint, dynamic data) async {
    _ensureTokenLoaded();

    final response = await http.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<http.Response> patch(String endpoint, dynamic data) async {
    _ensureTokenLoaded();

    final response = await http.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<http.Response> delete(String endpoint) async {
    _ensureTokenLoaded();

    final response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    return _handleResponse(response);
  }

  // ===============================
  // ⬇️ Download
  // ===============================
  static Future<http.Response> download(String endpoint) async {
    _ensureTokenLoaded();

    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return response;
    }

    if (response.statusCode == 401) {
      throw UnauthenticatedException();
    }

    throw Exception(
      'Download failed: ${response.statusCode} - ${response.body}',
    );
  }

  // ===============================
  // 👥 HR APIs
  // ===============================

  static Future<Map<String, dynamic>> hrGet(String endpoint) async {
    final response = await get(endpoint);
    return json.decode(utf8.decode(response.bodyBytes));
  }

  static Future<Map<String, dynamic>> hrPost(
    String endpoint,
    dynamic data,
  ) async {
    final response = await post(endpoint, data);
    return json.decode(utf8.decode(response.bodyBytes));
  }

  static Future<Map<String, dynamic>> hrPut(
    String endpoint,
    dynamic data,
  ) async {
    final response = await put(endpoint, data);
    return json.decode(utf8.decode(response.bodyBytes));
  }

  static Future<Map<String, dynamic>> hrDelete(String endpoint) async {
    final response = await delete(endpoint);
    return json.decode(utf8.decode(response.bodyBytes));
  }

  // ===============================
  // 🧬 Fingerprint
  // ===============================
  static Future<Map<String, dynamic>> fingerprintPost(
    String endpoint,
    dynamic data,
  ) async {
    _ensureTokenLoaded();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-fingerprint-api-key': 'your_fingerprint_api_key_here',
    };

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/hr$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(utf8.decode(response.bodyBytes));
    }

    if (response.statusCode == 401) {
      throw UnauthenticatedException();
    }

    throw Exception('API Error: ${response.statusCode} - ${response.body}');
  }

  // ===============================
  // 🧠 Helpers
  // ===============================
  static void _ensureTokenLoaded() {
    // حماية من طلبات بدري
    if (_token == null) {
      throw Exception('Auth token not initialized');
    }
  }

  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    if (response.statusCode == 401) {
      throw UnauthenticatedException();
    }

    throw Exception('API Error: ${response.statusCode}');
  }
}

// ===============================
// 🚫 Unauthorized Exception
// ===============================
class UnauthenticatedException implements Exception {}
