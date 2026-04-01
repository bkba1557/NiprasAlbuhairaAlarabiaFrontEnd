import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveBytesAsFileImpl(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  await Future.delayed(const Duration(milliseconds: 150));
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);

  return filename;
}

