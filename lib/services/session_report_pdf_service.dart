import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

class PdfFuelStockSummary {
  final String fuelType;
  final double stockBeforeSales;
  final double sales;
  final double stockAfterSales;

  PdfFuelStockSummary({
    required this.fuelType,
    required this.stockBeforeSales,
    required this.sales,
    required this.stockAfterSales,
  });
}

class SessionReportPdfService {
  static Future<Uint8List> buildSessionPdfBytes({
    required BuildContext context,
    required PumpSession session,
  }) async {
    final arabicFont = await _loadArabicFont();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
    );

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    final fuelPriceLookup = await _loadFuelPriceLookup(
      stationProvider: stationProvider,
      stationId: session.stationId,
    );

    final PumpSession? yesterdaySession = stationProvider.getPreviousSession(
      session,
    );

    final _SessionTotals sessionTotals = _calculateSessionTotals(
      session,
      fuelPriceLookup: fuelPriceLookup,
    );

    final double expensesTotal =
        session.expenses?.fold<double>(0, (sum, e) => sum + e.amount) ??
        (session.expensesTotal ?? 0);
    final double returnAmount = _calculateFuelReturnAmount(
      session,
      fuelPriceLookup: fuelPriceLookup,
    );
    final double expectedTotal =
        sessionTotals.amount - expensesTotal - returnAmount;
    final double actualTotal = session.paymentTypes.total;
    final double difference = actualTotal - expectedTotal;
    final String? differenceReason = session.differenceReason;

    // ================= بيانات المخزون =================
    List<PdfFuelStockSummary> pdfFuelSummaries = [];
    final Map<String, double> sessionSalesByFuel = _getSessionSalesByFuel(
      session,
      fuelPriceLookup: fuelPriceLookup,
    );

    if (session.fuelStockSummary.isNotEmpty) {
      pdfFuelSummaries = session.fuelStockSummary
          .map(
            (item) => PdfFuelStockSummary(
              fuelType: item.fuelType,
              stockBeforeSales: item.stockBeforeSales,
              sales: item.sales,
              stockAfterSales: item.stockAfterSales,
            ),
          )
          .toList();
    } else if (session.stationId.isNotEmpty) {
      try {
        await stationProvider.fetchFuelBalanceReport(
          stationId: session.stationId,
          startDate: DateTime(2000),
          endDate: session.sessionDate,
        );

        final List<FuelBalanceReportRow> rows = stationProvider.fuelBalanceReport
            .where((row) => !row.date.isAfter(session.sessionDate))
            .toList();

        Map<String, double> baseStockByFuel = _buildBaseStockFromReport(
          rows,
          session.sessionDate,
        );

        final inventoryBaseStock = await _loadBaseStockFromInventoriesFallback(
          stationProvider,
          session.stationId,
          session.sessionDate,
        );
        if (inventoryBaseStock.isNotEmpty) {
          baseStockByFuel.addAll(inventoryBaseStock);
        }

        // ✅ لو ما فيش تقرير/جرد للمحطة الجديدة لكن فيه توريد في الجلسة،
        // نضيفه كأساس للمخزون عشان يظهر الملخص في الـ PDF.
        final supply = session.fuelSupply;
        if (supply != null) {
          final supplyKey = _normalizeFuelType(supply.fuelType);
          if (supplyKey.isNotEmpty && !baseStockByFuel.containsKey(supplyKey)) {
            baseStockByFuel[supplyKey] = supply.quantity;
          }
        }

        final returnByFuel = _getSessionReturnByFuel(session);
        pdfFuelSummaries = _aggregateFuelStockForPdf(
          baseStockByFuel,
          sessionSalesByFuel,
          returnByFuel: returnByFuel,
        );
      } catch (e) {
        debugPrint('❌ Failed to load fuel balance rows for PDF: $e');
      }
    }

    // ================= إنشاء صفحة PDF =================
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader(session),
                pw.SizedBox(height: 6),
                if (yesterdaySession != null) ...[
                  _buildPdfSessionAndYesterdaySideBySide(
                    session,
                    yesterdaySession,
                  ),
                  pw.SizedBox(height: 6),
                ] else ...[
                  _buildPdfSessionInfoCompact(session),
                  pw.SizedBox(height: 6),
                ],
                _buildPdfPumpTable(
                  session,
                  fuelPriceLookup: fuelPriceLookup,
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: _buildPdfFinancialSummary(
                        expectedTotal: expectedTotal,
                        actualTotal: actualTotal,
                        difference: difference,
                        differenceReason: differenceReason,
                        expensesTotal: expensesTotal,
                        returnAmount: returnAmount,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      flex: 1,
                      child: _buildPdfPaymentsTable(session),
                    ),
                  ],
                ),
                if ((session.expenses ?? []).isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  _buildPdfExpensesTable(session),
                ],
                if (session.fuelReturns.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  _buildPdfFuelReturnSection(
                    session,
                    session.fuelReturns,
                    fuelPriceLookup: fuelPriceLookup,
                  ),
                ],
                if (pdfFuelSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  _buildPdfFuelStockSummaryEnhanced(pdfFuelSummaries),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<pw.Font> _loadArabicFont() async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    return pw.Font.ttf(fontData);
  }
}

// Helpers are appended below (kept outside the class for minimal rebuild cost).

Future<Map<String, double>> _loadFuelPriceLookup({
  required StationProvider stationProvider,
  required String stationId,
}) async {
  final lookup = <String, double>{};
  if (stationId.trim().isEmpty) return lookup;

  try {
    final station = await stationProvider.fetchStationDetails(stationId);
    if (station == null) return lookup;

    for (final price in station.fuelPrices) {
      lookup[price.fuelType] = price.price;
    }
  } catch (_) {}

  return lookup;
}

List<PdfFuelStockSummary> _aggregateFuelStockForPdf(
  Map<String, double> baseStockByFuel,
  Map<String, double> sessionSalesByFuel, {
  Map<String, double> returnByFuel = const {},
}) {
  final allFuelTypes = <String>{
    ...baseStockByFuel.keys,
    ...sessionSalesByFuel.keys,
    ...returnByFuel.keys,
  };

  return allFuelTypes.map((fuelType) {
    final double totalStock = baseStockByFuel[fuelType] ?? 0;
    final double soldLiters = sessionSalesByFuel[fuelType] ?? 0;
    final double returnedLiters = returnByFuel[fuelType] ?? 0;
    final double finalStock = totalStock - soldLiters + returnedLiters;

    return PdfFuelStockSummary(
      fuelType: fuelType,
      stockBeforeSales: totalStock,
      sales: soldLiters,
      stockAfterSales: finalStock,
    );
  }).toList();
}

String _normalizeFuelType(String value) {
  var normalized = value;
  normalized = normalized.replaceAll(RegExp(r'[\u200E\u200F]'), '');
  normalized = _arabicDigitsToWestern(normalized);
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

String _arabicDigitsToWestern(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();

  for (final ch in input.runes) {
    final char = String.fromCharCode(ch);
    final indexArabic = arabic.indexOf(char);
    if (indexArabic != -1) {
      buffer.write(indexArabic);
      continue;
    }
    final indexEastern = eastern.indexOf(char);
    if (indexEastern != -1) {
      buffer.write(indexEastern);
      continue;
    }
    buffer.write(char);
  }

  return buffer.toString();
}

Map<String, double> _buildBaseStockFromReport(
  List<FuelBalanceReportRow> rows,
  DateTime sessionDate,
) {
  final Map<String, FuelBalanceReportRow> latestByFuel = {};
  final targetDate = DateTime(
    sessionDate.year,
    sessionDate.month,
    sessionDate.day,
  );

  bool isSameOrBeforeDay(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    return !dd.isAfter(targetDate);
  }

  for (final row in rows) {
    if (!isSameOrBeforeDay(row.date)) continue;
    final key = _normalizeFuelType(row.fuelType);
    if (key.isEmpty) continue;

    final existing = latestByFuel[key];
    if (existing == null || row.date.isAfter(existing.date)) {
      latestByFuel[key] = row;
    }
  }

  final result = <String, double>{};
  for (final entry in latestByFuel.entries) {
    final row = entry.value;
    final double baseStock =
        row.actualBalance ??
        row.calculatedBalance ??
        (row.openingBalance + row.received - row.sales);
    result[entry.key] = baseStock;
  }
  return result;
}

Future<Map<String, double>> _loadBaseStockFromInventoriesFallback(
  StationProvider provider,
  String stationId,
  DateTime sessionDate,
) async {
  String _formatDate(DateTime date) => date.toIso8601String().split('T').first;

  try {
    await provider.fetchInventories(
      filters: {'stationId': stationId, 'endDate': _formatDate(sessionDate)},
    );
  } catch (_) {
    return {};
  }

  final targetDate = DateTime(
    sessionDate.year,
    sessionDate.month,
    sessionDate.day,
  );

  final latestByFuel = <String, DailyInventory>{};
  for (final inventory in provider.inventories) {
    final invDate = DateTime(
      inventory.inventoryDate.year,
      inventory.inventoryDate.month,
      inventory.inventoryDate.day,
    );
    if (invDate.isAfter(targetDate)) continue;

    final key = _normalizeFuelType(inventory.fuelType);
    if (key.isEmpty) continue;

    final existing = latestByFuel[key];
    if (existing == null ||
        inventory.inventoryDate.isAfter(existing.inventoryDate)) {
      latestByFuel[key] = inventory;
    }
  }

  final result = <String, double>{};
  for (final entry in latestByFuel.entries) {
    final inventory = entry.value;
    final double baseStock =
        inventory.actualBalance ??
        inventory.calculatedBalance ??
        (inventory.previousBalance +
            inventory.receivedQuantity -
            inventory.totalSales);
    result[entry.key] = baseStock;
  }
  return result;
}

Map<String, double> _getSessionSalesByFuel(
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final totals = _aggregateFuelTotals(
    session.nozzleReadings ?? [],
    session,
    fuelPriceLookup: fuelPriceLookup,
  );
  final result = <String, double>{};
  totals.forEach((fuelType, total) {
    final key = _normalizeFuelType(fuelType);
    if (key.isEmpty) return;
    result[key] = (result[key] ?? 0) + total.liters;
  });
  return result;
}

Map<String, double> _getSessionReturnByFuel(PumpSession session) {
  final result = <String, double>{};
  for (final ret in session.fuelReturns) {
    if (ret.quantity <= 0) continue;
    final key = _normalizeFuelType(ret.fuelType);
    if (key.isEmpty) continue;
    result[key] = (result[key] ?? 0) + ret.quantity;
  }
  return result;
}

double _calculateReadingLiters(NozzleReading reading) {
  if (reading.closingReading == null) return 0;
  final diff = reading.closingReading! - reading.openingReading;
  return diff > 0 ? diff : 0;
}

double _calculateReadingAmount(
  NozzleReading reading,
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final pricePerLiter = _resolveReadingUnitPrice(
    reading,
    session,
    fuelPriceLookup: fuelPriceLookup,
  );
  final liters = _calculateReadingLiters(reading);
  return liters * pricePerLiter;
}

double _resolveReadingUnitPrice(
  NozzleReading reading,
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final direct = fuelPriceLookup[reading.fuelType];
  if (direct != null && direct > 0) return direct;

  final normalized = _normalizeFuelType(reading.fuelType);
  for (final entry in fuelPriceLookup.entries) {
    if (_normalizeFuelType(entry.key) == normalized && entry.value > 0) {
      return entry.value;
    }
  }

  if (reading.unitPrice != null && reading.unitPrice! > 0) {
    return reading.unitPrice!;
  }
  if (session.unitPrice != null && session.unitPrice! > 0) {
    return session.unitPrice!;
  }
  return 0;
}

double _resolveFuelUnitPrice(
  String fuelType,
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final direct = fuelPriceLookup[fuelType];
  if (direct != null && direct > 0) return direct;

  final normalized = _normalizeFuelType(fuelType);
  for (final entry in fuelPriceLookup.entries) {
    if (_normalizeFuelType(entry.key) == normalized && entry.value > 0) {
      return entry.value;
    }
  }

  if (session.unitPrice != null && session.unitPrice! > 0) {
    return session.unitPrice!;
  }
  return 0;
}

double _calculateFuelReturnAmount(
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  double total = 0;
  for (final ret in session.fuelReturns) {
    if (ret.quantity <= 0) continue;
    if (ret.amount != null && ret.amount! > 0) {
      total += ret.amount!;
      continue;
    }
    final price = _resolveFuelUnitPrice(
      ret.fuelType,
      session,
      fuelPriceLookup: fuelPriceLookup,
    );
    total += ret.quantity * price;
  }
  return total;
}

Map<String, _FuelTotals> _aggregateFuelTotals(
  List<NozzleReading> readings,
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final totals = <String, _FuelTotals>{};
  for (final reading in readings) {
    final liters = _calculateReadingLiters(reading);
    final amount = _calculateReadingAmount(
      reading,
      session,
      fuelPriceLookup: fuelPriceLookup,
    );
    if (liters == 0 && amount == 0) continue;
    totals.putIfAbsent(reading.fuelType, () => _FuelTotals());
    totals[reading.fuelType]!.liters += liters;
    totals[reading.fuelType]!.amount += amount;
  }
  return totals;
}

_SessionTotals _calculateSessionTotals(
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final readings = session.nozzleReadings ?? [];
  double totalLiters = 0;
  double totalAmount = 0;

  for (final reading in readings) {
    final liters = _calculateReadingLiters(reading);
    final amount = _calculateReadingAmount(
      reading,
      session,
      fuelPriceLookup: fuelPriceLookup,
    );
    totalLiters += liters;
    totalAmount += amount;
  }

  return _SessionTotals(liters: totalLiters, amount: totalAmount);
}

pw.Widget _buildPdfFinancialSummary({
  required double expectedTotal,
  required double actualTotal,
  required double difference,
  String? differenceReason,
  double expensesTotal = 0,
  double returnAmount = 0,

  // 🔹 بيانات التسوية
  double? shortageAmount,
  String? shortageReason,
  bool shortageResolved = false,
}) {
  String diffLabel;
  PdfColor diffColor;

  if (difference > 0) {
    diffLabel = 'زيادة';
    diffColor = PdfColors.green;
  } else if (difference < 0) {
    diffLabel = 'عجز';
    diffColor = PdfColors.red;
  } else {
    diffLabel = 'متوازن';
    diffColor = PdfColors.grey700;
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'الملخص المالي',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.4),
          1: pw.FlexColumnWidth(1),
        },
        children: [
          _buildCompactInfoRow(
            'إجمالي المبلغ المطلوب',
            '${expectedTotal.toStringAsFixed(2)} ريال',
          ),
          if (expensesTotal > 0)
            _buildCompactInfoRow(
              'إجمالي المصروفات',
              '${expensesTotal.toStringAsFixed(2)} ريال',
            ),
          if (returnAmount > 0)
            _buildCompactInfoRow(
              'خصم إرجاع الوقود',
              '${returnAmount.toStringAsFixed(2)} ريال',
            ),
          _buildCompactInfoRow(
            'المبلغ المحصل',
            '${actualTotal.toStringAsFixed(2)} ريال',
          ),

          /// الفرق
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _pdfCell(
                '$diffLabel ${difference.abs().toStringAsFixed(2)} ريال',
                bold: true,
                fontSize: 8,
              ),
              _pdfCell('الفرق', bold: true, fontSize: 8),
            ],
          ),

          /// سبب الفرق
          if (differenceReason != null && differenceReason.trim().isNotEmpty)
            pw.TableRow(
              children: [
                _pdfCell(differenceReason, fontSize: 7.5),
                _pdfCell('سبب الفرق', bold: true, fontSize: 7.5),
              ],
            ),

          /// 🔴 تسوية العجز
          if (difference < 0 && shortageResolved == true) ...[
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _pdfCell(
                  '${shortageAmount?.toStringAsFixed(2) ?? '0'} ريال',
                  bold: true,
                  fontSize: 7.5,
                ),
                _pdfCell('مبلغ التسوية', bold: true, fontSize: 7.5),
              ],
            ),
            if (shortageReason != null && shortageReason.trim().isNotEmpty)
              pw.TableRow(
                children: [
                  _pdfCell(shortageReason, fontSize: 7.5),
                  _pdfCell('سبب التسوية', bold: true, fontSize: 7.5),
                ],
              ),
            pw.TableRow(
              children: [
                _pdfCell('تمت تسوية العجز', bold: true, fontSize: 7.5),
                _pdfCell('الحالة', bold: true, fontSize: 7.5),
              ],
            ),
          ],
        ],
      ),
    ],
  );
}

pw.TableRow _buildCompactInfoRow(String label, String value) {
  return pw.TableRow(
    children: [
      _pdfCell(value, fontSize: 8.5),
      _pdfCell(label, bold: true, fontSize: 8.5),
    ],
  );
}

pw.Widget _buildPdfSessionInfoCompact(PumpSession s) {
  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    children: [
      _buildCompactInfoRow('المحطة', s.stationName),
      _buildCompactInfoRow(
        'التاريخ',
        DateFormat('yyyy/MM/dd').format(s.sessionDate),
      ),
      _buildCompactInfoRow('الوردية', s.shiftType),
      _buildCompactInfoRow('الحالة', s.status),
      _buildCompactInfoRow('موظف الفتح', s.openingEmployeeName ?? '-'),
      _buildCompactInfoRow('موظف الغلق', s.closingEmployeeName ?? '-'),
    ],
  );
}

pw.Widget _buildPdfYesterdayInfoCompact(PumpSession s) {
  String time(DateTime? d) => d != null ? DateFormat('HH:mm').format(d) : '-';

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5),
    children: [
      _buildCompactInfoRow('رقم الجلسة', s.sessionNumber ?? '-'),
      _buildCompactInfoRow(
        'تاريخ الجلسة',
        DateFormat('yyyy/MM/dd').format(s.sessionDate),
      ),
      _buildCompactInfoRow('فتح الجلسة', time(s.openingTime)),
      _buildCompactInfoRow('غلق الجلسة', time(s.closingTime)),
    ],
  );
}

pw.Widget _buildPdfSessionAndYesterdaySideBySide(
  PumpSession session,
  PumpSession yesterdaySession,
) {
  return pw.Directionality(
    textDirection: pw.TextDirection.rtl,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ================= معلومات الجلسة (فوق) =================
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'معلومات الجلسة',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _buildPdfSessionInfoCompact(session),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'جلسة الأمس',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _buildPdfYesterdayInfoCompact(yesterdaySession),
                ],
              ),
            ),
          ],
        ),

        // ================= مسافة =================
        pw.SizedBox(height: 10),

        // ================= ملخص قراءات جلسة الأمس (تحتهم...) =================
        _buildPdfYesterdayPumpsSummary(yesterdaySession),
      ],
    ),
  );
}

pw.Widget _buildPdfHeader(PumpSession session) {
  String time(DateTime? d) => d != null ? DateFormat('HH:mm').format(d) : '-';

  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'شركة البحيرة العربية للنقليات',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'تقرير جلسة تشغيل',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'رقم الجلسة: ${session.sessionNumber}',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'التاريخ: ${DateFormat('yyyy/MM/dd').format(session.sessionDate)}',
              style: pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'فتح: ${time(session.openingTime)}',
              style: pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              'غلق: ${time(session.closingTime)}',
              style: pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfYesterdayPumpsSummary(PumpSession yesterdaySession) {
  final readings = yesterdaySession.nozzleReadings ?? [];
  if (readings.isEmpty) return pw.SizedBox();

  // ===== تجميع حسب (المضخات + وقود) =====
  final Map<String, List<NozzleReading>> grouped = {};
  for (final r in readings) {
    final key = '${r.pumpNumber}_${r.fuelType}';
    grouped.putIfAbsent(key, () => []);
    grouped[key]!.add(r);
  }

  // ===== تحويل لصفوف =====
  final rows = grouped.values.map((list) {
    final s = list.first;
    double open = 0, close = 0;
    bool hasClose = false;

    for (final r in list) {
      open += r.openingReading;
      if (r.closingReading != null) {
        close += r.closingReading!;
        hasClose = true;
      }
    }

    return pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        _pdfCell(
          s.pumpNumber,
          fontSize: 7.5,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        ),
        _pdfCell(
          s.fuelType,
          fontSize: 7.5,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        ),
        _pdfCell(
          open.toStringAsFixed(2),
          fontSize: 7.5,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        ),
        _pdfCell(
          hasClose ? close.toStringAsFixed(2) : '-',
          fontSize: 7.5,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        ),
        _pdfCell(
          hasClose ? (close - open).toStringAsFixed(2) : '-',
          fontSize: 7.5,
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        ),
      ],
    );
  }).toList();

  if (rows.isEmpty) return pw.SizedBox();

  // ===== تقسيم الصفوف لنصّين =====
  final mid = (rows.length / 2).ceil();
  final leftRows = rows.sublist(0, mid);
  final rightRows = rows.sublist(mid);

  pw.Table buildTable(List<pw.TableRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.8), // المضخات
        1: pw.FlexColumnWidth(1.2), // الوقود
        2: pw.FlexColumnWidth(1.2), // الفتح
        3: pw.FlexColumnWidth(1.2), // الغلق
        4: pw.FlexColumnWidth(1.0), // الفرق
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _pdfCell('المضخات', bold: true, fontSize: 8),
            _pdfCell('الوقود', bold: true, fontSize: 8),
            _pdfCell('الفتح', bold: true, fontSize: 8),
            _pdfCell('الغلق', bold: true, fontSize: 8),
            _pdfCell('الفرق', bold: true, fontSize: 8),
          ],
        ),
        ...rows,
      ],
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'ملخص قراءات جلسة الأمس',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: buildTable(leftRows)),
          pw.SizedBox(width: 6),
          if (rightRows.isNotEmpty) pw.Expanded(child: buildTable(rightRows)),
        ],
      ),
    ],
  );
}

pw.Widget _buildPdfPaymentsTable(PumpSession s) {
  final p = s.paymentTypes;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'طرق الدفع',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 3),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: [
          _buildCompactInfoRow('نقدى', p.cash.toStringAsFixed(2)),
          _buildCompactInfoRow('بطاقة', p.card.toStringAsFixed(2)),
          _buildCompactInfoRow('مدى', p.mada.toStringAsFixed(2)),
          _buildCompactInfoRow('أخرى', p.other.toStringAsFixed(2)),
          _buildCompactInfoRow(
            'الإجمالي',
            (p.cash + p.card + p.mada + p.other).toStringAsFixed(2),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildPdfPumpTable(
  PumpSession session, {
  required Map<String, double> fuelPriceLookup,
}) {
  final readings = session.nozzleReadings ?? [];
  if (readings.isEmpty) return pw.SizedBox();

  final Map<String, List<NozzleReading>> grouped = {};
  for (final r in readings) {
    grouped.putIfAbsent('${r.pumpNumber}-${r.fuelType}', () => []).add(r);
  }

  double totalAll = 0;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'تفاصيل المضخات',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 3),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('الإجمالي', bold: true, fontSize: 8),
              _pdfCell('الفرق', bold: true, fontSize: 8),
              _pdfCell('الغلق', bold: true, fontSize: 8),
              _pdfCell('الفتح', bold: true, fontSize: 8),
              _pdfCell('الوقود', bold: true, fontSize: 8),
              _pdfCell('المضخات', bold: true, fontSize: 8),
            ],
          ),
          ...grouped.entries.map((e) {
            double open = 0, close = 0;
            for (final r in e.value) {
              open += r.openingReading;
              close += r.closingReading ?? 0;
            }
            final liters = close - open;
            final price = _resolveReadingUnitPrice(
              e.value.first,
              session,
              fuelPriceLookup: fuelPriceLookup,
            );
            final total = liters * price;
            totalAll += total;

            final s = e.value.first;
            return pw.TableRow(
              children: [
                _pdfCell(total.toStringAsFixed(1), fontSize: 8),
                _pdfCell(liters.toStringAsFixed(1), fontSize: 8),
                _pdfCell(close.toStringAsFixed(1), fontSize: 8),
                _pdfCell(open.toStringAsFixed(1), fontSize: 8),
                _pdfCell(s.fuelType, fontSize: 8),
                _pdfCell(s.pumpNumber, fontSize: 8),
              ],
            );
          }),
        ],
      ),
      pw.SizedBox(height: 3),
      _pdfCell(
        'الإجمالي: ${totalAll.toStringAsFixed(2)} ريال',
        bold: true,
        fontSize: 8.5,
      ),
    ],
  );
}

pw.Widget _pdfCell(
  String text, {
  bool bold = false,
  double fontSize = 8,
  pw.EdgeInsets padding = const pw.EdgeInsets.symmetric(
    vertical: 2,
    horizontal: 3,
  ),
  pw.Alignment alignment = pw.Alignment.center,
}) {
  return pw.Container(
    alignment: alignment,
    padding: padding,
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _buildPdfExpensesTable(PumpSession session) {
  final e = session.expenses ?? [];
  if (e.isEmpty) return pw.SizedBox();
  final totalExpenses = e.fold<double>(0, (sum, x) => sum + x.amount);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'المصروفات',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 3),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('المبلغ', bold: true, fontSize: 8),
              _pdfCell('التصنيف', bold: true, fontSize: 8),
              _pdfCell('الوصف', bold: true, fontSize: 8),
            ],
          ),
          ...e.map(
            (x) => pw.TableRow(
              children: [
                _pdfCell(x.amount.toStringAsFixed(2), fontSize: 8),
                _pdfCell(x.category, fontSize: 8),
                _pdfCell(x.description ?? '-', fontSize: 8),
              ],
            ),
          ),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _pdfCell(
                totalExpenses.toStringAsFixed(2),
                bold: true,
                fontSize: 8,
              ),
              _pdfCell('إجمالي المصروفات', bold: true, fontSize: 8),
              _pdfCell('', fontSize: 8),
            ],
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildPdfFuelReturnSection(
  PumpSession session,
  List<FuelReturn> fuelReturns, {
  required Map<String, double> fuelPriceLookup,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'إرجاع وقود للخزان',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 3),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('الوقود', bold: true, fontSize: 8),
              _pdfCell('الكمية', bold: true, fontSize: 8),
              _pdfCell('السبب', bold: true, fontSize: 8),
              _pdfCell('قيمة الخصم', bold: true, fontSize: 8),
            ],
          ),
          ...fuelReturns.map((ret) {
            final amount = (ret.amount != null && ret.amount! > 0)
                ? ret.amount!
                : ret.quantity *
                    _resolveFuelUnitPrice(
                      ret.fuelType,
                      session,
                      fuelPriceLookup: fuelPriceLookup,
                    );
            return pw.TableRow(
              children: [
                _pdfCell(ret.fuelType, fontSize: 8),
                _pdfCell('${ret.quantity.toStringAsFixed(2)} لتر', fontSize: 8),
                _pdfCell(ret.reason ?? '-', fontSize: 8),
                _pdfCell(
                  amount > 0 ? amount.toStringAsFixed(2) : '-',
                  fontSize: 8,
                ),
              ],
            );
          }),
        ],
      ),
    ],
  );
}

pw.Widget _buildPdfFuelStockSummaryEnhanced(
  List<PdfFuelStockSummary> summaries,
) {
  if (summaries.isEmpty) return pw.SizedBox();

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'ملخص المخزون حسب نوع الوقود',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _pdfCell('الوقود', bold: true),
              _pdfCell('إجمالي المخزون', bold: true),
              _pdfCell('إجمالي اللترات المباعة', bold: true),
              _pdfCell('المخزون النهائي في الخزان', bold: true),
            ],
          ),
          ...summaries.map((s) {
            return pw.TableRow(
              children: [
                _pdfCell(s.fuelType),
                _pdfCell('${s.stockBeforeSales.toStringAsFixed(2)} لتر'),
                _pdfCell('${s.sales.toStringAsFixed(2)} لتر'),
                _pdfCell(
                  '${s.stockAfterSales.toStringAsFixed(2)} لتر',
                  bold: true,
                ),
              ],
            );
          }).toList(),
        ],
      ),
    ],
  );
}

class _FuelTotals {
  double liters;
  double amount;

  _FuelTotals({this.liters = 0, this.amount = 0});
}

class _SessionTotals {
  final double liters;
  final double amount;

  _SessionTotals({required this.liters, required this.amount});
}
