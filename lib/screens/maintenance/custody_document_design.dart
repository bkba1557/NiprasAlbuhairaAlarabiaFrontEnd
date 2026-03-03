import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/custody_document_model.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _watermarkText(CustodyDocumentStatus status) {
  switch (status) {
    case CustodyDocumentStatus.pending:
      return 'قيد المراجعة';
    case CustodyDocumentStatus.approved:
      return 'مقبول';
    case CustodyDocumentStatus.rejected:
      return 'مرفوض';
  }
}


class CustodyDocumentPreview extends StatelessWidget {
  final CustodyDocument document;

  const CustodyDocumentPreview({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final watermarkText = _watermarkText(document.status);
    return Stack(
      alignment: Alignment.center,
      children: [
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                _buildTable(context),
                if (document.reason.isNotEmpty) const SizedBox(height: 12),
                if (document.reason.isNotEmpty)
                  _buildReasonView(context, isWide: isWide),
                if (document.notes.isNotEmpty) const SizedBox(height: 12),
                if (document.notes.isNotEmpty)
                  _buildNotesView(context, isWide: isWide),
                const SizedBox(height: 12),
                _buildFooter(context),
              ],
            ),
          ),
        ),
        if (watermarkText != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _buildPreviewWatermark(watermarkText),
            ),
          ),
      ],
    );
  }

Widget _buildHeader(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(document.documentDate);
    final amountStr = NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    ).format(document.amount);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ الشعار (يسار)
          Image.asset(
            AppImages.logo,
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),

          const SizedBox(width: 12),

          // ✅ بيانات السند (يمين)
          Expanded(
            child: Table(
              defaultColumnWidth: const FlexColumnWidth(),
              border: TableBorder.all(color: Colors.transparent),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _buildHeaderRow(
                  'شركة البحيرة العربية للنقليات',
                  '',
                  isBold: true,
                ),
                _buildHeaderRow('الرقم الوطني الموحد', '7011144750'),
                _buildHeaderRow(
                  'عنوان السند',
                  document.documentTitle,
                  isBold: true,
                ),
                _buildHeaderRow('رقم السند', document.documentNumber),
                _buildHeaderRow(
                  'الجهة / المستلم',
                  '${document.destinationType} - ${document.destinationName}',
                ),
                _buildHeaderRow('التاريخ', dateStr),
                _buildHeaderRow('المبلغ', amountStr),
                _buildHeaderRow(
                  'حالة الصرف',
                  document.financeStatus.displayTitle,
                ),
                if (document.financeStatus == CustodyFinanceStatus.rejected &&
                    document.financeRejectReason?.trim().isNotEmpty == true)
                  _buildHeaderRow(
                    'سبب رفض الصرف',
                    document.financeRejectReason ?? '',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  TableRow _buildHeaderRow(String label, String value, {bool isBold = false}) {
    final labelStyle = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
      fontSize: 12,
    );
    final valueStyle = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: 12,
      color: Colors.grey.shade800,
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: labelStyle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.left,
            style: valueStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    final rows = document.rows;
    if (rows.isEmpty) {
      return const SizedBox();
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: index.isEven ? Colors.grey.shade50 : null,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: index == rows.length - 1 ? 0 : 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    row.value.isEmpty ? '-' : row.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReasonView(BuildContext context, {required bool isWide}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'سبب التعميد: ${document.reason}',
            style: TextStyle(
              fontSize: isWide ? 14 : 12,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesView(BuildContext context, {required bool isWide}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'ملاحظات: ${document.notes}',
        style: TextStyle(
          fontSize: isWide ? 14 : 12,
          color: Colors.grey.shade800,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSignatureBlock(
              title: 'المدير العام',
              name: 'حمادة الرشيدى - Hamada Rashidy',
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'مسؤول الصيانة',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    document.custodianName.isNotEmpty
                        ? document.custodianName
                        : 'مسؤول الصيانة',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade500),
                    ),
                    child: const Text(
                      'معتمد منه',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSignatureBlock(
              title: 'رئيس مجلس الإدارة',
              name: 'ناصر المطيرى - Nasser Khaled',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'المنطقة الصناعية – شركة البحيرة العربية للنقليات, المملكة العربية السعودية – منطقة حائل – حائل',
          style: TextStyle(fontSize: 9),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          '"Industrial Area – Al Buhaira Al Arabia Transport Company, Kingdom of Saudi Arabia – Hail Region – Hail."',
          style: TextStyle(fontSize: 9),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'جوال: 0535550130   |   البريد الإلكتروني: n.n.66@hotmail.com',
          style: TextStyle(fontSize: 8),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'نظام نبراس | شركة البحيرة العربية ',
          style: TextStyle(fontSize: 8),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPreviewWatermark(String text) {
    return Center(
      child: Transform.rotate(
        angle: -0.2,
        child: Opacity(
          opacity: 0.18,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 110,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureBlock({required String title, required String name}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 8),
          Container(width: 90, height: 1, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}

Future<Uint8List> buildCustodyDocumentPdf(CustodyDocument document) async {
  final logoData = await rootBundle.load(AppImages.logo);
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

  final cairoRegular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
  );
  final cairoBold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
  );

  final pdf = pw.Document();
  final watermarkText = _watermarkText(document.status);
  final basePageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
    textDirection: pw.TextDirection.rtl,
    theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
  );

  final pageTheme = watermarkText == null
      ? basePageTheme
      : basePageTheme.copyWith(
          buildBackground: (context) =>
              _buildPdfWatermarkBackground(watermarkText),
        );

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,

      // ================= CONTENT =================
      build: (context) {
        final content = <pw.Widget>[
          _buildPdfHeader(document, logoImage),
          _buildPdfDocumentInfo(document),

          pw.SizedBox(height: 8),
          _buildPdfTable(document),

          if (document.reason.isNotEmpty) pw.SizedBox(height: 6),
          if (document.reason.isNotEmpty)
            _buildPdfInfoBox('سبب التعميد', document.reason),

          if (document.notes.isNotEmpty) pw.SizedBox(height: 6),
          if (document.notes.isNotEmpty)
            _buildPdfInfoBox('ملاحظات', document.notes),
        ];

        return content;
      },

      // ================= FOOTER (ثابت) =================
      footer: (context) =>
          context.pageNumber == context.pagesCount
              ? pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 16, bottom: 20),
                  child: pw.Container(
                    alignment: pw.Alignment.bottomCenter,
                    child: _buildPdfFooter(document),
                  ),
                )
              : pw.SizedBox(),
      ),
    );

  return pdf.save();
}

pw.Widget _buildPdfInfoBox(String title, String value) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text('$title: $value', style: const pw.TextStyle(fontSize: 11)),
  );
}




pw.Widget _buildPdfHeader(CustodyDocument document, pw.MemoryImage logoImage) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey500),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ===== بيانات الشركة (يمين) =====
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'شركة البحيرة العربية للنقليات',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'الرقم الوطني الموحد: 7011144750',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 16),

        // ===== الشعار (يسار – بدون Box) =====
        pw.Container(
          width: 80,
          height: 80,
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfDocumentInfo(CustodyDocument document) {
  final amountStr = NumberFormat.currency(
    symbol: 'ر.س',
    decimalDigits: 2,
  ).format(document.amount);
  final timeStr = DateFormat('HH:mm').format(DateTime.now());
  pw.Widget cell(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value.isEmpty ? '-' : value,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  final items = <Map<String, String>>[
    {'label': 'عنوان السند', 'value': document.documentTitle},
    {'label': 'رقم السند', 'value': document.documentNumber},
    {
      'label': 'الجهة / المستلم',
      'value': '${document.destinationType} - ${document.destinationName}',
    },
    if (document.vehicleNumber.trim().isNotEmpty)
      {'label': 'رقم السيارة', 'value': document.vehicleNumber},
    {
      'label': 'التاريخ',
      'value': DateFormat('yyyy-MM-dd').format(document.documentDate),
    },
    {'label': 'الوقت', 'value': timeStr},
    {'label': 'المبلغ', 'value': amountStr},
    {'label': 'حالة الصرف', 'value': document.financeStatus.displayTitle},
    {'label': 'أنشئ بواسطة', 'value': document.createdBy},
  ];

  if (document.financeStatus == CustodyFinanceStatus.rejected &&
      document.financeRejectReason?.trim().isNotEmpty == true) {
    items.add({
      'label': 'سبب رفض الصرف',
      'value': document.financeRejectReason ?? '',
    });
  }

  final rows = <List<Map<String, String>>>[];
  for (var i = 0; i < items.length; i += 3) {
    rows.add([
      items[i],
      if (i + 1 < items.length) items[i + 1] else {'label': '', 'value': ''},
      if (i + 2 < items.length) items[i + 2] else {'label': '', 'value': ''},
    ]);
  }

  if (document.financeStatus == CustodyFinanceStatus.rejected &&
      document.financeRejectReason?.trim().isNotEmpty == true) {
    items.add({
      'label': 'سبب رفض الصرف',
      'value': document.financeRejectReason ?? '',
    });
  }

  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      children: rows.map((triple) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(child: cell(triple[0]['label']!, triple[0]['value']!)),
              pw.Container(width: 0.5, height: 28, color: PdfColors.grey300),
              pw.Expanded(child: cell(triple[1]['label']!, triple[1]['value']!)),
              pw.Container(width: 0.5, height: 28, color: PdfColors.grey300),
              pw.Expanded(child: cell(triple[2]['label']!, triple[2]['value']!)),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

pw.TableRow _pdfHeaderRow(
  String value,
  String label, {
  bool bold = false,
  bool isTitle = false,
}) {
  return pw.TableRow(
    children: [
      // ===== البيانات (يسار) =====
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: isTitle ? 12 : 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),

      // ===== العنوان (يمين) =====
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: isTitle ? 12 : 10,
            fontWeight: isTitle || bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      ),
    ],
  );
}



pw.Widget _buildPdfTable(CustodyDocument document) {
  final amountStr = NumberFormat.currency(
    symbol: 'ر.س',
    decimalDigits: 2,
  ).format(document.amount);

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400),
    columnWidths: const {
      0: pw.FlexColumnWidth(1), // المبلغ
      1: pw.FlexColumnWidth(2), // تفاصيل الصيانة
    },
    children: [
      // ===== رأس الجدول =====
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: pw.Text(
              'المبلغ',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: pw.Text(
              'تفاصيل الصيانة',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
        ],
      ),

      // ===== الصفوف =====
      ...document.rows.map(
        (row) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: pw.Text(
                row.value.isEmpty ? '-' : row.value,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: pw.Text(
                row.label,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
      ),

      // ===== الإجمالي =====
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: pw.Text(
              amountStr,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: pw.Text(
              'الإجمالي',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildPdfFooter(CustodyDocument document) {
  return pw.Column(
    children: [
      pw.Divider(),
      pw.SizedBox(height: 8),

      // ===== التوقيعات =====
      pw.Row(
        children: [
          _buildPdfSignatureBlock(title: 'المدير العام', name: 'حمادة الرشيدى'),
          _buildPdfSignatureBlock(
            title: 'مسؤول الصيانة',
            name: document.custodianName,
          ),
          _buildPdfSignatureBlock(
            title: 'رئيس مجلس الإدارة',
            name: 'ناصر المطيرى',
          ),
        ],
      ),

      pw.SizedBox(height: 10),

      // ===== عنوان الشركة =====
      pw.Text(
        'شركة البحيرة العربية للنقليات',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'نظام نبراس لإدارة السندات',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ],
  );
}



pw.Widget _buildPdfDetailRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text(value.isEmpty ? '-' : value, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}


pw.Widget _buildPdfSignatureBlock({
  required String title,
  required String name,
}) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          name,
          style: const pw.TextStyle(fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Container(width: 90, height: 1, color: PdfColors.grey700),
      ],
    ),
  );
}


pw.TableRow _buildPdfHeaderRow(
  String label,
  String value, {
  bool isBold = false,
  bool isHeader = false,
}) {
  final labelStyle = pw.TextStyle(
    fontSize: isHeader ? 12 : 11,
    fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  final valueStyle = pw.TextStyle(
    fontSize: 11,
    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.right,
          style: labelStyle,
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(
          value.isEmpty ? '-' : value,
          textAlign: pw.TextAlign.left,
          style: valueStyle,
        ),
      ),
    ],
  );
}

pw.Widget _buildPdfWatermarkBackground(String text) {
  return pw.Center(
    child: pw.Transform.rotate(
      angle: -0.35,
      child: pw.Opacity(
        opacity: 0.12,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 110,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey300,
          ),
        ),
      ),
    ),
  );
}


Future<void> printCustodyDocument(CustodyDocument document) async {
  final bytes = await buildCustodyDocumentPdf(document);
  await Printing.layoutPdf(onLayout: (_) => bytes);
}

Future<void> saveCustodyDocumentPdf(CustodyDocument document) async {
  final bytes = await buildCustodyDocumentPdf(document);
  final fileName = 'سند_عهده_${document.documentNumber}.pdf';
  await saveAndLaunchFile(bytes, fileName);
}
