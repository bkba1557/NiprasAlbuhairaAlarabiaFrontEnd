import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverBackgroundLocationPermission {
  static const String _promptKeyPrefix =
      'driver_background_location_prompted_v1_';

  static bool get _supportsBackgroundLocation =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> maybePromptOnFirstLaunch(
    BuildContext context, {
    required String userId,
    required bool isDriver,
  }) async {
    if (!isDriver || !_supportsBackgroundLocation) return;

    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_promptKeyPrefix$normalizedUserId';
    if (prefs.getBool(key) == true) return;

    if (!context.mounted) return;
    final shouldRequest =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('السماح بالموقع في الخلفية'),
              content: const Text(
                'نحتاج تشغيل الموقع في الخلفية أثناء تنفيذ الطلب حتى يبقى التتبع المباشر شغالًا، ويستطيع المالك متابعة مسار السيارة والمسافة والوقت المتوقع للوصول حتى لو خرجت من التطبيق.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ليس الآن'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('متابعة'),
                ),
              ],
            );
          },
        ) ??
        false;

    await prefs.setBool(key, true);
    if (!shouldRequest || !context.mounted) return;

    final permission = await requestBackgroundLocationPermission();
    if (!context.mounted) return;

    if (permission == LocationPermission.deniedForever) {
      await showSettingsDialog(context);
      return;
    }

    if (permission != LocationPermission.always) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم منح الموقع أثناء استخدام التطبيق فقط. لعمل التتبع المباشر بالخلفية فعّل "السماح طوال الوقت" من إعدادات التطبيق.',
          ),
        ),
      );
    }
  }

  static Future<LocationPermission> requestBackgroundLocationPermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse &&
        _supportsBackgroundLocation) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  static Future<void> showSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isAndroidBackgroundFlow = _supportsBackgroundLocation;
        return AlertDialog(
          title: Text(
            isAndroidBackgroundFlow
                ? 'فعّل إذن الموقع في الخلفية من الإعدادات'
                : 'فعّل إذن الموقع من الإعدادات',
          ),
          content: Text(
            isAndroidBackgroundFlow
                ? 'تم رفض إذن الموقع في الخلفية بشكل دائم. فعّل "السماح طوال الوقت" حتى يستمر تتبع الطلب مباشر أثناء وجود التطبيق في الخلفية.'
                : 'تم رفض إذن الموقع بشكل دائم. فعّل إذن الموقع أثناء استخدام التطبيق من إعدادات الجهاز.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('فتح الإعدادات'),
            ),
          ],
        );
      },
    );
  }
}
