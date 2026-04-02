import 'package:shared_preferences/shared_preferences.dart';

class CircularNumberService {
  static const String prefix = 'BHR';
  static const int minDigits = 5;
  static const int startSequence = 1;

  static const String _prefsKeyLastSequence = 'circular_last_sequence';

  static String format(int sequence) {
    final normalized = sequence < startSequence ? startSequence : sequence;
    final digits = normalized.toString().padLeft(minDigits, '0');
    return '$prefix$digits';
  }

  static int? tryParseSequence(String circularNumber) {
    final value = circularNumber.trim().toUpperCase();
    if (!value.startsWith(prefix)) return null;
    final tail = value.substring(prefix.length).trim();
    final parsed = int.tryParse(tail);
    if (parsed == null || parsed < startSequence) return null;
    return parsed;
  }

  static Future<int> _readLastSequence() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyLastSequence) ?? 0;
  }

  static Future<void> _writeLastSequence(int sequence) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyLastSequence, sequence);
  }

  static Future<String> reserveNextNumber() async {
    final last = await _readLastSequence();
    final next = (last < startSequence) ? startSequence : (last + 1);
    await _writeLastSequence(next);
    return format(next);
  }

  static Future<String> peekNextNumber() async {
    final last = await _readLastSequence();
    final next = (last < startSequence) ? startSequence : (last + 1);
    return format(next);
  }

  static Future<void> commitNumber(String circularNumber) async {
    final sequence = tryParseSequence(circularNumber);
    if (sequence == null) return;

    final last = await _readLastSequence();
    if (sequence > last) {
      await _writeLastSequence(sequence);
    }
  }
}

