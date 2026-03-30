import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/extract_pdf_text.dart <pdf-path>');
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final bytes = file.readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  try {
    final text = PdfTextExtractor(document).extractText();
    stdout.write(text);
  } finally {
    document.dispose();
  }
}
