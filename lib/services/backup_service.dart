import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/utils/api_config.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/file_download.dart';

class BackupService {
  static Future<String?> downloadLatestBackup({
    bool fresh = false,
  }) async {
    final endpoint = fresh ? '/backup/export?fresh=1' : '/backup/export';
    final response = await ApiService.download(endpoint);

    final filename =
        _filenameFromHeaders(response.headers) ?? _fallbackFilename();

    return saveBytesAsFile(
      Uint8List.fromList(response.bodyBytes),
      filename,
    );
  }

  static Future<Map<String, dynamic>> restoreFromBackup({
    required PlatformFile file,
    bool dropExisting = true,
  }) async {
    await ApiService.loadToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/backup/import?drop=${dropExisting ? '1' : '0'}',
    );

    final request = http.MultipartRequest('POST', uri);

    final headers = Map<String, String>.from(ApiService.headers);
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    if (kIsWeb || file.bytes != null) {
      final bytes = file.bytes ?? Uint8List(0);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );
    } else if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    } else {
      throw Exception('تعذر قراءة ملف النسخة الاحتياطية');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = ApiService.decodeJson(response);
      if (decoded is Map<String, dynamic>) return decoded;
      return Map<String, dynamic>.from(decoded as Map);
    }

    final message = _tryExtractErrorMessage(response.bodyBytes) ??
        'فشل استيراد النسخة الاحتياطية (HTTP ${response.statusCode})';
    throw Exception(message);
  }

  static String? _filenameFromHeaders(Map<String, String> headers) {
    final raw = headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'content-disposition',
          orElse: () => const MapEntry('', ''),
        )
        .value;

    if (raw.isEmpty) return null;

    final match = RegExp(r"filename\\*=UTF-8''([^;]+)").firstMatch(raw) ??
        RegExp(r'filename="?([^";]+)"?').firstMatch(raw);

    if (match == null) return null;
    return Uri.decodeFull(match.group(1) ?? '').trim();
  }

  static String _fallbackFilename() {
    final now = DateTime.now();
    final timestamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return 'order-track-backup-$timestamp.ndjson.gz';
  }

  static String? _tryExtractErrorMessage(List<int> bodyBytes) {
    final text = utf8.decode(bodyBytes, allowMalformed: true).trim();
    if (text.isEmpty) return null;

    try {
      final decoded = json.decode(text);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } catch (_) {
      // ignore
    }

    if (text.length <= 300) return text;
    return '${text.substring(0, 300)}...';
  }
}
