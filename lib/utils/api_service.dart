import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:order_tracker/utils/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _token;

  static String get _baseUrl => ApiConfig.baseUrl;
  static const String _tokenKey = 'auth_token';

  static Map<String, String> get headers {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  static Future<void> loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey) ?? '';
  }

  static void primeToken(String? token) {
    _token = token ?? '';
  }

  static Future<void> setToken(String? token) async {
    _token = token ?? '';
    final prefs = await SharedPreferences.getInstance();

    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  static Future<void> clearToken() async {
    _token = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<http.Response> get(String endpoint) async {
    await loadToken();

    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    return _handleResponse(response);
  }

  static Future<http.Response> post(String endpoint, dynamic data) async {
    await loadToken();

    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<http.Response> put(String endpoint, dynamic data) async {
    await loadToken();

    final response = await http.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<http.Response> patch(String endpoint, dynamic data) async {
    await loadToken();

    final response = await http.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<http.Response> delete(String endpoint) async {
    await loadToken();

    final response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    return _handleResponse(response);
  }

  static Future<http.Response> download(String endpoint) async {
    await loadToken();

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

    final message = _extractErrorMessage(response);
    if (message == null || message.isEmpty) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    throw Exception('Download failed: ${response.statusCode} - $message');
  }

  static Future<Map<String, dynamic>> hrGet(String endpoint) async {
    final response = await get(endpoint);
    return decodeJsonMap(response);
  }

  static Future<Map<String, dynamic>> hrPost(
    String endpoint,
    dynamic data,
  ) async {
    final response = await post(endpoint, data);
    return decodeJsonMap(response);
  }

  static Future<Map<String, dynamic>> hrPut(
    String endpoint,
    dynamic data,
  ) async {
    final response = await put(endpoint, data);
    return decodeJsonMap(response);
  }

  static Future<Map<String, dynamic>> hrDelete(String endpoint) async {
    final response = await delete(endpoint);
    return decodeJsonMap(response);
  }

  /// Decode JSON responses using UTF-8 bytes (safer for Arabic when the backend
  /// does not send charset in the Content-Type header).
  static dynamic decodeJson(http.Response response) {
    return json.decode(utf8.decode(response.bodyBytes));
  }

  static Map<String, dynamic> decodeJsonMap(http.Response response) {
    final decoded = decodeJson(response);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  static Future<Map<String, dynamic>> fingerprintPost(
    String endpoint,
    dynamic data,
  ) async {
    await loadToken();

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
      return decodeJsonMap(response);
    }

    if (response.statusCode == 401) {
      throw UnauthenticatedException();
    }

    throw Exception('API Error: ${response.statusCode} - ${response.body}');
  }

  static http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    if (response.statusCode == 401) {
      throw UnauthenticatedException();
    }

    final errorMessage = _extractErrorMessage(response);
    if (errorMessage == null || errorMessage.isEmpty) {
      throw Exception('API Error: ${response.statusCode}');
    }

    throw Exception('API Error: ${response.statusCode} - $errorMessage');
  }

  static String? _extractErrorMessage(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) return null;

    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } catch (_) {
      // Fall back to the raw body when the backend does not return JSON.
    }

    if (body.length <= 300) {
      return body;
    }

    return '${body.substring(0, 300)}...';
  }
}

class UnauthenticatedException implements Exception {}
