import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ArchiveDraftFile {
  final String name;
  final String? path;
  final Uint8List? bytes;

  const ArchiveDraftFile({
    required this.name,
    required this.path,
    required this.bytes,
  });
}

class ArchiveDocsUi {
  static const statusOptions = <Map<String, String>>[
    {'value': 'new', 'label': 'جديد'},
    {'value': 'received', 'label': 'مستلم'},
    {'value': 'in_progress', 'label': 'تحت الإجراء'},
    {'value': 'handover_pending', 'label': 'بانتظار الاستلام'},
    {'value': 'archived', 'label': 'مؤرشف'},
    {'value': 'closed', 'label': 'مغلق'},
  ];

  static const documentTypeOptions = <Map<String, String>>[
    {'value': 'incoming', 'label': 'وارد'},
    {'value': 'outgoing', 'label': 'صادر'},
    {'value': 'transaction', 'label': 'معاملة'},
  ];

  static const transactionClassOptions = <Map<String, String>>[
    {'value': 'internal', 'label': 'داخلية'},
    {'value': 'external', 'label': 'خارجية'},
  ];

  static String typeLabel(String? type) {
    switch (type) {
      case 'outgoing':
        return 'صادر';
      case 'transaction':
        return 'معاملة';
      default:
        return 'وارد';
    }
  }

  static String transactionClassLabel(String? transactionClass) {
    switch (transactionClass) {
      case 'external':
        return 'خارجية';
      case 'internal':
        return 'داخلية';
      default:
        return '';
    }
  }

  static String typeWithClassLabel(Map<String, dynamic> document) {
    final type = typeLabel(document['documentType']?.toString());
    final transactionClass =
        transactionClassLabel(document['transactionClass']?.toString());
    if (transactionClass.isEmpty) return type;
    return '$type • $transactionClass';
  }

  static String statusLabel(String? status) {
    switch (status) {
      case 'received':
        return 'مستلم';
      case 'in_progress':
        return 'تحت الإجراء';
      case 'handover_pending':
        return 'بانتظار الاستلام';
      case 'archived':
        return 'مؤرشف';
      case 'closed':
        return 'مغلق';
      default:
        return 'جديد';
    }
  }

  static String apiRoot() =>
      ApiEndpoints.baseUrl.replaceFirst(RegExp(r'/api$'), '');

  static String? attachmentUrl(Map<String, dynamic> attachment) {
    final path = (attachment['path'] ?? '').toString();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${apiRoot()}$path';
  }

  static bool isImageAttachment(Map<String, dynamic> attachment) {
    final mime = (attachment['mimeType'] ?? '').toString().toLowerCase();
    final name = (attachment['originalName'] ?? attachment['filename'] ?? '')
        .toString()
        .toLowerCase();
    return mime.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp');
  }

  static String dossierLabel(Map<String, dynamic> document) {
    return (document['dossierLabel'] ??
            document['dossierCode'] ??
            document['dossierName'] ??
            document['archiveFile'] ??
            '-')
        .toString();
  }
}

class ArchiveDocsLayout {
  static double screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => screenWidth(context) < 760;

  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= 760 && width < 1180;
  }

  static double maxContentWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width >= 1500) return 1480;
    if (width >= 1180) return 1180;
    return double.infinity;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = screenWidth(context);
    if (width < 760) {
      return const EdgeInsets.all(12);
    }
    if (width < 1180) {
      return const EdgeInsets.all(16);
    }
    return const EdgeInsets.all(20);
  }

  static BorderRadius cardRadius(BuildContext context) =>
      BorderRadius.circular(isPhone(context) ? 20 : 24);

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final compact = isPhone(context);
    final radius = BorderRadius.circular(compact ? 18 : 20);
    return InputDecoration(
      labelText: label,
      hintText: hint ?? hintText,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 14 : 16,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.lightGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.lightGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
      ),
    );
  }
}

class ArchiveDocumentsRepository {
  static Future<List<Map<String, dynamic>>> list({
    String search = '',
    int limit = 50,
    String? documentType,
    String? transactionClass,
    String? status,
    String? departmentName,
    String? archiveKey,
    String? dossierKey,
    String? currentHolderUserId,
  }) async {
    final endpoint = Uri(
      path: ApiEndpoints.archiveDocuments,
      queryParameters: {
        'limit': '$limit',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (documentType != null && documentType.isNotEmpty)
          'documentType': documentType,
        if (transactionClass != null && transactionClass.isNotEmpty)
          'transactionClass': transactionClass,
        if (status != null && status.isNotEmpty) 'status': status,
        if (departmentName != null && departmentName.trim().isNotEmpty)
          'departmentName': departmentName.trim(),
        if (archiveKey != null && archiveKey.trim().isNotEmpty)
          'archiveKey': archiveKey.trim(),
        if (dossierKey != null && dossierKey.trim().isNotEmpty)
          'dossierKey': dossierKey.trim(),
        if (currentHolderUserId != null && currentHolderUserId.trim().isNotEmpty)
          'currentHolderUserId': currentHolderUserId.trim(),
      },
    ).toString();

    final response = await ApiService.get(endpoint);
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['documents'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> metadata({
    String? departmentName,
    String? archiveKey,
  }) async {
    final endpoint = Uri(
      path: '${ApiEndpoints.archiveDocuments}/metadata',
      queryParameters: {
        if (departmentName != null && departmentName.trim().isNotEmpty)
          'departmentName': departmentName.trim(),
        if (archiveKey != null && archiveKey.trim().isNotEmpty)
          'archiveKey': archiveKey.trim(),
      },
    ).toString();

    final response = await ApiService.get(endpoint);
    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<User>> fetchUsers({String search = ''}) async {
    final endpoint = Uri(
      path: '/users',
      queryParameters: {
        'page': '1',
        'limit': '0',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    ).toString();

    final response = await ApiService.get(endpoint);
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final rawUsers = (data['users'] as List<dynamic>? ?? const []);
    return rawUsers
        .map((user) => User.fromJson(Map<String, dynamic>.from(user as Map)))
        .toList();
  }

  static Future<Map<String, dynamic>> getById(String id) async {
    final response = await ApiService.get(ApiEndpoints.archiveDocumentById(id));
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['document'] as Map);
  }

  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiService.patch(
      ApiEndpoints.archiveDocumentById(id),
      payload,
    );
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['document'] as Map);
  }

  static Future<Map<String, dynamic>> create({
    required ArchiveDraftFile file,
    required Map<String, String> fields,
    List<ArchiveDraftFile> extraAttachments = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.archiveDocuments}'),
    );

    final headers = Map<String, String>.from(ApiService.headers)
      ..remove('Content-Type');
    request.headers.addAll(headers);
    request.fields.addAll(
      fields.map((key, value) => MapEntry(key, value.trim())),
    );

    await _attachFile(request, 'document', file);
    for (final attachment in extraAttachments) {
      await _attachFile(request, 'attachments', attachment);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'فشل إنشاء سجل الأرشفة');
    }

    final document = Map<String, dynamic>.from(body['document'] as Map);
    if (body['labelPayload'] is Map) {
      document['labelPayload'] = Map<String, dynamic>.from(
        body['labelPayload'] as Map,
      );
    }
    return document;
  }

  static Future<Map<String, dynamic>> requestHandover(
    String id, {
    required String recipientUserId,
    String? note,
  }) async {
    final response = await ApiService.post(
      '/archive-documents/$id/handover/request',
      {
        'recipientUserId': recipientUserId,
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return data;
  }

  static Future<Map<String, dynamic>> verifyHandover(
    String id, {
    required String otp,
  }) async {
    final response = await ApiService.post(
      '/archive-documents/$id/handover/verify',
      {'otp': otp.trim()},
    );
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return data;
  }

  static Future<void> _attachFile(
    http.MultipartRequest request,
    String fieldName,
    ArchiveDraftFile file,
  ) async {
    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          file.bytes!,
          filename: file.name,
        ),
      );
      return;
    }

    if (!kIsWeb && file.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path!,
          filename: file.name,
        ),
      );
      return;
    }

    throw Exception('ملف المستند غير صالح');
  }
}

class ArchiveStickerPrinter {
  static Future<void> printDocument(Map<String, dynamic> document) async {
    final payload = document['labelPayload'] is Map
        ? Map<String, dynamic>.from(document['labelPayload'] as Map)
        : <String, dynamic>{};
    String value(String key) =>
        '${payload[key] ?? document[key] ?? ''}'.trim();

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    final barcodeData =
        (value('documentNumber').isNotEmpty
                ? value('documentNumber')
                : value('serialNumber'))
            .trim();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          8.5 * PdfPageFormat.cm,
          5.4 * PdfPageFormat.cm,
          marginAll: 0.2 * PdfPageFormat.cm,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) {
          pw.Widget row(String title, String content, {bool boldValue = false}) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 0.5),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 19 * PdfPageFormat.mm,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      '$title:',
                      style: pw.TextStyle(
                        fontSize: 6.1,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 2),
                  pw.Expanded(
                    child: pw.Text(
                      content.isEmpty ? '-' : content,
                      maxLines: 1,
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(
                        fontSize: 6.1,
                        fontWeight: boldValue
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return pw.Container(
            padding: const pw.EdgeInsets.all(3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: .7),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'استيكر أرشفة',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 1),
                row(
                  'النوع',
                  payload['documentTypeLabel']?.toString() ??
                      document['documentTypeLabel']?.toString() ??
                      ArchiveDocsUi.typeLabel(value('documentType')),
                  boldValue: true,
                ),
                if (value('transactionClass').isNotEmpty ||
                    value('transactionClassLabel').isNotEmpty)
                  row(
                    'التصنيف',
                    payload['transactionClassLabel']?.toString() ??
                        document['transactionClassLabel']?.toString() ??
                        ArchiveDocsUi.transactionClassLabel(
                          value('transactionClass'),
                        ),
                    boldValue: true,
                  ),
                row(
                  'الحالة',
                  payload['statusLabel']?.toString() ??
                      document['statusLabel']?.toString() ??
                      ArchiveDocsUi.statusLabel(value('status')),
                  boldValue: true,
                ),
                row('الرقم', value('documentNumber'), boldValue: true),
                row('الدوسيه', value('dossierLabel')),
                row('القسم', value('departmentName')),
                row('الأرشيف', value('archiveName')),
                row('المكتب', value('officeName')),
                row('الرف', value('shelfNumber')),
                if (barcodeData.isNotEmpty) ...[
                  pw.SizedBox(height: 0.8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 1.4,
                      vertical: 0.8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(
                        color: PdfColors.grey500,
                        width: 0.35,
                      ),
                      borderRadius: pw.BorderRadius.circular(1.5),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: barcodeData,
                      height: 12.5 * PdfPageFormat.mm,
                      width: double.infinity,
                      drawText: false,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}
