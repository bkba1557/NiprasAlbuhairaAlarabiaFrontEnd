// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

Future<Uint8List?> readBytesFromUrl(String url) async {
  try {
    final request = await html.HttpRequest.request(
      url,
      responseType: 'arraybuffer',
    );
    final response = request.response;
    if (response is ByteBuffer) {
      return response.asUint8List();
    }
    if (response is Uint8List) {
      return response;
    }
  } catch (_) {}
  return null;
}

void revokeObjectUrl(String url) {
  html.Url.revokeObjectUrl(url);
}

bool isGoogleMapsReady() {
  final google = js_util.getProperty(js_util.globalThis, 'google');
  return google != null && js_util.hasProperty(google, 'maps');
}

Future<void> downloadUrl(String url, {String? filename}) async {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute(
      'download',
      filename ?? '',
    )
    ..setAttribute('target', '_blank')
    ..click();
}

void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}
