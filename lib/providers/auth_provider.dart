// // auth_provider.dart
// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:order_tracker/models/models.dart';
// import 'package:order_tracker/utils/api_service.dart';
// import 'package:order_tracker/utils/app_routes.dart';
// import 'package:order_tracker/utils/constants.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class AuthProvider with ChangeNotifier {
//   User? _user;
//   String? _token;
//   bool _isLoading = false;
//   String? _error;

//   // ================= GETTERS =================
//   User? get user => _user;
//   String? get token => _token;
//   bool get isLoading => _isLoading;
//   String? get error => _error;
//   bool get isAuthenticated => _token != null && _user != null;
//   String? get role => _user?.role;

//   String? get stationId => _user?.stationId;
//   String? get stationName => _user?.stationName;

//   bool get isStationBoy => _user?.role == 'station_boy';

//   /// ✅ أدوار إدارية
//   bool get isAdminLike =>
//       _user?.role == 'owner' ||
//       _user?.role == 'admin' ||
//       _user?.role == 'manager';

//   String get initialRoute {
//     if (!isAuthenticated) {
//       return AppRoutes.front;
//     }

//     if (isStationBoy) {
//       return '/sessions';
//     }

//     return '/home';
//   }

//   // ================= INIT =================
//   /// تُستدعى مرة واحدة عند تشغيل التطبيق
//   Future<void> initialize() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final savedToken = prefs.getString('token');
//       final userJson = prefs.getString('user');

//       if (savedToken != null && userJson != null) {
//         _token = savedToken;
//         _user = User.fromJson(json.decode(userJson));

//         // أهم سطر 👇
//         ApiService.setToken(savedToken);

//         notifyListeners();
//         debugPrint('✅ AUTH INITIALIZED (TOKEN LOADED)');
//       }
//     } catch (e, s) {
//       debugPrint('❌ INIT AUTH ERROR: $e');
//       debugPrint('STACK: $s');
//     }
//   }

//   // ================= LOGIN =================
//   Future<bool> login(String email, String password) async {
//     _setLoading(true);
//     _error = null;

//     try {
//       final response = await http.post(
//         Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.login}'),
//         headers: const {'Content-Type': 'application/json'},
//         body: json.encode({'email': email, 'password': password}),
//       );

//       debugPrint('LOGIN STATUS: ${response.statusCode}');
//       debugPrint('LOGIN BODY: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final receivedToken = data['token'];
//         final userData = data['user'];

//         if (receivedToken == null || userData == null) {
//           throw Exception('Token أو User غير موجودين في الاستجابة');
//         }

//         _token = receivedToken;
//         _user = User.fromJson(userData);

//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('token', receivedToken);
//         await prefs.setString('user', json.encode(_user!.toJson()));

//         ApiService.setToken(receivedToken);

//         _setLoading(false);
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error = errorData['error'] ?? 'فشل تسجيل الدخول';
//       }
//     } on SocketException {
//       _error = 'لا يوجد اتصال بالإنترنت';
//     } catch (e, s) {
//       debugPrint('❌ LOGIN ERROR: $e');
//       debugPrint('STACK: $s');
//       _error = 'حدث خطأ غير متوقع أثناء تسجيل الدخول';
//     }

//     _setLoading(false);
//     notifyListeners();
//     return false;
//   }

//   // ================= REGISTER =================
//   Future<bool> register(
//     String name,
//     String email,
//     String password,
//     String company,
//     String? phone,
//   ) async {
//     _setLoading(true);
//     _error = null;

//     try {
//       final response = await http.post(
//         Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.register}'),
//         headers: const {'Content-Type': 'application/json'},
//         body: json.encode({
//           'name': name,
//           'email': email,
//           'password': password,
//           'company': company,
//           'phone': phone,
//         }),
//       );

//       if (response.statusCode == 201) {
//         final data = json.decode(response.body);

//         final receivedToken = data['token'];
//         final userData = data['user'];

//         if (receivedToken == null || userData == null) {
//           throw Exception('Token أو User غير موجودين');
//         }

//         _token = receivedToken;
//         _user = User.fromJson(userData);

//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('token', receivedToken);
//         await prefs.setString('user', json.encode(_user!.toJson()));

//         // مهم جدًا
//         ApiService.setToken(receivedToken);

//         _setLoading(false);
//         notifyListeners();
//         return true;
//       } else {
//         final errorData = json.decode(response.body);
//         _error = errorData['error'] ?? 'فشل إنشاء الحساب';
//       }
//     } catch (e, s) {
//       debugPrint('❌ REGISTER ERROR: $e');
//       debugPrint('STACK: $s');
//       _error = 'حدث خطأ غير متوقع أثناء التسجيل';
//     }

//     _setLoading(false);
//     notifyListeners();
//     return false;
//   }

//   // ================= LOGOUT =================
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('token');
//     await prefs.remove('user');

//     _user = null;
//     _token = null;

//     // مهم جدًا
//     ApiService.setToken(null);

//     notifyListeners();
//   }

//   // ================= UPDATE PROFILE =================
//   Future<void> updateProfile(User updatedUser) async {
//     _user = updatedUser;

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('user', json.encode(updatedUser.toJson()));

//     notifyListeners();
//   }

//   // ================= HELPERS =================
//   void clearError() {
//     _error = null;
//     notifyListeners();
//   }

//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }
// }




// auth_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/auth_token_storage.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  int? _tokenExpiryMillis;
  String? _pendingRoute;
  static const Set<String> _publicRoutes = <String>{
    '/',
    '/front',
    '/login',
    '/register',
  };

  // ================= GETTERS =================
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get pendingRoute => _pendingRoute;

  bool get isAuthenticated => _token != null && _user != null;
  String? get role => _user?.role;

  String? get stationId => _user?.stationId;
  String? get stationName => _user?.stationName;

  bool get isStationBoy => _user?.role == 'station_boy';

  /// ✅ أدوار إدارية
  bool get isAdminLike =>
      _user?.role == 'owner' ||
      _user?.role == 'admin' ||
      _user?.role == 'manager';

  // ================= INIT =================
  /// ⏳ تُستدعى مرة واحدة عند تشغيل التطبيق
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('token');
      final userJson = prefs.getString('user');
      final expiryMillis = prefs.getInt('tokenExpiry');

      if (savedToken != null &&
          userJson != null &&
          expiryMillis != null &&
          DateTime.now().millisecondsSinceEpoch < expiryMillis) {
        _token = savedToken;
        _user = User.fromJson(json.decode(userJson));
        _tokenExpiryMillis = expiryMillis;

        ApiService.setToken(savedToken);
        setAuthToken(savedToken);
        await _initPushNotificationsSafely();
        debugPrint('✅ AUTH INITIALIZED (TOKEN LOADED)');
      } else if (expiryMillis != null &&
          DateTime.now().millisecondsSinceEpoch >= expiryMillis) {
        await _clearStoredAuthData(prefs);
        debugPrint('ℹ️ Saved credentials expired, clearing data');
      } else {
        debugPrint('ℹ️ NO SAVED SESSION');
      }
    } catch (e, s) {
      debugPrint('❌ INIT AUTH ERROR: $e');
      debugPrint('STACK: $s');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ================= LOGIN =================
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.login}'),
        headers: const {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      debugPrint('LOGIN BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final receivedToken = data['token'];
        final userData = data['user'];

        if (receivedToken == null || userData == null) {
          throw Exception('Token أو User غير موجودين في الاستجابة');
        }

        _token = receivedToken;
        _user = User.fromJson(userData);

        final prefs = await SharedPreferences.getInstance();
        final expiry = DateTime.now().add(const Duration(days: 30));
        _tokenExpiryMillis = expiry.millisecondsSinceEpoch;

        await prefs.setString('token', receivedToken);
        await prefs.setString('user', json.encode(_user!.toJson()));
        await prefs.setInt('tokenExpiry', _tokenExpiryMillis!);

        ApiService.setToken(receivedToken);
        setAuthToken(receivedToken);
        await _initPushNotificationsSafely();

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل تسجيل الدخول';
      }
    } on SocketException {
      _error = 'لا يوجد اتصال بالإنترنت';
    } catch (e, s) {
      debugPrint('❌ LOGIN ERROR: $e');
      debugPrint('STACK: $s');
      _error = 'حدث خطأ غير متوقع أثناء تسجيل الدخول';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  // ================= REGISTER =================
  Future<bool> register(
    String name,
    String email,
    String password,
    String company,
    String? phone,
  ) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.register}'),
        headers: const {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'company': company,
          'phone': phone,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        final receivedToken = data['token'];
        final userData = data['user'];

        if (receivedToken == null || userData == null) {
          throw Exception('Token أو User غير موجودين');
        }

        _token = receivedToken;
        _user = User.fromJson(userData);

        final prefs = await SharedPreferences.getInstance();
        final expiry = DateTime.now().add(const Duration(days: 30));
        _tokenExpiryMillis = expiry.millisecondsSinceEpoch;

        await prefs.setString('token', receivedToken);
        await prefs.setString('user', json.encode(_user!.toJson()));
        await prefs.setInt('tokenExpiry', _tokenExpiryMillis!);

        ApiService.setToken(receivedToken);
        setAuthToken(receivedToken);
        await _initPushNotificationsSafely();

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _error = errorData['error'] ?? 'فشل إنشاء الحساب';
      }
    } catch (e, s) {
      debugPrint('❌ REGISTER ERROR: $e');
      debugPrint('STACK: $s');
      _error = 'حدث خطأ غير متوقع أثناء التسجيل';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await PushNotificationService.unregister();
    final prefs = await SharedPreferences.getInstance();
    await _clearStoredAuthData(prefs);

    notifyListeners();
  }

  // ================= UPDATE PROFILE =================
  Future<void> updateProfile(User updatedUser) async {
    _user = updatedUser;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(updatedUser.toJson()));

    notifyListeners();
  }

  // ================= HELPERS =================
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setPendingRoute(String? route) {
    if (route == null || route.trim().isEmpty) return;
    final normalizedRoute = route.trim();
    final path = Uri.tryParse(normalizedRoute)?.path ?? normalizedRoute;
    if (_publicRoutes.contains(path)) return;
    _pendingRoute ??= normalizedRoute;
  }

  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }


  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _clearStoredAuthData([SharedPreferences? prefs]) async {
    final localPrefs = prefs ?? await SharedPreferences.getInstance();
    await localPrefs.remove('token');
    await localPrefs.remove('user');
    await localPrefs.remove('tokenExpiry');
    _token = null;
    _user = null;
    _tokenExpiryMillis = null;
    _pendingRoute = null;
    ApiService.setToken(null);
    clearAuthToken();
  }

  Future<void> _initPushNotificationsSafely() async {
    try {
      await PushNotificationService.init();
    } catch (e, s) {
      debugPrint('Push init error ignored for auth flow: $e');
      debugPrint('STACK: $s');
    }
  }
}
