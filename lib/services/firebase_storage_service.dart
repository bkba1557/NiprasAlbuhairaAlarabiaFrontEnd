import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      final safeName = fileName.replaceAll(RegExp(r'\s+'), '_');
      final ref = _storage.ref(
        'employees/$employeeKey/documents/${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );

      UploadTask uploadTask;

      if (kIsWeb) {
        if (webBytes == null) {
          throw Exception('Web file bytes are null');
        }
        uploadTask = ref.putData(
          webBytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        if (filePath == null) {
          throw Exception('File path is null');
        }
        uploadTask = ref.putFile(
          File(filePath),
          SettableMetadata(contentType: contentType),
        );
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('❌ Firebase upload error: $e');
      rethrow;
    }
  }

  static Future<String> uploadSessionImage({
    required String sessionId,
    required String type, // opening | closing
    required String nozzleId,
    Uint8List? webBytes, // 👈 للويب
    String? filePath, // 👈 للموبايل
  }) async {
    try {
      final ref = _storage.ref(
        'sessions/$sessionId/$type/$nozzleId${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      UploadTask uploadTask;

      if (kIsWeb) {
        // 🌐 WEB
        if (webBytes == null) {
          throw Exception('Web image bytes are null');
        }
        uploadTask = ref.putData(
          webBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // 📱 MOBILE
        if (filePath == null) {
          throw Exception('File path is null');
        }
        uploadTask = ref.putFile(
          File(filePath),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('❌ Firebase upload error: $e');
      rethrow;
    }
  }
}
