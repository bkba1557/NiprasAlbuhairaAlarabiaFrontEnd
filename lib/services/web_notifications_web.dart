// ignore: avoid_web_libraries_in_flutter
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;

dynamic _audioContext;
bool _audioInitHooked = false;

Future<void> ensureWebNotificationPermission() async {
  if (html.Notification.permission == 'granted') return;
  await html.Notification.requestPermission();
}

void initWebNotificationSound() {
  if (_audioInitHooked) return;
  _audioInitHooked = true;

  void unlock([html.Event? _]) {
    _ensureAudioContext();
    _resumeAudioContext();
  }

  html.window.addEventListener('pointerdown', unlock);
  html.window.addEventListener('keydown', unlock);
  html.window.addEventListener('touchstart', unlock);
}

void showWebNotification(String title, String body) {
  if (html.Notification.permission != 'granted') return;
  html.Notification(title, body: body);
}

void playWebNotificationSound() {
  try {
    _ensureAudioContext();
    if (_audioContext == null) return;
    _resumeAudioContext();

    final oscillator = js_util.callMethod(_audioContext, 'createOscillator', []);
    final gain = js_util.callMethod(_audioContext, 'createGain', []);
    final gainParam = js_util.getProperty(gain, 'gain');
    js_util.setProperty(gainParam, 'value', 0.04);
    js_util.setProperty(oscillator, 'type', 'sine');
    final frequency = js_util.getProperty(oscillator, 'frequency');
    js_util.setProperty(frequency, 'value', 880);
    js_util.callMethod(oscillator, 'connect', [gain]);
    js_util.callMethod(
      gain,
      'connect',
      [js_util.getProperty(_audioContext, 'destination')],
    );
    js_util.callMethod(oscillator, 'start', [0]);
    final currentTime = js_util.getProperty(_audioContext, 'currentTime') as num;
    js_util.callMethod(oscillator, 'stop', [currentTime + 0.2]);
  } catch (_) {
    // ignore autoplay errors
  }
}

void _ensureAudioContext() {
  if (_audioContext != null) return;
  final audioContextCtor =
      js_util.getProperty(html.window, 'AudioContext') ??
          js_util.getProperty(html.window, 'webkitAudioContext');
  if (audioContextCtor == null) return;
  _audioContext = js_util.callConstructor(audioContextCtor, []);
}

void _resumeAudioContext() {
  if (_audioContext == null) return;
  try {
    final state = js_util.getProperty(_audioContext, 'state');
    if (state == 'suspended') {
      js_util.callMethod(_audioContext, 'resume', []);
    }
  } catch (_) {
    // ignore resume errors
  }
}
