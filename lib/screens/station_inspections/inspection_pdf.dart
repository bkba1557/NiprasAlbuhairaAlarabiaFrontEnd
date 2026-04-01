import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'inspection_models.dart';

Future<Uint8List> buildInspectionPdf(StationInspection inspection) async {
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

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => _buildPdfHeader(logoImage),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: _buildPdfFooter(),
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'تقرير تفتيش محطة',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 12),
        _buildInfoSection('بيانات المحطة', [
          _infoRow('اسم المحطة', inspection.name),
          _infoRow('المدينة', inspection.city),
          _infoRow('المنطقة', inspection.region),
          _infoRow('العنوان', inspection.address),
          _infoRow('الحالة', _statusLabel(inspection.status)),
          if (inspection.location != null)
            _infoRow(
              'الإحداثيات',
              '${inspection.location!.lat.toStringAsFixed(6)}, ${inspection.location!.lng.toStringAsFixed(6)}',
            ),
        ]),
        pw.SizedBox(height: 10),
        _buildInfoSection('بيانات المالك', [
          _infoRow('اسم المالك', inspection.owner?.name ?? '-'),
          _infoRow('رقم الجوال', inspection.owner?.phone ?? '-'),
          _infoRow('عنوان المالك', inspection.owner?.address ?? '-'),
        ]),
        pw.SizedBox(height: 10),
        _buildPumpsSection(inspection),
        pw.SizedBox(height: 10),
        _buildFuelSummarySection(inspection),
        pw.SizedBox(height: 10),
        _buildInfoSection('ملاحظات', [
          pw.Text(
            inspection.notes?.isNotEmpty == true ? inspection.notes! : '-',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ]),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _buildPdfHeader(pw.MemoryImage logoImage) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
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
                'نظام نبراس لإدارة وتتبع الطلبات',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'تقرير تفتيش محطة الوقود',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 70,
          height: 70,
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
      pw.SizedBox(height: 4),
      pw.Text(
        'شركة البحيرة العربية | نظام نبراس',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    ],
  );
}

pw.Widget _buildInfoSection(String title, List<pw.Widget> children) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

pw.Widget _infoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    ),
  );
}

pw.Widget _buildPumpsSection(StationInspection inspection) {
  final rows = <List<String>>[];
  for (final pump in inspection.pumps) {
    if (pump.nozzles.isEmpty) {
      rows.add([
        pump.type,
        '-',
        '-',
        pump.openingReading.toStringAsFixed(2),
        pump.closingReading?.toStringAsFixed(2) ?? '-',
        pump.soldLiters.toStringAsFixed(2),
      ]);
    } else {
      for (final nozzle in pump.nozzles) {
        rows.add([
          pump.type,
          nozzle.nozzleNumber.toString(),
          _fuelLabel(nozzle.fuelType),
          nozzle.openingReading.toStringAsFixed(2),
          nozzle.closingReading?.toStringAsFixed(2) ?? '-',
          nozzle.soldLiters.toStringAsFixed(2),
        ]);
      }
    }
  }

  if (rows.isEmpty) {
    rows.add(['-', '-', '-', '-', '-', '-']);
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'تفاصيل المضخات والليات',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _buildTable(
          headers: const [
            'المضخة',
            'اللية',
            'نوع الوقود',
            'قراءة الفتح',
            'قراءة الإغلاق',
            'اللترات المباعة',
          ],
          rows: rows,
        ),
      ],
    ),
  );
}

pw.Widget _buildFuelSummarySection(StationInspection inspection) {
  final totals = <FuelType, double>{};
  for (final pump in inspection.pumps) {
    for (final nozzle in pump.nozzles) {
      totals[nozzle.fuelType] =
          (totals[nozzle.fuelType] ?? 0) + nozzle.soldLiters;
    }
  }

  final rows = totals.entries
      .map((entry) => [_fuelLabel(entry.key), entry.value.toStringAsFixed(2)])
      .toList();

  if (rows.isEmpty) {
    rows.add(['-', '0']);
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'إجمالي المبيعات حسب نوع الوقود',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _buildTable(
          headers: const ['نوع الوقود', 'إجمالي اللترات'],
          rows: rows,
        ),
      ],
    ),
  );
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
                    fontSize: 8,
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
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

String _fuelLabel(FuelType type) {
  switch (type) {
    case FuelType.gas91:
      return 'بنزين 91';
    case FuelType.gas95:
      return 'بنزين 95';
    case FuelType.diesel:
      return 'ديزل';
    case FuelType.kerosene:
      return 'كيروسين';
  }
}

String _statusLabel(InspectionStatus status) {
  switch (status) {
    case InspectionStatus.accepted:
      return 'مقبول';
    case InspectionStatus.rejected:
      return 'مرفوض';
    case InspectionStatus.pending:
    default:
      return 'تحت المراجعة';
  }
}
