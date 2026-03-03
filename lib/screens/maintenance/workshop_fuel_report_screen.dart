import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class WorkshopFuelReportScreen extends StatefulWidget {
  const WorkshopFuelReportScreen({super.key});

  @override
  State<WorkshopFuelReportScreen> createState() =>
      _WorkshopFuelReportScreenState();
}

class _WorkshopFuelReportScreenState extends State<WorkshopFuelReportScreen> {
  String? _stationId;
  String? _stationName;
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime _endDate = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      final provider = context.read<WorkshopFuelProvider>();
      _stationId = (args?['stationId'] ?? provider.settings?['stationId'])
          ?.toString();
      _stationName = (args?['stationName'] ?? provider.settings?['stationName'])
          ?.toString();
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    final provider = context.read<WorkshopFuelProvider>();
    _stationId ??= provider.settings?['stationId']?.toString();
    _stationName ??= provider.settings?['stationName']?.toString();

    if (_stationId == null || _stationId!.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    await provider.fetchRefuels(
      stationId: _stationId!,
      startDate: _startDate,
      endDate: _endDate,
    );
    await provider.fetchReadings(
      stationId: _stationId!,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  double _readNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _groupRefuelsByDay(
      List<Map<String, dynamic>> refuels) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final refuel in refuels) {
      final date = DateTime.tryParse(refuel['createdAt']?.toString() ?? '') ??
          DateTime.now();
      final key = DateFormat('yyyy/MM/dd').format(date);
      grouped.putIfAbsent(key, () {
        return {
          'date': key,
          'liters': 0.0,
          'totalAmount': 0.0,
          'count': 0,
        };
      });
      grouped[key]!['liters'] =
          (grouped[key]!['liters'] as double) + _readNum(refuel['liters']);
      grouped[key]!['totalAmount'] = (grouped[key]!['totalAmount'] as double) +
          _readNum(refuel['totalAmount']);
      grouped[key]!['count'] = (grouped[key]!['count'] as int) + 1;
    }

    final list = grouped.values.toList();
    list.sort((a, b) {
      final ad = DateFormat('yyyy/MM/dd').parse(a['date'] as String);
      final bd = DateFormat('yyyy/MM/dd').parse(b['date'] as String);
      return ad.compareTo(bd);
    });
    return list;
  }

  bool _isWithinSelectedRange(DateTime date) {
    final start = DateUtils.dateOnly(_startDate);
    final end = DateUtils.dateOnly(_endDate);
    final value = DateUtils.dateOnly(date);
    return !value.isBefore(start) && !value.isAfter(end);
  }

  List<Map<String, dynamic>> _filterRefuelsByRange(
      List<Map<String, dynamic>> refuels) {
    return refuels.where((refuel) {
      final date = DateTime.tryParse(refuel['createdAt']?.toString() ?? '');
      if (date == null) return false;
      return _isWithinSelectedRange(date);
    }).toList();
  }

  List<Map<String, dynamic>> _filterReadingsByRange(
      List<Map<String, dynamic>> readings) {
    return readings.where((reading) {
      final date = DateTime.tryParse(reading['readingDate']?.toString() ?? '');
      if (date == null) return false;
      return _isWithinSelectedRange(date);
    }).toList();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _loadReport();
  }

  Future<void> _exportPdf(WorkshopFuelProvider provider) async {
    final filteredRefuels = _filterRefuelsByRange(provider.refuels);
    final filteredReadings = _filterReadingsByRange(provider.readings);
    if (filteredRefuels.isEmpty && filteredReadings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }

    final pdf = pw.Document();
    final logo = pw.MemoryImage(
      (await rootBundle.load(AppImages.logo)).buffer.asUint8List(),
    );
    final arabicFontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final arabicFontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    final startText = DateFormat('yyyy/MM/dd').format(_startDate);
    final endText = DateFormat('yyyy/MM/dd').format(_endDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFontRegular,
          bold: arabicFontBold,
        ),
        build: (_) => [
          _buildPdfHeader(logo, '$startText - $endText'),
          pw.SizedBox(height: 4),
          _buildDailySummaryTable(filteredRefuels),
          pw.SizedBox(height: 4),
          _buildRefuelTable(filteredRefuels),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: _buildSummaryTable(provider, filteredRefuels),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 4,
                child: _buildReadingTable(
                  readings: filteredReadings,
                  currentBalance: provider.currentBalance,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _buildPdfFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkshopFuelProvider>();
    _stationName ??= provider.settings?['stationName']?.toString();
    final refuels = _filterRefuelsByRange(provider.refuels);
    final readings = _filterReadingsByRange(provider.readings);
    final dailySummary = _groupRefuelsByDay(refuels);

    final totalLiters = refuels.fold<double>(
      0,
      (sum, r) => sum + _readNum(r['liters']),
    );
    final totalAmount = refuels.fold<double>(
      0,
      (sum, r) => sum + _readNum(r['totalAmount']),
    );

    readings.sort((a, b) {
      final ad = DateTime.tryParse(a['readingDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['readingDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });

    final prevReading = readings.isNotEmpty
        ? _readNum(readings.first['previousReading'])
        : 0.0;
    final currentReading = readings.isNotEmpty
        ? _readNum(readings.last['currentReading'])
        : 0.0;
    final totalReadingLiters = readings.isNotEmpty
        ? _readNum(readings.last['totalLiters'])
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('تقرير وقود الورشة - ${_stationName ?? ''}'),
        actions: [
          IconButton(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
          IconButton(
            onPressed: () => _exportPdf(provider),
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSummaryChip('سعر اللتر',
                    provider.unitPrice > 0
                        ? '${provider.unitPrice.toStringAsFixed(2)} ريال'
                        : 'غير محدد'),
                const SizedBox(width: 12),
                _buildSummaryChip('إجمالي اللترات',
                    totalLiters.toStringAsFixed(2)),
                const SizedBox(width: 12),
                _buildSummaryChip('إجمالي المبلغ',
                    totalAmount.toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'التجميع اليومي',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDailySummaryTableUi(dailySummary),
            const SizedBox(height: 16),
            Text(
              'تفاصيل التعبئة',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRefuelTableUi(refuels),
            const SizedBox(height: 16),
            Text(
              'قراءات العداد',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildReadingTableUi(
              prevReading: prevReading,
              currentReading: currentReading,
              totalLiters: totalReadingLiters,
              currentBalance: provider.currentBalance,
            ),
            const SizedBox(height: 24),
            _buildSignaturesUi(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title: ', style: const TextStyle(color: AppColors.mediumGray)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRefuelTableUi(List<Map<String, dynamic>> refuels) {
    if (refuels.isEmpty) {
      return const Text('لا توجد بيانات في هذه الفترة');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('اسم السائق')),
          DataColumn(label: Text('رقم السيارة')),
          DataColumn(label: Text('اللترات')),
          DataColumn(label: Text('سعر اللتر')),
          DataColumn(label: Text('المبلغ')),
        ],
        rows: refuels.map((refuel) {
          final date = DateTime.tryParse(refuel['createdAt']?.toString() ?? '') ??
              DateTime.now();
          return DataRow(cells: [
            DataCell(Text(DateFormat('yyyy/MM/dd').format(date))),
            DataCell(Text(refuel['driverName']?.toString() ?? 'سائق غير معروف')),
            DataCell(Text(refuel['vehicleNumber']?.toString() ?? '--')),
            DataCell(Text(_readNum(refuel['liters']).toStringAsFixed(2))),
            DataCell(Text(_readNum(refuel['unitPrice']).toStringAsFixed(2))),
            DataCell(Text(_readNum(refuel['totalAmount']).toStringAsFixed(2))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildDailySummaryTableUi(List<Map<String, dynamic>> dailySummary) {
    if (dailySummary.isEmpty) {
      return const Text('لا يوجد بيانات في هذه الفترة');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('إجمالي اللترات')),
          DataColumn(label: Text('إجمالي المبلغ')),
          DataColumn(label: Text('عدد التعبئات')),
        ],
        rows: dailySummary.map((row) {
          return DataRow(cells: [
            DataCell(Text(row['date'].toString())),
            DataCell(Text((row['liters'] as double).toStringAsFixed(2))),
            DataCell(Text((row['totalAmount'] as double).toStringAsFixed(2))),
            DataCell(Text(row['count'].toString())),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildReadingTableUi({
    required double prevReading,
    required double currentReading,
    required double totalLiters,
    required double currentBalance,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('القراءة السابقة')),
          DataColumn(label: Text('القراءة الحالية')),
          DataColumn(label: Text('إجمالي اللترات')),
          DataColumn(label: Text('رصيد الخزان')),
        ],
        rows: [
          DataRow(cells: [
            DataCell(Text(prevReading.toStringAsFixed(2))),
            DataCell(Text(currentReading.toStringAsFixed(2))),
            DataCell(Text(totalLiters.toStringAsFixed(2))),
            DataCell(Text(currentBalance.toStringAsFixed(2))),
          ]),
        ],
      ),
    );
  }

  Widget _buildSignaturesUi() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Column(
          children: [
            Text('توقيع الفني'),
            SizedBox(height: 24),
            Text('__________________'),
          ],
        ),
        Column(
          children: [
            Text('اعتماد المدير'),
            SizedBox(height: 24),
            Text('__________________'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildRefuelTable(List<Map<String, dynamic>> refuels) {
    return pw.Table.fromTextArray(
      headers: const [
        'التاريخ',
        'اسم السائق',
        'رقم السيارة',
        'اللترات',
        'سعر اللتر',
        'المبلغ',
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      data: refuels.map((refuel) {
        final date = DateTime.tryParse(refuel['createdAt']?.toString() ?? '') ??
            DateTime.now();
        return [
          DateFormat('yyyy/MM/dd').format(date),
          refuel['driverName']?.toString() ?? 'سائق غير معروف',
          refuel['vehicleNumber']?.toString() ?? '--',
          _readNum(refuel['liters']).toStringAsFixed(2),
          _readNum(refuel['unitPrice']).toStringAsFixed(2),
          _readNum(refuel['totalAmount']).toStringAsFixed(2),
        ];
      }).toList(),
    );
  }

  pw.Widget _buildSummaryTable(
    WorkshopFuelProvider provider,
    List<Map<String, dynamic>> refuels,
  ) {
    final totalLiters = refuels
        .fold<double>(0, (sum, r) => sum + _readNum(r['liters']));
    final totalAmount = refuels
        .fold<double>(0, (sum, r) => sum + _readNum(r['totalAmount']));

    return pw.Table.fromTextArray(
      headers: const ['سعر اللتر', 'إجمالي اللترات', 'إجمالي المبلغ'],
      tableWidth: pw.TableWidth.max,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerPadding: const pw.EdgeInsets.all(1.2),
      cellPadding: const pw.EdgeInsets.all(1.2),
      cellAlignment: pw.Alignment.center,
      data: [
        [
          provider.unitPrice.toStringAsFixed(2),
          totalLiters.toStringAsFixed(2),
          totalAmount.toStringAsFixed(2),
        ]
      ],
    );
  }

  pw.Widget _buildReadingTable({
    required List<Map<String, dynamic>> readings,
    required double currentBalance,
  }) {
    final sortedReadings = [...readings];
    sortedReadings.sort((a, b) {
      final ad = DateTime.tryParse(a['readingDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['readingDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });

    final prevReading = sortedReadings.isNotEmpty
        ? _readNum(sortedReadings.first['previousReading'])
        : 0;
    final currentReading = sortedReadings.isNotEmpty
        ? _readNum(sortedReadings.last['currentReading'])
        : 0;
    final totalLiters = sortedReadings.isNotEmpty
        ? _readNum(sortedReadings.last['totalLiters'])
        : 0;

    return pw.Table.fromTextArray(
      headers: const [
        'القراءة السابقة',
        'القراءة الحالية',
        'إجمالي اللترات',
        'رصيد الخزان',
      ],
      tableWidth: pw.TableWidth.max,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerPadding: const pw.EdgeInsets.all(1.2),
      cellPadding: const pw.EdgeInsets.all(1.2),
      cellAlignment: pw.Alignment.center,
      data: [
        [
          prevReading.toStringAsFixed(2),
          currentReading.toStringAsFixed(2),
          totalLiters.toStringAsFixed(2),
          currentBalance.toStringAsFixed(2),
        ]
      ],
    );
  }

  pw.Widget _buildDailySummaryTable(List<Map<String, dynamic>> refuels) {
    final dailySummary = _groupRefuelsByDay(refuels);
    if (dailySummary.isEmpty) {
      return pw.Text('لا يوجد بيانات في هذه الفترة');
    }
    return pw.Table.fromTextArray(
      headers: const [
        'التاريخ',
        'إجمالي اللترات',
        'إجمالي المبلغ',
        'عدد التعبئات',
      ],
      tableWidth: pw.TableWidth.max,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerPadding: const pw.EdgeInsets.all(1.2),
      cellPadding: const pw.EdgeInsets.all(1.2),
      cellAlignment: pw.Alignment.center,
      data: dailySummary.map((row) {
        return [
          row['date'].toString(),
          (row['liters'] as double).toStringAsFixed(2),
          (row['totalAmount'] as double).toStringAsFixed(2),
          row['count'].toString(),
        ];
      }).toList(),
    );
  }

  pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Text('توقيع الفني'),
            pw.SizedBox(height: 24),
            pw.Text('__________________'),
          ],
        ),
        pw.Column(
          children: [
            pw.Text('اعتماد المدير'),
            pw.SizedBox(height: 24),
            pw.Text('__________________'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfHeader(pw.MemoryImage logoImage, String dateRange) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'شركة البحيرة العربية للنقليات',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'الرقم الوطني الموحد: 7011144750',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Divider(),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'تقرير وقود الورشة',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'الفترة: $dateRange',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              width: 80,
              height: 80,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Text('توقيع مسؤول الصيانة'),
                pw.SizedBox(height: 24),
                pw.Text('__________________'),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('اعتماد الادارة '),
                pw.SizedBox(height: 24),
                pw.Text('__________________'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'المملكة العربية السعودية - نظام نبراس | شركة البحيرة العربية',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }
}
