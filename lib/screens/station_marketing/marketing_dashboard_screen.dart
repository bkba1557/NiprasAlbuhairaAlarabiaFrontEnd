import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/providers/station_inspection_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

import 'marketing_models.dart';
import 'marketing_handover_report_form_screen.dart';
import 'marketing_handover_report_screen.dart';
import 'marketing_station_details_screen.dart';
import 'marketing_station_form_screen.dart';
import 'package:order_tracker/screens/station_inspections/inspection_details_screen.dart';
import 'package:order_tracker/screens/station_inspections/inspection_form_screen.dart';
import 'package:order_tracker/screens/station_inspections/inspection_models.dart';

class MarketingStationsScreen extends StatefulWidget {
  const MarketingStationsScreen({super.key});

  @override
  State<MarketingStationsScreen> createState() =>
      _MarketingStationsScreenState();
}

class _MarketingStationsScreenState extends State<MarketingStationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final TextEditingController _expenseReasonController =
      TextEditingController();
  final TextEditingController _expenseAmountController =
      TextEditingController();
  final TextEditingController _expenseNotesController = TextEditingController();
  DateTime _expenseDateTime = DateTime.now();
  String? _expenseStationId;

  final TextEditingController _receiptAmountController =
      TextEditingController();
  final TextEditingController _receiptNotesController = TextEditingController();
  DateTime _receiptDateTime = DateTime.now();
  String? _receiptStationId;
  String _receiptReason = 'التأجير';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketingStationProvider>().fetchStations();
      context.read<StationInspectionProvider>().fetchInspections();
    });
  }

  void _toggleSidebar() {
    setState(() => _isSidebarExpanded = !_isSidebarExpanded);
  }

  void _onSidebarSelected(int index, {bool closeDrawer = false}) {
    if (closeDrawer) {
      Navigator.pop(context);
    }

    if (index == 5) {
      Navigator.pushNamed(context, AppRoutes.qualificationDashboard);
      return;
    }

    if (index == 6) {
      Navigator.pushNamed(context, AppRoutes.qualificationMap);
      return;
    }

    if (index == 7) {
      Navigator.pushNamed(context, AppRoutes.tasks);
      return;
    }

    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _expenseReasonController.dispose();
    _expenseAmountController.dispose();
    _expenseNotesController.dispose();
    _receiptAmountController.dispose();
    _receiptNotesController.dispose();
    super.dispose();
  }

  List<MarketingStation> _filteredStations(List<MarketingStation> stations) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return stations;
    return stations.where((station) {
      return station.name.toLowerCase().contains(query) ||
          station.city.toLowerCase().contains(query) ||
          station.address.toLowerCase().contains(query) ||
          (station.tenantName ?? '').toLowerCase().contains(query);
    }).toList();
  }

  int _statusCount(
    List<MarketingStation> stations,
    StationMarketingStatus status,
  ) {
    return stations.where((s) => s.status == status).length;
  }

  double _totalLiters(List<MarketingStation> stations) {
    return stations.fold(0, (sum, station) {
      final liters = station.pumps.fold<double>(
        0,
        (total, pump) => total + pump.soldLiters,
      );
      return sum + liters;
    });
  }

  String _ratingForStation(MarketingStation station) {
    final liters = station.pumps.fold<double>(
      0,
      (total, pump) => total + pump.soldLiters,
    );
    if (liters >= 5000) return 'ممتاز';
    if (liters >= 2000) return 'جيد جدا';
    if (liters >= 500) return 'جيد';
    return 'ضعيف';
  }

  Color _ratingColor(String rating) {
    switch (rating) {
      case 'ممتاز':
        return AppColors.successGreen;
      case 'جيد جدا':
        return Colors.teal;
      case 'جيد':
        return AppColors.warningOrange;
      default:
        return AppColors.errorRed;
    }
  }

  Future<void> _openCreateStation() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MarketingStationFormScreen()),
    );

    if (result == true && mounted) {
      await context.read<MarketingStationProvider>().fetchStations();
      setState(() => _selectedIndex = 1);
    }
  }

  Future<void> _openStationDetails(MarketingStation station) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingStationDetailsScreen(
          stationId: station.id,
          initialStation: station,
        ),
      ),
    );

    if (result == true && mounted) {
      await context.read<MarketingStationProvider>().fetchStations();
    }
  }

  Future<void> _openReportForm(MarketingStation station) async {
    final updated = await Navigator.push<MarketingStation>(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingHandoverReportFormScreen(station: station),
      ),
    );
    if (updated != null && mounted) {
      await context.read<MarketingStationProvider>().fetchStations();
    }
  }

  void _openReportView(MarketingStation station) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingHandoverReportScreen(station: station),
      ),
    );
  }

  Future<void> _openCreateInspection() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StationInspectionFormScreen()),
    );

    if (result == true && mounted) {
      await context.read<StationInspectionProvider>().fetchInspections();
      setState(() => _selectedIndex = 4);
    }
  }

  Future<void> _openInspectionDetails(StationInspection inspection) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StationInspectionDetailsScreen(
          inspectionId: inspection.id,
          initialInspection: inspection,
        ),
      ),
    );

    if (result == true && mounted) {
      await context.read<StationInspectionProvider>().fetchInspections();
    }
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedIndex == 4) {
      return FloatingActionButton.extended(
        onPressed: _openCreateInspection,
        icon: const Icon(Icons.add),
        label: const Text('إضافة معاينة'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: _openCreateStation,
      icon: const Icon(Icons.add),
      label: const Text('إضافة محطة'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Consumer2<MarketingStationProvider, StationInspectionProvider>(
      builder: (context, provider, inspectionProvider, _) {
        final stations = provider.stations;
        final filtered = _filteredStations(stations);
        final reportStations = _filteredReportStations(stations);
        final title = _titleForIndex(_selectedIndex);
        final primaryFab = _buildFloatingActionButton();

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.appBarGradient,
              ),
            ),
            leading: isWide
                ? IconButton(
                    tooltip: _isSidebarExpanded
                        ? 'إخفاء القائمة'
                        : 'إظهار القائمة',
                    icon: Icon(
                      _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                    ),
                    onPressed: _toggleSidebar,
                  )
                : null,
            title: Text(
              isWide ? 'تسويق المحطات' : title,
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                tooltip: 'الإشعارات',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.notifications);
                },
              ),
              IconButton(
                tooltip: 'تسجيل الخروج',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final authProvider = context.read<AuthProvider>();
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
          ),

          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _buildSideBar(
                      isWide: true,
                      isExpanded: true,
                      selectedIndex: _selectedIndex,
                      onSelected: (index) {
                        _onSidebarSelected(index, closeDrawer: true);
                      },
                      title: title,
                    ),
                  ),
                ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [if (primaryFab != null) primaryFab],
          ),
          body: Stack(
            children: [
              const AppSoftBackground(),
              Row(
                children: [
                  if (isWide)
                    _buildSideBar(
                      isWide: isWide,
                      isExpanded: _isSidebarExpanded,
                      selectedIndex: _selectedIndex,
                      onSelected: (index) {
                        _onSidebarSelected(index);
                      },
                      title: title,
                      onToggle: _toggleSidebar,
                    ),
                  Expanded(
                    child: _buildContentForIndex(
                      isWide: isWide,
                      stations: stations,
                      filteredStations: filtered,
                      reportStations: reportStations,
                      provider: provider,
                      inspectionProvider: inspectionProvider,
                    ),
                  ),
                ],
              ),
              if (provider.isLoading || inspectionProvider.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.white70,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'الداشبورد';
      case 1:
        return 'سجل المحطات';
      case 2:
        return 'سجل محاضر تسليم المحروقات';
      case 3:
        return 'مصروفات المحطات';
      case 4:
        return 'معاينات المحطات';
      case 5:
        return 'مواقع تحت الدراسة';
      case 6:
        return 'خريطة الموقع';
      case 7:
        return 'المهام';
      default:
        return 'تسويق المحطات';
    }
  }

  List<MarketingStation> _filteredReportStations(
    List<MarketingStation> stations,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final reports = stations.where((s) => s.handoverReport != null).toList();
    if (query.isEmpty) return reports;
    return reports.where((station) {
      final report = station.handoverReport!;
      return station.name.toLowerCase().contains(query) ||
          station.city.toLowerCase().contains(query) ||
          report.reportNumber.toLowerCase().contains(query) ||
          report.contractReference.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildSideBar({
    required bool isWide,
    required bool isExpanded,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required String title,
    VoidCallback? onToggle,
  }) {
    if (!isWide) {
      return const SizedBox(width: 0);
    }

    final showToggle = onToggle != null;
    final effectiveExpanded = showToggle ? isExpanded : true;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      width: effectiveExpanded ? 260 : 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        border: Border(
          left: isRtl
              ? BorderSide(color: AppColors.lightGray)
              : BorderSide.none,
          right: isRtl
              ? BorderSide.none
              : BorderSide(color: AppColors.lightGray),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: effectiveExpanded ? 20 : 12,
              vertical: 18,
            ),
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.local_gas_station, size: 20),
                ),
                if (effectiveExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تسويق المحطات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),
                if (showToggle)
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      effectiveExpanded
                          ? (isRtl ? Icons.chevron_right : Icons.chevron_left)
                          : (isRtl ? Icons.chevron_left : Icons.chevron_right),
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _sideItem(
                  icon: Icons.dashboard,
                  label: 'الداشبورد',
                  index: 0,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.list_alt,
                  label: 'سجل المحطات',
                  index: 1,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.assignment,
                  label: 'سجل محاضر تسليم المحروقات',
                  index: 2,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.payments_outlined,
                  label: 'مصروفات المحطات',
                  index: 3,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.rate_review_outlined,
                  label:
                      '\u0645\u0639\u0627\u064a\u0646\u0627\u062a \u0627\u0644\u0645\u062d\u0637\u0627\u062a',
                  index: 4,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.verified_outlined,
                  label:
                      '\u0645\u0648\u0627\u0642\u0639 \u062a\u062d\u062a \u0627\u0644\u062f\u0631\u0627\u0633\u0629',
                  index: 5,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.map_outlined,
                  label:
                      '\u062e\u0631\u064a\u0637\u0629 \u0627\u0644\u0645\u0648\u0642\u0639',
                  index: 6,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
                _sideItem(
                  icon: Icons.assignment_turned_in,
                  label: '\u0627\u0644\u0645\u0647\u0627\u0645',
                  index: 7,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                  isExpanded: effectiveExpanded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideItem({
    required IconData icon,
    required String label,
    required int index,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required bool isExpanded,
  }) {
    final isSelected = index == selectedIndex;
    final color = isSelected ? AppColors.primaryBlue : AppColors.darkGray;
    final iconBg = isSelected
        ? AppColors.primaryBlue.withValues(alpha: 0.14)
        : AppColors.backgroundGray.withValues(alpha: 0.65);
    return InkWell(
      onTap: () => onSelected(index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 12 : 10,
          vertical: 9,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.10)
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: isExpanded
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            if (isExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentForIndex({
    required bool isWide,
    required List<MarketingStation> stations,
    required List<MarketingStation> filteredStations,
    required List<MarketingStation> reportStations,
    required MarketingStationProvider provider,
    required StationInspectionProvider inspectionProvider,
  }) {
    Widget child;
    switch (_selectedIndex) {
      case 0:
        child = _buildDashboardTab(isWide, stations);
        break;
      case 1:
        child = _buildStationsTab(isWide, filteredStations, provider);
        break;
      case 2:
        child = _buildHandoverReportsTab(isWide, reportStations);
        break;
      case 3:
        child = _buildExpensesTab(isWide, stations, provider);
        break;
      case 4:
        child = _buildInspectionsTab(isWide, inspectionProvider);
        break;
      case 5:
        child = _buildDashboardTab(isWide, stations);
        break;
      case 6:
        child = _buildDashboardTab(isWide, stations);
        break;
      case 7:
        child = _buildDashboardTab(isWide, stations);
        break;
      default:
        child = _buildDashboardTab(isWide, stations);
    }

    if (!isWide) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: child,
      ),
    );
  }

  Widget _buildDashboardTab(bool isWide, List<MarketingStation> stations) {
    final totalStations = stations.length;
    final totalLiters = _totalLiters(stations);
    final totalCost = _totalStationCostAll(stations);
    final totalLeaseAmount = _totalLeaseAmountAll(stations);
    final totalExpenses = _totalExpensesAll(stations);
    final expectedProfit = totalLeaseAmount - totalCost - totalExpenses;
    final suggestedTotal = _totalSuggestedLeaseAll(stations);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('ملخص التسويق'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              label: 'المحطات المسجلة',
              value: totalStations.toString(),
              icon: Icons.local_gas_station,
              color: AppColors.primaryBlue,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'تحت المراجعة',
              value: _statusCount(
                stations,
                StationMarketingStatus.pendingReview,
              ).toString(),
              icon: Icons.rate_review,
              color: AppColors.warningOrange,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'مؤجرة',
              value: _statusCount(
                stations,
                StationMarketingStatus.rented,
              ).toString(),
              icon: Icons.assignment_ind,
              color: Colors.teal,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'إجمالي اللترات',
              value: _formatNumber(totalLiters),
              icon: Icons.local_fire_department,
              color: AppColors.successGreen,
              width: isWide ? 260 : double.infinity,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('ملخص مالي'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              label: 'تكلفة الاستئجار',
              value: _formatCurrency(totalCost),
              icon: Icons.money_off,
              color: AppColors.errorRed,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'المصاريف',
              value: _formatCurrency(totalExpenses),
              icon: Icons.receipt_long,
              color: AppColors.warningOrange,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'سعر التأجير المخطط',
              value: _formatCurrency(totalLeaseAmount),
              icon: Icons.payments,
              color: AppColors.successGreen,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'الربح المتوقع',
              value: _formatCurrency(expectedProfit),
              icon: Icons.account_balance_wallet_outlined,
              color: expectedProfit >= 0 ? Colors.teal : AppColors.errorRed,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'سعر تأجير مقترح',
              value: _formatCurrency(suggestedTotal),
              icon: Icons.lightbulb,
              color: AppColors.accentBlue,
              width: isWide ? 260 : double.infinity,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('التوزيعات والإحصائيات'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _distributionPanel(
              title: 'توزيع الحالات',
              icon: Icons.insights,
              child: _buildStatusDistribution(stations),
              width: isWide ? 360 : double.infinity,
            ),
            _distributionPanel(
              title: 'توزيع المدن',
              icon: Icons.location_city,
              child: _buildCityDistribution(stations),
              width: isWide ? 360 : double.infinity,
            ),
            _distributionPanel(
              title: 'توزيع اللترات',
              icon: Icons.water_drop,
              child: _buildLitersDistribution(stations),
              width: isWide ? 360 : double.infinity,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('جدول المحطات التفصيلي'),
        const SizedBox(height: 12),
        _buildStationsTable(stations),
      ],
    );
  }

  Widget _distributionPanel({
    required String title,
    required IconData icon,
    required Widget child,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGray,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistribution(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text(
        'لا توجد بيانات بعد',
        style: TextStyle(color: AppColors.mediumGray),
      );
    }

    final total = stations.length.toDouble();
    final items = [
      _StatusEntry(
        label: 'تحت المراجعة',
        count: _statusCount(stations, StationMarketingStatus.pendingReview),
        color: AppColors.warningOrange,
        icon: Icons.rate_review,
      ),
      _StatusEntry(
        label: 'جاهزة للتأجير',
        count: _statusCount(stations, StationMarketingStatus.readyForLease),
        color: AppColors.accentBlue,
        icon: Icons.check_circle_outline,
      ),
      _StatusEntry(
        label: 'مؤجرة',
        count: _statusCount(stations, StationMarketingStatus.rented),
        color: Colors.teal,
        icon: Icons.assignment_ind,
      ),
      _StatusEntry(
        label: 'مستأجرة لشركة ناصر المطيري',
        count: _statusCount(
          stations,
          StationMarketingStatus.rentedToNasserMotairi,
        ),
        color: Colors.blueGrey,
        icon: Icons.apartment,
      ),
      _StatusEntry(
        label: 'ملغية',
        count: _statusCount(stations, StationMarketingStatus.cancelled),
        color: AppColors.errorRed,
        icon: Icons.cancel,
      ),
      _StatusEntry(
        label: 'تحت الصيانة',
        count: _statusCount(stations, StationMarketingStatus.maintenance),
        color: Colors.deepOrange,
        icon: Icons.build_circle,
      ),
      _StatusEntry(
        label: 'تحت الدراسة',
        count: _statusCount(stations, StationMarketingStatus.study),
        color: Colors.indigo,
        icon: Icons.search,
      ),
    ];

    return Column(
      children: items.map((item) {
        final percent = total == 0 ? 0.0 : item.count / total;
        return _buildBarRow(
          label: item.label,
          value: _formatNumber(item.count),
          percent: percent,
          color: item.color,
          icon: item.icon,
        );
      }).toList(),
    );
  }

  Widget _buildCityDistribution(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text(
        'لا توجد بيانات بعد',
        style: TextStyle(color: AppColors.mediumGray),
      );
    }

    final counts = <String, int>{};
    for (final station in stations) {
      final city = station.city.trim().isEmpty ? 'غير محدد' : station.city;
      counts[city] = (counts[city] ?? 0) + 1;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = stations.length.toDouble();
    final top = entries.take(6).toList();

    return Column(
      children: top.map((entry) {
        final percent = total == 0 ? 0.0 : entry.value / total;
        return _buildBarRow(
          label: entry.key,
          value: _formatNumber(entry.value),
          percent: percent,
          color: AppColors.accentBlue,
          icon: Icons.location_city,
        );
      }).toList(),
    );
  }

  Widget _buildLitersDistribution(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text(
        'لا توجد بيانات بعد',
        style: TextStyle(color: AppColors.mediumGray),
      );
    }

    final liters = <_NamedValue>[];
    for (final station in stations) {
      liters.add(
        _NamedValue(label: station.name, value: _stationLiters(station)),
      );
    }
    liters.sort((a, b) => b.value.compareTo(a.value));

    final top = liters.take(6).toList();
    final maxValue = top.isEmpty ? 0.0 : top.first.value;

    return Column(
      children: top.map((entry) {
        final percent = maxValue == 0 ? 0.0 : entry.value / maxValue;
        return _buildBarRow(
          label: entry.label,
          value: _formatNumber(entry.value),
          percent: percent,
          color: AppColors.successGreen,
          icon: Icons.local_fire_department,
        );
      }).toList(),
    );
  }

  Widget _buildBarRow({
    required String label,
    required String value,
    required double percent,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationsTable(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return AppSurfaceCard(
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        child: const Text(
          'لا توجد محطات بعد',
          style: TextStyle(
            color: AppColors.mediumGray,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: 420,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        AppColors.backgroundGray.withValues(alpha: 0.70),
                      ),
                      columnSpacing: 24,
                      dividerThickness: 0.6,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGray,
                      ),
                      dataTextStyle: const TextStyle(
                        color: AppColors.darkGray,
                        fontWeight: FontWeight.w600,
                      ),
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('المحطة')),
                        DataColumn(label: Text('المدينة')),
                        DataColumn(label: Text('الحالة')),
                        DataColumn(label: Text('المضخات')),
                        DataColumn(label: Text('اللترات')),
                        DataColumn(label: Text('سعر الاستئجار')),
                        DataColumn(label: Text('سعر التأجير')),
                        DataColumn(label: Text('المستأجر')),
                        DataColumn(label: Text('التقييم')),
                      ],
                      rows: [
                        for (int i = 0; i < stations.length; i++)
                          _buildStationRow(i + 1, stations[i]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _buildStationRow(int index, MarketingStation station) {
    final liters = _stationLiters(station);
    final rating = _ratingForStation(station);
    return DataRow(
      cells: [
        DataCell(Text(index.toString())),
        DataCell(Text(station.name)),
        DataCell(Text(station.city)),
        DataCell(_statusBadge(station.status)),
        DataCell(Text(station.pumps.length.toString())),
        DataCell(Text(_formatNumber(liters))),
        DataCell(Text(_formatCurrency(station.accounting.stationCost))),
        DataCell(Text(_formatCurrency(station.accounting.leaseAmount))),
        DataCell(Text(station.tenantName ?? 'بدون')),
        DataCell(Text(rating, style: TextStyle(color: _ratingColor(rating)))),
      ],
    );
  }

  double _stationLiters(MarketingStation station) {
    return station.pumps.fold<double>(
      0,
      (total, pump) => total + pump.soldLiters,
    );
  }

  String _formatNumber(num value) {
    return NumberFormat.decimalPattern('ar').format(value);
  }

  Widget _buildTasksTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('وظائف التسويق'),
        const SizedBox(height: 16),
        _taskCard(
          title: 'مراجعة المحطات الجديدة',
          subtitle: 'تحقق من بيانات المحطات المضافة حديثا واعتمادها.',
          icon: Icons.task_alt,
        ),
        const SizedBox(height: 12),
        _taskCard(
          title: 'جدولة زيارات ميدانية',
          subtitle: 'تنظيم زيارات لتقييم حالة المحطات على أرض الواقع.',
          icon: Icons.calendar_month,
        ),
        const SizedBox(height: 12),
        _taskCard(
          title: 'متابعة عقود التأجير',
          subtitle: 'مراجعة العقود والتجديدات والتنبيهات.',
          icon: Icons.description_outlined,
        ),
      ],
    );
  }

  Widget _buildDistributionTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('توزيعة الفرق'),
        const SizedBox(height: 16),
        _infoCard(
          title: 'توزيع المناطق',
          body: 'قم بتوزيع المحطات على فرق التسويق حسب المدينة أو المنطقة.',
        ),
        const SizedBox(height: 12),
        _infoCard(
          title: 'توزيع المهام',
          body: 'حدد المسؤول عن كل محطة لمتابعة الصيانة والتأجير.',
        ),
      ],
    );
  }

  Widget _buildStationsTab(
    bool isWide,
    List<MarketingStation> stations,
    MarketingStationProvider provider,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppSurfaceCard(
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('سجل المحطات'),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المحطة، المدينة، المستأجر...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _searchController.clear());
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.82),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: const TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: stations.isEmpty
              ? const Center(child: Text('لا توجد محطات للعرض'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final station = stations[index];
                    final rating = _ratingForStation(station);
                    return _stationCard(
                      station: station,
                      rating: rating,
                      ratingColor: _ratingColor(rating),
                      isWide: isWide,
                      onTap: () => _openStationDetails(station),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: stations.length,
                ),
        ),
      ],
    );
  }

  Widget _buildHandoverReportsTab(
    bool isWide,
    List<MarketingStation> stations,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppSurfaceCard(
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('سجل محاضر تسليم المحروقات'),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المحطة أو رقم المحضر أو المرجع...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _searchController.clear());
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.82),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: stations.isEmpty
              ? const Center(child: Text('لا توجد محاضر تسليم بعد'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final station = stations[index];
                    final report = station.handoverReport!;
                    return InkWell(
                      onTap: () => _openReportView(station),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightGray),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    report.reportNumber.isNotEmpty
                                        ? 'محضر رقم ${report.reportNumber}'
                                        : 'محضر تسليم محروقات',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _statusBadge(station.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              station.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              station.city,
                              style: TextStyle(color: AppColors.mediumGray),
                            ),
                            const SizedBox(height: 6),
                            if (report.contractReference.isNotEmpty)
                              Text(
                                'مرجع العقد: ${report.contractReference}',
                                style: TextStyle(color: AppColors.mediumGray),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openReportView(station),
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('عرض'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _openReportForm(station),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('تعديل'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: stations.length,
                ),
        ),
      ],
    );
  }

  Widget _buildExpensesTab(
    bool isWide,
    List<MarketingStation> stations,
    MarketingStationProvider provider,
  ) {
    _ensureExpenseStationSelection(stations);

    final totalExpenses = _totalExpensesAll(stations);
    final totalReceipts = _totalReceiptsAll(stations);
    final net = totalReceipts - totalExpenses;
    final expenseEntries = _collectExpenseEntries(stations);
    final receiptEntries = _collectReceiptEntries(stations);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('لوحة المصروفات والمقبوضات'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              label: 'إجمالي المصروفات',
              value: _formatCurrency(totalExpenses),
              icon: Icons.money_off,
              color: AppColors.errorRed,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'إجمالي المقبوضات',
              value: _formatCurrency(totalReceipts),
              icon: Icons.payments,
              color: AppColors.successGreen,
              width: isWide ? 260 : double.infinity,
            ),
            _statCard(
              label: 'صافي الربح/الخسارة',
              value: _formatCurrency(net),
              icon: Icons.account_balance_wallet_outlined,
              color: net >= 0 ? Colors.teal : AppColors.warningOrange,
              width: isWide ? 260 : double.infinity,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _financeSection(
          title: 'مصروفات المحطات',
          actionLabel: 'إضافة مصروف',
          actionIcon: Icons.add,
          onAction: () => _openExpenseDialog(stations, provider),
          distributionTitle: 'توزيعة المصروفات على المحطات',
          distributionBody: _buildExpenseDistributionList(stations),
          recordsTitle: 'سجل سندات المصروف',
          recordsBody: _voucherList(
            entries: expenseEntries,
            emptyLabel: 'لا توجد سندات مصروف بعد',
            amountColor: AppColors.errorRed,
          ),
        ),
        const SizedBox(height: 24),
        _financeSection(
          title: 'مقبوضات المحطات',
          actionLabel: 'إنشاء مقبوض',
          actionIcon: Icons.add_circle_outline,
          onAction: () => _openReceiptDialog(stations, provider),
          distributionTitle: 'توزيعة المقبوضات على المحطات',
          distributionBody: _buildReceiptDistributionList(stations),
          recordsTitle: 'سجل سندات القبض',
          recordsBody: _voucherList(
            entries: receiptEntries,
            emptyLabel: 'لا توجد سندات قبض بعد',
            amountColor: AppColors.successGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildInspectionsTab(
    bool isWide,
    StationInspectionProvider inspectionProvider,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final inspections = inspectionProvider.inspections;
    final filtered = query.isEmpty
        ? List<StationInspection>.from(inspections)
        : inspections.where((inspection) {
            final ownerName = inspection.owner?.name ?? '';
            final createdBy = inspection.createdByName ?? '';
            return inspection.name.toLowerCase().contains(query) ||
                inspection.city.toLowerCase().contains(query) ||
                inspection.region.toLowerCase().contains(query) ||
                inspection.address.toLowerCase().contains(query) ||
                ownerName.toLowerCase().contains(query) ||
                createdBy.toLowerCase().contains(query) ||
                _inspectionStatusLabel(
                  inspection.status,
                ).toLowerCase().contains(query);
          }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: AppSurfaceCard(
            borderRadius: const BorderRadius.all(Radius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('معاينات المحطات'),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المحطة، المدينة، المنطقة، المالك...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _searchController.clear());
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.82),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (inspectionProvider.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    inspectionProvider.error!,
                    style: const TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0639\u0627\u064a\u0646\u0627\u062a \u0644\u0644\u0639\u0631\u0636',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final inspection = filtered[index];
                    return _inspectionCard(
                      inspection: inspection,
                      isWide: isWide,
                      onTap: () => _openInspectionDetails(inspection),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: filtered.length,
                ),
        ),
      ],
    );
  }

  Widget _inspectionCard({
    required StationInspection inspection,
    required bool isWide,
    required VoidCallback onTap,
  }) {
    final totalLiters = inspection.pumps.fold<double>(
      0,
      (sum, pump) => sum + pump.soldLiters,
    );
    final totalNozzles = inspection.pumps.fold<int>(
      0,
      (sum, pump) => sum + pump.nozzleCount,
    );
    final attachmentCount = inspection.attachments.length;
    final ownerName = inspection.owner?.name ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inspection.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _inspectionStatusBadge(inspection.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${inspection.city} - ${inspection.region} - ${inspection.address}',
              style: TextStyle(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  icon: Icons.speed,
                  label:
                      '\u0627\u0644\u0645\u0636\u062e\u0627\u062a: ${inspection.pumps.length}',
                ),
                _infoChip(
                  icon: Icons.call_split,
                  label: '\u0627\u0644\u0644\u064a\u0627\u062a: $totalNozzles',
                ),
                _infoChip(
                  icon: Icons.water_drop,
                  label:
                      '\u0627\u0644\u0644\u062a\u0631\u0627\u062a: ${totalLiters.toStringAsFixed(0)}',
                ),
                if (attachmentCount > 0)
                  _infoChip(
                    icon: Icons.attach_file,
                    label:
                        '\u0645\u0631\u0641\u0642\u0627\u062a: $attachmentCount',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ownerName.isNotEmpty
                  ? '\u0627\u0644\u0645\u0627\u0644\u0643: $ownerName'
                  : '\u0627\u0644\u0645\u0627\u0644\u0643: -',
              style: TextStyle(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 6),
            Text(
              '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0645\u0639\u0627\u064a\u0646\u0629: ${DateFormat('yyyy-MM-dd').format(inspection.createdAt)}',
              style: TextStyle(color: AppColors.mediumGray),
            ),
            if (isWide) ...[
              const SizedBox(height: 6),
              Text(
                '\u062a\u0645\u062a \u0627\u0644\u0625\u0636\u0627\u0641\u0629 \u0628\u0648\u0627\u0633\u0637\u0629: ${inspection.createdByName ?? '-'}',
                style: TextStyle(color: AppColors.lightGray),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inspectionStatusBadge(InspectionStatus status) {
    final label = _inspectionStatusLabel(status);
    Color color;

    switch (status) {
      case InspectionStatus.accepted:
        color = AppColors.successGreen;
        break;
      case InspectionStatus.rejected:
        color = AppColors.errorRed;
        break;
      case InspectionStatus.pending:
      default:
        color = AppColors.warningOrange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  String _inspectionStatusLabel(InspectionStatus status) {
    switch (status) {
      case InspectionStatus.accepted:
        return '\u0645\u0642\u0628\u0648\u0644\u0629';
      case InspectionStatus.rejected:
        return '\u0645\u0631\u0641\u0648\u0636\u0629';
      case InspectionStatus.pending:
      default:
        return '\u062a\u062d\u062a \u0627\u0644\u0645\u0639\u0627\u064a\u0646\u0629';
    }
  }

  Widget _financeSection({
    required String title,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onAction,
    required String distributionTitle,
    required Widget distributionBody,
    required String recordsTitle,
    required Widget recordsBody,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeaderWithAction(
            title: title,
            actionLabel: actionLabel,
            icon: actionIcon,
            onPressed: onAction,
          ),
          const SizedBox(height: 16),
          _subSectionTitle(distributionTitle),
          const SizedBox(height: 12),
          distributionBody,
          const SizedBox(height: 16),
          _subSectionTitle(recordsTitle),
          const SizedBox(height: 12),
          recordsBody,
        ],
      ),
    );
  }

  Widget _sectionHeaderWithAction({
    required String title,
    required String actionLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(actionLabel),
        ),
      ],
    );
  }

  Widget _subSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold));
  }

  Widget _buildExpenseDistributionList(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text(
        'لا توجد محطات بعد',
        style: TextStyle(color: AppColors.mediumGray),
      );
    }
    return Column(
      children: stations.map((station) {
        final expenses = _totalExpensesForStation(station);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${station.city} - ${station.address}',
                style: TextStyle(color: AppColors.mediumGray),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    icon: Icons.money_off,
                    label: 'المصروفات: ${_formatCurrency(expenses)}',
                    color: AppColors.errorRed,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReceiptDistributionList(List<MarketingStation> stations) {
    if (stations.isEmpty) {
      return Text(
        'لا توجد محطات بعد',
        style: TextStyle(color: AppColors.mediumGray),
      );
    }
    return Column(
      children: stations.map((station) {
        final expenses = _totalExpensesForStation(station);
        final receipts = _totalReceiptsForStation(station);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${station.city} - ${station.address}',
                style: TextStyle(color: AppColors.mediumGray),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    icon: Icons.payments,
                    label: 'المقبوضات: ${_formatCurrency(receipts)}',
                    color: AppColors.successGreen,
                  ),
                  _infoChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'الصافي: ${_formatCurrency(receipts - expenses)}',
                    color: receipts - expenses >= 0
                        ? Colors.teal
                        : AppColors.warningOrange,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openExpenseDialog(
    List<MarketingStation> stations,
    MarketingStationProvider provider,
  ) async {
    if (stations.isEmpty) {
      _showSnackBar('أضف محطة أولاً');
      return;
    }
    _ensureExpenseStationSelection(stations);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة مصروف'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStationDropdown(
                        label: 'المحطة',
                        stations: stations,
                        selectedId: _expenseStationId,
                        onChanged: (value) {
                          setState(() => _expenseStationId = value);
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _expenseReasonController,
                        label: 'سبب المصروف',
                        icon: Icons.description_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _expenseAmountController,
                        label: 'المبلغ (ر.س)',
                        icon: Icons.payments,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _expenseNotesController,
                        label: 'ملاحظات (اختياري)',
                        icon: Icons.notes,
                        requiredField: false,
                      ),
                      const SizedBox(height: 12),
                      _dateTimePicker(
                        label: 'تاريخ ووقت المصروف',
                        value: _expenseDateTime,
                        onTap: () => _pickDateTime(
                          initial: _expenseDateTime,
                          onSelected: (value) {
                            setState(() => _expenseDateTime = value);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final ok = await _saveExpense(provider);
                          if (ok && mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openReceiptDialog(
    List<MarketingStation> stations,
    MarketingStationProvider provider,
  ) async {
    if (stations.isEmpty) {
      _showSnackBar('أضف محطة أولاً');
      return;
    }
    _ensureExpenseStationSelection(stations);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إنشاء مقبوض'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStationDropdown(
                        label: 'المحطة',
                        stations: stations,
                        selectedId: _receiptStationId,
                        onChanged: (value) {
                          setState(() => _receiptStationId = value);
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _receiptReason,
                        items: const [
                          DropdownMenuItem(
                            value: 'التأجير',
                            child: Text('التأجير'),
                          ),
                          DropdownMenuItem(
                            value: 'تحصيل الإيجار',
                            child: Text('تحصيل الإيجار'),
                          ),
                          DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _receiptReason = value);
                          setDialogState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'سبب القبض',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _receiptAmountController,
                        label: 'المبلغ (ر.س)',
                        icon: Icons.payments,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _receiptNotesController,
                        label: 'ملاحظات (اختياري)',
                        icon: Icons.notes,
                        requiredField: false,
                      ),
                      const SizedBox(height: 12),
                      _dateTimePicker(
                        label: 'تاريخ ووقت القبض',
                        value: _receiptDateTime,
                        onTap: () => _pickDateTime(
                          initial: _receiptDateTime,
                          onSelected: (value) {
                            setState(() => _receiptDateTime = value);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final ok = await _saveReceipt(provider);
                          if (ok && mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _expenseFormCard(
    bool isWide,
    List<MarketingStation> stations,
    MarketingStationProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStationDropdown(
            label: 'المحطة',
            stations: stations,
            selectedId: _expenseStationId,
            onChanged: (value) => setState(() => _expenseStationId = value),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _expenseReasonController,
            label: 'سبب المصروف',
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _expenseAmountController,
            label: 'المبلغ (ر.س)',
            icon: Icons.payments,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _expenseNotesController,
            label: 'ملاحظات (اختياري)',
            icon: Icons.notes,
            requiredField: false,
          ),
          const SizedBox(height: 12),
          _dateTimePicker(
            label: 'تاريخ ووقت المصروف',
            value: _expenseDateTime,
            onTap: () => _pickDateTime(
              initial: _expenseDateTime,
              onSelected: (value) => setState(() => _expenseDateTime = value),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: provider.isLoading ? null : () => _saveExpense(provider),
            icon: const Icon(Icons.save),
            label: const Text('حفظ سند المصروف'),
          ),
        ],
      ),
    );
  }

  Widget _receiptFormCard(
    bool isWide,
    List<MarketingStation> stations,
    MarketingStationProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStationDropdown(
            label: 'المحطة',
            stations: stations,
            selectedId: _receiptStationId,
            onChanged: (value) => setState(() => _receiptStationId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _receiptReason,
            items: const [
              DropdownMenuItem(value: 'التأجير', child: Text('التأجير')),
              DropdownMenuItem(
                value: 'تحصيل الإيجار',
                child: Text('تحصيل الإيجار'),
              ),
              DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _receiptReason = value);
            },
            decoration: InputDecoration(
              labelText: 'سبب القبض',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _receiptAmountController,
            label: 'المبلغ (ر.س)',
            icon: Icons.payments,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _receiptNotesController,
            label: 'ملاحظات (اختياري)',
            icon: Icons.notes,
            requiredField: false,
          ),
          const SizedBox(height: 12),
          _dateTimePicker(
            label: 'تاريخ ووقت القبض',
            value: _receiptDateTime,
            onTap: () => _pickDateTime(
              initial: _receiptDateTime,
              onSelected: (value) => setState(() => _receiptDateTime = value),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: provider.isLoading ? null : () => _saveReceipt(provider),
            icon: const Icon(Icons.save),
            label: const Text('حفظ سند القبض'),
          ),
        ],
      ),
    );
  }

  Widget _buildStationDropdown({
    required String label,
    required List<MarketingStation> stations,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      items: stations
          .map(
            (station) =>
                DropdownMenuItem(value: station.id, child: Text(station.name)),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _dateTimePicker({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    final formatted = DateFormat('yyyy-MM-dd HH:mm').format(value);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 8),
            Text(formatted),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final time = pickedTime ?? TimeOfDay.fromDateTime(initial);
    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
    );
    onSelected(dateTime);
  }

  void _ensureExpenseStationSelection(List<MarketingStation> stations) {
    if (stations.isEmpty) return;
    if (_expenseStationId == null) {
      _expenseStationId = stations.first.id;
    }
    if (_receiptStationId == null) {
      _receiptStationId = stations.first.id;
    }
  }

  double _totalExpensesForStation(MarketingStation station) {
    return station.expenseVouchers.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
  }

  double _totalReceiptsForStation(MarketingStation station) {
    return station.receiptVouchers.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
  }

  double _totalExpensesAll(List<MarketingStation> stations) {
    return stations.fold<double>(
      0,
      (sum, station) => sum + _totalExpensesForStation(station),
    );
  }

  double _totalReceiptsAll(List<MarketingStation> stations) {
    return stations.fold<double>(
      0,
      (sum, station) => sum + _totalReceiptsForStation(station),
    );
  }

  double _totalStationCostAll(List<MarketingStation> stations) {
    return stations.fold<double>(
      0,
      (sum, station) => sum + station.accounting.stationCost,
    );
  }

  double _totalLeaseAmountAll(List<MarketingStation> stations) {
    return stations.fold<double>(
      0,
      (sum, station) => sum + station.accounting.leaseAmount,
    );
  }

  double _totalSuggestedLeaseAll(List<MarketingStation> stations) {
    const targetMargin = 0.15;
    return stations.fold<double>(0, (sum, station) {
      final base = station.accounting.stationCost + station.accounting.expenses;
      final suggested = base == 0 ? 0 : base * (1 + targetMargin);
      return sum + suggested;
    });
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    ).format(value);
  }

  Future<bool> _saveExpense(MarketingStationProvider provider) async {
    if (_expenseStationId == null) {
      _showSnackBar('اختر محطة أولاً');
      return false;
    }
    final amount = double.tryParse(_expenseAmountController.text.trim()) ?? 0;
    final reason = _expenseReasonController.text.trim();
    if (amount <= 0 || reason.isEmpty) {
      _showSnackBar('سبب المصروف والمبلغ مطلوبان');
      return false;
    }

    final expense = StationExpense(
      reason: reason,
      amount: amount,
      createdAt: _expenseDateTime,
      notes: _expenseNotesController.text.trim(),
    );
    final result = await provider.addExpenseVoucher(
      _expenseStationId!,
      expense,
    );
    if (result == null) {
      _showSnackBar(provider.error ?? 'فشل إضافة المصروف');
      return false;
    }

    setState(() {
      _expenseReasonController.clear();
      _expenseAmountController.clear();
      _expenseNotesController.clear();
      _expenseDateTime = DateTime.now();
    });
    _showSnackBar('تم حفظ سند المصروف');

    return true;
  }

  Future<bool> _saveReceipt(MarketingStationProvider provider) async {
    if (_receiptStationId == null) {
      _showSnackBar('اختر محطة أولاً');
      return false;
    }
    final amount = double.tryParse(_receiptAmountController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showSnackBar('المبلغ مطلوب');
      return false;
    }

    final receipt = StationReceipt(
      reason: _receiptReason,
      amount: amount,
      createdAt: _receiptDateTime,
      notes: _receiptNotesController.text.trim(),
    );
    final result = await provider.addReceiptVoucher(
      _receiptStationId!,
      receipt,
    );
    if (result == null) {
      _showSnackBar(provider.error ?? 'فشل إضافة سند القبض');
      return false;
    }

    setState(() {
      _receiptAmountController.clear();
      _receiptNotesController.clear();
      _receiptDateTime = DateTime.now();
      _receiptReason = 'التأجير';
    });
    _showSnackBar('تم حفظ سند القبض');

    return true;
  }

  List<_VoucherEntry> _collectExpenseEntries(List<MarketingStation> stations) {
    final entries = <_VoucherEntry>[];
    for (final station in stations) {
      for (final expense in station.expenseVouchers) {
        entries.add(
          _VoucherEntry(
            stationName: station.name,
            reason: expense.reason,
            amount: expense.amount,
            createdAt: expense.createdAt,
          ),
        );
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  List<_VoucherEntry> _collectReceiptEntries(List<MarketingStation> stations) {
    final entries = <_VoucherEntry>[];
    for (final station in stations) {
      for (final receipt in station.receiptVouchers) {
        entries.add(
          _VoucherEntry(
            stationName: station.name,
            reason: receipt.reason,
            amount: receipt.amount,
            createdAt: receipt.createdAt,
          ),
        );
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Widget _voucherList({
    required List<_VoucherEntry> entries,
    required String emptyLabel,
    required Color amountColor,
  }) {
    if (entries.isEmpty) {
      return Text(emptyLabel, style: TextStyle(color: AppColors.mediumGray));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGray),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: amountColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.stationName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.reason,
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(entry.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(entry.createdAt),
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _stationCard({
    required MarketingStation station,
    required String rating,
    required Color ratingColor,
    required bool isWide,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_gas_station, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusBadge(station.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${station.city} - ${station.address}',
              style: TextStyle(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  icon: Icons.speed,
                  label: 'المضخات: ${station.pumps.length}',
                ),
                _infoChip(
                  icon: Icons.person,
                  label: station.tenantName == null
                      ? 'بدون مستأجر'
                      : 'المستأجر: ${station.tenantName}',
                ),
                _infoChip(
                  icon: Icons.assessment,
                  label: 'التقييم: $rating',
                  color: ratingColor,
                ),
              ],
            ),
            if (isWide) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'تمت الإضافة بواسطة: ${station.createdByName ?? 'غير محدد'}',
                  style: TextStyle(color: AppColors.lightGray),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.95),
                    color.withValues(alpha: 0.55),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
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

  Widget _taskCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
        color: Colors.white,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
            foregroundColor: AppColors.primaryBlue,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: AppColors.mediumGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.backgroundGray,
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: AppColors.mediumGray)),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: chipColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statusBadge(StationMarketingStatus status) {
    String label;
    Color color;

    switch (status) {
      case StationMarketingStatus.pendingReview:
        label = 'تحت المراجعة';
        color = AppColors.warningOrange;
        break;
      case StationMarketingStatus.readyForLease:
        label = 'جاهزة للتأجير';
        color = AppColors.accentBlue;
        break;
      case StationMarketingStatus.rented:
        label = 'مؤجرة';
        color = Colors.teal;
        break;
      case StationMarketingStatus.rentedToNasserMotairi:
        label = 'مستأجرة لشركة ناصر المطيري';
        color = Colors.blueGrey;
        break;
      case StationMarketingStatus.cancelled:
        label = 'ملغية';
        color = AppColors.errorRed;
        break;
      case StationMarketingStatus.maintenance:
        label = 'تحت الصيانة';
        color = Colors.deepOrange;
        break;
      case StationMarketingStatus.study:
        label = 'تحت الدراسة';
        color = Colors.indigo;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _StatusEntry {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusEntry({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
}

class _NamedValue {
  final String label;
  final double value;

  const _NamedValue({required this.label, required this.value});
}

class _VoucherEntry {
  final String stationName;
  final String reason;
  final double amount;
  final DateTime createdAt;

  _VoucherEntry({
    required this.stationName,
    required this.reason,
    required this.amount,
    required this.createdAt,
  });
}
