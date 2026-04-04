import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/maintenance/maintenance_card.dart';
import 'package:order_tracker/widgets/maintenance/stats_card.dart';
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

  Future<void> _generateNextMonthRecords() async {
    final provider = context.read<MaintenanceProvider>();
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
  }

  Widget _buildQuickNavAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isSmallScreen,
  }) {
    return IconButton(
      tooltip: tooltip,
      splashRadius: 22,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: isSmallScreen ? 20 : 24,
        color: Colors.white,
      ),
    );
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
    final bool canViewArchive =
        user?.hasAnyPermission(['archive_view', 'archive_manage']) ?? false;

    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 600;
    final isSmallScreen = screenWidth < 400;

    final statusData = _buildStatusChartData(provider);
    final statusTotal = statusData.fold<int>(
      0,
      (sum, entry) => sum + (entry['count'] as int? ?? 0),
    );

    final stats = provider.monthlyStats;
    final totalVehicles =
        int.tryParse((stats?['totalVehicles'] ?? '0').toString()) ?? 0;
    final completedDays =
        int.tryParse((stats?['completedDays'] ?? '0').toString()) ?? 0;
    final totalDays =
        int.tryParse((stats?['totalDays'] ?? '0').toString()) ?? 0;
    final completionRateValue =
        double.tryParse((stats?['completionRate'] ?? '0').toString()) ?? 0;
    final vehiclesByStatus = stats?['vehiclesByStatus'];
    final underReview = vehiclesByStatus is Map
        ? int.tryParse(
                (vehiclesByStatus['تحت_المراجعة'] ??
                        vehiclesByStatus['تحت المراجعة'] ??
                        '0')
                    .toString(),
              ) ??
              0
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AppBar(
        automaticallyImplyLeading: !hideBackArrow, // ⭐ إخفاء سهم الرجوع
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
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
              color: Colors.white.withValues(alpha: 0.08),
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
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canViewArchive)
                      _buildQuickNavAction(
                        icon: Icons.archive_outlined,
                        tooltip: 'الأرشيف',
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.archiveDocuments,
                          );
                        },
                        isSmallScreen: isSmallScreen,
                      ),
                    _buildQuickNavAction(
                      icon: Icons.assignment_turned_in,
                      tooltip: 'المهام',
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.tasks);
                      },
                      isSmallScreen: isSmallScreen,
                    ),
                    _buildQuickNavAction(
                      icon: Icons.add,
                      tooltip: 'إضافة صيانة',
                      onPressed: () {
                        Navigator.pushNamed(context, '/maintenance/new');
                      },
                      isSmallScreen: isSmallScreen,
                    ),
                    if (role == 'maintenance_car_management' ||
                        role == 'admin' ||
                        role == 'owner')
                      _buildQuickNavAction(
                        icon: Icons.calendar_month,
                        tooltip: 'إنشاء شهر جديد',
                        onPressed: _generateNextMonthRecords,
                        isSmallScreen: isSmallScreen,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
      body: Stack(
        children: [
          const _MaintenanceDashboardBackground(),
          Positioned.fill(
            child: RefreshIndicator(
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
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
                                : 3,
                            childAspectRatio: isLargeScreen
                                ? 1.5
                                : isMediumScreen
                                ? 1.8
                                : 1.0,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            children: [
                              StatsCard(
                                title: 'المركبات',
                                value: totalVehicles.toString(),
                                icon: Icons.directions_car,
                                color: AppColors.infoBlue,
                                subtitle: 'إجمالي المركبات',
                                isLargeScreen: isLargeScreen,
                                compact: !isMediumScreen,
                              ),
                              StatsCard(
                                title: 'الأيام المكتملة',
                                value: completedDays.toString(),
                                icon: Icons.check_circle,
                                color: AppColors.successGreen,
                                subtitle: 'من إجمالي $totalDays يوم',
                                isLargeScreen: isLargeScreen,
                                compact: !isMediumScreen,
                              ),
                              StatsCard(
                                title: 'نسبة الإنجاز',
                                value:
                                    '${completionRateValue.toStringAsFixed(2)}%',
                                icon: Icons.trending_up,
                                color: AppColors.warningOrange,
                                subtitle: 'معدل الإنجاز',
                                isLargeScreen: isLargeScreen,
                                compact: !isMediumScreen,
                              ),
                              StatsCard(
                                title: 'تحت المراجعة',
                                value: underReview.toString(),
                                icon: Icons.hourglass_top,
                                color: AppColors.pendingYellow,
                                subtitle: 'مركبات تحت المراجعة',
                                isLargeScreen: isLargeScreen,
                                compact: !isMediumScreen,
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
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
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
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.appBarWaterBright
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.pie_chart_outline,
                                        color: AppColors.appBarWaterDeep,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'توزيع المركبات حسب الحالة',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: isLargeScreen
                                                  ? 22
                                                  : isMediumScreen
                                                  ? 18
                                                  : 16,
                                              color: AppColors.appBarWaterDeep,
                                            ),
                                      ),
                                    ),
                                  ],
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
                                      : statusData.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'لا توجد بيانات للشهر المحدد',
                                          ),
                                        )
                                      : SfCircularChart(
                                          tooltipBehavior: TooltipBehavior(
                                            enable: true,
                                            header: '',
                                            format: 'point.x : point.y',
                                          ),
                                          annotations: [
                                            CircularChartAnnotation(
                                              widget: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    statusTotal.toString(),
                                                    textDirection:
                                                        ui.TextDirection.ltr,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: AppColors
                                                              .appBarWaterDeep,
                                                          height: 1.0,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'مركبة',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .mediumGray,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          legend: Legend(
                                            isVisible: true,
                                            position: LegendPosition.bottom,
                                            overflowMode:
                                                LegendItemOverflowMode.wrap,
                                            textStyle: TextStyle(
                                              fontSize: isSmallScreen ? 12 : 14,
                                            ),
                                          ),
                                          series: _buildStatusSeries(
                                            statusData,
                                          ),
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
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
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
          ),
        ],
      ),
    );
  }

  Widget _buildWorkshopFuelCard(
    BuildContext context, {
    required bool isLargeScreen,
    required bool canAccess,
  }) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(22);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: InkWell(
          onTap: canAccess
              ? () => Navigator.pushNamed(
                  context,
                  AppRoutes.workshopFuelDashboard,
                )
              : null,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 18 : 16),
            child: Row(
              children: [
                Container(
                  width: isLargeScreen ? 72 : 56,
                  height: isLargeScreen ? 72 : 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.appBarWaterGlow,
                        AppColors.appBarWaterBright,
                        AppColors.appBarWaterDeep,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.appBarWaterDeep.withValues(
                          alpha: 0.16,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_gas_station,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مخزون وقود الورشة',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.appBarWaterDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عرض المخزون والتعبئات والتقارير الخاصة بالورشة',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mediumGray,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (canAccess)
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.appBarWaterDeep.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.workshopFuelDashboard,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'دخول',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.errorRed.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      'لا يسمح',
                      style: TextStyle(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildStatusChartData(
    MaintenanceProvider provider,
  ) {
    final statusCounts = <String, int>{};

    final stats = provider.monthlyStats?['vehiclesByStatus'];
    if (stats is Map && stats.isNotEmpty) {
      for (final entry in stats.entries) {
        statusCounts[entry.key.toString()] =
            int.tryParse(entry.value.toString()) ?? 0;
      }
    }

    if (statusCounts.isEmpty) {
      for (final record in provider.maintenanceRecords) {
        final status =
            (record['status'] ?? record['monthlyStatus'] ?? 'غير_محدد')
                .toString()
                .trim();
        if (status.isEmpty) continue;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }

    if (statusCounts.isEmpty) return const [];

    final data = statusCounts.entries.where((entry) => entry.value > 0).map((
      entry,
    ) {
      final raw = entry.key;
      return <String, dynamic>{
        'status': raw.replaceAll('_', ' '),
        'count': entry.value,
        'color': _statusColor(raw),
      };
    }).toList();

    data.sort((a, b) {
      final aCount = a['count'] as int? ?? 0;
      final bCount = b['count'] as int? ?? 0;
      return bCount.compareTo(aCount);
    });

    return data;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'مكتمل':
        return AppColors.successGreen;
      case 'غير مكتمل':
      case 'غير_مكتمل':
        return AppColors.errorRed;
      case 'تحت المراجعة':
      case 'تحت_المراجعة':
        return AppColors.warningOrange;
      case 'مرفوض':
        return AppColors.silverDark;
      default:
        return AppColors.appBarWaterMid;
    }
  }

  List<CircularSeries<Map<String, dynamic>, String>> _buildStatusSeries(
    List<Map<String, dynamic>> data,
  ) {
    return [
      DoughnutSeries<Map<String, dynamic>, String>(
        dataSource: data,
        xValueMapper: (d, _) => (d['status'] ?? '').toString(),
        yValueMapper: (d, _) => d['count'] as int? ?? 0,
        pointColorMapper: (d, _) => d['color'] as Color?,
        radius: '84%',
        innerRadius: '62%',
        dataLabelSettings: const DataLabelSettings(isVisible: false),
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
              leading: const Icon(Icons.print_outlined, color: Colors.blueGrey),
              title: const Text('طباعة اليوميات (حسب السيارات + التاريخ)'),
              onTap: () {
                Navigator.pop(context);
                _showDailyChecksPrintOptions();
              },
            ),
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

  DateTime _normalizeDate(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  DateTime _selectedMonthStart() => DateTime.parse('$_selectedMonth-01');

  DateTime _selectedMonthEnd() {
    final start = _selectedMonthStart();
    return DateTime(start.year, start.month + 1, 0);
  }

  void _showDailyChecksPrintOptions() {
    final provider = context.read<MaintenanceProvider>();
    final records = provider.maintenanceRecords
        .whereType<Map>()
        .map(
          (raw) => raw.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سيارات في هذا الشهر للطباعة.')),
      );
      return;
    }

    records.sort((a, b) {
      final aPlate = (a['plateNumber'] ?? '').toString();
      final bPlate = (b['plateNumber'] ?? '').toString();
      return aPlate.compareTo(bPlate);
    });

    final monthStart = _selectedMonthStart();
    final monthEnd = _selectedMonthEnd();

    final selectedIds = <String>{};
    var range = DateTimeRange(start: monthStart, end: monthEnd);
    final searchController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setStateSheet) {
                  final search = searchController.text.trim().toLowerCase();
                  final filtered = search.isEmpty
                      ? records
                      : records.where((r) {
                          final plate = (r['plateNumber'] ?? '')
                              .toString()
                              .toLowerCase();
                          final driver = (r['driverName'] ?? '')
                              .toString()
                              .toLowerCase();
                          final tank = (r['tankNumber'] ?? '')
                              .toString()
                              .toLowerCase();
                          return plate.contains(search) ||
                              driver.contains(search) ||
                              tank.contains(search);
                        }).toList();

                  final allFilteredSelected =
                      filtered.isNotEmpty &&
                      filtered.every((r) {
                        final id = (r['_id'] ?? r['id'] ?? '')
                            .toString()
                            .trim();
                        return id.isNotEmpty && selectedIds.contains(id);
                      });

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'طباعة اليوميات',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'إغلاق',
                              onPressed: () =>
                                  Navigator.pop(bottomSheetContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDateRangePicker(
                                    context: bottomSheetContext,
                                    firstDate: monthStart,
                                    lastDate: monthEnd,
                                    initialDateRange: range,
                                  );
                                  if (picked == null) return;
                                  setStateSheet(() {
                                    range = picked;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${DateFormat('yyyy-MM-dd').format(range.start)} → ${DateFormat('yyyy-MM-dd').format(range.end)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث (اللوحة / السائق / رقم الخزان)',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchController.text.trim().isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح',
                                    onPressed: () {
                                      searchController.clear();
                                      setStateSheet(() {});
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                          onChanged: (_) => setStateSheet(() {}),
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: allFilteredSelected,
                            onChanged: (value) {
                              final shouldSelectAll = value == true;
                              setStateSheet(() {
                                for (final r in filtered) {
                                  final id = (r['_id'] ?? r['id'] ?? '')
                                      .toString()
                                      .trim();
                                  if (id.isEmpty) continue;
                                  if (shouldSelectAll) {
                                    selectedIds.add(id);
                                  } else {
                                    selectedIds.remove(id);
                                  }
                                }
                              });
                            },
                            title: Text(
                              filtered.length == records.length
                                  ? 'تحديد الكل'
                                  : 'تحديد الكل (نتائج البحث)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Material(
                              color: Colors.white,
                              child: ListView.separated(
                                controller: scrollController,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final r = filtered[index];
                                  final id = (r['_id'] ?? r['id'] ?? '')
                                      .toString()
                                      .trim();
                                  final plate = (r['plateNumber'] ?? '-')
                                      .toString();
                                  final driver = (r['driverName'] ?? '-')
                                      .toString();
                                  final tank = (r['tankNumber'] ?? '')
                                      .toString();

                                  final selected =
                                      id.isNotEmpty && selectedIds.contains(id);

                                  return CheckboxListTile(
                                    value: selected,
                                    onChanged: id.isEmpty
                                        ? null
                                        : (value) {
                                            setStateSheet(() {
                                              if (value == true) {
                                                selectedIds.add(id);
                                              } else {
                                                selectedIds.remove(id);
                                              }
                                            });
                                          },
                                    title: Text(
                                      plate,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      tank.trim().isEmpty
                                          ? driver
                                          : '$driver • خزان: $tank',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(bottomSheetContext),
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: selectedIds.isEmpty
                                    ? null
                                    : () async {
                                        Navigator.pop(bottomSheetContext);

                                        final selectedRecords = records.where((
                                          r,
                                        ) {
                                          final id = (r['_id'] ?? r['id'] ?? '')
                                              .toString()
                                              .trim();
                                          return id.isNotEmpty &&
                                              selectedIds.contains(id);
                                        }).toList();

                                        await _printDailyChecksReport(
                                          selectedRecords: selectedRecords,
                                          range: range,
                                        );
                                      },
                                icon: const Icon(Icons.print_outlined),
                                label: Text('طباعة (${selectedIds.length})'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(searchController.dispose);
  }

  String _translateDailyCheckStatus(dynamic status) {
    switch (status?.toString()) {
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      case 'under_review':
        return 'قيد المراجعة';
      case 'pending':
        return 'معلق';
      default:
        return (status ?? '').toString().trim();
    }
  }

  PdfColor _statusWatermarkColor(String statusText) {
    if (statusText == 'معتمد') return PdfColors.green;
    if (statusText == 'مرفوض') return PdfColors.red;
    if (statusText == 'قيد المراجعة') return PdfColors.orange;
    if (statusText == 'معلق') return PdfColors.grey600;
    return PdfColors.grey600;
  }

  Future<Map<String, dynamic>> _fetchMaintenanceRecordDetails(
    String maintenanceId,
  ) async {
    final response = await ApiService.hrGet('/maintenance/$maintenanceId');
    final success = response['success'] == true;
    final data = response['data'];
    if (success && data is Map) {
      return data.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    throw Exception(
      response['message']?.toString() ?? 'فشل جلب بيانات السيارة',
    );
  }

  List<Map<String, dynamic>> _extractDailyChecks(dynamic record) {
    if (record is! Map) return const [];
    final rawChecks = record['dailyChecks'];
    if (rawChecks is! List) return const [];
    return rawChecks
        .whereType<Map>()
        .map(
          (c) => c.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> _filterDailyChecksByRange({
    required List<Map<String, dynamic>> dailyChecks,
    required DateTimeRange range,
  }) {
    final start = _normalizeDate(range.start);
    final end = _normalizeDate(range.end);

    final filtered = <Map<String, dynamic>>[];
    for (final check in dailyChecks) {
      final date = DateTime.tryParse(check['date']?.toString() ?? '');
      if (date == null) continue;
      final normalized = _normalizeDate(date);
      if (normalized.isBefore(start) || normalized.isAfter(end)) continue;
      filtered.add(check);
    }

    filtered.sort((a, b) {
      final aDate = DateTime.tryParse(a['date']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['date']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    return filtered;
  }

  Future<void> _printDailyChecksReport({
    required List<Map<String, dynamic>> selectedRecords,
    required DateTimeRange range,
  }) async {
    if (selectedRecords.isEmpty) return;

    final officerName =
        context.read<AuthProvider>().user?.name ?? 'مسؤول الصيانة';

    var processedVehicles = 0;
    var totalPages = 0;
    var currentPlate = '';

    if (!context.mounted) return;

    BuildContext? dialogContext;
    StateSetter? setStateDialog;

    void safeDialogSetState(VoidCallback fn) {
      final setter = setStateDialog;
      if (setter == null) return;
      setter(fn);
    }

    void closeDialog() {
      final ctx = dialogContext;
      if (ctx == null) return;
      if (!Navigator.of(ctx).canPop()) return;
      Navigator.of(ctx).pop();
      dialogContext = null;
      setStateDialog = null;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) {
            setStateDialog = setState;
            return AlertDialog(
              title: const Text('جاري تجهيز الطباعة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'السيارات: $processedVehicles/${selectedRecords.length}',
                  ),
                  if (currentPlate.isNotEmpty) Text('الحالية: $currentPlate'),
                  Text('الصفحات: $totalPages'),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
      );

      final arabicFontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
      );
      final arabicFontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
      );

      final pdf = pw.Document();

      final cache = <String, Map<String, dynamic>>{};

      for (final record in selectedRecords) {
        processedVehicles++;

        final id = (record['_id'] ?? record['id'] ?? '').toString().trim();
        currentPlate = (record['plateNumber'] ?? '-').toString().trim();

        safeDialogSetState(() {});

        Map<String, dynamic> fullRecord = record;
        final hasDailyChecks = record['dailyChecks'] is List;
        if (!hasDailyChecks && id.isNotEmpty) {
          fullRecord = cache[id] ?? await _fetchMaintenanceRecordDetails(id);
          cache[id] = fullRecord;
        }

        final dailyChecks = _filterDailyChecksByRange(
          dailyChecks: _extractDailyChecks(fullRecord),
          range: range,
        );

        final plateNumber =
            (fullRecord['plateNumber'] ?? record['plateNumber'] ?? '-')
                .toString();
        final driverName =
            (fullRecord['driverName'] ?? record['driverName'] ?? '-')
                .toString();

        final recordInfo = <String, dynamic>{
          ...fullRecord,
          'plateNumber': plateNumber,
          'driverName': driverName,
        };

        if (dailyChecks.isEmpty) {
          totalPages++;
          safeDialogSetState(() {});

          pdf.addPage(
            pw.MultiPage(
              pageTheme: pw.PageTheme(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(20),
                theme: pw.ThemeData.withFont(
                  base: arabicFontRegular,
                  bold: arabicFontBold,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
              header: (_) => _buildDailyCheckPdfHeader(
                logo,
                recordInfo,
                range.start,
                subtitle:
                    'لا توجد فحوصات يومية ضمن المدى: ${DateFormat('yyyy-MM-dd').format(range.start)} → ${DateFormat('yyyy-MM-dd').format(range.end)}',
              ),
              footer: (_) => pw.Column(
                children: [
                  _buildDailyCheckPdfFooter(
                    maintenanceOfficerName: officerName,
                  ),
                  pw.SizedBox(height: 5),
                  _buildDailyCheckPdfBottomDividerWithAddress(),
                ],
              ),
              build: (_) => [
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Text(
                    'لم يتم العثور على يوميات/فحوصات يومية لهذه السيارة داخل المدى المختار.',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          continue;
        }

        for (final check in dailyChecks) {
          final checkDate = DateTime.tryParse(check['date']?.toString() ?? '');
          if (checkDate == null) continue;

          final statusText = _translateDailyCheckStatus(check['status']);
          final watermarkColor = _statusWatermarkColor(statusText);

          totalPages++;
          safeDialogSetState(() {});

          pdf.addPage(
            pw.MultiPage(
              pageTheme: pw.PageTheme(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(20),
                theme: pw.ThemeData.withFont(
                  base: arabicFontRegular,
                  bold: arabicFontBold,
                ),
                textDirection: pw.TextDirection.rtl,
                buildBackground: (context) {
                  if (statusText.isEmpty) return pw.SizedBox();
                  return pw.Stack(
                    children: [
                      pw.Positioned.fill(
                        child: pw.Center(
                          child: pw.Opacity(
                            opacity: 0.16,
                            child: pw.Transform.rotate(
                              angle: -0.35,
                              child: pw.Text(
                                statusText,
                                style: pw.TextStyle(
                                  fontSize: 62,
                                  fontWeight: pw.FontWeight.bold,
                                  color: watermarkColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              header: (_) => _buildDailyCheckPdfHeader(
                logo,
                recordInfo,
                checkDate,
                subtitle:
                    'حالة اليومية: ${statusText.isEmpty ? '-' : statusText}',
              ),
              footer: (_) => pw.Column(
                children: [
                  _buildDailyCheckPdfFooter(
                    maintenanceOfficerName: officerName,
                  ),
                  pw.SizedBox(height: 5),
                  _buildDailyCheckPdfBottomDividerWithAddress(),
                ],
              ),
              build: (_) => [
                pw.SizedBox(height: 10),
                _buildDailyCheckPdfTable(check),
              ],
            ),
          );
        }
      }

      closeDialog();

      if (!context.mounted) return;

      if (totalPages == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد يوميات ضمن المدى المحدد.')),
        );
        return;
      }

      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (e) {
      closeDialog();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تجهيز الطباعة: $e')));
    } finally {
      closeDialog();
    }
  }

  pw.Widget _buildDailyCheckPdfHeader(
    pw.MemoryImage logoImage,
    Map<String, dynamic> record,
    DateTime checkDate, {
    String? subtitle,
  }) {
    final date = DateFormat('yyyy-MM-dd').format(checkDate);

    final plateNumber = record['plateNumber']?.toString() ?? '-';
    final driverName = record['driverName']?.toString() ?? '-';

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
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'الرقم الوطني الموحد: 7011144750',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Divider(color: PdfColors.grey400, height: 1),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'فحص/يومية المركبة',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'رقم المركبة (اللوحة): $plateNumber',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    'اسم السائق: $driverName',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'التاريخ: $date',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(subtitle, style: const pw.TextStyle(fontSize: 7)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              width: 90,
              height: 90,
              alignment: pw.Alignment.center,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildDailyCheckPdfTable(Map<String, dynamic> dailyCheck) {
    String toText(dynamic value) => (value ?? '').toString().trim();

    final inspectionResult = toText(dailyCheck['inspectionResult']);
    final notes = toText(dailyCheck['notes']);
    final maintenanceType = toText(dailyCheck['maintenanceType']);
    final maintenanceCost = dailyCheck['maintenanceCost'];
    final maintenanceCostText = maintenanceCost == null
        ? ''
        : maintenanceCost is num
        ? maintenanceCost.toStringAsFixed(2)
        : maintenanceCost.toString();

    final rows = <Map<String, String>>[
      {'label': 'قراءة العداد', 'value': toText(dailyCheck['odometerReading'])},
      {
        'label': 'تغيير الزيت',
        'value': (dailyCheck['oilChanged'] == true) ? 'نعم' : 'لا',
      },
      {'label': 'نتيجة الفحص', 'value': inspectionResult},
      {'label': 'سلامة المركبة', 'value': toText(dailyCheck['vehicleSafety'])},
      {'label': 'سلامة السائق', 'value': toText(dailyCheck['driverSafety'])},
      {
        'label': 'صيانة كهرباء',
        'value': toText(dailyCheck['electricalMaintenance']),
      },
      {
        'label': 'صيانة ميكانيكا',
        'value': toText(dailyCheck['mechanicalMaintenance']),
      },
      {'label': 'فحص التانكي', 'value': toText(dailyCheck['tankInspection'])},
      {'label': 'فحص الإطارات', 'value': toText(dailyCheck['tiresInspection'])},
      {'label': 'فحص الفرامل', 'value': toText(dailyCheck['brakesInspection'])},
      {'label': 'فحص الأضواء', 'value': toText(dailyCheck['lightsInspection'])},
      {'label': 'فحص السوائل', 'value': toText(dailyCheck['fluidsCheck'])},
      {
        'label': 'معدات الطوارئ',
        'value': toText(dailyCheck['emergencyEquipment']),
      },
    ];

    if (inspectionResult == 'تحتاج صيانة') {
      rows.addAll([
        {'label': 'نوع الصيانة', 'value': maintenanceType},
        {'label': 'تكلفة الصيانة', 'value': maintenanceCostText},
      ]);
    }

    if (notes.isNotEmpty) {
      rows.add({'label': 'ملاحظات', 'value': notes});
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1.3),
        },
        children: rows.map((row) {
          return pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  row['value']!.isNotEmpty ? row['value']! : '-',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                alignment: pw.Alignment.centerRight,
                color: PdfColors.grey200,
                child: pw.Text(
                  row['label']!,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildDailyCheckPdfFooter({
    required String maintenanceOfficerName,
  }) {
    pw.Widget signatureLine() => pw.Column(
      children: [
        pw.SizedBox(height: 10),
        pw.Container(width: 80, height: 0.8, color: PdfColors.grey700),
        pw.SizedBox(height: 2),
        pw.Text('التوقيع', style: const pw.TextStyle(fontSize: 7)),
      ],
    );

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        child: pw.Column(
          children: [
            pw.Divider(thickness: 0.8),
            pw.SizedBox(height: 5),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _dailyCheckFooterPerson(
                    'المدير العام',
                    'Hamada Rashidy - حمادة الرشيدي',
                    signatureLine(),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _dailyCheckFooterMaintenance(maintenanceOfficerName),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _dailyCheckFooterPerson(
                    'رئيس مجلس الإدارة',
                    'ناصر المطيري - Nasser Khaled',
                    signatureLine(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _dailyCheckFooterPerson(
    String title,
    String name,
    pw.Widget signature,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          name,
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
          softWrap: true,
          maxLines: 2,
        ),
        signature,
      ],
    );
  }

  pw.Widget _dailyCheckFooterMaintenance(String maintenanceOfficerName) {
    return pw.SizedBox(
      width: 140,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'مسؤول الصيانة',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            maintenanceOfficerName,
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'معتمد منه',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDailyCheckPdfBottomDividerWithAddress() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 20),
        child: pw.Column(
          children: [
            pw.Divider(thickness: 0.8, color: PdfColors.grey700),
            pw.SizedBox(height: 8),
            pw.Text(
              'المنطقة الصناعية – شركة البحيرة العربية للنقليات، المملكة العربية السعودية – منطقة حائل – حائل',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '“Industrial Area – Al Buhaira Al Arabia Transport Company, Kingdom of Saudi Arabia – Hail Region – Hail.”',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'جوال: 0535550130   |   البريد الإلكتروني: n.n.66@hotmail.com',
              style: const pw.TextStyle(fontSize: 7.5),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'نظام نبراس | شركة البحيرة العربية',
              style: const pw.TextStyle(fontSize: 7.5),
              textAlign: pw.TextAlign.center,
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

class _MaintenanceDashboardBackground extends StatelessWidget {
  const _MaintenanceDashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: const [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF6F8FE),
                    Color(0xFFF2F5FC),
                    Color(0xFFEEF2FA),
                  ],
                ),
              ),
            ),
            _SoftBlob(
              alignment: Alignment(-1.05, -0.70),
              size: 620,
              color: Color(0x336BCBFF),
            ),
            _SoftBlob(
              alignment: Alignment(1.05, -0.20),
              size: 540,
              color: Color(0x2626D0CE),
            ),
            _SoftBlob(
              alignment: Alignment(0.0, 1.1),
              size: 640,
              color: Color(0x1A1D4ED8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _SoftBlob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
