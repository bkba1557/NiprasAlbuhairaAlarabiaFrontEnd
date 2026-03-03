import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveAndLaunchFileImpl(List<int> bytes, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  await OpenFile.open(file.path);
}
