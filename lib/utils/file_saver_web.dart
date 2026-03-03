import 'dart:async';
import 'dart:html' as html;

Future<void> saveAndLaunchFileImpl(List<int> bytes, String filename) async {
  final blob = html.Blob([bytes], _contentTypeFor(filename));
  final url = html.Url.createObjectUrlFromBlob(blob);
  final lower = filename.toLowerCase();
  final isPdf = lower.endsWith('.pdf');

  if (isPdf) {
    html.window.open(url, '_blank');
    await Future.delayed(const Duration(milliseconds: 400));
    html.Url.revokeObjectUrl(url);
    return;
  }

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  await Future.delayed(const Duration(milliseconds: 120));
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}

String _contentTypeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.xls')) {
    return 'application/vnd.ms-excel';
  }
  if (lower.endsWith('.pdf')) {
    return 'application/pdf';
  }
  return 'application/octet-stream';
}
