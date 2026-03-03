import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/maintenance/maintenance_card.dart';
import 'package:order_tracker/widgets/maintenance/stats_card.dart';
import 'package:order_tracker/widgets/chat_floating_button.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:order_tracker/utils/file_saver.dart';

class MaintenanceDashboardScreen extends StatefulWidget {
  const MaintenanceDashboardScreen({super.key});

  @override
  State<MaintenanceDashboardScreen> createState() =>
      _MaintenanceDashboardScreenState();
}

class _MaintenanceDashboardScreenState
    extends State<MaintenanceDashboardScreen> {
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  late List<String> _availableMonths;

  @override
  void initState() {
    super.initState();
    _availableMonths = _generateMonthsList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  List<String> _generateMonthsList() {
    final now = DateTime.now();
    final months = <String>[];
    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i);
      months.add(DateFormat('yyyy-MM').format(date));
    }
    return months;
  }

  Future<void> _loadData() async {
    final provider = context.read<MaintenanceProvider>();
    if (provider.isLoadingRecords || provider.isLoadingStats) return;
    await provider.fetchMaintenanceRecords(month: _selectedMonth, limit: 1000);
    await provider.fetchMonthlyStats(_selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MaintenanceProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isWideScreen = MediaQuery.of(context).size.width >= 900;
    final authProvider = context.watch<AuthProvider>();
    final String? role = authProvider.role;
    final User? user = authProvider.user;

    final bool hideBackArrow =
        role == 'maintenance' || role == 'maintenance_car_management';
    final bool canAccessWorkshopFuel =
        role == 'maintenance' ||
        role == 'maintenance_technician' ||
        role == 'maintenance_car_management' ||
        role == 'admin' ||
        role == 'owner' ||
        role == 'manager';

    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 600;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !hideBackArrow, // ⭐ إخفاء سهم الرجوع
        title: const Text(
          'الصيانة الدورية',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          // =========================
          // 📅 اختيار الشهر
          // =========================
          Container(
            width: isSmallScreen ? 120 : 150,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: _selectedMonth,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: Theme.of(context).primaryColor,
              icon: Icon(
                Icons.arrow_drop_down,
                size: isSmallScreen ? 20 : 24,
                color: Colors.white,
              ),
              items: _availableMonths.map((month) {
                return DropdownMenuItem<String>(
                  value: month,
                  child: Text(
                    DateFormat('MMMM yyyy').format(DateTime.parse('$month-01')),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedMonth = value!);
                _loadData();
              },
            ),
          ),

          SizedBox(width: isSmallScreen ? 8 : 12),

          // =========================
          // 🆕 إنشاء شهر جديد (للمدير فقط)
          // =========================
          if (role == 'maintenance_car_management' ||
              role == 'admin' ||
              role == 'owner')
            IconButton(
              tooltip: 'إنشاء شهر جديد',
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final provider = Provider.of<MaintenanceProvider>(
                  context,
                  listen: false,
                );

                final nextMonth = DateFormat(
                  'yyyy-MM',
                ).format(DateTime.now().add(const Duration(days: 32)));

                try {
                  await provider.generateMaintenanceMonth(nextMonth);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم إنشاء سجلات شهر $nextMonth'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  setState(() {
                    _selectedMonth = nextMonth;
                    if (!_availableMonths.contains(nextMonth)) {
                      _availableMonths.insert(0, nextMonth);
                    }
                  });

                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل إنشاء الشهر: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),

          // =========================
          // ➕ إضافة صيانة (يدوي)
          // =========================
          IconButton(
            tooltip: 'إضافة صيانة',
            onPressed: () {
              Navigator.pushNamed(context, '/maintenance/new');
            },
            icon: Icon(
              Icons.add,
              size: isSmallScreen ? 20 : 24,
              color: Colors.white,
            ),
          ),

          // =========================
          // 📌 المهام (انتقال)
          // =========================
          IconButton(
            tooltip: 'المهام',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.tasks);
            },
            icon: Icon(
              Icons.assignment_turned_in,
              size: isSmallScreen ? 20 : 24,
              color: Colors.white,
            ),
          ),
          // =========================
          // 👤 البروفايل
          // =========================
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isWideScreen ? 18 : 16,
                    backgroundColor: AppColors.primaryBlue,
                    child: Text(
                      (user!.name.isNotEmpty
                          ? user!.name[0].toUpperCase()
                          : 'U'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isWideScreen) ...[
                    const SizedBox(width: 8),
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // =========================
          // 🚪 تسجيل الخروج
          // =========================
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (!context.mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ChatFloatingButton(
            heroTag: 'maintenance_chat_fab',
            mini: true,
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'maintenance_add_fab',
            onPressed: () {
              Navigator.pushNamed(context, '/maintenance/new');
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),

      // =========================
      // ✅ BODY (Responsive FIX)
      // =========================
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 1200 : double.infinity,
              minHeight: screenHeight,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen
                    ? 24
                    : isMediumScreen
                    ? 20
                    : 16,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // 📊 إحصائيات الشهر
                  // =========================
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'إحصائيات الشهر',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isLargeScreen
                            ? 28
                            : isMediumScreen
                            ? 24
                            : 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (provider.monthlyStats != null)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isLargeScreen
                          ? 4
                          : isMediumScreen
                          ? 2
                          : 1,
                      childAspectRatio: isLargeScreen
                          ? 1.5
                          : isMediumScreen
                          ? 1.8
                          : 2.0,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        StatsCard(
                          title: 'المركبات',
                          value: provider.monthlyStats!['totalVehicles']
                              .toString(),
                          icon: Icons.directions_car,
                          color: Colors.blue,
                          subtitle: 'إجمالي المركبات',
                          isLargeScreen: isLargeScreen,
                        ),
                        StatsCard(
                          title: 'الأيام المكتملة',
                          value: provider.monthlyStats!['completedDays']
                              .toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                          subtitle:
                              'من إجمالي ${provider.monthlyStats!['totalDays']} يوم',
                          isLargeScreen: isLargeScreen,
                        ),
                        StatsCard(
                          title: 'نسبة الإنجاز',
                          value: '${provider.monthlyStats!['completionRate']}%',
                          icon: Icons.trending_up,
                          color: Colors.orange,
                          subtitle: 'معدل الإنجاز',
                          isLargeScreen: isLargeScreen,
                        ),
                        StatsCard(
                          title: 'تحت المراجعة',
                          value: provider
                              .monthlyStats!['vehiclesByStatus']['تحت_المراجعة']
                              .toString(),
                          icon: Icons.hourglass_top,
                          color: Colors.yellow,
                          subtitle: 'مركبات تحت المراجعة',
                          isLargeScreen: isLargeScreen,
                        ),
                      ],
                    )
                  else
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  const SizedBox(height: 32),

                  _buildWorkshopFuelCard(
                    context,
                    isLargeScreen: isLargeScreen,
                    canAccess: canAccessWorkshopFuel,
                  ),

                  const SizedBox(height: 32),

                  // =========================
                  // 📈 مخطط الحالات
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 24
                            : isMediumScreen
                            ? 20
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'توزيع المركبات حسب الحالة',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: isLargeScreen
                                ? 320
                                : isMediumScreen
                                ? 280
                                : 240,
                            child: provider.monthlyStats == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _buildStatusSeries(provider).isEmpty
                                ? const Center(
                                    child: Text('لا توجد بيانات للشهر المحدد'),
                                  )
                                : SfCircularChart(
                                    legend: Legend(
                                      isVisible: true,
                                      position: LegendPosition.bottom,
                                      overflowMode: LegendItemOverflowMode.wrap,
                                      textStyle: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                    series: _buildStatusSeries(provider),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // =========================
                  // 🧾 سجلات الصيانة
                  // =========================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'سجلات الصيانة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isLargeScreen
                              ? 28
                              : isMediumScreen
                              ? 24
                              : 20,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _showExportOptions,
                            child: Text(
                              'تصدير',
                              style: TextStyle(
                                fontSize: isLargeScreen
                                    ? 18
                                    : isMediumScreen
                                    ? 16
                                    : 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.custodyDocuments,
                            ),
                            icon: const Icon(Icons.description),
                            label: Text(
                              'سند العهدة',
                              style: TextStyle(
                                fontSize: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 14
                                    : 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (provider.isLoading)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.maintenanceRecords.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isLargeScreen ? 48 : 40),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.car_repair,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('لا توجد سجلات صيانة'),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: provider.maintenanceRecords.map((record) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: MaintenanceCard(
                            record: record,
                            isLargeScreen: isLargeScreen,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/maintenance/details',
                                arguments: record['_id'] ?? record['id'],
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // 📊 Chart Data
  // =========================
    Widget _buildWorkshopFuelCard(
    BuildContext context, {
    required bool isLargeScreen,
    required bool canAccess,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: canAccess
            ? () => Navigator.pushNamed(
                  context,
                  AppRoutes.workshopFuelDashboard,
                )
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: isLargeScreen ? 72 : 56,
                height: isLargeScreen ? 72 : 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_gas_station,
                  size: 32,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مخزون وقود الورشة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عرض المخزون والتعبئات والتقارير الخاصة بالورشة',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGray,
                          ),
                    ),
                  ],
                ),
              ),
              if (canAccess)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.workshopFuelDashboard,
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('دخول'),
                )
              else
                const Text(
                  'لا يسمح',
                  style: TextStyle(color: AppColors.errorRed),
                ),
            ],
          ),
        ),
      ),
    );
  }

List<CircularSeries> _buildStatusSeries(MaintenanceProvider provider) {
    Map<String, int> statusCounts = {};

    // 1️⃣ حاول من الإحصائيات
    final stats = provider.monthlyStats?['vehiclesByStatus'];
    if (stats != null && stats is Map && stats.isNotEmpty) {
      for (final entry in stats.entries) {
        statusCounts[entry.key.toString()] =
            int.tryParse(entry.value.toString()) ?? 0;
      }
    }

    // 2️⃣ fallback من السجلات لو الإحصائيات فاضية
    if (statusCounts.isEmpty) {
      for (final record in provider.maintenanceRecords) {
        final status = record['status'] ?? 'غير_محدد';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }

    if (statusCounts.isEmpty) return [];

    Color getColor(String status) {
      switch (status) {
        case 'مكتمل':
          return Colors.green;
        case 'غير مكتمل':
        case 'غير_مكتمل':
          return Colors.red;
        case 'تحت المراجعة':
        case 'تحت_المراجعة':
          return Colors.orange;
        case 'مرفوض':
          return Colors.grey;
        default:
          return Colors.blueGrey;
      }
    }

    final data = statusCounts.entries.map((e) {
      return {
        'status': e.key.replaceAll('_', ' '),
        'count': e.value,
        'color': getColor(e.key),
      };
    }).toList();

    return [
      DoughnutSeries<Map<String, dynamic>, String>(
        dataSource: data,
        xValueMapper: (d, _) => d['status'],
        yValueMapper: (d, _) => d['count'],
        pointColorMapper: (d, _) => d['color'],
        dataLabelSettings: const DataLabelSettings(isVisible: true),
      ),
    ];
  }

  // =========================
  // 📤 Export
  // =========================
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('تقرير شهري PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportMonthlyPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('تقرير شهري Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportMonthlyExcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPDF() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('جاري تحضير ملف PDF...')));
  }

  Future<void> _exportToExcel() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('جاري تحضير ملف Excel...')));
  }

  Future<void> _exportMonthlyExcel() async {
    final provider = context.read<MaintenanceProvider>();
    final vehicles = _prepareReportVehicles(provider.maintenanceRecords);

    if (vehicles.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لصناعة الملف.')),
      );
      return;
    }

    try {
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'تقرير الصيانة الشهرى';

      // =========================
      // 🟦 إعداد اتجاه الصفحة
      // =========================
      sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;
      sheet.pageSetup.isCenterHorizontally = true;
      sheet.pageSetup.isCenterVertically = false;

      // =========================
      // 🏢 عنوان التقرير
      // =========================
      sheet.getRangeByName('A1:G1').merge();
      sheet
          .getRangeByIndex(1, 1)
          .setText(
            'شركة البحيرة العربية للنقليات – تقرير الصيانة الشهرى ($_selectedMonth)',
          );

      final titleStyle = workbook.styles.add('titleStyle');
      titleStyle.bold = true;
      titleStyle.fontSize = 16;
      titleStyle.hAlign = xlsio.HAlignType.center;
      titleStyle.vAlign = xlsio.VAlignType.center;

      sheet.getRangeByIndex(1, 1).cellStyle = titleStyle;
      sheet.getRangeByIndex(1, 1).rowHeight = 34;

      // =========================
      // 📋 عناوين الجدول
      // =========================
      final headers = [
        'رقم اللوحة',
        'نوع المركبة',
        'أيام الشهر',
        'أيام الفحص',
        'أيام لم تفحص',
        'نسبة الالتزام',
        'حالة الصيانة',
      ];

      final headerStyle = workbook.styles.add('headerStyle');
      headerStyle.bold = true;
      headerStyle.fontSize = 12;
      headerStyle.hAlign = xlsio.HAlignType.center;
      headerStyle.vAlign = xlsio.VAlignType.center;
      headerStyle.backColor = '#E3F2FD';
      headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(3, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidthInPixels(i + 1, 140);
      }

      // =========================
      // 📊 البيانات
      // =========================
      final dataStyle = workbook.styles.add('dataStyle');
      dataStyle.fontSize = 11;
      dataStyle.hAlign = xlsio.HAlignType.center;
      dataStyle.vAlign = xlsio.VAlignType.center;
      dataStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      int row = 4;
      for (final vehicle in vehicles) {
        final summary = vehicle['summary'] as Map<String, dynamic>;
        final completionRate = summary['completionRate'];
        final completionText = completionRate is num
            ? completionRate.toStringAsFixed(1)
            : '0.0';

        sheet.getRangeByIndex(row, 1)
          ..setText(vehicle['plateNumber'] ?? '')
          ..cellStyle = dataStyle;

        sheet.getRangeByIndex(row, 2)
          ..setText(vehicle['vehicleType'] ?? '')
          ..cellStyle = dataStyle;

        sheet.getRangeByIndex(row, 3)
          ..setNumber(summary['totalDays'] ?? 0)
          ..cellStyle = dataStyle;

        sheet.getRangeByIndex(row, 4)
          ..setNumber(summary['checkedDays'] ?? 0)
          ..cellStyle = dataStyle;

        sheet.getRangeByIndex(row, 5)
          ..setNumber(summary['notCheckedDays'] ?? 0)
          ..cellStyle = dataStyle;

        sheet.getRangeByIndex(row, 6)
          ..setText('$completionText%')
          ..cellStyle = dataStyle;

        sheet.getRangeByIndex(row, 7)
          ..setText(
            (vehicle['maintenanceRequired'] as String).isNotEmpty
                ? 'تحتاج صيانة'
                : 'سليمة',
          )
          ..cellStyle = dataStyle;

        row++;
      }

      // =========================
      // 🧾 فوتر بسيط
      // =========================
      final footerRow = row + 2;
      sheet.getRangeByName('A$footerRow:G$footerRow').merge();
      sheet
          .getRangeByIndex(footerRow, 1)
          .setText('تم إنشاء التقرير بواسطة نظام نبراس – شركة البحيرة العربية');

      final footerStyle = workbook.styles.add('footerStyle');
      footerStyle.fontSize = 10;
      footerStyle.hAlign = xlsio.HAlignType.center;
      footerStyle.fontColor = '#555555';

      sheet.getRangeByIndex(footerRow, 1).cellStyle = footerStyle;

      // =========================
      // 💾 حفظ الملف
      // =========================
      final bytes = workbook.saveAsStream();
      workbook.dispose();

      await _saveAndLaunchFile(bytes, 'تقرير_الصيانة_$_selectedMonth.xlsx');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل في إنشاء الملف: $e')));
    }
  }

  Future<void> _exportMonthlyPDF() async {
    final provider = context.read<MaintenanceProvider>();
    final vehicles = _prepareReportVehicles(provider.maintenanceRecords);

    if (vehicles.isEmpty) return;

    final pdf = pw.Document();

    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
    );

    final arabicFontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final arabicFontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFontRegular,
          bold: arabicFontBold,
        ),
        header: (_) => _buildPdfHeader(logo, _selectedMonth),
        footer: (_) => _buildPdfFooter(),
        build: (_) => [_buildVehiclesTable(vehicles)],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  List<Map<String, dynamic>> _prepareReportVehicles(List<dynamic> records) {
    return records.map<Map<String, dynamic>>((record) {
      final data = record is Map
          ? Map<String, dynamic>.from(
              (record as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : <String, dynamic>{};
      return {
        'plateNumber': data['plateNumber']?.toString() ?? '',
        'vehicleType':
            (data['vehicleType'] ?? data['vehicleModel'])?.toString() ?? '',
        'summary': _buildVehicleSummary(data),
        'maintenanceRequired': _formatMaintenanceIndicator(
          data['maintenanceRequired'],
        ),
      };
    }).toList();
  }

  Map<String, dynamic> _buildVehicleSummary(Map<String, dynamic> data) {
    final summaryData = <String, dynamic>{};
    if (data['summary'] is Map) {
      summaryData.addAll((data['summary'] as Map).cast<String, dynamic>());
    }

    final totalDays =
        _readNum(summaryData['totalDays'])?.toInt() ??
        _readNum(data['totalDays'])?.toInt() ??
        0;
    final checkedDays =
        _readNum(summaryData['checkedDays'])?.toInt() ??
        _readNum(data['checkedDays'])?.toInt() ??
        _readNum(data['completedDays'])?.toInt() ??
        0;
    final notCheckedDays =
        _readNum(summaryData['notCheckedDays'])?.toInt() ??
        _readNum(data['notCheckedDays'])?.toInt() ??
        math.max(totalDays - checkedDays, 0);

    final completionRate =
        _readNum(summaryData['completionRate'])?.toDouble() ??
        (totalDays > 0 ? (checkedDays / totalDays) * 100 : 0);

    return {
      'totalDays': totalDays,
      'checkedDays': checkedDays,
      'notCheckedDays': notCheckedDays,
      'completionRate': double.parse(completionRate.toStringAsFixed(1)),
    };
  }

  num? _readNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  String _formatMaintenanceIndicator(dynamic value) {
    if (value == null) return '';
    if (value is Iterable) {
      return value
          .map((item) => item?.toString() ?? '')
          .where((text) => text.isNotEmpty)
          .join(', ');
    }
    return value.toString();
  }

  Future<void> _saveAndLaunchFile(List<int> bytes, String filename) async {
    await saveAndLaunchFile(bytes, filename);
  }

  pw.Widget _buildPdfHeader(pw.MemoryImage logoImage, String selectedMonth) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
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
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'الرقم الوطني الموحد: 7011144750',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'تقرير الصيانة الشهرى',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'شهر: $selectedMonth',
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

  pw.Widget _buildVehiclesTable(List<Map<String, dynamic>> vehicles) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      headers: const [
        'رقم اللوحة',
        'نوع المركبة',
        'أيام الشهر',
        'أيام الفحص',
        'أيام لم تفحص',
        'نسبة الالتزام',
        'حالة الصيانة',
      ],
      data: vehicles.map((v) {
        final s = v['summary'];
        return [
          v['plateNumber'] ?? '',
          v['vehicleType'] ?? '',
          s['totalDays'] ?? 0,
          s['checkedDays'] ?? 0,
          s['notCheckedDays'] ?? 0,
          '${(s['completionRate'] ?? 0).toStringAsFixed(1)}%',
          (v['maintenanceRequired'] as String).isNotEmpty
              ? 'تحتاج صيانة'
              : 'سليمة',
        ];
      }).toList(),
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
                pw.Text('المدير العام'),
                pw.SizedBox(height: 24),
                pw.Text('__________________'),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('رئيس مجلس الإدارة'),
                pw.SizedBox(height: 24),
                pw.Text('__________________'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'المملكة العربية السعودية – شركة البحيرة العربية',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }
}
