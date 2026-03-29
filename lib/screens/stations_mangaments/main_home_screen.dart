import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/stations/service_card.dart';
import 'package:provider/provider.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  static const double _maxContentWidth = 1200;

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  _HomeQuickStats? _quickStats;
  bool _isLoadingQuickStats = false;
  String? _quickStatsError;

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  bool _isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1100;
  }

  bool _isPhone(BuildContext context) => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuickStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final String? role = authProvider.role;
    final bool isStationDashboardUser =
        role == 'sales_manager_statiun' || role == 'owner_station';
    final bool isOwnerStation = role == 'owner_station';

    final media = MediaQuery.of(context);
    final bool isDesktop = _isDesktop(context);
    final bool tablet = _isTablet(context);
    final bool isPhone = _isPhone(context);
    final bool wideAppBar = media.size.width >= 900;

    final int gridColumns = isDesktop ? 4 : (tablet ? 3 : 2);
    final double horizontalPadding = isDesktop ? 18 : (isPhone ? 8 : 14);

    final services = <Widget>[
      _service(
        context,
        'مبيعات المحطات',
        'إدارة محطات الوقود والمبيعات',
        Icons.local_gas_station_rounded,
        [AppColors.secondaryTeal, const Color(0xFF1D976C)],
        AppRoutes.stationsDashboard,
        compact: isPhone,
      ),
      _service(
        context,
        'إدارة المحطات',
        isOwnerStation
            ? 'عرض المحطات المرتبطة بحسابك'
            : 'إضافة وتعديل محطات الوقود',
        Icons.apartment_rounded,
        [AppColors.warningOrange, const Color(0xFFFF6B00)],
        AppRoutes.stationsList,
        compact: isPhone,
      ),
      _service(
        context,
        'قراءات المضخات',
        'فتح وإغلاق قراءات المبيعات',
        Icons.gas_meter_rounded,
        [AppColors.successGreen, const Color(0xFF16A34A)],
        AppRoutes.sessionsList,
        compact: isPhone,
      ),
      _service(
        context,
        'المخازن',
        'عرض الوقود المتاح حسب المحطة',
        Icons.warehouse_rounded,
        [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
        AppRoutes.stationWarehouses,
        compact: isPhone,
      ),
      _service(
        context,
        'المخزون اليومي',
        'متابعة مخزون الوقود',
        Icons.inventory_2_rounded,
        [AppColors.infoBlue, const Color(0xFF2563EB)],
        AppRoutes.inventoryList,
        compact: isPhone,
      ),
      _service(
        context,
        'خزنة المحطات',
        'متابعة النقدي والشبكة وسندات الصرف',
        Icons.account_balance_wallet_rounded,
        [const Color(0xFF0F766E), const Color(0xFF0EA5A4)],
        AppRoutes.stationTreasury,
        compact: isPhone,
      ),
      _service(
        context,
        'التقرير الشهري للمحطات',
        'تقرير شهري شامل للمبيعات والمصروفات والعجز',
        Icons.query_stats_rounded,
        [const Color(0xFF334155), const Color(0xFF0F172A)],
        AppRoutes.monthlyStationsReport,
        compact: isPhone,
      ),
      if (!isOwnerStation)
        _service(
          context,
          'المهام اليومية',
          'متابعة المهام اليومية',
          Icons.task_alt_rounded,
          [AppColors.primaryBlue, AppColors.appBarWaterBright],
          AppRoutes.tasks,
          compact: isPhone,
        ),
      if (!isOwnerStation)
        _service(
          context,
          'صرف سندات العهدة',
          'صرف سندات العهدة ومتابعتها',
          Icons.receipt_long_rounded,
          [const Color(0xFF0EA5E9), const Color(0xFF1D4ED8)],
          AppRoutes.custodyDocuments,
          compact: isPhone,
        ),
      if (user?.role == 'admin')
        _service(
          context,
          'المستخدمين',
          'إدارة حسابات المستخدمين',
          Icons.manage_accounts_rounded,
          [const Color(0xFFEC4899), const Color(0xFFDB2777)],
          '',
          compact: isPhone,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isStationDashboardUser,
        toolbarHeight: isPhone ? 64 : 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: const _GradientAppBarBackground(),
        titleSpacing: isPhone ? 8 : NavigationToolbar.kMiddleSpacing,
        titleTextStyle: TextStyle(
          fontSize: isPhone ? 17 : 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        title: const Text('إدارة مبيعات المحطات', style: TextStyle(fontFamily: "Cairo"),),
        actions: [
          _appBarIconAction(
            tooltip: 'الإشعارات',
            icon: Icons.notifications_rounded,
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications), 
          ),
          const SizedBox(width: 4),
          _profileAction(
            context: context,
            name: user?.name ?? '',
            showName: wideAppBar,
          ),
          if (isStationDashboardUser) ...[
            const SizedBox(width: 4),
            _appBarIconAction(
              tooltip: 'تسجيل الخروج',
              icon: Icons.logout_rounded,
              onTap: () async {
                await authProvider.logout();
                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const _DashboardBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MainHomeScreen._maxContentWidth,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isDesktop ? 20 : (isPhone ? 12 : 16),
                      horizontalPadding,
                      isPhone ? 10 : 12,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _buildWelcomeHeader(
                        context,
                        name: user?.name ?? '',
                        company: user?.company ?? '',
                        isDesktop: isDesktop,
                        isPhone: isPhone,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isPhone ? 2 : 6,
                      horizontalPadding,
                      isPhone ? 10 : 12,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _buildSectionHeader(context, isPhone: isPhone),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      16,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        crossAxisSpacing: isPhone ? 8 : 14,
                        mainAxisSpacing: isPhone ? 10 : 14,
                        mainAxisExtent: isDesktop ? 148 : (isPhone ? 114 : 156),
                      ),
                      delegate: SliverChildListDelegate(services),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      isPhone ? 12 : 16,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _buildStatsPanel(context, isPhone: isPhone),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: isPhone ? 90 : 110),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadQuickStats() async {
    if (_isLoadingQuickStats) return;

    setState(() {
      _isLoadingQuickStats = true;
      _quickStatsError = null;
    });

    try {
      await ApiService.loadToken();

      final date = DateTime.now();
      final dateKey = _formatDateKey(date);

      final stationIds = await _fetchStationIds();
      if (stationIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _quickStats = const _HomeQuickStats(
            stationsCount: 0,
            sessionsCount: 0,
            todaySales: 0,
            compliancePercent: 0,
          );
        });
        return;
      }

      final statsList = await Future.wait(
        stationIds.map((id) async {
          try {
            return await _fetchStationStats(
              id,
              startDate: dateKey,
              endDate: dateKey,
            );
          } catch (_) {
            return null;
          }
        }),
      );

      final valid = statsList.whereType<StationStats>().toList();
      if (valid.isEmpty) {
        throw Exception('تعذر جلب إحصائيات اليوم');
      }

      double totalSales = 0;
      double totalNet = 0;
      int totalSessions = 0;

      for (final s in valid) {
        totalSales += s.totalSales;
        totalNet += s.netRevenue;
        totalSessions += s.totalSessions;
      }

      final compliance = totalSales > 0 ? (totalNet / totalSales) * 100 : 0.0;
      final clampedCompliance = compliance.clamp(0.0, 100.0);

      if (!mounted) return;
      setState(() {
        _quickStats = _HomeQuickStats(
          stationsCount: stationIds.length,
          sessionsCount: totalSessions,
          todaySales: totalSales,
          compliancePercent: clampedCompliance,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quickStatsError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingQuickStats = false);
    }
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<List<String>> _fetchStationIds() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isOwnerStation && authProvider.stationIds.isNotEmpty) {
      return authProvider.stationIds;
    }

    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}/stations/stations',
    ).replace(queryParameters: const {'page': '1', 'limit': '0'});

    final response = await http.get(uri, headers: ApiService.headers);
    if (response.statusCode != 200) {
      throw Exception('فشل جلب المحطات');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final stations =
        (decoded is Map ? decoded['stations'] : null) as List? ?? [];

    return stations
        .whereType<Map>()
        .map((e) => (e['_id'] ?? e['id'] ?? '').toString())
        .where((id) => id.trim().isNotEmpty)
        .toList();
  }

  Future<StationStats> _fetchStationStats(
    String stationId, {
    required String startDate,
    required String endDate,
  }) async {
    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}/stations/stations/$stationId/stats',
    ).replace(queryParameters: {'startDate': startDate, 'endDate': endDate});

    final response = await http.get(uri, headers: ApiService.headers);
    if (response.statusCode != 200) {
      throw Exception('فشل جلب الإحصائيات');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('بيانات إحصائيات غير صالحة');
    }

    return StationStats.fromJson(decoded);
  }

  Widget _service(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    List<Color> colors,
    String route,
    {required bool compact}
  ) {
    final gradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: colors,
    );

    return ServiceCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      gradient: gradient,
      compact: compact,
      onTap: route.isEmpty ? null : () => Navigator.pushNamed(context, route),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required bool isPhone}) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخدمات',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: isPhone ? 16 : null,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: isPhone ? 1 : 4),
              Text(
                'اختر الخدمة المطلوبة للبدء',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: isPhone ? 10 : null,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context, {
    required String name,
    required String company,
    required bool isDesktop,
    required bool isPhone,
  }) {
    final theme = Theme.of(context);
    final greeting = _getGreeting();
    final greetingIcon = _greetingIcon();

    final trimmedName = name.trim();
    final trimmedCompany = company.trim();
    final title = trimmedName.isEmpty ? 'مرحباً' : 'مرحباً، $trimmedName';

    return Container(
      padding: EdgeInsets.all(isDesktop ? 22 : (isPhone ? 12 : 18)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isPhone ? 20 : 26),
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: isPhone ? 18 : null,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (trimmedCompany.isNotEmpty) ...[
                  SizedBox(height: isPhone ? 3 : 6),
                  Text(
                    trimmedCompany,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isPhone ? 11 : null,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
                SizedBox(height: isPhone ? 8 : 14),
                _infoPill(icon: greetingIcon, label: greeting),
              ],
            ),
          ),
          SizedBox(width: isPhone ? 8 : 16),
          _welcomeMark(isDesktop: isDesktop, isPhone: isPhone),
        ],
      ),
    );
  }

  Widget _welcomeMark({required bool isDesktop, required bool isPhone}) {
    final double size = isDesktop ? 84 : (isPhone ? 58 : 74);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.appBarGradient,
        borderRadius: BorderRadius.circular(isPhone ? 18 : 24),
        boxShadow: [
          BoxShadow(
            color: AppColors.appBarWaterDeep.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Icon(
        Icons.local_gas_station_rounded,
        color: Colors.white,
        size: isPhone ? 24 : 34,
      ),
    );
  }

  Widget _buildStatsPanel(BuildContext context, {required bool isPhone}) {
    final theme = Theme.of(context);

    final quickStats = _quickStats;
    final numberAr = NumberFormat.decimalPattern('ar');
    final complianceAr = NumberFormat('##0.##', 'ar');

    final String stationsValue;
    final String sessionsValue;
    final String revenueValue;
    final String complianceValue;

    if (quickStats != null) {
      stationsValue = numberAr.format(quickStats.stationsCount);
      sessionsValue = numberAr.format(quickStats.sessionsCount);
      revenueValue = numberAr.format(quickStats.todaySales);
      complianceValue = complianceAr.format(quickStats.compliancePercent);
    } else if (_isLoadingQuickStats) {
      stationsValue = '...';
      sessionsValue = '...';
      revenueValue = '...';
      complianceValue = '...';
    } else {
      stationsValue = '—';
      sessionsValue = '—';
      revenueValue = '—';
      complianceValue = '—';
    }

    final stats = <_QuickStat>[
      _QuickStat(
        icon: Icons.local_gas_station_rounded,
        value: stationsValue,
        label: 'محطة',
        color: AppColors.primaryBlue,
      ),
      _QuickStat(
        icon: Icons.play_circle_rounded,
        value: sessionsValue,
        label: 'جلسة نشطة',
        color: AppColors.successGreen,
      ),
      _QuickStat(
        icon: Icons.payments_rounded,
        value: revenueValue,
        label: 'ريال اليوم',
        color: AppColors.warningOrange,
      ),
      _QuickStat(
        icon: Icons.verified_rounded,
        value: complianceValue,
        label: 'مطابقة',
        color: AppColors.infoBlue,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isPhone ? 10 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 22),
        color: Colors.white.withValues(alpha: 0.90),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'إحصائيات اليوم',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: isPhone ? 13 : null,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _isLoadingQuickStats ? null : _loadQuickStats,
                visualDensity: isPhone
                    ? const VisualDensity(horizontal: -2, vertical: -2)
                    : VisualDensity.standard,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: isPhone ? 20 : 24,
                  color: const Color(0xFF0F172A).withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
          if (_isLoadingQuickStats) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.black.withValues(alpha: 0.04),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.appBarWaterBright,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_quickStatsError != null && _quickStats == null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.errorRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تعذر تحميل الإحصائيات من السيرفر',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7F1D1D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final double itemWidth;
              if (w >= 900) {
                itemWidth = (w - (3 * 12)) / 4;
              } else if (w >= 560) {
                itemWidth = (w - 12) / 2;
              } else {
                itemWidth = w;
              }

              return Wrap(
                spacing: isPhone ? 10 : 12,
                runSpacing: isPhone ? 10 : 12,
                children: [
                  for (final s in stats)
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatTile(
                        context,
                        stat: s,
                        isPhone: isPhone,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required _QuickStat stat,
    required bool isPhone,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 10 : 14,
        vertical: isPhone ? 8 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isPhone ? 14 : 18),
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: isPhone ? 34 : 42,
            height: isPhone ? 34 : 42,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(isPhone ? 11 : 14),
            ),
            child: Icon(stat.icon, color: stat.color, size: isPhone ? 17 : 22),
          ),
          SizedBox(width: isPhone ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: isPhone ? 15 : null,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: isPhone ? 1 : 2),
                Text(
                  stat.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isPhone ? 10 : null,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill({required IconData icon, required String label}) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 8 : 12,
        vertical: isPhone ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.appBarWaterDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.appBarWaterDeep.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isPhone ? 14 : 18, color: AppColors.appBarWaterDeep),
          SizedBox(width: isPhone ? 5 : 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: isPhone ? 10.5 : 13,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  IconData _greetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 18) return Icons.wb_sunny_outlined;
    return Icons.nights_stay_rounded;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'مساء الخير';
  }

  Widget _appBarIconAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isPhone ? 12 : 14),
        child: Container(
          width: isPhone ? 34 : 40,
          height: isPhone ? 34 : 40,
          margin: EdgeInsets.symmetric(
            horizontal: isPhone ? 1 : 4,
            vertical: isPhone ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(isPhone ? 12 : 14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: isPhone ? 18 : 22),
        ),
      ),
    );
  }

  Widget _profileAction({
    required BuildContext context,
    required String name,
    required bool showName,
  }) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U';

    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isPhone ? 1 : 4,
          vertical: isPhone ? 8 : 10,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: showName ? (isPhone ? 7 : 10) : (isPhone ? 5 : 8),
          vertical: isPhone ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: showName ? (isPhone ? 28 : 32) : (isPhone ? 26 : 30),
              height: showName ? (isPhone ? 28 : 32) : (isPhone ? 26 : 30),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondaryTeal,
                    AppColors.appBarWaterBright,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: showName ? (isPhone ? 12 : 14) : (isPhone ? 11 : 13),
                  ),
                ),
              ),
            ),
            if (showName) ...[
              SizedBox(width: isPhone ? 8 : 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: isPhone ? 12 : 13,
                  ),
                ),
              ),
              SizedBox(width: isPhone ? 2 : 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
                size: isPhone ? 18 : 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientAppBarBackground extends StatelessWidget {
  const _GradientAppBarBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [const Color(0xFFF8FAFF), AppColors.backgroundGray],
            ),
          ),
          child: Stack(
            children: const [
              Positioned(
                top: -170,
                left: -150,
                child: _SoftBlob(
                  size: 420,
                  colors: [Color(0x3342E8E0), Color(0x001A2980)],
                ),
              ),
              Positioned(
                bottom: -220,
                right: -170,
                child: _SoftBlob(
                  size: 520,
                  colors: [Color(0x33FF9800), Color(0x00000000)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _SoftBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _QuickStat {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _HomeQuickStats {
  final int stationsCount;
  final int sessionsCount;
  final double todaySales;
  final double compliancePercent;

  const _HomeQuickStats({
    required this.stationsCount,
    required this.sessionsCount,
    required this.todaySales,
    required this.compliancePercent,
  });
}
