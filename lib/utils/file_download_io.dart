import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> saveBytesAsFileImpl(Uint8List bytes, String filename) async {
  String? directoryPath;

  try {
    directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
    );
  } catch (_) {
    directoryPath = null;
  }

  Directory? directory;
  if (directoryPath != null && directoryPath.trim().isNotEmpty) {
    directory = Directory(directoryPath);
  } else {
    directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
  }

  final outputPath = _resolveUniquePath(directory.path, filename);
  final file = File(outputPath);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return outputPath;
}

String _resolveUniquePath(String directoryPath, String filename) {
  final extension = p.extension(filename);
  final baseName = p.basenameWithoutExtension(filename);

  var candidate = p.join(directoryPath, filename);
  var counter = 1;

  while (File(candidate).existsSync()) {
    candidate = p.join(directoryPath, '${baseName}_$counter$extension');
    counter += 1;
  }

  return candidate;
}

