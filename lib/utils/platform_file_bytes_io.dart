import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> readPlatformFileBytesImpl(PlatformFile file) async {
  if (file.bytes != null) return file.bytes;
  final path = file.path;
  if (path == null || path.trim().isEmpty) return null;
  final data = await File(path).readAsBytes();
  return Uint8List.fromList(data);
}

