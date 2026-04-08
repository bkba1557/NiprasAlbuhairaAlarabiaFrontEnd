import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DriverTripLockSnapshot {
  final String orderId;
  final bool showMap;

  const DriverTripLockSnapshot({
    required this.orderId,
    required this.showMap,
  });

  factory DriverTripLockSnapshot.fromJson(Map<String, dynamic> json) {
    return DriverTripLockSnapshot(
      orderId: (json['orderId'] ?? '').toString().trim(),
      showMap: json['showMap'] == false ? false : true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'orderId': orderId,
    'showMap': showMap,
  };
}

class DriverTripLock {
  static String _key(String userId) => 'driver_active_trip_lock_$userId';

  static Future<void> save({
    required String userId,
    required String orderId,
    required bool showMap,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedOrderId = orderId.trim();
    if (normalizedUserId.isEmpty || normalizedOrderId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(normalizedUserId),
      jsonEncode(
        DriverTripLockSnapshot(
          orderId: normalizedOrderId,
          showMap: showMap,
        ).toJson(),
      ),
    );
  }

  static Future<DriverTripLockSnapshot?> load(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(normalizedUserId));
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final snapshot = DriverTripLockSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (snapshot.orderId.isEmpty) return null;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(normalizedUserId));
  }
}
