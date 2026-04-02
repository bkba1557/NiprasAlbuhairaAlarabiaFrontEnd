import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:photo_view/photo_view.dart'; // optional for zoom
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/web_platform.dart' as web_platform;

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

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final Map<String, double> _fuelPriceLookup = {};
  bool _isFuelPriceLoading = false;
  StationProvider? _stationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessionDetails();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.read<StationProvider>();
    if (_stationProvider != provider) {
      _stationProvider = provider;
    }

    _syncFuelPricesFromProviderCache();
  }

  void _syncFuelPricesFromProviderCache() {
    if (!mounted) return;
    final provider = _stationProvider ?? context.read<StationProvider>();
    final session = provider.selectedSession;
    if (session == null || session.stationId.isEmpty) return;

    final cachedStation = provider.getCachedStation(session.stationId);
    if (cachedStation == null) return;

    final next = <String, double>{
      for (final price in cachedStation.fuelPrices) price.fuelType: price.price,
    };
    if (mapEquals(_fuelPriceLookup, next)) return;

    setState(() {
      _fuelPriceLookup
        ..clear()
        ..addAll(next);
      _isFuelPriceLoading = false;
    });
  }

  // دالة واحدة فقط للتجميع (تم إزالة التكرار)
  Map<String, Map<String, List<NozzleReading>>> _groupByPumpAndFuel(
    List<NozzleReading> readings,
  ) {
    final Map<String, Map<String, List<NozzleReading>>> result = {};

    for (final r in readings) {
      result.putIfAbsent(r.pumpNumber, () => {});
      result[r.pumpNumber]!.putIfAbsent(r.fuelType, () => []);
      result[r.pumpNumber]![r.fuelType]!.add(r);
    }

    return result;
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
    String _formatDate(DateTime date) =>
        date.toIso8601String().split('T').first;

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

  Map<String, double> _getSessionSalesByFuel(PumpSession session) {
    final totals = _aggregateFuelTotals(session.nozzleReadings ?? [], session);
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

  double _calculateReadingAmount(NozzleReading reading, PumpSession session) {
    final pricePerLiter = _resolveReadingUnitPrice(reading, session);
    final liters = _calculateReadingLiters(reading);
    return liters * pricePerLiter;
  }

  double _resolveReadingUnitPrice(NozzleReading reading, PumpSession session) {
    final direct = _fuelPriceLookup[reading.fuelType];
    if (direct != null && direct > 0) return direct;

    final normalized = _normalizeFuelType(reading.fuelType);
    for (final entry in _fuelPriceLookup.entries) {
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

  double _resolveFuelUnitPrice(String fuelType, PumpSession session) {
    final direct = _fuelPriceLookup[fuelType];
    if (direct != null && direct > 0) return direct;

    final normalized = _normalizeFuelType(fuelType);
    for (final entry in _fuelPriceLookup.entries) {
      if (_normalizeFuelType(entry.key) == normalized && entry.value > 0) {
        return entry.value;
      }
    }

    if (session.unitPrice != null && session.unitPrice! > 0) {
      return session.unitPrice!;
    }
    return 0;
  }

  double _calculateFuelReturnAmount(PumpSession session) {
    double total = 0;
    for (final ret in session.fuelReturns) {
      if (ret.quantity <= 0) continue;
      if (ret.amount != null && ret.amount! > 0) {
        total += ret.amount!;
        continue;
      }
      final price = _resolveFuelUnitPrice(ret.fuelType, session);
      total += ret.quantity * price;
    }
    return total;
  }

  double calculateYesterdayOpening(PumpSession yesterdaySession) {
    double total = 0;
    for (final n in yesterdaySession.nozzleReadings ?? []) {
      total += n.openingReading;
    }
    return total;
  }

  double calculateYesterdayClosing(PumpSession yesterdaySession) {
    double total = 0;
    for (final n in yesterdaySession.nozzleReadings ?? []) {
      if (n.closingReading != null) {
        total += n.closingReading!;
      }
    }
    return total;
  }

  Map<String, _FuelTotals> _aggregateFuelTotals(
    List<NozzleReading> readings,
    PumpSession session,
  ) {
    final totals = <String, _FuelTotals>{};
    for (final reading in readings) {
      final liters = _calculateReadingLiters(reading);
      final amount = _calculateReadingAmount(reading, session);
      if (liters == 0 && amount == 0) continue;
      totals.putIfAbsent(reading.fuelType, () => _FuelTotals());
      totals[reading.fuelType]!.liters += liters;
      totals[reading.fuelType]!.amount += amount;
    }
    return totals;
  }

  _SessionTotals _calculateSessionTotals(PumpSession session) {
    final readings = session.nozzleReadings ?? [];
    double totalLiters = 0;
    double totalAmount = 0;

    for (final reading in readings) {
      final liters = _calculateReadingLiters(reading);
      final amount = _calculateReadingAmount(reading, session);
      totalLiters += liters;
      totalAmount += amount;
    }

    return _SessionTotals(liters: totalLiters, amount: totalAmount);
  }

  Future<void> _approveSessionClosing(PumpSession session) async {
    final provider = Provider.of<StationProvider>(context, listen: false);

    final success = await provider.approveClosingSession(session.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اعتماد إغلاق الجلسة بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل اعتماد الجلسة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> exportSessionToPdf(
    BuildContext context,
    PumpSession session,
  ) async {
    // ================= تحميل الخط العربي =================
    final arabicFont = await _loadArabicFont();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
    );

    // ================= Provider =================
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    // ================= جلب جلسة الأمس =================
    final PumpSession? yesterdaySession = stationProvider.getPreviousSession(
      session,
    );

    // ================= الحسابات المالية =================
    final _SessionTotals sessionTotals = _calculateSessionTotals(session);
    final double expensesTotal =
        session.expenses?.fold<double>(0, (sum, e) => sum + e.amount) ??
        (session.expensesTotal ?? 0);
    final double returnAmount = _calculateFuelReturnAmount(session);
    final double expectedTotal =
        sessionTotals.amount - expensesTotal - returnAmount;
    final double actualTotal = session.paymentTypes.total;
    final double difference = actualTotal - expectedTotal;
    final String? differenceReason = session.differenceReason;

    // ================= بيانات المخزون =================
    List<PdfFuelStockSummary> pdfFuelSummaries = [];
    final Map<String, double> sessionSalesByFuel = _getSessionSalesByFuel(
      session,
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
        // ⬅️ نجيب كل تقارير المخزون لحد وقت الجلسة
        await stationProvider.fetchFuelBalanceReport(
          stationId: session.stationId,
          startDate: DateTime(2000), // بداية مفتوحة
          endDate: session.sessionDate,
        );

        // ⬅️ نفلتر أي صف بعد الجلسة
        final List<FuelBalanceReportRow> rows = stationProvider
            .fuelBalanceReport
            .where((row) => !row.date.isAfter(session.sessionDate))
            .toList();

        // ✅ رصيد أساس من التقرير
        Map<String, double> baseStockByFuel = _buildBaseStockFromReport(
          rows,
          session.sessionDate,
        );

        // ✅ دمج رصيد الجرد اليومي (الأقرب للتاريخ) كأولوية للرصيد الفعلي
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

        // ✅ تجميع صح لكل نوع وقود (إجمالي المخزون - مبيعات الجلسة)
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
                // ================= Header =================
                _buildPdfHeader(session),
                pw.SizedBox(height: 6),

                // ================= Session + Yesterday =================
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

                // ================= Pumps Table =================
                _buildPdfPumpTable(session),
                pw.SizedBox(height: 4),

                // ================= Financial + Payments =================
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

                // ================= Expenses =================
                if ((session.expenses ?? []).isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  _buildPdfExpensesTable(session),
                ],
                if (session.fuelReturns.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  _buildPdfFuelReturnSection(session, session.fuelReturns),
                ],

                // ================= Fuel Stock Summary =================
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

    // ================= عرض / طباعة PDF =================
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<pw.Font> _loadArabicFont() async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  Future<void> exportSessionToExcel(PumpSession session) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Session Report';

    // RTL + Landscape
    sheet.isRightToLeft = true;
    sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;

    // Header
    sheet.getRangeByName('A1:E1').merge();
    sheet
        .getRangeByName('A1')
        .setText('تقرير جلسة رقم ${session.sessionNumber}');
    sheet.getRangeByName('A1').cellStyle
      ..bold = true
      ..fontSize = 16
      ..hAlign = xlsio.HAlignType.center;

    // Table headers
    final headers = [
      'المضخات',
      'نوع الوقود',
      'سعر اللتر',
      'اللترات',
      'الإجمالي',
    ];
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(3, i + 1).setText(headers[i]);
      sheet.getRangeByIndex(3, i + 1).cellStyle.bold = true;
    }

    int row = 4;
    for (final r in session.nozzleReadings ?? []) {
      final liters = _calculateReadingLiters(r);
      if (liters == 0) continue;

      final price = _resolveReadingUnitPrice(r, session);
      final total = liters * price;

      sheet.getRangeByIndex(row, 1).setText(r.pumpNumber);
      sheet.getRangeByIndex(row, 2).setText(r.fuelType);
      sheet.getRangeByIndex(row, 3).setNumber(price);
      sheet.getRangeByIndex(row, 4).setNumber(liters);
      sheet.getRangeByIndex(row, 5).setNumber(total);

      row++;
    }

    final expensesTotal =
        session.expenses?.fold<double>(0, (sum, e) => sum + e.amount) ?? 0;
    final returnAmount = _calculateFuelReturnAmount(session);
    final sessionTotals = _calculateSessionTotals(session);
    final expectedTotal = sessionTotals.amount - expensesTotal - returnAmount;
    final actualTotal = session.paymentTypes.total;

    row += 1;
    sheet.getRangeByIndex(row, 1).setText('إجمالي المبلغ المطلوب');
    sheet.getRangeByIndex(row, 5).setNumber(expectedTotal);
    row += 1;
    if (expensesTotal > 0) {
      sheet.getRangeByIndex(row, 1).setText('إجمالي المصروفات');
      sheet.getRangeByIndex(row, 5).setNumber(expensesTotal);
      row += 1;
    }
    if (returnAmount > 0) {
      sheet.getRangeByIndex(row, 1).setText('خصم إرجاع الوقود');
      sheet.getRangeByIndex(row, 5).setNumber(returnAmount);
      row += 1;
    }
    sheet.getRangeByIndex(row, 1).setText('المبلغ المحصل');
    sheet.getRangeByIndex(row, 5).setNumber(actualTotal);
    row += 1;
    if (session.fuelReturns.isNotEmpty) {
      for (final ret in session.fuelReturns) {
        sheet.getRangeByIndex(row, 1).setText('نوع وقود الإرجاع');
        sheet.getRangeByIndex(row, 5).setText(ret.fuelType);
        row += 1;
        sheet.getRangeByIndex(row, 1).setText('كمية الإرجاع (لتر)');
        sheet.getRangeByIndex(row, 5).setNumber(ret.quantity);
        row += 1;
        sheet.getRangeByIndex(row, 1).setText('سبب الإرجاع');
        sheet.getRangeByIndex(row, 5).setText(ret.reason ?? '-');
        row += 1;
      }
    }

    if (session.fuelStockSummary.isNotEmpty) {
      row += 1;
      sheet.getRangeByIndex(row, 1).setText('ملخص المخزون');
      sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
      row += 1;

      final stockHeaders = ['الوقود', 'قبل البيع', 'المباع', 'بعد البيع'];
      for (int i = 0; i < stockHeaders.length; i++) {
        sheet.getRangeByIndex(row, i + 1).setText(stockHeaders[i]);
        sheet.getRangeByIndex(row, i + 1).cellStyle.bold = true;
      }

      row += 1;
      for (final summary in session.fuelStockSummary) {
        sheet.getRangeByIndex(row, 1).setText(summary.fuelType);
        sheet.getRangeByIndex(row, 2).setNumber(summary.stockBeforeSales);
        sheet.getRangeByIndex(row, 3).setNumber(summary.sales);
        sheet.getRangeByIndex(row, 4).setNumber(summary.stockAfterSales);
        row += 1;
      }
    }

    sheet.autoFitColumn(1);
    sheet.autoFitColumn(2);
    sheet.autoFitColumn(3);
    sheet.autoFitColumn(4);
    sheet.autoFitColumn(5);

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/session_${session.sessionNumber}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _loadSessionDetails() async {
    final provider = Provider.of<StationProvider>(context, listen: false);
    await provider.fetchSessionById(widget.sessionId);
    final session = provider.selectedSession;
    if (session != null) {
      await _loadStationFuelPrices(session);
    }
  }

  Future<void> _loadStationFuelPrices(PumpSession session) async {
    if (!mounted) return;
    setState(() {
      _isFuelPriceLoading = true;
    });

    final provider = Provider.of<StationProvider>(context, listen: false);
    final station = await provider.fetchStationDetails(session.stationId);

    if (!mounted) return;
    setState(() {
      _fuelPriceLookup.clear();
      if (station != null) {
        for (final price in station.fuelPrices) {
          _fuelPriceLookup[price.fuelType] = price.price;
        }
      }
      _isFuelPriceLoading = false;
    });
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

          // ================= ملخص قراءات جلسة الأمس (تحتهم) =================
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
              pw.Text('تقرير جلسة تشغيل', style: pw.TextStyle(fontSize: 10)),
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

  pw.Widget buildPdfPaymentsTable(PumpSession session) {
    final p = session.paymentTypes;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'طرق الدفع',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
          },
          children: [
            _pdfPaymentRow('نقدى', p.cash),
            _pdfPaymentRow('بطاقة', p.card),
            _pdfPaymentRow('مدى', p.mada),
            _pdfPaymentRow('أخرى', p.other),
            _pdfPaymentRow('الإجمالي', p.total, isTotal: true),
          ],
        ),
      ],
    );
  }

  pw.TableRow _pdfPaymentRow(
    String label,
    double value, {
    bool isTotal = false,
  }) {
    return pw.TableRow(
      decoration: isTotal
          ? const pw.BoxDecoration(color: PdfColors.grey300)
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            '${value.toStringAsFixed(2)} ريال',
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfPumpTable(PumpSession session) {
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
              final price = _resolveReadingUnitPrice(e.value.first, session);
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
    List<FuelReturn> fuelReturns,
  ) {
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
                  : ret.quantity * _resolveFuelUnitPrice(ret.fuelType, session);
              return pw.TableRow(
                children: [
                  _pdfCell(ret.fuelType, fontSize: 8),
                  _pdfCell(
                    '${ret.quantity.toStringAsFixed(2)} لتر',
                    fontSize: 8,
                  ),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role == 'owner';
    final session = stationProvider.selectedSession;

    if (stationProvider.isLoading && session == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            AppSoftBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (session == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          ),
          title: const Text(
            'تفاصيل الجلسة',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: const [
            AppSoftBackground(),
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppSurfaceCard(child: Text('الجلسة غير موجودة')),
              ),
            ),
          ],
        ),
      );
    }

    final sessionTotals = _calculateSessionTotals(session);
    final actualSales = session.totalSales ?? session.paymentTypes.total;
    final differenceValue = actualSales - sessionTotals.amount;
    final averagePrice = sessionTotals.liters > 0
        ? sessionTotals.amount / sessionTotals.liters
        : (session.unitPrice ?? 0);
    final showSalesSummaryCard =
        sessionTotals.liters > 0 || actualSales > 0 || _isFuelPriceLoading;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 241, 241),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: Text(
          'الجلسة ${session.sessionNumber}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // ===================== تصدير PDF =====================
          IconButton(
            tooltip: 'تصدير PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              await exportSessionToPdf(context, session);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير ملف PDF بنجاح')),
                );
              }
            },
          ),

          // ===================== تصدير Excel =====================
          IconButton(
            tooltip: 'تصدير Excel',
            icon: const Icon(Icons.table_chart),
            onPressed: () async {
              await exportSessionToExcel(session);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير ملف Excel بنجاح')),
                );
              }
            },
          ),

          if (isOwner)
            IconButton(
              tooltip: 'تعديل الجلسة',
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.pushNamed(
                  context,
                  AppRoutes.sessionEdit,
                  arguments: session,
                );

                if (updated == true && mounted) {
                  await _loadSessionDetails();
                }
              },
            ),

          if (isOwner)
            IconButton(
              tooltip: 'حذف الجلسة',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: const Text(
                      'هل أنت متأكد من حذف الجلسة؟ لا يمكن التراجع عن هذا الإجراء.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                final success = await stationProvider.deleteSession(session.id);

                if (!mounted) return;

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف الجلسة بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(stationProvider.error ?? 'فشل حذف الجلسة'),
                    ),
                  );
                }
              },
            ),

          const VerticalDivider(width: 8),

          // ===================== إغلاق الجلسة =====================
          if (session.status == 'مفتوحة')
            IconButton(
              tooltip: 'إغلاق الجلسة',
              icon: const Icon(Icons.stop_circle),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/sessions/close',
                  arguments: session,
                );
              },
            ),

          // ===================== اعتماد الإغلاق =====================
          if (session.status == 'مغلقة' && !session.closingApproved)
            IconButton(
              tooltip: 'اعتماد الإغلاق',
              icon: const Icon(Icons.check_circle),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد الاعتماد'),
                    content: const Text('هل أنت متأكد من اعتماد إغلاق الجلسة؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('اعتماد'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _approveSessionClosing(session);
                }
              },
            ),
        ],
      ),

      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final isTablet =
                    constraints.maxWidth >= 600 && constraints.maxWidth < 900;
                final isDesktop = constraints.maxWidth >= 900;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile
                        ? 12
                        : isTablet
                        ? 24
                        : 32,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: isDesktop ? 1200 : 750,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Session Info Card
                    _buildSessionInfoCard(session, isMobile, isTablet),
                    const SizedBox(height: 20),

                    // Opening Details Full Card
                    _buildOpeningDetailsFullCard(session, isMobile, isTablet),
                    const SizedBox(height: 20),

                    // Pump Readings Section
                    _buildPumpFullReadingsSection(session, isMobile, isTablet),
                    const SizedBox(height: 20),

                    // Closing Images Card
                    if (session.status != 'مفتوحة')
                      _buildClosingImagesCard(session, isMobile, isTablet),

                    // Opening Details Card
                    _buildBasicOpeningDetailsCard(session, isMobile, isTablet),
                    const SizedBox(height: 20),

                    // Closing Details Card
                    if (session.status != 'مفتوحة')
                      _buildClosingDetailsCard(session, isMobile, isTablet),

                    // Sales Summary Card
                    if (showSalesSummaryCard)
                      _buildSalesSummaryCard(
                        session,
                        sessionTotals,
                        actualSales,
                        differenceValue,
                        averagePrice,
                        isMobile,
                        isTablet,
                      ),

                    // Fuel Supply Card
                    if (session.fuelSupply != null)
                      _buildFuelSupplyCard(session, isMobile, isTablet),

                    // Expenses Card
                    if ((session.expenses ?? []).isNotEmpty)
                      _buildExpensesCard(session, isMobile, isTablet),

                    // Balance and Difference Card
                    if (session.carriedForwardBalance != 0 ||
                        session.calculatedDifference != null)
                      _buildBalanceCard(session, isMobile, isTablet),

                    // Notes Card
                    if (session.notes != null && session.notes!.isNotEmpty)
                      _buildNotesCard(session, isMobile, isTablet),

                    // Pump Breakdown Card
                    if ((session.pumps ?? []).isNotEmpty)
                      _buildPumpBreakdownCard(session, isMobile, isTablet),

                    const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Widget Builder Methods ====================

  Widget _buildSessionInfoCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الجلسة',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildResponsiveInfoGrid(
              [
                _buildInfoItem('رقم الجلسة', session.sessionNumber),
                _buildInfoItem('المحطة', session.stationName),
                if (session.pumpNumber.isNotEmpty)
                  _buildInfoItem('المضخات', session.pumpNumber),
                if (session.fuelType.isNotEmpty)
                  _buildInfoItem('نوع الوقود', session.fuelType),
                if (session.pumpsCount != null)
                  _buildInfoItem('عدد المضخات', '${session.pumpsCount}'),
                _buildInfoItem('الوردية', session.shiftType),
                _buildInfoItem(
                  'تاريخ الجلسة',
                  DateFormat('yyyy/MM/dd').format(session.sessionDate),
                ),
                _buildInfoItemWithColor(
                  'حالة الجلسة',
                  session.status,
                  _getStatusColor(session.status),
                ),
              ],
              isMobile,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveInfoGrid(
    List<Widget> items,
    bool isMobile,
    bool isTablet,
  ) {
    if (isMobile) {
      return Column(children: items);
    } else {
      return Wrap(
        spacing: 20,
        runSpacing: 16,
        children: items.map((item) {
          return SizedBox(width: isTablet ? 300 : 350, child: item);
        }).toList(),
      );
    }
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItemWithColor(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningDetailsFullCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    final readings = session.nozzleReadings ?? [];
    final groupedReadings = _groupByPumpAndFuel(readings);
    final fuelTotals = readings.isNotEmpty
        ? _aggregateFuelTotals(readings, session)
        : <String, _FuelTotals>{};

    final openingReadings = readings
        .where(
          (r) => r.openingImageUrl != null && r.openingImageUrl!.isNotEmpty,
        )
        .toList();

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل فتح الجلسة (جميع المضخات)',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            if (openingReadings.isEmpty) ...[
              _buildEmptyState(
                'لم يتم تسجيل أي قراءات فتح للطلمبات بعد',
                Icons.warning,
                AppColors.warningOrange,
              ),
            ] else ...[
              if (fuelTotals.isNotEmpty) ...[
                _buildFuelTotalsSummary(fuelTotals, isMobile, isTablet),
                const SizedBox(height: 20),
              ],
              ...groupedReadings.entries.map(
                (pumpEntry) => _buildPumpFuelDetails(
                  session,
                  pumpEntry.key,
                  pumpEntry.value,
                  isMobile,
                  isTablet,
                ),
              ),

              const SizedBox(height: 16),

              if (session.unitPrice != null)
                _buildInfoItem(
                  'سعر اللتر وقت الفتح',
                  '${session.unitPrice!.toStringAsFixed(2)} ريال',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelTotalsSummary(
    Map<String, _FuelTotals> fuelTotals,
    bool isMobile,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجمالي الوقود حسب النوع',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.mediumGray,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fuelTotals.entries.map((entry) {
            final value = entry.value;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: isMobile ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.successGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${value.liters.toStringAsFixed(2)} لتر',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: AppColors.darkGray,
                    ),
                  ),
                  if (value.amount > 0)
                    Text(
                      '${value.amount.toStringAsFixed(2)} ريال',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPumpFuelDetails(
    PumpSession session,
    String pumpNumber,
    Map<String, List<NozzleReading>> fuelMap,
    bool isMobile,
    bool isTablet,
  ) {
    final pumpReadings = fuelMap.values.expand((list) => list);
    final pumpLiters = pumpReadings
        .map(_calculateReadingLiters)
        .fold(0.0, (prev, liters) => prev + liters);
    final pumpAmount = pumpReadings
        .map((reading) => _calculateReadingAmount(reading, session))
        .fold(0.0, (prev, amount) => prev + amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
        color: AppColors.lightGray.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_gas_station,
                size: 20,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'المضخات رقم $pumpNumber',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const Spacer(),
              if (pumpLiters > 0 || pumpAmount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${pumpLiters.toStringAsFixed(1)} لتر',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.infoBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          for (final fuelEntry in fuelMap.entries)
            _buildFuelGroup(session, fuelEntry.key, fuelEntry.value, isMobile),

          if (pumpLiters > 0 || pumpAmount > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGray.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'إجمالي المضخات:',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${pumpLiters.toStringAsFixed(2)} لتر',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGray,
                    ),
                  ),
                  if (pumpAmount > 0) ...[
                    const SizedBox(width: 16),
                    Text(
                      '${pumpAmount.toStringAsFixed(2)} ريال',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFuelGroup(
    PumpSession session,
    String fuelType,
    List<NozzleReading> nozzles,
    bool isMobile,
  ) {
    final fuelLiters = nozzles
        .map(_calculateReadingLiters)
        .fold(0.0, (prev, liters) => prev + liters);
    final fuelAmount = nozzles
        .map((reading) => _calculateReadingAmount(reading, session))
        .fold(0.0, (prev, amount) => prev + amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
        color: AppColors.successGreen.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fuelType,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text('${nozzles.length} ليّة'),
                backgroundColor: AppColors.successGreen.withOpacity(0.2),
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (fuelLiters > 0 || fuelAmount > 0)
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'الإجمالي:',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${fuelLiters.toStringAsFixed(2)} لتر',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: AppColors.darkGray,
                    ),
                  ),
                  if (fuelAmount > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${fuelAmount.toStringAsFixed(2)} ريال',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          for (final nozzle in nozzles)
            _buildNozzleOpeningDetails(nozzle, isMobile),
        ],
      ),
    );
  }

  Widget _buildNozzleOpeningDetails(NozzleReading reading, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فتحة ${reading.nozzleNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGray,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getPositionText(reading.position),
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.infoBlue.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '${reading.openingReading.toStringAsFixed(2)} لتر',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.infoBlue,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (reading.openingImageUrl != null &&
              reading.openingImageUrl!.isNotEmpty)
            _buildReadingImageSection(
              'صورة الفتح',
              reading.openingImageUrl!,
              isMobile,
            ),

          if (reading.attachmentPath != null &&
              reading.attachmentPath!.isNotEmpty)
            _buildNozzleAttachment(reading.attachmentPath!, isMobile),
        ],
      ),
    );
  }

  Widget _buildPumpFullReadingsSection(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    final readings = session.nozzleReadings ?? [];
    if (readings.isEmpty) return const SizedBox.shrink();

    final grouped = _groupByPumpAndFuel(readings);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل المضخات والقراءات',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),

            ...grouped.entries.map(
              (pumpEntry) => _buildPumpFullCard(
                session,
                pumpEntry.key,
                pumpEntry.value,
                isMobile,
                isTablet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpFullCard(
    PumpSession session,
    String pumpNumber,
    Map<String, List<NozzleReading>> fuelMap,
    bool isMobile,
    bool isTablet,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
        color: AppColors.lightGray.withOpacity(0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_gas_station,
                size: 20,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                '🚛 المضخات رقم $pumpNumber',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          for (final fuelEntry in fuelMap.entries)
            _buildFuelFullDetails(
              session,
              fuelEntry.key,
              fuelEntry.value,
              isMobile,
            ),
        ],
      ),
    );
  }

  Widget _buildFuelFullDetails(
    PumpSession session,
    String fuelType,
    List<NozzleReading> nozzles,
    bool isMobile,
  ) {
    double totalLiters = 0;
    double expectedAmount = 0;

    for (final n in nozzles) {
      totalLiters += _calculateReadingLiters(n);
      expectedAmount += _calculateReadingAmount(n, session);
    }

    final diff = session.calculatedDifference ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
        color: AppColors.successGreen.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_gas_station,
                size: 16,
                color: AppColors.successGreen,
              ),
              const SizedBox(width: 6),
              Text(
                '⛽ $fuelType',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Opening Readings
          Text(
            '🔓 قراءات الفتح',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          ...nozzles.map((n) => _buildOpeningRow(n, isMobile)),

          const SizedBox(height: 12),

          // Closing Readings
          if (session.status != 'مفتوحة') ...[
            Text(
              '🔒 قراءات الغلق',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            ...nozzles.map((n) => _buildClosingRow(n, session, isMobile)),
            const SizedBox(height: 12),
          ],

          // Totals
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Column(
              children: [
                _buildCalcRow(
                  'إجمالي اللترات',
                  '$totalLiters لتر',
                  isMobile: isMobile,
                ),
                _buildCalcRow(
                  'المبلغ المتوقع',
                  '${expectedAmount.toStringAsFixed(2)} ريال',
                  isMobile: isMobile,
                ),
                _buildCalcRow(
                  'الفرق',
                  '${diff >= 0 ? 'زيادة' : 'عجز'} ${diff.abs().toStringAsFixed(2)} ريال',
                  color: diff >= 0
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningRow(NozzleReading n, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'لي ${n.nozzleNumber}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ),
          Text(
            n.openingReading.toStringAsFixed(2),
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: AppColors.infoBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingRow(NozzleReading n, PumpSession session, bool isMobile) {
    if (n.closingReading == null) return const SizedBox.shrink();

    final liters = _calculateReadingLiters(n);
    final amount = _calculateReadingAmount(n, session);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'لي ${n.nozzleNumber}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${liters.toStringAsFixed(2)} لتر',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${amount.toStringAsFixed(2)} ريال',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: AppColors.darkGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalcRow(
    String label,
    String value, {
    Color? color,
    required bool isMobile,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGray,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 13,
              color: color ?? AppColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingImagesCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    final readings = session.nozzleReadings ?? [];

    final closingReadings = readings
        .where(
          (r) => r.closingImageUrl != null && r.closingImageUrl!.isNotEmpty,
        )
        .toList();

    if (closingReadings.isEmpty) return const SizedBox.shrink();

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  '📸 صور قراءات الغلق',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 18
                        : isTablet
                        ? 20
                        : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: closingReadings.map((reading) {
                return SizedBox(
                  width: isMobile ? double.infinity : 300,
                  child: AppSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المضخات ${reading.pumpNumber} – لي ${reading.nozzleNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGray,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'نوع الوقود: ${reading.fuelType}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildReadingImageSection(
                            '',
                            reading.closingImageUrl!,
                            isMobile,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicOpeningDetailsCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    // 🔹 تجميع الليّات حسب المضخات
    final Map<String, List<NozzleReading>> pumpsMap = {};
    for (final n in session.nozzleReadings ?? []) {
      pumpsMap.putIfAbsent(n.pumpNumber, () => []).add(n);
    }

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= العنوان =================
            Text(
              'تفاصيل فتح الجلسة',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),

            const SizedBox(height: 16),

            // ================= معلومات عامة =================
            _buildResponsiveInfoGrid(
              [
                _buildInfoItem(
                  'وقت الفتح',
                  DateFormat('yyyy/MM/dd HH:mm').format(session.openingTime),
                ),
                if (session.openingEmployeeName != null &&
                    session.openingEmployeeName!.isNotEmpty)
                  _buildInfoItem('موظف الفتح', session.openingEmployeeName!),
                _buildInfoItemWithColor(
                  'حالة اعتماد الفتح',
                  session.openingApproved
                      ? 'معتمدة من الأدمن'
                      : 'قيد انتظار اعتماد الأدمن',
                  session.openingApproved
                      ? AppColors.successGreen
                      : AppColors.warningOrange,
                ),
              ],
              isMobile,
              isTablet,
            ),

            const SizedBox(height: 24),

            // ================= تفاصيل المضخات =================
            ...pumpsMap.entries.map((pumpEntry) {
              final pumpNumber = pumpEntry.key;
              final nozzles = pumpEntry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                  ),
                  color: AppColors.primaryBlue.withOpacity(0.03),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- عنوان المضخات ----------
                    Text(
                      '🚛 المضخات رقم $pumpNumber',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ---------- الليّات ----------
                    ...nozzles.map((nozzle) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(isMobile ? 10 : 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.lightGray.withOpacity(0.6),
                          ),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // صف علوي
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'لِيّة ${nozzle.nozzleNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    nozzle.side == 'left' ? 'يسار' : 'يمين',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: nozzle.side == 'left'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  side: BorderSide.none,
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // نوع الوقود + القراءة
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _buildMiniInfo('نوع الوقود', nozzle.fuelType),
                                _buildMiniInfo(
                                  'قراءة الفتح',
                                  nozzle.openingReading.toStringAsFixed(2),
                                ),
                              ],
                            ),

                            // ---------- صورة الفتح ----------
                            if (nozzle.openingImageUrl != null &&
                                nozzle.openingImageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  nozzle.openingImageUrl!,
                                  height: isMobile ? 120 : 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    color: AppColors.lightGray.withOpacity(0.2),
                                    child: const Text('تعذر تحميل الصورة'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildClosingDetailsCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل إغلاق الجلسة',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildResponsiveInfoGrid(
              [
                if (session.closingReading != null)
                  _buildInfoItem(
                    'قراءة الإغلاق',
                    session.closingReading!.toStringAsFixed(2),
                  ),
                if (session.closingTime != null)
                  _buildInfoItem(
                    'وقت الإغلاق',
                    DateFormat('yyyy/MM/dd HH:mm').format(session.closingTime!),
                  ),
                if (session.closingEmployeeName != null)
                  _buildInfoItem('موظف الإغلاق', session.closingEmployeeName!),
                if (session.status == 'مغلقة' || session.status == 'معتمدة')
                  _buildInfoItemWithColor(
                    'حالة اعتماد الإغلاق',
                    session.closingApproved ? 'معتمدة' : 'قيد الانتظار',
                    session.closingApproved
                        ? AppColors.successGreen
                        : AppColors.warningOrange,
                  ),
                if (session.closingApproved &&
                    session.closingApprovedBy != null)
                  _buildInfoItem('معتمد بواسطة', session.closingApprovedBy!),
                if (session.closingApprovedAt != null)
                  _buildInfoItem(
                    'تاريخ اعتماد الإغلاق',
                    session.closingApprovedAt != null
                        ? DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(session.closingApprovedAt!)
                        : '',
                  ),
              ],
              isMobile,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryCard(
    PumpSession session,
    _SessionTotals sessionTotals,
    double actualSales,
    double differenceValue,
    double averagePrice,
    bool isMobile,
    bool isTablet,
  ) {
    final readings = session.nozzleReadings ?? [];
    if (readings.isEmpty) return const SizedBox.shrink();

    /// =======================
    /// تجميع حسب (المضخات + نوع وقود + سعر)
    /// =======================
    final Map<String, _SalesRow> rows = {};

    for (final r in readings) {
      final liters = _calculateReadingLiters(r);
      if (liters <= 0) continue;

      final unitPrice = _resolveReadingUnitPrice(r, session);
      final key = '${r.pumpNumber}_${r.fuelType}_$unitPrice';

      rows.putIfAbsent(
        key,
        () => _SalesRow(
          pumpNumber: r.pumpNumber,
          fuelType: r.fuelType,
          unitPrice: unitPrice,
        ),
      );

      rows[key]!.liters += liters;
    }

    double grandTotal = 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: 16,
      ),
      child: AppSurfaceCard(
        borderRadius: BorderRadius.circular(18),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.table_chart,
                    color: AppColors.primaryBlue,
                    size: isMobile ? 22 : 26,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'إجمالي المبيعات حسب المضخات ونوع الوقود',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ================= TABLE HEADER =================
            _buildSalesTableHeader(),

            // ================= TABLE ROWS =================
            ...rows.values.map((row) {
              final total = row.liters * row.unitPrice;
              grandTotal += total;

              return _buildSalesTableRow(row: row, total: total);
            }).toList(),

            const SizedBox(height: 12),

            // ================= GRAND TOTAL (تحت الجدول مباشرة) =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.successGreen.withOpacity(0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.summarize,
                    color: AppColors.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'الإجمالي الكلي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${grandTotal.toStringAsFixed(2)} ريال',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),

            // ================= PAYMENTS =================
            if (session.paymentTypes.total > 0) ...[
              const SizedBox(height: 20),
              _buildPaymentSummaryCard(session, isMobile, isTablet),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.4)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              'المضخات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'نوع الوقود',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'سعر اللتر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'اللترات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الإجمالي',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.mediumGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: AppSurfaceCard(
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'طرق الدفع',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildPaymentItem(
              'نقدي',
              session.paymentTypes.cash,
              AppColors.successGreen,
              isMobile,
            ),
            _buildPaymentItem(
              'بطاقة',
              session.paymentTypes.card,
              AppColors.infoBlue,
              isMobile,
            ),
            _buildPaymentItem(
              'مدى',
              session.paymentTypes.mada,
              AppColors.primaryBlue,
              isMobile,
            ),
            _buildPaymentItem(
              'أخرى',
              session.paymentTypes.other,
              AppColors.mediumGray,
              isMobile,
            ),

            const Divider(height: 24),

            _buildPaymentItem(
              'الإجمالي',
              session.paymentTypes.total,
              AppColors.warningOrange,
              isMobile,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTableRow({required _SalesRow row, required double total}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('المضخات ${row.pumpNumber}')),
          Expanded(
            flex: 2,
            child: Text(
              row.fuelType,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${row.unitPrice.toStringAsFixed(2)} ريال'),
          ),
          Expanded(flex: 2, child: Text('${row.liters.toStringAsFixed(2)}')),
          Expanded(
            flex: 2,
            child: Text(
              '${total.toStringAsFixed(2)} ريال',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return AppSurfaceCard(
      color: color.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
    String type,
    double amount,
    Color color,
    bool isMobile, {
    bool isTotal = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isTotal ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTotal ? Icons.summarize : Icons.payment,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type,
              style: TextStyle(
                color: isTotal ? AppColors.darkGray : AppColors.mediumGray,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} ريال',
            style: TextStyle(
              color: color,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal
                  ? 16
                  : isMobile
                  ? 13
                  : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelSupplyCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'توريد وقود جديد',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 18
                        : isTablet
                        ? 20
                        : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResponsiveInfoGrid(
              [
                _buildInfoItem('نوع الوقود', session.fuelSupply!.fuelType),
                _buildInfoItem('الكمية', '${session.fuelSupply!.quantity} لتر'),
                if (session.fuelSupply!.tankerNumber != null)
                  _buildInfoItem(
                    'رقم التانكر',
                    session.fuelSupply!.tankerNumber!,
                  ),
                if (session.fuelSupply!.supplierName != null)
                  _buildInfoItem(
                    'اسم المورد',
                    session.fuelSupply!.supplierName!,
                  ),
              ],
              isMobile,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard(PumpSession session, bool isMobile, bool isTablet) {
    final totalExpenses = session.expenses!.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.money_off, color: AppColors.errorRed),
                const SizedBox(width: 8),
                Text(
                  'المصروفات',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 18
                        : isTablet
                        ? 20
                        : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...session.expenses!.map((expense) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.lightGray),
                  color: AppColors.lightGray.withOpacity(0.05),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense.description,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGray,
                              fontSize: isMobile ? 13 : 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.errorRed.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${expense.amount.toStringAsFixed(2)} ريال',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (expense.category.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mediumGray.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          expense.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),

            const Divider(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorRed.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.summarize, color: AppColors.errorRed),
                  const SizedBox(width: 12),
                  Text(
                    'إجمالي المصروفات',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGray,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${totalExpenses.toStringAsFixed(2)} ريال',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 16 : 18,
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(PumpSession session, bool isMobile, bool isTablet) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.balance, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'الرصيد والفرق',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 18
                        : isTablet
                        ? 20
                        : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResponsiveInfoGrid(
              [
                if (session.carriedForwardBalance != 0)
                  _buildInfoItem(
                    'الرصيد المرحل',
                    '${session.carriedForwardBalance.toStringAsFixed(2)} ريال',
                  ),
                if (session.calculatedDifference != null)
                  _buildInfoItemWithColor(
                    'الفرق المحسوب',
                    '${session.calculatedDifference!.toStringAsFixed(2)} ريال',
                    session.calculatedDifference! >= 0
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                if (session.actualDifference != null)
                  _buildInfoItem(
                    'الفرق الفعلي',
                    '${session.actualDifference!.toStringAsFixed(2)} ريال',
                  ),
                if (session.differenceReason != null)
                  _buildInfoItem('سبب الفرق', session.differenceReason!),
              ],
              isMobile,
              isTablet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(PumpSession session, bool isMobile, bool isTablet) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'ملاحظات',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 18
                        : isTablet
                        ? 20
                        : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGray.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: Text(
                session.notes!,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: AppColors.darkGray,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpBreakdownCard(
    PumpSession session,
    bool isMobile,
    bool isTablet,
  ) {
    final pumps = session.pumps ?? [];
    if (pumps.isEmpty) return const SizedBox.shrink();

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل المضخات',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: pumps.map((pump) {
                return _buildPumpBreakdownItem(pump, isMobile);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpBreakdownItem(PumpReading pump, bool isMobile) {
    final closingReading = pump.closingReading;
    final difference = closingReading != null
        ? closingReading - pump.openingReading
        : null;

    return Container(
      width: isMobile ? double.infinity : 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_gas_station,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المضخات ${pump.pumpNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.successGreen.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  pump.fuelType,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'قراءة الفتح',
            '${pump.openingReading.toStringAsFixed(2)} لتر',
          ),
          _buildInfoRow(
            'قراءة الإغلاق',
            closingReading != null
                ? '${closingReading.toStringAsFixed(2)} لتر'
                : 'لم يتم الإغلاق',
            valueColor: closingReading != null
                ? AppColors.darkGray
                : AppColors.mediumGray,
          ),
          if (difference != null)
            _buildInfoRow(
              'الفرق',
              '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)} لتر',
              valueColor: difference >= 0
                  ? AppColors.successGreen
                  : AppColors.errorRed,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.darkGray,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingImageSection(
    String label,
    String imageUrl,
    bool isMobile,
  ) {
    Future<void> _downloadImage() async {
      try {
        if (kIsWeb) {
          await web_platform.downloadUrl(
            imageUrl,
            filename:
                'reading_image_' +
                DateTime.now().millisecondsSinceEpoch.toString(),
          );
        } else {
          final uri = Uri.parse(imageUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (e) {
        debugPrint('Download image error: $e');
      }
    }

    Future<void> _openImageInNewTab() async {
      try {
        if (kIsWeb) {
          web_platform.openUrlInNewTab(imageUrl);
        } else {
          final uri = Uri.parse(imageUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppWebView,
              webViewConfiguration: const WebViewConfiguration(
                enableJavaScript: true,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Open image error: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],

        Stack(
          children: [
            GestureDetector(
              onTap: () => _showImageDialog(imageUrl),
              child: Container(
                height: isMobile ? 160 : 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.lightGray),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.lightGray.withOpacity(0.2),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      return Container(
                        color: AppColors.lightGray.withOpacity(0.2),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error,
                              color: AppColors.mediumGray,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'تعذر تحميل الصورة',
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  Tooltip(
                    message: 'فتح الصورة ',
                    child: InkWell(
                      onTap: _openImageInNewTab,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'تحميل الصورة',
                    child: InkWell(
                      onTap: _downloadImage,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNozzleAttachment(String attachmentPath, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الملف المرفوع:',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.mediumGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            // TODO: Open attachment
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightGray.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachmentPath.split('/').last,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.download, size: 16, color: AppColors.primaryBlue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text('صورة', style: TextStyle(color: Colors.white)),
            ),
            body: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          );
        },
      ),
    );
  }

  String _getPositionText(String positionCode) {
    switch (positionCode) {
      case 'USU.USU+':
      case 'right':
      case 'يمين':
        return 'اليمين';
      case 'USO3OOñ':
      case 'left':
      case 'يسار':
        return 'اليسار';
      default:
        return positionCode;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مفتوحة':
        return AppColors.infoBlue;
      case 'مغلقة':
        return AppColors.warningOrange;
      case 'معتمدة':
        return AppColors.successGreen;
      case 'ملغاة':
        return AppColors.errorRed;
      default:
        return AppColors.mediumGray;
    }
  }
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

class _SalesRow {
  final String pumpNumber;
  final String fuelType;
  final double unitPrice;
  double liters = 0;

  _SalesRow({
    required this.pumpNumber,
    required this.fuelType,
    required this.unitPrice,
  });
}
