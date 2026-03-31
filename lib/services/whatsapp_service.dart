import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/services/firebase_storage_service.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppContact {
  final String id;
  final String name;
  final String phone;
  final String source;
  final String? subtitle;

  const WhatsAppContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.source,
    this.subtitle,
  });

  String get sourceLabel {
    switch (source) {
      case 'customer':
        return 'عميل';
      case 'driver':
        return 'سائق';
      case 'user':
        return 'مستخدم';
      case 'form':
        return 'العميل الحالي';
      default:
        return source;
    }
  }
}

class WhatsAppAttachmentShare {
  final String fileName;
  final String url;

  const WhatsAppAttachmentShare({
    required this.fileName,
    required this.url,
  });
}

class WhatsAppOutboundMessage {
  final String phone;
  final String text;
  final String? recipientName;

  const WhatsAppOutboundMessage({
    required this.phone,
    required this.text,
    this.recipientName,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'to': phone,
    'text': text,
    if (recipientName != null && recipientName!.trim().isNotEmpty)
      'recipientName': recipientName!.trim(),
  };
}

class WhatsAppService {
  static const String companyName = 'شركة البحيرة العربية';
  static const String systemName = 'نظام نبراس';
  static const String _defaultCountryCode = '966';

  static bool canAccessForRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    return normalized == 'owner' || normalized == 'admin';
  }

  static String? normalizePhone(String? rawPhone) {
    final digits = (rawPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    var normalized = digits;
    if (normalized.startsWith('00')) {
      normalized = normalized.substring(2);
    }
    if (normalized.startsWith(_defaultCountryCode)) {
      return normalized;
    }
    if (normalized.startsWith('0')) {
      normalized = normalized.replaceFirst(RegExp(r'^0+'), '');
      return normalized.isEmpty ? null : '$_defaultCountryCode$normalized';
    }
    if (normalized.length == 9) {
      return '$_defaultCountryCode$normalized';
    }
    if (normalized.length < 8) return null;
    return normalized;
  }

  static Uri? buildLaunchUri({
    required String phone,
    required String message,
  }) {
    final candidates = buildLaunchUris(phone: phone, message: message);
    return candidates.isEmpty ? null : candidates.first;
  }

  static List<Uri> buildLaunchUris({
    required String phone,
    required String message,
  }) {
    final normalizedPhone = normalizePhone(phone);
    if (normalizedPhone == null) return const <Uri>[];

    final encodedMessage = message.trim();
    final appUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: <String, String>{
        'phone': normalizedPhone,
        'text': encodedMessage,
      },
    );
    final webChatUri = Uri.https('web.whatsapp.com', '/send', <String, String>{
      'phone': normalizedPhone,
      'text': encodedMessage,
      'type': 'phone_number',
      'app_absent': '0',
    });
    final shortLinkUri = Uri.https('wa.me', '/$normalizedPhone', <String, String>{
      'text': encodedMessage,
    });

    if (kIsWeb) {
      return <Uri>[webChatUri, shortLinkUri];
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return <Uri>[appUri, shortLinkUri];
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return <Uri>[appUri, webChatUri, shortLinkUri];
      case TargetPlatform.fuchsia:
        return <Uri>[shortLinkUri];
    }
  }

  static Future<bool> launchMessage({
    required String phone,
    required String message,
  }) async {
    final uris = buildLaunchUris(phone: phone, message: message);
    if (uris.isEmpty) return false;

    for (final uri in uris) {
      final mode = uri.scheme == 'whatsapp'
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault;
      try {
        final launched = await launchUrl(
          uri,
          mode: mode,
          webOnlyWindowName: '_blank',
        );
        if (launched) {
          return true;
        }
      } catch (_) {
        // Try the next available WhatsApp launch strategy.
      }
    }

    return false;
  }

  static Future<Map<String, dynamic>> sendDirectMessages({
    required List<WhatsAppOutboundMessage> messages,
  }) async {
    final filteredMessages = messages
        .where(
          (message) =>
              normalizePhone(message.phone) != null &&
              message.text.trim().isNotEmpty,
        )
        .map((message) => message.toJson())
        .toList();

    if (filteredMessages.isEmpty) {
      throw Exception('لا توجد رسائل صالحة للإرسال');
    }

    final response = await ApiService.post('/whatsapp/send', <String, dynamic>{
      'messages': filteredMessages,
    });

    return json.decode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sendDirectMessage({
    required String phone,
    required String message,
    String? recipientName,
  }) {
    return sendDirectMessages(
      messages: <WhatsAppOutboundMessage>[
        WhatsAppOutboundMessage(
          phone: phone,
          text: message,
          recipientName: recipientName,
        ),
      ],
    );
  }

  static String buildBrandedMessage({
    required String body,
    String? recipientName,
    List<WhatsAppAttachmentShare> attachments = const [],
  }) {
    final buffer = StringBuffer()
      ..writeln(companyName)
      ..writeln(systemName);

    final trimmedRecipient = recipientName?.trim() ?? '';
    if (trimmedRecipient.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('عناية: $trimmedRecipient');
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(trimmedBody);
    }

    if (attachments.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('روابط المرفقات:');
      for (final attachment in attachments) {
        buffer.writeln('- ${attachment.fileName}: ${attachment.url}');
      }
    }

    return buffer.toString().trim();
  }

  static String buildWelcomeMessage({
    required String customerName,
  }) {
    return buildBrandedMessage(
      recipientName: customerName,
      body: 'تم إنشاء ملف خاص بكم في نظام نبراس، ويسعدنا خدمتكم عبر شركة البحيرة العربية.',
    );
  }

  static Future<List<WhatsAppAttachmentShare>> uploadAttachments({
    required String folderKey,
    required List<PlatformFile> files,
  }) async {
    final uploaded = <WhatsAppAttachmentShare>[];
    for (final file in files) {
      final result = await FirebaseStorageService.uploadWhatsappAttachment(
        folderKey: folderKey,
        file: file,
      );
      uploaded.add(
        WhatsAppAttachmentShare(
          fileName: result['filename']?.toString() ?? file.name,
          url: result['url']?.toString() ?? '',
        ),
      );
    }
    return uploaded.where((item) => item.url.trim().isNotEmpty).toList();
  }

  static Future<List<WhatsAppContact>> fetchAvailableContacts() async {
    final contacts = <WhatsAppContact>[];
    final seenPhones = <String>{};

    void addContact({
      required String id,
      required String name,
      required String phone,
      required String source,
      String? subtitle,
    }) {
      final normalizedPhone = normalizePhone(phone);
      if (normalizedPhone == null) return;
      final cleanName = name.trim();
      if (cleanName.isEmpty) return;
      if (!seenPhones.add(normalizedPhone)) return;
      contacts.add(
        WhatsAppContact(
          id: id,
          name: cleanName,
          phone: phone.trim(),
          source: source,
          subtitle: subtitle?.trim().isEmpty == true ? null : subtitle?.trim(),
        ),
      );
    }

    await Future.wait<void>([
      _fetchUsers(addContact),
      _fetchCustomers(addContact),
      _fetchDrivers(addContact),
    ]);

    contacts.sort((a, b) => a.name.compareTo(b.name));
    return contacts;
  }

  static Future<void> _fetchUsers(
    void Function({
      required String id,
      required String name,
      required String phone,
      required String source,
      String? subtitle,
    })
    addContact,
  ) async {
    try {
      final response = await ApiService.get('/users?page=1&limit=0');
      final data = json.decode(utf8.decode(response.bodyBytes));
      final rawUsers = data is Map<String, dynamic> ? data['users'] : null;
      if (rawUsers is! List) return;
      for (final rawUser in rawUsers.whereType<Map<String, dynamic>>()) {
        addContact(
          id: rawUser['id']?.toString() ?? '',
          name: rawUser['name']?.toString() ?? '',
          phone: rawUser['phone']?.toString() ?? '',
          source: 'user',
          subtitle: rawUser['role']?.toString(),
        );
      }
    } catch (_) {}
  }

  static Future<void> _fetchCustomers(
    void Function({
      required String id,
      required String name,
      required String phone,
      required String source,
      String? subtitle,
    })
    addContact,
  ) async {
    try {
      var page = 1;
      var totalPages = 1;

      do {
        final response = await http.get(
          Uri.parse('${ApiEndpoints.baseUrl}/customers?page=$page&limit=100'),
          headers: ApiService.headers,
        );
        if (response.statusCode != 200) return;

        final data = json.decode(utf8.decode(response.bodyBytes));
        final rawCustomers =
            data is Map<String, dynamic> ? data['customers'] : null;
        if (rawCustomers is List) {
          for (final rawCustomer in rawCustomers.whereType<Map<String, dynamic>>()) {
            final customerId =
                (rawCustomer['_id'] ?? rawCustomer['id'] ?? '').toString();
            final customerName = rawCustomer['name']?.toString() ?? '';
            final company = rawCustomer['company']?.toString();

            addContact(
              id: customerId,
              name: customerName,
              phone: rawCustomer['phone']?.toString() ?? '',
              source: 'customer',
              subtitle: company,
            );

            addContact(
              id: '$customerId-contact',
              name: rawCustomer['contactPerson']?.toString().trim().isNotEmpty ==
                      true
                  ? rawCustomer['contactPerson']!.toString()
                  : customerName,
              phone: rawCustomer['contactPersonPhone']?.toString() ?? '',
              source: 'customer',
              subtitle: 'هاتف المسؤول',
            );
          }
        }

        final pagination =
            data is Map<String, dynamic> ? data['pagination'] : null;
        if (pagination is Map<String, dynamic>) {
          totalPages = pagination['pages'] is int
              ? pagination['pages'] as int
              : int.tryParse(pagination['pages']?.toString() ?? '') ?? page;
        } else {
          totalPages = page;
        }
        page += 1;
      } while (page <= totalPages);
    } catch (_) {}
  }

  static Future<void> _fetchDrivers(
    void Function({
      required String id,
      required String name,
      required String phone,
      required String source,
      String? subtitle,
    })
    addContact,
  ) async {
    try {
      var page = 1;
      var totalPages = 1;

      do {
        final response = await http.get(
          Uri.parse('${ApiEndpoints.baseUrl}/drivers?page=$page&limit=100'),
          headers: ApiService.headers,
        );
        if (response.statusCode != 200) return;

        final data = json.decode(utf8.decode(response.bodyBytes));
        final rawDrivers = data is Map<String, dynamic> ? data['drivers'] : null;
        if (rawDrivers is List) {
          for (final rawDriver in rawDrivers.whereType<Map<String, dynamic>>()) {
            addContact(
              id: (rawDriver['_id'] ?? rawDriver['id'] ?? '').toString(),
              name: rawDriver['name']?.toString() ?? '',
              phone: rawDriver['phone']?.toString() ?? '',
              source: 'driver',
              subtitle: rawDriver['licenseNumber']?.toString(),
            );
          }
        }

        final pagination =
            data is Map<String, dynamic> ? data['pagination'] : null;
        if (pagination is Map<String, dynamic>) {
          totalPages = pagination['pages'] is int
              ? pagination['pages'] as int
              : int.tryParse(pagination['pages']?.toString() ?? '') ?? page;
        } else {
          totalPages = page;
        }
        page += 1;
      } while (page <= totalPages);
    } catch (_) {}
  }
}
