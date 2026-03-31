import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String> uploadEmployeeDocument({
    required String employeeKey,
    required String fileName,
    Uint8List? webBytes,
    String? filePath,
    String? contentType,
  }) async {
    try {
      final safeName = _sanitizeFileName(fileName);
      final ref = _storage.ref(
        'employees/$employeeKey/documents/${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );

      if (kIsWeb) {
        if (webBytes == null) {
          throw Exception('Web file bytes are null');
        }
        await ref.putData(webBytes, SettableMetadata(contentType: contentType));
      } else {
        if (filePath == null) {
          throw Exception('File path is null');
        }
        await ref.putFile(
          File(filePath),
          SettableMetadata(contentType: contentType),
        );
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<String> uploadSessionImage({
    required String sessionId,
    required String type,
    required String nozzleId,
    Uint8List? webBytes,
    String? filePath,
  }) async {
    try {
      final ref = _storage.ref(
        'sessions/$sessionId/$type/$nozzleId${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (kIsWeb) {
        if (webBytes == null) {
          throw Exception('Web image bytes are null');
        }
        await ref.putData(
          webBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        if (filePath == null) {
          throw Exception('File path is null');
        }
        await ref.putFile(
          File(filePath),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadStationMaintenanceMedia({
    required String requestId,
    required String section,
    required XFile file,
  }) async {
    final safeName = _sanitizeFileName(file.name);
    final contentType = _inferContentType(safeName);
    final ref = _storage.ref(
      'station-maintenance/$requestId/$section/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    try {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: contentType));
      } else {
        await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
      }

      return {
        'filename': safeName,
        'path': await ref.getDownloadURL(),
        'fileType': contentType,
      };
    } catch (e) {
      debugPrint('Station maintenance Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadStationMaintenanceDocument({
    required String requestId,
    required String section,
    required PlatformFile file,
  }) async {
    final safeName = _sanitizeFileName(file.name);
    final contentType = _inferContentType(safeName);
    final ref = _storage.ref(
      'station-maintenance/$requestId/$section/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    try {
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('Web file bytes are null');
        }
        await ref.putData(
          file.bytes!,
          SettableMetadata(contentType: contentType),
        );
      } else {
        final filePath = file.path;
        if (filePath == null || filePath.isEmpty) {
          throw Exception('File path is null');
        }
        await ref.putFile(
          File(filePath),
          SettableMetadata(contentType: contentType),
        );
      }

      return {
        'filename': safeName,
        'path': await ref.getDownloadURL(),
        'fileType': contentType,
      };
    } catch (e) {
      debugPrint('Station maintenance Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadOrderAttachment({
    required String orderKey,
    required PlatformFile file,
  }) async {
    final safeName = _sanitizeFileName(file.name);
    final contentType = _inferContentType(safeName);
    final ref = _storage.ref(
      'orders/$orderKey/attachments/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    try {
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('Web file bytes are null');
        }
        await ref.putData(
          file.bytes!,
          SettableMetadata(contentType: contentType),
        );
      } else {
        final filePath = file.path;
        if (filePath == null || filePath.isEmpty) {
          throw Exception('File path is null');
        }
        await ref.putFile(
          File(filePath),
          SettableMetadata(contentType: contentType),
        );
      }

      return {
        'filename': safeName,
        'path': await ref.getDownloadURL(),
        'fileType': contentType,
      };
    } catch (e) {
      debugPrint('Order Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadCustomerDocument({
    required String customerKey,
    required String docType,
    required PlatformFile file,
  }) async {
    final safeName = _sanitizeFileName(file.name);
    final contentType = _inferContentType(safeName);
    final ref = _storage.ref(
      'customers/$customerKey/$docType/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    try {
      await _uploadPlatformFile(
        ref: ref,
        file: file,
        contentType: contentType,
      );

      return {
        'filename': safeName,
        'url': await ref.getDownloadURL(),
        'storagePath': ref.fullPath,
        'fileType': contentType,
      };
    } catch (e) {
      debugPrint('Customer Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadWhatsappAttachment({
    required String folderKey,
    required PlatformFile file,
  }) async {
    final safeName = _sanitizeFileName(file.name);
    final contentType = _inferContentType(safeName);
    final ref = _storage.ref(
      'whatsapp/$folderKey/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    try {
      await _uploadPlatformFile(
        ref: ref,
        file: file,
        contentType: contentType,
      );

      return {
        'filename': safeName,
        'url': await ref.getDownloadURL(),
        'storagePath': ref.fullPath,
        'fileType': contentType,
      };
    } catch (e) {
      debugPrint('WhatsApp Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<void> _uploadPlatformFile({
    required Reference ref,
    required PlatformFile file,
    String? contentType,
  }) async {
    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('Web file bytes are null');
      }
      await ref.putData(file.bytes!, SettableMetadata(contentType: contentType));
      return;
    }

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      if (file.bytes == null) {
        throw Exception('File path is null');
      }
      await ref.putData(file.bytes!, SettableMetadata(contentType: contentType));
      return;
    }

    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: contentType),
    );
  }

  static String _sanitizeFileName(String fileName) {
    final collapsed = fileName.trim().replaceAll(RegExp(r'\s+'), '_');
    return collapsed.isEmpty ? 'file' : collapsed;
  }

  static String? _inferContentType(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.zip':
        return 'application/zip';
      case '.txt':
        return 'text/plain';
      default:
        return null;
    }
  }
}
