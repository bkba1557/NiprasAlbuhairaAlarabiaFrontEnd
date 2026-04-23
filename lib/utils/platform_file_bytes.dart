import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'platform_file_bytes_stub.dart'
    if (dart.library.io) 'platform_file_bytes_io.dart'
    if (dart.library.html) 'platform_file_bytes_web.dart';

Future<Uint8List?> readPlatformFileBytes(PlatformFile file) =>
    readPlatformFileBytesImpl(file);

