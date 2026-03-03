import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'marketing_models.dart';

Future<Uint8List> buildMarketingHandoverPdf(MarketingStation station) async {
  final report = station.handoverReport ?? HandoverReport.empty();
  final logoData = await rootBundle.load(AppImages.logo);
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
  final cairoRegular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
  );
  final cairoBold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
  );

  final pdf = pw.Document();
  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
    textDirection: pw.TextDirection.rtl,
    theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
  );

  final stationName =
      report.stationName.trim().isNotEmpty ? report.stationName : station.name;
  final city = report.city.trim().isNotEmpty ? report.city : station.city;
  final street =
      report.street.trim().isNotEmpty ? report.street : station.address;

  final contractText = report.contractReference.trim().isEmpty
      ? ''
      : ' حسب العقد المبرم ${_valueOrDash(report.contractReference)}';

  final paragraph = 'انه في يوم ${_valueOrDash(report.dayName)} بتاريخ '
      '${_valueOrDash(report.hijriDate)} هـ الموافق '
      '${_valueOrDash(report.gregorianDate)} تم الوقوف على محطة المحروقات '
      'المسماة بمحطة ${_valueOrDash(stationName)} مدينة ${_valueOrDash(city)} '
      'حي ${_valueOrDash(report.district)} على شارع ${_valueOrDash(street)} '
      'وتحمل ترخيص مدني تحت الرقم ${_valueOrDash(report.civilLicenseNumber)} '
      'بتاريخ ${_valueOrDash(report.civilLicenseDate)} هـ وترخيص البلدية '
      'تحت الرقم ${_valueOrDash(report.municipalityLicenseNumber)} بتاريخ '
      '${_valueOrDash(report.municipalityLicenseDate)} هـ، وذلك من قبل السيد '
      'صاحب المحطة/ ${_valueOrDash(report.ownerName)} أو من ينوب عنه '
      'بوكالة شرعية رقم ${_valueOrDash(report.authorizationNumber)}، '
      'ومندوب شركة ${_valueOrDash(report.companyName)} '
      '${_valueOrDash(report.companyRepresentativeName)}$contractText. '
      'وقد تم الاستلام والتسليم للمحطة المعنية على النحو التالي:';

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => _buildPdfHeader(report, logoImage),
      footer: (context) => context.pageNumber == context.pagesCount
          ? pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16, bottom: 12),
              child: _buildPdfFooter(),
            )
          : pw.SizedBox(),
      build: (context) => [
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            report.reportNumber.trim().isEmpty
                ? 'محضر استلام محطة محروقات'
                : 'محضر استلام محطة محروقات (${report.reportNumber})',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(paragraph, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 12),
        pw.Text('1) طرمبات الوقود:', style: _sectionStyle()),
        pw.SizedBox(height: 4),
        pw.Text(
          'يوجد بالمحطة عدد (${_valueOrDash(report.dispensersCount)}) طرمبة '
          'تموين سيارات منها (${_valueOrDash(report.doubleDispensersCount)}) مزدوج.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 4),
        _buildTable(
          headers: const [
            'نوع الطرمبة',
            'العدد',
            'قراءة العداد السري',
            'الحالة الفنية',
          ],
          rows: _ensureRows(
            report.fuelDispensers
                .map(
                  (row) => [
                    row.pumpType,
                    row.count,
                    row.meterReading,
                    row.technicalStatus,
                  ],
                )
                .toList(),
            4,
            4,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('2) الخزانات:', style: _sectionStyle()),
        pw.SizedBox(height: 4),
        _buildTable(
          headers: const [
            'رقم الخزان',
            'نوع الوقود',
            'السعة التشغيلية',
            'الحالة الفنية',
          ],
          rows: _ensureRows(
            report.fuelTanks
                .map(
                  (row) => [
                    row.tankNumber,
                    row.fuelType,
                    row.operatingCapacity,
                    row.technicalStatus,
                  ],
                )
                .toList(),
            4,
            4,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('3) الطرمبات الغاطسة:', style: _sectionStyle()),
        pw.SizedBox(height: 4),
        _buildTable(
          headers: const [
            'ماركة الغاطس',
            'عددها',
            'قوة الغاطس',
            'الحالة الفنية',
          ],
          rows: _ensureRows(
            report.submersiblePumps
                .map(
                  (row) => [
                    row.brand,
                    row.count,
                    row.power,
                    row.technicalStatus,
                  ],
                )
                .toList(),
            1,
            4,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('4) المعدات:', style: _sectionStyle()),
        pw.SizedBox(height: 4),
        _buildTable(
          headers: const [
            'نوع الجهاز',
            'العدد',
            'المواصفات',
            'الحالة الفنية',
            'الملاحظات',
          ],
          rows: _ensureRows(
            report.equipment
                .map(
                  (row) => [
                    row.equipmentType,
                    row.count,
                    row.specifications,
                    row.technicalStatus,
                    row.notes,
                  ],
                )
                .toList(),
            5,
            5,
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _buildPdfHeader(HandoverReport report, pw.MemoryImage logoImage) {
  final companyName = report.companyName.trim().isNotEmpty
      ? report.companyName
      : 'شركة البحيرة العربية للنقليات';
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey500),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                companyName,
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
        pw.Container(
          width: 80,
          height: 80,
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfFooter() {
  return pw.Column(
    children: [
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 6),
      pw.Text(
        'المنطقة الصناعية – شركة البحيرة العربية للنقليات، المملكة العربية السعودية – منطقة حائل – حائل',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'نظام نبراس | شركة البحيرة العربية',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    ],
  );
}

pw.TextStyle _sectionStyle() {
  return pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
}

String _valueOrDash(String? value) {
  if (value == null) return '........';
  final trimmed = value.trim();
  return trimmed.isEmpty ? '........' : trimmed;
}

List<List<String>> _ensureRows(
  List<List<String>> rows,
  int minRows,
  int columns,
) {
  final output = rows.map((row) {
    if (row.length >= columns) return row;
    return row + List.filled(columns - row.length, '');
  }).toList();
  while (output.length < minRows) {
    output.add(List.filled(columns, ''));
  }
  return output;
}

pw.Widget _buildTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: headers
            .map(
              (header) => pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  header,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...rows.map(
        (row) => pw.TableRow(
          children: row
              .map(
                (cell) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    cell.trim().isEmpty ? ' ' : cell,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}
