import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
    {'value': 'archived', 'label': 'مؤرشف'},
    {'value': 'closed', 'label': 'مغلق'},
  ];

  static String typeLabel(String? t) => t == 'outgoing' ? 'صادر' : 'وارد';

  static String statusLabel(String? s) {
    switch (s) {
      case 'received':
        return 'مستلم';
      case 'in_progress':
        return 'تحت الإجراء';
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
}

class ArchiveDocumentsRepository {
  static Future<List<Map<String, dynamic>>> list({
    String search = '',
    int limit = 50,
    String? documentType,
    String? status,
  }) async {
    final endpoint = Uri(
      path: ApiEndpoints.archiveDocuments,
      queryParameters: {
        'limit': '$limit',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (documentType != null && documentType.isNotEmpty)
          'documentType': documentType,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).toString();

    final response = await ApiService.get(endpoint);
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['documents'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
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
    required String documentType,
    required String status,
    required String currentHolderType,
    required ArchiveDraftFile file,
    String? subject,
    String? currentHolderName,
    String? currentDepartment,
    String? currentEmployeeName,
    String? archiveName,
    String? archiveFile,
    String? archiveShelf,
    String? notes,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.archiveDocuments}'),
    );

    final headers = Map<String, String>.from(ApiService.headers)
      ..remove('Content-Type');
    req.headers.addAll(headers);

    req.fields.addAll({
      'documentType': documentType,
      'status': status,
      'currentHolderType': currentHolderType,
      if ((subject ?? '').trim().isNotEmpty) 'subject': subject!.trim(),
      if ((currentHolderName ?? '').trim().isNotEmpty)
        'currentHolderName': currentHolderName!.trim(),
      if ((currentDepartment ?? '').trim().isNotEmpty)
        'currentDepartment': currentDepartment!.trim(),
      if ((currentEmployeeName ?? '').trim().isNotEmpty)
        'currentEmployeeName': currentEmployeeName!.trim(),
      if ((archiveName ?? '').trim().isNotEmpty) 'archiveName': archiveName!.trim(),
      if ((archiveFile ?? '').trim().isNotEmpty) 'archiveFile': archiveFile!.trim(),
      if ((archiveShelf ?? '').trim().isNotEmpty)
        'archiveShelf': archiveShelf!.trim(),
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    });

    if (file.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'document',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else if (!kIsWeb && file.path != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'document',
          file.path!,
          filename: file.name,
        ),
      );
    } else {
      throw Exception('ملف المستند غير صالح');
    }

    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    final body =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'فشل إنشاء سجل الأرشفة');
    }
    final doc = Map<String, dynamic>.from(body['document'] as Map);
    if (body['labelPayload'] is Map) {
      doc['labelPayload'] = Map<String, dynamic>.from(body['labelPayload'] as Map);
    }
    return doc;
  }
}

class ArchiveStickerPrinter {
  static Future<void> printDocument(Map<String, dynamic> d) async {
    final pld = d['labelPayload'] is Map
        ? Map<String, dynamic>.from(d['labelPayload'] as Map)
        : <String, dynamic>{};
    String val(String k) => '${pld[k] ?? d[k] ?? ''}';

    final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
    final barcodeData = (val('documentNumber').trim().isNotEmpty
            ? val('documentNumber')
            : val('serialNumber'))
        .trim();
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          8 * PdfPageFormat.cm,
          4.7 * PdfPageFormat.cm,
          marginAll: 0.2 * PdfPageFormat.cm,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: reg, bold: bold),
        build: (_) {
          pw.Widget row(String t, String v, {bool b = false}) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 0.5),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 16 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '$t:',
                        style: pw.TextStyle(
                          fontSize: 6.2,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 2),
                    pw.Expanded(
                      child: pw.Text(
                        v.isEmpty ? '-' : v,
                        textAlign: pw.TextAlign.left,
                        maxLines: 1,
                        style: pw.TextStyle(
                          fontSize: 6.2,
                          fontWeight:
                              b ? pw.FontWeight.bold : pw.FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
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
                row('النوع',
                    pld['documentTypeLabel']?.toString() ??
                        d['documentTypeLabel']?.toString() ??
                        ArchiveDocsUi.typeLabel(val('documentType')),
                    b: true),
                row('الحالة',
                    pld['statusLabel']?.toString() ??
                        d['statusLabel']?.toString() ??
                        ArchiveDocsUi.statusLabel(val('status')),
                    b: true),
                row('رقم المستند', val('documentNumber'), b: true),
                row('السريال', val('serialNumber')),
                if (barcodeData.isNotEmpty) ...[
                  pw.SizedBox(height: 0.8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 1.4,
                      vertical: 0.8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey500, width: 0.35),
                      borderRadius: pw.BorderRadius.circular(1.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: barcodeData,
                          height: 12.5 * PdfPageFormat.mm,
                          width: double.infinity,
                          drawText: false,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 0.35),
                  pw.Text(
                    'نظام نبراس | شركة البحيرة العربية للنقليات',
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 4.8),
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
