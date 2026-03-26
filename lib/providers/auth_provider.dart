import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/services/push_notification_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/auth_token_storage.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/login_device_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const Duration _requestTimeout = Duration(seconds: 20);

  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  int? _tokenExpiryMillis;
  String? _pendingRoute;
  String? _pendingLoginType;
  String? _pendingIdentifier;
  String? _pendingMaskedEmail;

  static const Set<String> _publicRoutes = <String>{
    '/',
    '/front',
    '/login',
    '/register',
  };

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get pendingRoute => _pendingRoute;
  String? get pendingMaskedEmail => _pendingMaskedEmail;

  bool get isAuthenticated => _token != null && _user != null;
  bool get hasPendingOtp =>
      _pendingLoginType != null && _pendingIdentifier != null;
  String? get role => _user?.role;
  String? get stationId => _user?.stationId;
  List<String> get stationIds =>
      List.unmodifiable(_user?.stationIds ?? const <String>[]);
  String? get stationName => _user?.stationName;

  bool get isStationBoy => _user?.role == 'station_boy';
  bool get isOwnerStation => _user?.role == 'owner_station';

  bool get isAdminLike =>
      _user?.role == 'owner' ||
      _user?.role == 'admin' ||
      _user?.role == 'manager';

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

        ApiService.primeToken(savedToken);
        setAuthToken(savedToken);
        unawaited(_initPushNotificationsSafely());
      } else if (expiryMillis != null &&
          DateTime.now().millisecondsSinceEpoch >= expiryMillis) {
        await _clearStoredAuthData(prefs);
      }
    } catch (e, s) {
      debugPrint('INIT AUTH ERROR: $e');
      debugPrint('STACK: $s');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.login}'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);

      final body = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        await _completeAuthenticatedSession(body);
        _setLoading(false);
        notifyListeners();
        return true;
      }

      _error = body['error']?.toString() ?? 'فشل تسجيل الدخول';
    } on TimeoutException {
      _error = 'انتهت مهلة الاتصال بالخادم';
    } on SocketException {
      _error = 'لا يوجد اتصال بالإنترنت';
    } on http.ClientException catch (e) {
      _error = _friendlyClientErrorMessage(e.message);
    } catch (e, s) {
      debugPrint('LOGIN ERROR: $e');
      debugPrint('STACK: $s');
      _error = 'حدث خطأ غير متوقع أثناء تسجيل الدخول';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  Future<bool> requestLoginOtp({
    required String loginType,
    required String identifier,
  }) async {
    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty) {
      _error = 'يرجى إدخال بيانات الدخول';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final device = await LoginDeviceUtil.resolve();
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.requestLoginOtp}'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'loginType': loginType,
              'identifier': trimmedIdentifier,
              ...device.toJson(),
            }),
          )
          .timeout(_requestTimeout);

      final body = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        _pendingLoginType = loginType;
        _pendingIdentifier = trimmedIdentifier;
        _pendingMaskedEmail = body['maskedEmail']?.toString();
        _setLoading(false);
        notifyListeners();
        return true;
      }

      _error = body['error']?.toString() ?? 'تعذر إرسال رمز التحقق';
    } on TimeoutException {
      _error = 'انتهت مهلة الاتصال بالخادم';
    } on SocketException {
      _error = 'لا يوجد اتصال بالإنترنت';
    } on http.ClientException catch (e) {
      _error = _friendlyClientErrorMessage(e.message);
    } catch (e, s) {
      debugPrint('OTP REQUEST ERROR: $e');
      debugPrint('STACK: $s');
      _error = 'حدث خطأ أثناء إرسال رمز التحقق';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  Future<bool> verifyLoginOtp(String otp) async {
    final trimmedOtp = otp.trim();

    if (!hasPendingOtp) {
      _error = 'انتهت جلسة التحقق، يرجى طلب رمز جديد';
      notifyListeners();
      return false;
    }

    if (trimmedOtp.length != 6) {
      _error = 'أدخل رمز تحقق مكوناً من 6 أرقام';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final device = await LoginDeviceUtil.resolve();
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.verifyLoginOtp}'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'loginType': _pendingLoginType,
              'identifier': _pendingIdentifier,
              'otp': trimmedOtp,
              ...device.toJson(),
            }),
          )
          .timeout(_requestTimeout);

      final body = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        await _completeAuthenticatedSession(body);
        cancelPendingOtp(notify: false);
        _setLoading(false);
        notifyListeners();
        return true;
      }

      _error = body['error']?.toString() ?? 'فشل التحقق من الرمز';
    } on TimeoutException {
      _error = 'انتهت مهلة الاتصال بالخادم';
    } on SocketException {
      _error = 'لا يوجد اتصال بالإنترنت';
    } on http.ClientException catch (e) {
      _error = _friendlyClientErrorMessage(e.message);
    } catch (e, s) {
      debugPrint('OTP VERIFY ERROR: $e');
      debugPrint('STACK: $s');
      _error = 'حدث خطأ أثناء التحقق من الرمز';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String company,
    String? phone, {
    String? username,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.register}'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'name': name,
              'username': username,
              'email': email,
              'password': password,
              'company': company,
              'phone': phone,
            }),
          )
          .timeout(_requestTimeout);

      final body = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 201) {
        await _completeAuthenticatedSession(body);
        _setLoading(false);
        notifyListeners();
        return true;
      }

      _error = body['error']?.toString() ?? 'فشل إنشاء الحساب';
    } on TimeoutException {
      _error = 'انتهت مهلة الاتصال بالخادم';
    } on SocketException {
      _error = 'لا يوجد اتصال بالإنترنت';
    } on http.ClientException catch (e) {
      _error = _friendlyClientErrorMessage(e.message);
    } catch (e, s) {
      debugPrint('REGISTER ERROR: $e');
      debugPrint('STACK: $s');
      _error = 'حدث خطأ غير متوقع أثناء التسجيل';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  Future<void> logout({bool notifyServer = true}) async {
    if (notifyServer) {
      try {
        await ApiService.post(ApiEndpoints.logout, const {});
      } catch (e, s) {
        debugPrint('LOGOUT NOTIFY ERROR: $e');
        debugPrint('STACK: $s');
      }
    }

    await PushNotificationService.unregister();
    final prefs = await SharedPreferences.getInstance();
    await _clearStoredAuthData(prefs);
    notifyListeners();
  }

  Future<void> updateProfile(User updatedUser) async {
    _user = updatedUser;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(updatedUser.toJson()));

    notifyListeners();
  }

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

  void cancelPendingOtp({bool notify = true}) {
    _pendingLoginType = null;
    _pendingIdentifier = null;
    _pendingMaskedEmail = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _friendlyClientErrorMessage(String message) {
    final normalized = message.trim();

    if (normalized.isEmpty) {
      return 'تعذر الاتصال بالخادم';
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('cleartext') && lower.contains('not permitted')) {
      return 'الاتصال غير مسموح لأن الخادم يستخدم HTTP (يرجى تفعيل Cleartext على أندرويد)';
    }

    return 'تعذر الاتصال بالخادم';
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
    _pendingLoginType = null;
    _pendingIdentifier = null;
    _pendingMaskedEmail = null;
    await ApiService.setToken(null);
    clearAuthToken();
  }

  Future<void> _completeAuthenticatedSession(Map<String, dynamic> data) async {
    final receivedToken = data['token'];
    final userData = data['user'];

    if (receivedToken == null || userData == null) {
      throw Exception('Token أو بيانات المستخدم غير موجودة في الاستجابة');
    }

    _token = receivedToken.toString();
    _user = User.fromJson(Map<String, dynamic>.from(userData));

    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(const Duration(days: 30));
    _tokenExpiryMillis = expiry.millisecondsSinceEpoch;

    await Future.wait<dynamic>([
      prefs.setString('token', _token!),
      prefs.setString('user', json.encode(_user!.toJson())),
      prefs.setInt('tokenExpiry', _tokenExpiryMillis!),
      ApiService.setToken(_token),
    ]);
    setAuthToken(_token!);
    unawaited(_initPushNotificationsSafely());
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
