import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/stations/fuel_price_card.dart';
import 'package:order_tracker/widgets/stations/pump_card.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class StationDetailsScreen extends StatefulWidget {
  final String stationId;

  const StationDetailsScreen({super.key, required this.stationId});

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  int _selectedTab = 0;
  DateTime _selectedDate = DateTime.now();
  TabController? _tabController;
  final ScrollController _pumpsScrollController = ScrollController();
  final ScrollController _fuelPricesScrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  bool isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 1100;

  bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1100;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStationDetails();
    });
  }

  Future<void> _loadStationDetails() async {
    final provider = Provider.of<StationProvider>(context, listen: false);
    await provider.fetchStationById(
      widget.stationId,
      inventoryDate: _selectedDate,
    );
    await provider.fetchCurrentStock(widget.stationId);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      if (!mounted) return;
      await _loadStationDetails();
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _pumpsScrollController.dispose();
    _fuelPricesScrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null) return;
    if (!controller.indexIsChanging) {
      setState(() {
        _selectedTab = controller.index;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  List<_StationFuelStockRow> _buildFuelStockRows(
    Station station,
    List<Map<String, dynamic>> currentStock,
  ) {
    final rowsByFuel = <String, Map<String, dynamic>>{};

    for (final row in currentStock) {
      final fuelType = row['fuelType']?.toString().trim() ?? '';
      if (fuelType.isEmpty) continue;
      rowsByFuel[fuelType] = row;
    }

    final orderedFuelTypes = <String>[
      ...station.fuelTypes,
      ...rowsByFuel.keys.where((fuelType) => !station.fuelTypes.contains(fuelType)),
    ];

    return orderedFuelTypes.map((fuelType) {
      final row = rowsByFuel[fuelType];
      final actualStock = _toDouble(
        row?['inventoryReferenceBalance'] ?? row?['currentBalance'],
      );
      final sales = _toDouble(row?['salesSinceInventory']);
      final remainingStock = _toDouble(row?['currentBalance']);
      final capacity = _toDouble(row?['capacity']);

      return _StationFuelStockRow(
        fuelType: fuelType,
        actualStock: actualStock,
        sales: sales,
        remainingStock: remainingStock,
        capacity: capacity,
      );
    }).toList();
  }

  String _formatLiters(double value) => '${value.toStringAsFixed(2)} لتر';

  String _sanitizeFilePart(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  Future<void> _printStockReport(
    Station station,
    List<_StationFuelStockRow> rows,
  ) async {
    final bytes = await _buildStockPdf(station, rows);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _exportStockPdf(
    Station station,
    List<_StationFuelStockRow> rows,
  ) async {
    final bytes = await _buildStockPdf(station, rows);
    final fileStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final stationName = _sanitizeFilePart(station.stationName);
    await saveAndLaunchFile(bytes, 'مخزون_${stationName}_$fileStamp.pdf');
  }

  Future<void> _exportStockExcel(
    Station station,
    List<_StationFuelStockRow> rows,
  ) async {
    final bytes = await _buildStockExcel(station, rows);
    final fileStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final stationName = _sanitizeFilePart(station.stationName);
    await saveAndLaunchFile(
      bytes,
      'مخزون_${stationName}_$fileStamp.xlsx',
    );
  }

  Future<Uint8List> _buildStockPdf(
    Station station,
    List<_StationFuelStockRow> rows,
  ) async {
    final arabicFontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final arabicFontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    final theme = pw.ThemeData.withFont(
      base: arabicFontRegular,
      bold: arabicFontBold,
      fontFallback: [arabicFontRegular],
    );

    final totalActual = rows.fold<double>(
      0,
      (sum, row) => sum + row.actualStock,
    );
    final totalSales = rows.fold<double>(0, (sum, row) => sum + row.sales);
    final totalRemaining = rows.fold<double>(
      0,
      (sum, row) => sum + row.remainingStock,
    );

    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Text(
            'تقرير مخزون المحطة',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('المحطة: ${station.stationName}'),
          pw.Text('تاريخ التصدير: ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'الوقود',
              'المخزون الفعلي',
              'المبيعات',
              'المتبقي بعد المبيعات',
              'سعة الخزان',
            ],
            data: rows
                .map(
                  (row) => [
                    row.fuelType,
                    row.actualStock.toStringAsFixed(2),
                    row.sales.toStringAsFixed(2),
                    row.remainingStock.toStringAsFixed(2),
                    row.capacity.toStringAsFixed(2),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Text('إجمالي المخزون الفعلي: ${totalActual.toStringAsFixed(2)} لتر'),
              pw.Text('إجمالي المبيعات: ${totalSales.toStringAsFixed(2)} لتر'),
              pw.Text('إجمالي المتبقي: ${totalRemaining.toStringAsFixed(2)} لتر'),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _buildStockExcel(
    Station station,
    List<_StationFuelStockRow> rows,
  ) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'مخزون المحطة';
    sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;

    final titleStyle = workbook.styles.add('stationStockTitle');
    titleStyle.bold = true;
    titleStyle.fontSize = 14;
    titleStyle.hAlign = xlsio.HAlignType.center;
    titleStyle.vAlign = xlsio.VAlignType.center;

    final headerStyle = workbook.styles.add('stationStockHeader');
    headerStyle.bold = true;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    final dataStyle = workbook.styles.add('stationStockData');
    dataStyle.hAlign = xlsio.HAlignType.center;
    dataStyle.vAlign = xlsio.VAlignType.center;
    dataStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    sheet.getRangeByName('A1:E1').merge();
    sheet.getRangeByName('A1').setText('تقرير مخزون المحطة - ${station.stationName}');
    sheet.getRangeByName('A1').cellStyle = titleStyle;
    sheet.getRangeByName('A2:E2').merge();
    sheet.getRangeByName('A2').setText(
      'تاريخ التصدير: ${_dateFormat.format(DateTime.now())}',
    );

    const headers = [
      'الوقود',
      'المخزون الفعلي',
      'المبيعات',
      'المتبقي بعد المبيعات',
      'سعة الخزان',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < rows.length; i++) {
      final rowIndex = i + 4;
      final row = rows[i];
      final values = [
        row.fuelType,
        row.actualStock.toStringAsFixed(2),
        row.sales.toStringAsFixed(2),
        row.remainingStock.toStringAsFixed(2),
        row.capacity.toStringAsFixed(2),
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.getRangeByIndex(rowIndex, col + 1);
        cell.setText(values[col]);
        cell.cellStyle = dataStyle;
      }
    }

    final totalRowIndex = rows.length + 5;
    final totalActual = rows.fold<double>(
      0,
      (sum, row) => sum + row.actualStock,
    );
    final totalSales = rows.fold<double>(0, (sum, row) => sum + row.sales);
    final totalRemaining = rows.fold<double>(
      0,
      (sum, row) => sum + row.remainingStock,
    );

    sheet.getRangeByIndex(totalRowIndex, 1).setText('الإجمالي');
    sheet.getRangeByIndex(totalRowIndex, 2).setText(totalActual.toStringAsFixed(2));
    sheet.getRangeByIndex(totalRowIndex, 3).setText(totalSales.toStringAsFixed(2));
    sheet.getRangeByIndex(
      totalRowIndex,
      4,
    ).setText(totalRemaining.toStringAsFixed(2));

    for (int col = 1; col <= 5; col++) {
      sheet.getRangeByIndex(totalRowIndex, col).cellStyle = headerStyle;
      sheet.autoFitColumn(col);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role == 'owner';
    final station = stationProvider.selectedStation;
    final sessions = stationProvider.sessions;
    final stockRows = station == null
        ? const <_StationFuelStockRow>[]
        : _buildFuelStockRows(station, stationProvider.currentStock);

    final web = isWeb(context);

    if (stationProvider.isLoading && station == null) {
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

    if (station == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          ),
          title: const Text('تفاصيل المحطة'),
          centerTitle: true,
        ),
        body: Stack(
          children: const [
            AppSoftBackground(),
            Center(
              child: AppSurfaceCard(
                child: Text(
                  'المحطة غير موجودة',
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          if (_tabController != controller) {
            _tabController?.removeListener(_handleTabChange);
            _tabController = controller;
            _tabController?.addListener(_handleTabChange);
            _selectedTab = controller?.index ?? 0;
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
              title: Text(
                station.stationName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              actions: [
                // تسعيرة الوقود (عرض التسعيرة)
                IconButton(
                  tooltip: 'تسعيرة الوقود',
                  icon: const Icon(Icons.local_gas_station),
                  onPressed: () {
                    _showFuelPricingDialog(context, station);
                  },
                ),

                // صرف مخزون
                IconButton(
                  tooltip: 'صرف مخزون',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    _showStockDisbursementDialog(
                      context: context,
                      station: station,
                      stockRows: stockRows,
                    );
                  },
                ),

                // تحويل مخزون
                IconButton(
                  tooltip: 'تحويل مخزون',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    _showStockTransferDialog(
                      context: context,
                      station: station,
                      stockRows: stockRows,
                    );
                  },
                ),

                // تعديل بيانات المحطة
                IconButton(
                  tooltip: 'تعديل المحطة',
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/station/form',
                      arguments: station,
                    );
                  },
                ),

                // حذف المحطة (للمالك فقط)
                if (isOwner)
                  IconButton(
                    tooltip: 'حذف المحطة',
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('تأكيد الحذف'),
                          content: const Text(
                            'هل أنت متأكد من حذف المحطة؟ لا يمكن التراجع عن هذا الإجراء.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.errorRed,
                              ),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      final success = await stationProvider.deleteStation(
                        station.id,
                      );

                      if (!mounted) return;

                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حذف المحطة بنجاح'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              stationProvider.error ?? 'فشل حذف المحطة',
                            ),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                      }
                    },
                  ),

                // اختيار التاريخ
                IconButton(
                  tooltip: 'اختيار التاريخ',
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
                PopupMenuButton<String>(
                  tooltip: 'تصدير المخزون',
                  icon: const Icon(Icons.download_outlined),
                  onSelected: (value) async {
                    if (stockRows.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا توجد بيانات مخزون للتصدير'),
                          backgroundColor: AppColors.warningOrange,
                        ),
                      );
                      return;
                    }

                    if (value == 'print') {
                      await _printStockReport(station, stockRows);
                      return;
                    }

                    if (value == 'pdf') {
                      await _exportStockPdf(station, stockRows);
                      return;
                    }

                    await _exportStockExcel(station, stockRows);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(Icons.print_outlined),
                        title: Text('طباعة'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('PDF'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'excel',
                      child: ListTile(
                        leading: Icon(Icons.table_view_outlined),
                        title: Text('Excel'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                onTap: (index) {
                  _tabController?.animateTo(index);
                },

                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,

                // (اختياري) شكل الخط
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),

                tabs: const [
                  Tab(text: 'نظرة عامة'),
                  Tab(text: 'المضخات'),
                  Tab(text: 'جلسات اليوم'),
                ],
              ),
            ),

            body: Stack(
              children: [
                const AppSoftBackground(),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TabBarView(
                        children: [
                          _buildOverviewTab(station),
                          _buildPumpsTab(station),
                          _buildSessionsTab(sessions),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: _selectedTab == 1 && !web
                ? FloatingActionButton(
                    onPressed: () {
                      _showAddPumpDialog(context, station);
                    },
                    child: const Icon(Icons.add),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(Station station) {
    final double w = MediaQuery.of(context).size.width;
    final bool web = w >= 1100;
    final bool tablet = w >= 700 && w < 1100;

    // عرض مناسب للكروت على الويب (مايبقاش عريض زيادة)
    final double maxWidth = web ? 1100 : double.infinity;

    // مقاسات موحّدة
    final double outerPadding = web ? 12 : 16;
    final double cardPadding = web ? 16 : 20;
    final double titleSize = web ? 15 : 16;
    final double headerSize = web ? 18 : 20;
    final double gap = web ? 12 : 16;

    Widget sectionCard({
      required String title,
      required Widget child,
      double? titleFont,
    }) {
      return AppSurfaceCard(
        padding: EdgeInsets.all(cardPadding),
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: titleFont ?? titleSize,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(height: web ? 10 : 15),
            child,
          ],
        ),
      );
    }

    // ================= Station Info Content =================

    final stationInfo = sectionCard(
      title: 'معلومات المحطة',
      titleFont: headerSize,
      child: web
          // ================= WEB: Grid =================
          ? GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // عمودين
                crossAxisSpacing: 20,
                mainAxisSpacing: 11,
                childAspectRatio: 7.2, // 👈 يطوّل الكارت ويقلل العرض
              ),
              children: [
                _buildInfoRow('كود المحطة', station.stationCode),
                _buildInfoRow('اسم المحطة', station.stationName),
                _buildInfoRow(
                  'الموقع',
                  '${station.city} - ${station.location}',
                ),
                _buildInfoRow('اسم المدير', station.managerName),
                _buildInfoRow('هاتف المدير', station.managerPhone),
                _buildInfoRow(
                  'تاريخ الإنشاء',
                  DateFormat('yyyy/MM/dd').format(station.createdAt),
                ),
                _buildInfoRow(
                  'الحالة',
                  station.isActive ? 'نشطة' : 'غير نشطة',
                  valueColor: station.isActive
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                ),
              ],
            )
          // ================= MOBILE / TABLET: Column =================
          : Column(
              children: [
                _buildInfoRow('كود المحطة', station.stationCode),
                _buildInfoRow('اسم المحطة', station.stationName),
                _buildInfoRow(
                  'الموقع',
                  '${station.city} - ${station.location}',
                ),
                _buildInfoRow('اسم المدير', station.managerName),
                _buildInfoRow('هاتف المدير', station.managerPhone),
                _buildInfoRow(
                  'تاريخ الإنشاء',
                  DateFormat('yyyy/MM/dd').format(station.createdAt),
                ),
                _buildInfoRow(
                  'الحالة',
                  station.isActive ? 'نشطة' : 'غير نشطة',
                  valueColor: station.isActive
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                ),
              ],
            ),
    );

    // ================= Fuel Types Content =================
    final fuelTypes = sectionCard(
      title: 'أنواع الوقود المتاحة',
      child: Wrap(
        spacing: web ? 8 : 10,
        runSpacing: web ? 8 : 10,
        children: station.fuelTypes.map((fuelType) {
          return Chip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.symmetric(
              horizontal: web ? 8 : 10,
              vertical: web ? 0 : 2,
            ),
            label: Text(
              fuelType,
              style: TextStyle(
                fontSize: web ? 12 : 14,
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.primaryBlue.withOpacity(0.10),
          );
        }).toList(),
      ),
    );

    // ================= Pumps Summary Content =================
    final pumpsSummary = SizedBox(
      height: web ? 280 : 320,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'المضخات',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const Spacer(),
                Chip(label: Text('${station.pumps.length}')),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: station.pumps.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد المضخات',
                        style: TextStyle(color: AppColors.mediumGray),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      controller: _pumpsScrollController,
                      child: ListView.separated(
                        controller: _pumpsScrollController,
                        primary: false,
                        physics: const BouncingScrollPhysics(),
                        itemCount: station.pumps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          return PumpCard(pump: station.pumps[index]);
                        },
                      ),
                    ),
            ),
            if (station.pumps.length > 3)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () {
                    _tabController?.animateTo(1);
                  },
                  child: const Text('عرض جميع المضخات'),
                ),
              ),
          ],
        ),
      ),
    );

    // ================= Fuel Prices Content =================
    final fuelPrices = sectionCard(
      title: 'أسعار الوقود',
      child: station.fuelPrices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لا توجد أسعار',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
            )
          : SizedBox(
              height: 220, // 👈 ارتفاع ثابت للكارت
              child: Scrollbar(
                thumbVisibility: true,
                controller: _fuelPricesScrollController,
                child: ListView.separated(
                  controller: _fuelPricesScrollController,
                  primary: false,
                  itemCount: station.fuelPrices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return FuelPriceCard(price: station.fuelPrices[index]);
                  },
                ),
              ),
            ),
    );

    final stockRows = _buildFuelStockRows(
      station,
      context.watch<StationProvider>().currentStock,
    );

    final statistics = sectionCard(
      title: 'ملخص مخزون المحطة',
      child: _buildStockSummaryContent(stockRows, web, tablet),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(outerPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (web || tablet) ...[
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: web ? 2 : 1,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    childAspectRatio: web ? 2.2 : 1.6,
                  ),
                  children: [stationInfo, fuelTypes],
                ),
                SizedBox(height: gap),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: web ? 2 : 1,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    childAspectRatio: web ? 1.7 : 1.35,
                  ),
                  children: [pumpsSummary, fuelPrices],
                ),
                SizedBox(height: gap),
                statistics,
              ] else ...[
                stationInfo,
                SizedBox(height: gap),
                fuelTypes,
                SizedBox(height: gap),
                pumpsSummary,
                SizedBox(height: gap),
                if (station.fuelPrices.isNotEmpty) fuelPrices,
                SizedBox(height: gap),
                statistics,
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockSummaryContent(
    List<_StationFuelStockRow> rows,
    bool web,
    bool tablet,
  ) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'لا توجد بيانات مخزون حالية لهذه المحطة',
          style: TextStyle(color: AppColors.mediumGray),
        ),
      );
    }

    final totalActual = rows.fold<double>(
      0,
      (sum, row) => sum + row.actualStock,
    );
    final totalSales = rows.fold<double>(0, (sum, row) => sum + row.sales);
    final totalRemaining = rows.fold<double>(
      0,
      (sum, row) => sum + row.remainingStock,
    );

    final chartColors = <Color>[
      AppColors.primaryBlue,
      AppColors.infoBlue,
      AppColors.warningOrange,
      AppColors.successGreen,
      AppColors.mediumGray,
    ];

    final chartData = rows.asMap().entries.map((entry) {
      final row = entry.value;
      return <String, dynamic>{
        'fuelType': row.fuelType,
        'value': row.remainingStock,
        'color': chartColors[entry.key % chartColors.length],
      };
    }).toList();

    final metrics = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStockMetricCard(
          label: 'إجمالي المخزون الفعلي',
          value: _formatLiters(totalActual),
          color: AppColors.primaryBlue,
        ),
        _buildStockMetricCard(
          label: 'إجمالي المبيعات',
          value: _formatLiters(totalSales),
          color: AppColors.warningOrange,
        ),
        _buildStockMetricCard(
          label: 'إجمالي المتبقي',
          value: _formatLiters(totalRemaining),
          color: AppColors.successGreen,
        ),
      ],
    );

    final chart = SizedBox(
      height: web ? 220 : 260,
      child: SfCircularChart(
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          textStyle: TextStyle(fontFamily: 'Cairo', fontSize: web ? 11 : 12),
        ),
        series: <CircularSeries>[
          DoughnutSeries<Map<String, dynamic>, String>(
            dataSource: chartData,
            xValueMapper: (data, _) => data['fuelType'] as String,
            yValueMapper: (data, _) => data['value'] as double,
            pointColorMapper: (data, _) => data['color'] as Color,
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.outside,
              textStyle: TextStyle(fontFamily: 'Cairo', fontSize: web ? 10 : 12),
            ),
          ),
        ],
      ),
    );

    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          AppColors.primaryBlue.withOpacity(0.08),
        ),
        columns: const [
          DataColumn(label: Text('الوقود')),
          DataColumn(label: Text('المخزون الفعلي')),
          DataColumn(label: Text('المبيعات')),
          DataColumn(label: Text('المتبقي')),
          DataColumn(label: Text('السعة')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.fuelType)),
                  DataCell(Text(_formatLiters(row.actualStock))),
                  DataCell(Text(_formatLiters(row.sales))),
                  DataCell(Text(_formatLiters(row.remainingStock))),
                  DataCell(Text(_formatLiters(row.capacity))),
                ],
              ),
            )
            .toList(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        metrics,
        const SizedBox(height: 16),
        if (web || tablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: chart),
              const SizedBox(width: 16),
              Expanded(child: table),
            ],
          )
        else ...[
          chart,
          const SizedBox(height: 16),
          table,
        ],
      ],
    );
  }

  Widget _buildStockMetricCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPumpDialog(BuildContext rootContext, Station station) {
    final TextEditingController pumpNumberController = TextEditingController();
    final stationProvider = Provider.of<StationProvider>(
      rootContext,
      listen: false,
    );
    final bool web = isWeb(rootContext);
    final List<NozzleData> nozzlesData = [NozzleData(position: 'يمين')];
    bool isActive = true;
    bool isSubmitting = false;

    showDialog(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void addNozzle() {
              nozzlesData.add(NozzleData(position: 'يمين'));
              setState(() {});
            }

            void removeNozzle(int index) {
              nozzlesData.removeAt(index);
              setState(() {});
            }

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: web ? 400 : 24,
                vertical: 24,
              ),
              title: const Text(
                'Add pump',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: web ? 420 : double.infinity,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pumpNumberController,
                        decoration: InputDecoration(
                          labelText: 'Pump number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.primaryBlue.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nozzles',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: addNozzle,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (nozzlesData.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.mediumGray.withOpacity(0.3),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'No nozzles yet',
                              style: TextStyle(color: AppColors.mediumGray),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: List.generate(nozzlesData.length, (index) {
                            final nozzle = nozzlesData[index];
                            final bool isLast = index == nozzlesData.length - 1;
                            return Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGray.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.mediumGray.withOpacity(
                                      0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Nozzle ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: AppColors.errorRed,
                                            size: 20,
                                          ),
                                          onPressed: () => removeNozzle(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.infoBlue.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.lightGray,
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: nozzle.position.isNotEmpty
                                            ? nozzle.position
                                            : null,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        hint: const Text('Position'),
                                        items: const [
                                          DropdownMenuItem<String>(
                                            value: 'يمين',
                                            child: Text('يمين'),
                                          ),
                                          DropdownMenuItem<String>(
                                            value: 'يسار',
                                            child: Text('يسار'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            nozzle.position = value ?? '';
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.infoBlue.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.lightGray,
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: nozzle.fuelType.isNotEmpty
                                            ? nozzle.fuelType
                                            : null,
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        hint: const Text('Fuel type'),
                                        items: station.fuelTypes.map((
                                          fuelType,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: fuelType,
                                            child: Text(fuelType),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            nozzle.fuelType = value ?? '';
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Checkbox(
                            value: isActive,
                            onChanged: (value) {
                              setState(() {
                                isActive = value ?? true;
                              });
                            },
                          ),
                          const Text(
                            'Active',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (pumpNumberController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter pump number'),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                            return;
                          }
                          if (nozzlesData.isEmpty) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text('Add at least one nozzle'),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                            return;
                          }
                          for (int i = 0; i < nozzlesData.length; i++) {
                            final nozzle = nozzlesData[i];
                            if (nozzle.position.isEmpty ||
                                nozzle.fuelType.isEmpty) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Complete nozzle ${i + 1} details',
                                  ),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                              return;
                            }
                          }

                          setState(() {
                            isSubmitting = true;
                          });

                          final nozzlePayload = nozzlesData.asMap().entries.map(
                            (entry) {
                              final position = entry.value.position;
                              final side = position == 'يسار'
                                  ? 'left'
                                  : 'right';
                              return {
                                'nozzleNumber': entry.key + 1,
                                'side': side,
                                'fuelType': entry.value.fuelType,
                                'isActive': true,
                              };
                            },
                          ).toList();

                          final fuelTypeCount = <String, int>{};
                          for (final nozzle in nozzlePayload) {
                            final fuelType =
                                nozzle['fuelType'] as String? ?? '';
                            if (fuelType.isEmpty) continue;
                            fuelTypeCount[fuelType] =
                                (fuelTypeCount[fuelType] ?? 0) + 1;
                          }

                          final mainFuelType = fuelTypeCount.isNotEmpty
                              ? fuelTypeCount.entries
                                    .reduce(
                                      (a, b) => a.value >= b.value ? a : b,
                                    )
                                    .key
                              : station.fuelTypes.isNotEmpty
                              ? station.fuelTypes.first
                              : '';

                          final pumpPayload = {
                            'pumpNumber': pumpNumberController.text.trim(),
                            'fuelType': mainFuelType,
                            'nozzleCount': nozzlePayload.length,
                            'isActive': isActive,
                            'createdAt': DateTime.now().toIso8601String(),
                            'nozzles': nozzlePayload,
                          };

                          final success = await stationProvider.addPump(
                            station.id,
                            pumpPayload,
                          );

                          if (!dialogContext.mounted || !mounted) {
                            return;
                          }

                          setState(() {
                            isSubmitting = false;
                          });

                          if (success) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              const SnackBar(
                                content: Text('Pump added successfully'),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  stationProvider.error ?? 'Failed to add pump',
                                ),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add pump'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPumpsTab(Station station) {
    final bool web = isWeb(context);

    return RefreshIndicator(
      onRefresh: _loadStationDetails,
      child: ListView(
        padding: EdgeInsets.all(web ? 20 : 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Text(
                'Pumps',
                style: TextStyle(
                  fontSize: web ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  '${station.pumps.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (web)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add pump'),
                onPressed: () => _showAddPumpDialog(context, station),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
              ),
            ),
          if (web) const SizedBox(height: 12),
          if (station.pumps.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: web ? 40 : 80),
              child: const Center(
                child: Text(
                  'No pumps yet',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
            )
          else
            ...station.pumps.map((pump) {
              return PumpCard(
                pump: pump,
                onTap: () => _showPumpActionsDialog(context, station.id, pump),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(List<PumpSession> sessions) {
    final bool web = MediaQuery.of(context).size.width >= 1100;
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final todaySessions = sessions.where((session) {
      final sessionDay = DateTime(
        session.sessionDate.year,
        session.sessionDate.month,
        session.sessionDate.day,
      );
      return sessionDay == selectedDay;
    }).toList();

    final openSessions = todaySessions
        .where((session) => session.status == 'مفتوحة')
        .toList();
    final closedSessions = todaySessions
        .where((session) => session.status == 'مغلقة')
        .toList();
    final approvedSessions = todaySessions
        .where((session) => session.status == 'معتمدة')
        .toList();

    Widget sectionHeader(String title, Color color, int count) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: web ? 15 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Chip(
            label: Text('$count', style: TextStyle(fontSize: web ? 11 : 12)),
          ),
        ],
      );
    }

    Widget buildSessionList(List<PumpSession> list) {
      if (list.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'لا توجد جلسات لعرضها',
            style: TextStyle(color: AppColors.mediumGray),
          ),
        );
      }

      return Column(
        children: list.map((session) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text('${session.pumpNumber} · ${session.shiftType}'),
              subtitle: Text(
                '${session.openingEmployeeName ?? ''} · ${DateFormat('HH:mm').format(session.openingTime)}',
              ),
              trailing: Text(
                session.status,
                style: TextStyle(
                  color: session.status == 'مفتوحة'
                      ? AppColors.warningOrange
                      : session.status == 'مغلقة'
                      ? AppColors.primaryBlue
                      : AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStationDetails,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(web ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'الجلسات المفتوحة',
              AppColors.warningOrange,
              openSessions.length,
            ),
            const SizedBox(height: 8),
            buildSessionList(openSessions),
            const SizedBox(height: 20),
            sectionHeader(
              'الجلسات المغلقة',
              AppColors.primaryBlue,
              closedSessions.length,
            ),
            const SizedBox(height: 8),
            buildSessionList(closedSessions),
            const SizedBox(height: 20),
            sectionHeader(
              'الجلسات المعتمدة',
              AppColors.successGreen,
              approvedSessions.length,
            ),
            const SizedBox(height: 8),
            buildSessionList(approvedSessions),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: web ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: web ? 110 : 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mediumGray,
                fontSize: web ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: web ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? AppColors.darkGray,
                fontSize: web ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPumpActionsDialog(
    BuildContext context,
    String stationId,
    Pump pump,
  ) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    // ================= WEB → Dialog =================
    if (web) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 400,
            vertical: 24,
          ),
          title: const Text(
            'إجراءات المضخات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionTile(
                icon: Icons.edit,
                iconColor: AppColors.primaryBlue,
                title: 'تعديل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showEditPumpDialog(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: pump.isActive ? Icons.pause_circle : Icons.play_circle,
                iconColor: pump.isActive
                    ? AppColors.warningOrange
                    : AppColors.successGreen,
                title: pump.isActive ? 'تعطيل المضخات' : 'تفعيل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _togglePumpStatus(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: Icons.delete,
                iconColor: AppColors.errorRed,
                title: 'حذف المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showDeletePumpDialog(context, stationId, pump.id);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    // ================= MOBILE → BottomSheet =================
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionTile(
                icon: Icons.edit,
                iconColor: AppColors.primaryBlue,
                title: 'تعديل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showEditPumpDialog(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: pump.isActive ? Icons.pause_circle : Icons.play_circle,
                iconColor: pump.isActive
                    ? AppColors.warningOrange
                    : AppColors.successGreen,
                title: pump.isActive ? 'تعطيل المضخات' : 'تفعيل المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _togglePumpStatus(context, stationId, pump);
                },
              ),
              _actionTile(
                icon: Icons.delete,
                iconColor: AppColors.errorRed,
                title: 'حذف المضخات',
                onTap: () {
                  Navigator.pop(context);
                  _showDeletePumpDialog(context, stationId, pump.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _showEditPumpDialog(BuildContext context, String stationId, Pump pump) {
    final TextEditingController pumpNumberController = TextEditingController(
      text: pump.pumpNumber,
    );

    List<NozzleData> nozzlesData = pump.nozzles
        .map((n) => NozzleData(position: n.position, fuelType: n.fuelType))
        .toList();

    bool isActive = pump.isActive;
    final bool web = MediaQuery.of(context).size.width >= 1100;

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final station = stationProvider.selectedStation;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void addNozzle() {
              setState(() {
                nozzlesData.add(NozzleData());
              });
            }

            void removeNozzle(int index) {
              setState(() {
                nozzlesData.removeAt(index);
              });
            }

            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: web ? 400 : 24,
                vertical: 24,
              ),
              title: const Text(
                'تعديل المضخات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75, // ✅ مهم
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// رقم المضخات
                      TextField(
                        controller: pumpNumberController,
                        decoration: InputDecoration(
                          labelText: 'رقم المضخات',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.primaryBlue.withOpacity(0.05),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// عنوان الليات
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الليات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: addNozzle,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة لي'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// ✅ قائمة الليات (قابلة للتمرير)
                      SizedBox(
                        height: 300,
                        child: nozzlesData.isEmpty
                            ? const Center(
                                child: Text(
                                  'لم يتم إضافة أي لي بعد',
                                  style: TextStyle(color: AppColors.mediumGray),
                                ),
                              )
                            : ListView.separated(
                                itemCount: nozzlesData.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final nozzle = nozzlesData[index];
                                  return _buildNozzleEditor(
                                    context,
                                    index,
                                    nozzle,
                                    station?.fuelTypes ?? [],
                                    () => removeNozzle(index),
                                    setState,
                                  );
                                },
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                              ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Checkbox(
                            value: isActive,
                            onChanged: (v) =>
                                setState(() => isActive = v ?? true),
                          ),
                          const Text('نشطة'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  child: const Text('حفظ'),
                  onPressed: () async {
                    if (pumpNumberController.text.trim().isEmpty ||
                        nozzlesData.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى استكمال البيانات'),
                          backgroundColor: AppColors.errorRed,
                        ),
                      );
                      return;
                    }

                    final updatedPump = Pump(
                      id: pump.id,
                      pumpNumber: pumpNumberController.text.trim(),
                      fuelType: pump.fuelType,
                      nozzleCount: nozzlesData.length,
                      isActive: isActive,
                      createdAt: pump.createdAt,
                      nozzles: nozzlesData.map((d) {
                        return Nozzle(
                          id: '',
                          nozzleNumber: '${nozzlesData.indexOf(d) + 1}',
                          position: d.position,
                          fuelType: d.fuelType,
                          isActive: true,
                          currentReading: 0,
                          createdAt: DateTime.now(),
                        );
                      }).toList(),
                    );

                    final success = await stationProvider.updatePump(
                      stationId,
                      updatedPump,
                    );

                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'تم تحديث المضخات بنجاح'
                              : 'فشل تحديث المضخات',
                        ),
                        backgroundColor: success
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNozzleEditor(
    BuildContext context,
    int index,
    NozzleData nozzle,
    List<String> fuelTypes,
    VoidCallback onRemove,
    void Function(void Function()) setState,
  ) {
    final fuelOptions = fuelTypes.toSet().toList();
    final selectedFuelType = fuelOptions.contains(nozzle.fuelType)
        ? nozzle.fuelType
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mediumGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// عنوان اللي + حذف
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'اللي ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: AppColors.errorRed,
                  size: 20,
                ),
                onPressed: onRemove,
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// موقع اللي (يمين / يسار)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: DropdownButton<String>(
              value: nozzle.position.isNotEmpty ? nozzle.position : null,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('موقع اللي'),
              items: const [
                DropdownMenuItem(value: 'يمين', child: Text('يمين')),
                DropdownMenuItem(value: 'يسار', child: Text('يسار')),
              ],
              onChanged: (value) {
                setState(() {
                  nozzle.position = value ?? '';
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          /// نوع الوقود
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: DropdownButton<String>(
              value: selectedFuelType,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('نوع الوقود'),
              items: fuelOptions.map((fuel) {
                return DropdownMenuItem(value: fuel, child: Text(fuel));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  nozzle.fuelType = value ?? '';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _togglePumpStatus(BuildContext context, String stationId, Pump pump) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: web ? 420 : 24,
          vertical: 24,
        ),
        title: Row(
          children: [
            Icon(
              pump.isActive ? Icons.pause_circle : Icons.play_circle,
              color: pump.isActive
                  ? AppColors.warningOrange
                  : AppColors.successGreen,
            ),
            const SizedBox(width: 8),
            Text(
              pump.isActive ? 'تعطيل المضخات' : 'تفعيل المضخات',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: web ? 420 : double.infinity),
          child: Text(
            pump.isActive
                ? 'هل تريد تعطيل المضخات رقم ${pump.pumpNumber}؟'
                : 'هل تريد تفعيل المضخات رقم ${pump.pumpNumber}؟',
            style: const TextStyle(fontSize: 15),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pump.isActive
                  ? AppColors.warningOrange
                  : AppColors.successGreen,
            ),
            onPressed: () async {
              final stationProvider = Provider.of<StationProvider>(
                context,
                listen: false,
              );

              // 🔧 مكان تنفيذ منطق التفعيل / التعطيل الحقيقي
              final success = await stationProvider.togglePumpStatus(
                stationId,
                pump.id,
                !pump.isActive,
              );

              if (!mounted) return;

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      pump.isActive
                          ? 'تم تعطيل المضخات بنجاح'
                          : 'تم تفعيل المضخات بنجاح',
                    ),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      stationProvider.error ?? 'فشل تغيير حالة المضخات',
                    ),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showDeletePumpDialog(
    BuildContext context,
    String stationId,
    String pumpId,
  ) {
    final bool web = MediaQuery.of(context).size.width >= 1100;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: web ? 420 : 24,
          vertical: 24,
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_forever, color: AppColors.errorRed),
            SizedBox(width: 8),
            Text('حذف المضخات', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: web ? 420 : double.infinity),
          child: const Text(
            'هل أنت متأكد من حذف هذه المضخات؟\n'
            'لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(fontSize: 15),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () async {
              final stationProvider = Provider.of<StationProvider>(
                context,
                listen: false,
              );

              // 🔧 هنا مكان تنفيذ منطق الحذف الحقيقي
              final success = await stationProvider.deletePump(
                stationId,
                pumpId,
              );

              if (!mounted) return;

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف المضخات بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(stationProvider.error ?? 'فشل حذف المضخات'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showFuelPricingDialog(BuildContext context, Station station) {
    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );

    /// Controllers لكل نوع وقود
    final Map<String, TextEditingController> controllers = {
      for (final fuel in station.fuelTypes)
        fuel: TextEditingController(
          text: station.fuelPrices
              .firstWhere(
                (p) => p.fuelType == fuel,
                orElse: () => FuelPrice(
                  id: '',
                  fuelType: fuel,
                  price: 0,
                  effectiveDate: DateTime.now(),
                ),
              )
              .price
              .toString(),
        ),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تسعيرة الوقود للمحطة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: station.fuelTypes.map((fuelType) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        fuelType,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: controllers[fuelType],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'السعر',
                          suffixText: 'ريال',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            child: const Text('حفظ التسعيرة'),
            onPressed: () async {
              /// تجهيز البيانات للإرسال
              final List<Map<String, dynamic>> prices = [];

              for (final fuelType in station.fuelTypes) {
                final price = double.tryParse(
                  controllers[fuelType]!.text.trim(),
                );

                if (price != null && price > 0) {
                  prices.add({'fuelType': fuelType, 'price': price});
                }
              }

              if (prices.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال سعر واحد على الأقل'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
                return;
              }

              final success = await stationProvider.updateFuelPrices(
                station.id,
                prices,
              );

              if (!mounted) return;

              if (success) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث تسعيرة الوقود بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showStockDisbursementDialog({
    required BuildContext context,
    required Station station,
    required List<_StationFuelStockRow> stockRows,
  }) async {
    if (stockRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات مخزون حالية لهذه المحطة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final fuelTypes = stockRows
        .map((row) => row.fuelType.trim())
        .where((fuel) => fuel.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    var selectedFuelType = fuelTypes.isNotEmpty ? fuelTypes.first : '';
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();

    Future<void> submit(BuildContext dialogContext) async {
      final quantity = double.tryParse(qtyController.text.trim()) ?? 0;
      final reason = reasonController.text.trim();

      final row = stockRows.where((r) => r.fuelType == selectedFuelType);
      final available = row.isNotEmpty ? row.first.remainingStock : 0;

      if (selectedFuelType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار نوع الوقود'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال كمية صحيحة'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (quantity > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الكمية أكبر من المتاح (${available.toStringAsFixed(2)} لتر)'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سبب الصرف'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      final provider = context.read<StationProvider>();
      final success = await provider.createStockDisbursement(
        stationId: station.id,
        fuelType: selectedFuelType,
        quantity: quantity,
        reason: reason,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(dialogContext);
        await provider.fetchCurrentStock(station.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم صرف المخزون بنجاح'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'فشل صرف المخزون'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final row = stockRows.where((r) => r.fuelType == selectedFuelType);
          final available = row.isNotEmpty ? row.first.remainingStock : 0;

          return AlertDialog(
            title: const Text('صرف مخزون'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedFuelType.isEmpty ? null : selectedFuelType,
                    decoration: const InputDecoration(
                      labelText: 'نوع الوقود',
                      border: OutlineInputBorder(),
                    ),
                    items: fuelTypes
                        .map(
                          (fuel) => DropdownMenuItem<String>(
                            value: fuel,
                            child: Text(fuel),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedFuelType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'المتاح: ${available.toStringAsFixed(2)} لتر',
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية (لتر)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'سبب الصرف',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => submit(dialogContext),
                child: const Text('تأكيد'),
              ),
            ],
          );
        },
      ),
    );

    qtyController.dispose();
    reasonController.dispose();
  }

  Future<Station?> _showInlineCreateStationDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final locationController = TextEditingController();
    final cityController = TextEditingController();
    final managerNameController = TextEditingController();
    final managerPhoneController = TextEditingController();

    Future<Station?> create(BuildContext dialogContext) async {
      final name = nameController.text.trim();
      final location = locationController.text.trim();
      final city = cityController.text.trim();
      final managerName = managerNameController.text.trim();
      final managerPhone = managerPhoneController.text.trim();
      final stationCode = codeController.text.trim();

      if ([name, location, city, managerName, managerPhone].any((v) => v.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تعبئة جميع الحقول المطلوبة'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return null;
      }

      final station = Station(
        id: '',
        stationCode: stationCode,
        stationName: name,
        location: location,
        city: city,
        managerName: managerName,
        managerPhone: managerPhone,
        fuelTypes: const [],
        pumps: const [],
        createdById: '',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fuelPrices: const [],
      );

      final provider = context.read<StationProvider>();
      final success = await provider.createStation(station);
      if (!mounted) return null;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'فشل إنشاء المحطة'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return null;
      }

      final created = provider.stations.isNotEmpty ? provider.stations.first : null;
      Navigator.pop(dialogContext, created);
      return created;
    }

    final createdStation = await showDialog<Station?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة محطة جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المحطة *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'كود المحطة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'المدينة *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'الموقع *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: managerNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المدير *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: managerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم المدير *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => create(dialogContext),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    nameController.dispose();
    codeController.dispose();
    locationController.dispose();
    cityController.dispose();
    managerNameController.dispose();
    managerPhoneController.dispose();

    return createdStation;
  }

  Future<void> _showStockTransferDialog({
    required BuildContext context,
    required Station station,
    required List<_StationFuelStockRow> stockRows,
  }) async {
    if (stockRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات مخزون حالية لهذه المحطة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final provider = context.read<StationProvider>();
    if (provider.stations.isEmpty) {
      await provider.fetchStations();
    }

    final fuelTypes = stockRows
        .map((row) => row.fuelType.trim())
        .where((fuel) => fuel.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    var selectedFuelType = fuelTypes.isNotEmpty ? fuelTypes.first : '';
    String? toStationId;
    final qtyController = TextEditingController();
    final notesController = TextEditingController();

    Future<void> submit(BuildContext dialogContext) async {
      final quantity = double.tryParse(qtyController.text.trim()) ?? 0;

      final row = stockRows.where((r) => r.fuelType == selectedFuelType);
      final available = row.isNotEmpty ? row.first.remainingStock : 0;

      if (toStationId == null || toStationId!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار المحطة المحول لها'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (toStationId == station.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن التحويل لنفس المحطة'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (selectedFuelType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار نوع الوقود'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال كمية صحيحة'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      if (quantity > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الكمية أكبر من المتاح (${available.toStringAsFixed(2)} لتر)'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      final success = await provider.createStockTransfer(
        fromStationId: station.id,
        toStationId: toStationId!,
        fuelType: selectedFuelType,
        quantity: quantity,
        notes: notesController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(dialogContext);
        await provider.fetchCurrentStock(station.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحويل المخزون بنجاح'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'فشل تحويل المخزون'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final stations = context.watch<StationProvider>().stations;
          final stationOptions = stations
              .where((s) => s.id != station.id)
              .toList()
            ..sort((a, b) => a.stationName.compareTo(b.stationName));

          final row = stockRows.where((r) => r.fuelType == selectedFuelType);
          final available = row.isNotEmpty ? row.first.remainingStock : 0;

          return AlertDialog(
            title: const Text('تحويل مخزون'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedFuelType.isEmpty ? null : selectedFuelType,
                    decoration: const InputDecoration(
                      labelText: 'نوع الوقود',
                      border: OutlineInputBorder(),
                    ),
                    items: fuelTypes
                        .map(
                          (fuel) => DropdownMenuItem<String>(
                            value: fuel,
                            child: Text(fuel),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedFuelType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'المتاح: ${available.toStringAsFixed(2)} لتر',
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية (لتر)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: toStationId,
                    decoration: const InputDecoration(
                      labelText: 'المحطة المحول لها',
                      border: OutlineInputBorder(),
                    ),
                    items: stationOptions
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.stationName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => toStationId = value),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await _showInlineCreateStationDialog(
                          context,
                        );
                        if (!mounted) return;
                        if (created == null) return;
                        setState(() => toStationId = created.id);
                      },
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('إضافة محطة جديدة'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => submit(dialogContext),
                child: const Text('تأكيد'),
              ),
            ],
          );
        },
      ),
    );

    qtyController.dispose();
    notesController.dispose();
  }
}

// نموذج بيانات اللي المؤقت
class _StationFuelStockRow {
  final String fuelType;
  final double actualStock;
  final double sales;
  final double remainingStock;
  final double capacity;

  const _StationFuelStockRow({
    required this.fuelType,
    required this.actualStock,
    required this.sales,
    required this.remainingStock,
    required this.capacity,
  });
}

class NozzleData {
  String position;
  String fuelType;

  NozzleData({this.position = 'يمين', this.fuelType = ''});
}
