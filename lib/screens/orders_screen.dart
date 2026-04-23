import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/screens/tracking/driver_delivery_tracking_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/filter_dialog.dart';
import 'package:order_tracker/widgets/order_data_grid.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 30;
  static const List<_OrdersTabItem> _tabs = [
    _OrdersTabItem(key: 'all', label: 'الكل'),
    _OrdersTabItem(key: 'customer', label: 'طلبات العملاء'),
    _OrdersTabItem(key: 'supplier', label: 'طلبات الموردين'),
    _OrdersTabItem(key: 'merged', label: 'المدمجة'),
  ];

  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  Map<String, dynamic> _extraFilters = {};
  Map<String, int> _summaryCounts = const {};
  List<Order> _orders = const [];
  bool _isLoading = false;
  bool _isStatsLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalOrders = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, 1);
    _rangeEnd = DateTime(now.year, now.month + 1, 0);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOrders(resetPage: true, refreshStats: true);
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    _refreshOrders(resetPage: true);
    setState(() {});
  }

  String _formatRangeDate(DateTime value) {
    return DateFormat('yyyy/MM/dd', 'ar').format(value);
  }

  String _formatMonthLabel(DateTime value) {
    return DateFormat('MMMM yyyy', 'ar').format(value);
  }

  String? _currentOrderSourceFilter() {
    switch (_tabController.index) {
      case 1:
        return 'عميل';
      case 2:
        return 'مورد';
      case 3:
        return 'مدمج';
      default:
        return null;
    }
  }

  bool _tabUsesArrivalDate() => _tabController.index == 3;

  String _tableDateField() {
    return _tabUsesArrivalDate() ? 'arrivalDate' : 'orderDate';
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Map<String, dynamic> _dateRangeFilters() {
    return {
      'startDate': DateTime(
        _rangeStart.year,
        _rangeStart.month,
        _rangeStart.day,
      ).toIso8601String(),
      'endDate': DateTime(
        _rangeEnd.year,
        _rangeEnd.month,
        _rangeEnd.day,
        23,
        59,
        59,
        999,
      ).toIso8601String(),
    };
  }

  Map<String, dynamic> _baseFilters() {
    final filters = <String, dynamic>{..._extraFilters, ..._dateRangeFilters()};
    filters.remove('page');
    filters.remove('limit');
    filters.remove('dateField');
    return filters;
  }

  Map<String, dynamic> _tableFilters() {
    final filters = <String, dynamic>{
      ..._baseFilters(),
      'dateField': _tableDateField(),
      'limit': _pageSize,
    };

    final orderSource = _currentOrderSourceFilter();
    if (orderSource != null) {
      filters['orderSource'] = orderSource;
    }

    return filters;
  }

  Future<void> _refreshOrders({
    bool resetPage = false,
    bool refreshStats = false,
    int? pageOverride,
  }) async {
    final provider = context.read<OrderProvider>();
    final page = resetPage ? 1 : (pageOverride ?? _currentPage);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final pageFuture = provider.fetchOrdersPageSnapshot(
        page: page,
        filters: _tableFilters(),
      );
      final statsFuture = refreshStats ? _loadStats() : Future<void>.value();

      final pageSnapshot = await pageFuture;
      await statsFuture;

      if (!mounted) return;
      setState(() {
        _orders = pageSnapshot.orders;
        _currentPage = pageSnapshot.currentPage;
        _totalPages = pageSnapshot.totalPages;
        _totalOrders = pageSnapshot.totalOrders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isStatsLoading = true);

    final provider = context.read<OrderProvider>();
    final orderDateFilters = <String, dynamic>{
      ..._baseFilters(),
      'dateField': 'orderDate',
    };
    final arrivalDateFilters = <String, dynamic>{
      ..._baseFilters(),
      'dateField': 'arrivalDate',
    };

    final results = await Future.wait<int>([
      provider.fetchOrdersCount(filters: orderDateFilters),
      provider.fetchOrdersCount(
        filters: {...orderDateFilters, 'orderSource': 'عميل'},
      ),
      provider.fetchOrdersCount(
        filters: {...orderDateFilters, 'orderSource': 'مورد'},
      ),
      provider.fetchOrdersCount(
        filters: {...arrivalDateFilters, 'orderSource': 'مدمج'},
      ),
      provider.fetchOrdersCount(
        filters: {...arrivalDateFilters, 'status': 'تم التسليم'},
      ),
      provider.fetchOrdersCount(
        filters: {...arrivalDateFilters, 'status': 'تم التنفيذ'},
      ),
      provider.fetchOrdersCount(
        filters: {...arrivalDateFilters, 'status': 'مكتمل'},
      ),
      provider.fetchOrdersCount(filters: {...orderDateFilters, 'status': 'ملغى'}),
    ]);

    if (!mounted) return;

    setState(() {
      _summaryCounts = {
        'all': results[0],
        'customer': results[1],
        'supplier': results[2],
        'merged': results[3],
        'completed': results[4] + results[5] + results[6],
        'cancelled': results[7],
      };
      _isStatsLoading = false;
    });
  }

  List<Order> _applySearch(List<Order> orders) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return orders;

    return orders.where((order) {
      final fields = <String>[
        order.orderNumber,
        order.supplierName,
        order.driverName ?? '',
        order.customer?.name ?? '',
        order.supplierOrderNumber ?? '',
        order.effectiveRequestType,
      ];

      return fields.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _showFilters() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const FilterDialog(),
    );

    if (result == null || !mounted) return;

    final filters = Map<String, dynamic>.from(result)
      ..remove('startDate')
      ..remove('endDate');

    setState(() => _extraFilters = filters);
    await _refreshOrders(resetPage: true, refreshStats: true);
  }

  Future<void> _clearFilters() async {
    if (_extraFilters.isEmpty) return;
    setState(() => _extraFilters = {});
    await _refreshOrders(resetPage: true, refreshStats: true);
  }

  DateTime get _selectedMonth => DateTime(_rangeStart.year, _rangeStart.month);

  set _selectedMonth(DateTime value) {
    _rangeStart = DateTime(value.year, value.month, 1);
    _rangeEnd = DateTime(value.year, value.month + 1, 0);
  }

  Future<void> _applyDateRange(DateTime start, DateTime end) async {
    final normalizedStart = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);
    final safeStart = normalizedStart.isAfter(normalizedEnd)
        ? normalizedEnd
        : normalizedStart;
    final safeEnd = normalizedStart.isAfter(normalizedEnd)
        ? normalizedStart
        : normalizedEnd;

    setState(() {
      _rangeStart = safeStart;
      _rangeEnd = safeEnd;
    });
    await _refreshOrders(resetPage: true, refreshStats: true);
  }

  Future<void> _pickRangeDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _rangeStart : _rangeEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      helpText: isStart ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
    );

    if (picked == null || !mounted) return;

    await _applyDateRange(
      isStart ? picked : _rangeStart,
      isStart ? _rangeEnd : picked,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      helpText: 'اختر الفترة المطلوبة',
      saveText: 'تطبيق',
      confirmText: 'تطبيق',
      cancelText: 'إلغاء',
    );

    if (picked == null || !mounted) return;
    await _applyDateRange(picked.start, picked.end);
  }

  Future<void> _setQuickRange({
    required DateTime start,
    required DateTime end,
  }) async {
    await _applyDateRange(start, end);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'اختر أي يوم داخل الشهر المطلوب',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
    await _refreshOrders(resetPage: true, refreshStats: true);
  }

  Future<void> _shiftMonth(int offset) async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    await _refreshOrders(resetPage: true, refreshStats: true);
  }

  Future<void> _goToPage(int page) async {
    if (page < 1) return;
    if (_isLoading || page == _currentPage) return;
    await _refreshOrders(
      resetPage: false,
      refreshStats: false,
      pageOverride: page,
    );
  }

  String _filterLabel(String key) {
    switch (key) {
      case 'status':
        return 'الحالة';
      case 'supplierName':
        return 'المورد';
      case 'orderNumber':
        return 'رقم الطلب';
      case 'customerName':
        return 'العميل';
      case 'driverName':
        return 'السائق';
      default:
        return key;
    }
  }

  String _tabLabel(_OrdersTabItem item) {
    final count = _summaryCounts[item.key];
    if (_isStatsLoading || count == null) {
      return item.label;
    }
    return '${item.label} ($count)';
  }

  List<Widget> _buildHeaderSlivers() {
    return [
      SliverToBoxAdapter(child: _buildDateRangeSelector()),
      SliverToBoxAdapter(child: _buildStatsSection()),
      SliverToBoxAdapter(child: _buildActiveFiltersBanner()),
      SliverToBoxAdapter(child: _buildSearchField()),
      if (_error != null && !_isLoading)
        SliverToBoxAdapter(child: _buildErrorBanner(_error!)),
      const SliverToBoxAdapter(child: SizedBox(height: 6)),
    ];
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.lightGray.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final controls = Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton(
                  tooltip: 'الشهر السابق',
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_right),
                ),
                OutlinedButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('اختيار الشهر'),
                ),
                IconButton(
                  tooltip: 'الشهر التالي',
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            );

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فلترة الطلبات حسب الشهر',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMonthLabel(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يعرض النظام طلبات هذا الشهر فقط، وبحد أقصى $_pageSize صفاً في كل صفحة.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mediumGray,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'الإحصائيات أدناه تعتمد على تاريخ الطلب.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.mediumGray,
                    height: 1.25,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 8), controls],
              );
            }

            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateQuickAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: AppColors.primaryBlue.withValues(alpha: 0.14),
      ),
      labelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDarkBlue,
      ),
      avatar: const Icon(
        Icons.bolt_outlined,
        size: 14,
        color: AppColors.primaryBlue,
      ),
      label: Text(label),
    );
  }

  Widget _buildDateSelectorCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    final now = _normalizeDate(DateTime.now());
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
    final last7DaysStart = now.subtract(const Duration(days: 6));
    final last30DaysStart = now.subtract(const Duration(days: 29));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.lightGray.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فلترة الطلبات حسب الفترة',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatRangeDate(_rangeStart)} - ${_formatRangeDate(_rangeEnd)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يمكنك تحديد فترة من تاريخ إلى تاريخ، مع اعتماد الطلبات المدمجة والمكتملة على تاريخ الوصول للعميل.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mediumGray,
                    height: 1.35,
                  ),
                ),
              ],
            );

            final selectors = compact
                ? Column(
                    children: [
                      _buildDateSelectorCard(
                        label: 'من تاريخ',
                        value: _formatRangeDate(_rangeStart),
                        icon: Icons.calendar_today_outlined,
                        onTap: () => _pickRangeDate(isStart: true),
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 8),
                      _buildDateSelectorCard(
                        label: 'إلى تاريخ',
                        value: _formatRangeDate(_rangeEnd),
                        icon: Icons.event_available_outlined,
                        onTap: () => _pickRangeDate(isStart: false),
                        color: AppColors.successGreen,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildDateSelectorCard(
                          label: 'من تاريخ',
                          value: _formatRangeDate(_rangeStart),
                          icon: Icons.calendar_today_outlined,
                          onTap: () => _pickRangeDate(isStart: true),
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDateSelectorCard(
                          label: 'إلى تاريخ',
                          value: _formatRangeDate(_rangeEnd),
                          icon: Icons.event_available_outlined,
                          onTap: () => _pickRangeDate(isStart: false),
                          color: AppColors.successGreen,
                        ),
                      ),
                    ],
                  );

            final controls = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: const Text('اختيار الفترة'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDateQuickAction(
                      label: 'اليوم',
                      onTap: () => _setQuickRange(start: now, end: now),
                    ),
                    _buildDateQuickAction(
                      label: 'آخر 7 أيام',
                      onTap: () => _setQuickRange(
                        start: last7DaysStart,
                        end: now,
                      ),
                    ),
                    _buildDateQuickAction(
                      label: 'آخر 30 يوم',
                      onTap: () => _setQuickRange(
                        start: last30DaysStart,
                        end: now,
                      ),
                    ),
                    _buildDateQuickAction(
                      label: 'هذا الشهر',
                      onTap: () => _setQuickRange(
                        start: currentMonthStart,
                        end: currentMonthEnd,
                      ),
                    ),
                  ],
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 12),
                  selectors,
                  const SizedBox(height: 10),
                  controls,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    controls,
                  ],
                ),
                const SizedBox(height: 12),
                selectors,
              ],
            );
          },
        ),
      ),
    );
  }

  List<_OrdersStatCardData> _statsData() {
    return [
      _OrdersStatCardData(
        title: 'إجمالي الشهر',
        value: _summaryCounts['all'] ?? 0,
        icon: Icons.receipt_long_outlined,
        color: AppColors.primaryBlue,
      ),
      _OrdersStatCardData(
        title: 'طلبات العملاء',
        value: _summaryCounts['customer'] ?? 0,
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF00796B),
      ),
      _OrdersStatCardData(
        title: 'طلبات الموردين',
        value: _summaryCounts['supplier'] ?? 0,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFFEF6C00),
      ),
      _OrdersStatCardData(
        title: 'الطلبات المدمجة',
        value: _summaryCounts['merged'] ?? 0,
        icon: Icons.merge_type_outlined,
        color: const Color(0xFF6A1B9A),
      ),
      _OrdersStatCardData(
        title: 'الطلبات المكتملة',
        value: _summaryCounts['merged'] ?? 0,
        icon: Icons.task_alt_outlined,
        color: AppColors.successGreen,
      ),
      _OrdersStatCardData(
        title: 'الطلبات الملغاة',
        value: _summaryCounts['cancelled'] ?? 0,
        icon: Icons.cancel_outlined,
        color: AppColors.errorRed,
      ),
    ];
  }

  List<_OrdersStatCardData> _periodStatsData() {
    return [
      _OrdersStatCardData(
        title: 'إجمالي الفترة',
        value: _summaryCounts['all'] ?? 0,
        icon: Icons.receipt_long_outlined,
        color: AppColors.primaryBlue,
      ),
      _OrdersStatCardData(
        title: 'طلبات العملاء',
        value: _summaryCounts['customer'] ?? 0,
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF00796B),
      ),
      _OrdersStatCardData(
        title: 'طلبات الموردين',
        value: _summaryCounts['supplier'] ?? 0,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFFEF6C00),
      ),
      _OrdersStatCardData(
        title: 'الطلبات المدمجة',
        value: _summaryCounts['merged'] ?? 0,
        icon: Icons.merge_type_outlined,
        color: const Color(0xFF6A1B9A),
      ),
      _OrdersStatCardData(
        title: 'الطلبات المكتملة',
        value: _summaryCounts['completed'] ?? 0,
        icon: Icons.task_alt_outlined,
        color: AppColors.successGreen,
      ),
      _OrdersStatCardData(
        title: 'الطلبات الملغاة',
        value: _summaryCounts['cancelled'] ?? 0,
        icon: Icons.cancel_outlined,
        color: AppColors.errorRed,
      ),
    ];
  }

  Widget _buildStatsSection() {
    final items = _periodStatsData();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1180
              ? 3
              : constraints.maxWidth >= 760
              ? 2
              : 1;
          final spacing = 10.0;
          final itemWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items.map((item) {
              return SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isStatsLoading ? '...' : item.value.toString(),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: item.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildActiveFiltersBanner() {
    if (_extraFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  color: AppColors.primaryBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الفلاتر الإضافية المطبقة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('مسح الفلاتر'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _extraFilters.entries.map((entry) {
                return Chip(
                  label: Text('${_filterLabel(entry.key)}: ${entry.value}'),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppColors.primaryBlue.withValues(alpha: 0.18),
                  ),
                  labelStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'ابحث داخل نتائج الصفحة الحالية...',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.errorRed,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOrder(Order order, bool isDriverUser) {
    if (isDriverUser) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDeliveryTrackingScreen(initialOrder: order),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.orderDetails,
      arguments: order.id,
    );
  }

  String _formatDate(DateTime value) {
    return DateFormat('yyyy/MM/dd', 'ar').format(value);
  }

  String _formatQuantity(Order order) {
    final quantity = order.quantity;
    if (quantity == null) {
      return order.fuelType?.trim().isNotEmpty == true
          ? order.fuelType!.trim()
          : 'غير محدد';
    }

    final formatted = quantity % 1 == 0
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    final unit = (order.unit ?? '').trim();
    final fuel = (order.fuelType ?? '').trim();

    if (fuel.isEmpty && unit.isEmpty) return formatted;
    if (fuel.isEmpty) return '$formatted $unit';
    if (unit.isEmpty) return '$fuel • $formatted';
    return '$fuel • $formatted $unit';
  }

  String _valueOrFallback(String? value, {String fallback = 'غير محدد'}) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  String _partyName(Order order) {
    final customerName = (order.customer?.name ?? '').trim();
    final movementCustomerName = (order.movementCustomerName ?? '').trim();
    final supplierName = order.supplierName.trim();

    if (order.orderSource == 'عميل') {
      return customerName.isNotEmpty
          ? customerName
          : movementCustomerName.isNotEmpty
          ? movementCustomerName
          : supplierName;
    }

    return supplierName.isNotEmpty
        ? supplierName
        : customerName.isNotEmpty
        ? customerName
        : 'غير محدد';
  }

  String _driverStatusText(Order order) {
    final driverName = order.driverName?.trim();
    if (driverName != null && driverName.isNotEmpty) {
      return '${order.status} • $driverName';
    }
    return order.status;
  }

  String _locationText(Order order) {
    final parts = <String>[
      if ((order.location).trim().isNotEmpty &&
          order.location.trim() != 'غير محدد')
        order.location.trim(),
      if ((order.address ?? '').trim().isNotEmpty) order.address!.trim(),
    ];

    if (parts.isEmpty) {
      return 'غير محدد';
    }

    return parts.join(' • ');
  }

  Widget _mobileMetaChip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    int maxLines = 3,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDarkBlue,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileOrderCard(Order order, bool isDriverUser) {
    final statusColor = order.statusColor;
    final sourceLabel = order.orderSourceText;
    final partyName = _partyName(order);
    final requestType = order.effectiveRequestType.trim().isEmpty
        ? 'غير محدد'
        : order.effectiveRequestType.trim();
    final supplierOrderNumber = _valueOrFallback(order.supplierOrderNumber);
    final location = _locationText(order);
    final narrowLayout = MediaQuery.sizeOf(context).width < 360;
    final actionLabel = isDriverUser ? 'فتح التتبع' : 'عرض التفاصيل';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOrder(order, isDriverUser),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          partyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mobileMetaChip(
                    label: sourceLabel,
                    color: AppColors.primaryBlue,
                    icon: Icons.inventory_2_outlined,
                  ),
                  _mobileMetaChip(
                    label: requestType,
                    color: AppColors.warningOrange,
                    icon: Icons.category_outlined,
                  ),
                  _mobileMetaChip(
                    label: 'رقم المورد: $supplierOrderNumber',
                    color: AppColors.secondaryTeal,
                    icon: Icons.pin_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final columns = narrowLayout || constraints.maxWidth < 330
                      ? 1
                      : 2;
                  final itemWidth = (constraints.maxWidth -
                          (spacing * (columns - 1))) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.calendar_month_outlined,
                          label: 'تاريخ الطلب',
                          value: _formatDate(order.orderDate),
                          accent: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.local_shipping_outlined,
                          label: 'المورد / العميل',
                          value: partyName,
                          accent: AppColors.secondaryTeal,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.category_outlined,
                          label: 'الوقود / الكمية',
                          value: _formatQuantity(order),
                          accent: AppColors.warningOrange,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.pin_outlined,
                          label: 'رقم طلب المورد',
                          value: supplierOrderNumber,
                          accent: AppColors.infoBlue,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.schedule_outlined,
                          label: 'تاريخ التحميل',
                          value: order.formattedLoadingDateTime,
                          accent: const Color(0xFF5E35B1),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.event_available_outlined,
                          label: 'تاريخ الوصول',
                          value: order.formattedArrivalDateTime,
                          accent: const Color(0xFF00897B),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.drive_eta_outlined,
                          label: 'الحالة / السائق',
                          value: _driverStatusText(order),
                          accent: statusColor,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _mobileDetailTile(
                          icon: Icons.place_outlined,
                          label: 'الموقع',
                          value: location,
                          accent: const Color(0xFF6D4C41),
                          maxLines: 4,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openOrder(order, isDriverUser),
                  icon: Icon(
                    isDriverUser
                        ? Icons.route_outlined
                        : Icons.open_in_new_outlined,
                    size: 18,
                  ),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileOrdersList(List<Order> orders, bool isDriverUser) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMobileOrderCard(orders[index], isDriverUser);
      },
    );
  }

  Widget _buildOrdersTable(bool isDriverUser) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _applySearch(_orders);

    if (filtered.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;
      final message = isSearching
          ? 'لا توجد نتائج مطابقة داخل الصفحة الحالية.'
          : 'لا توجد طلبات مطابقة للشهر والفلاتر المحددة.';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        if (isMobile) {
          return _buildMobileOrdersList(filtered, isDriverUser);
        }

        return OrderDataGrid(
          orders: filtered,
          onRowTap: (order) => _openOrder(order, isDriverUser),
        );
      },
    );
  }

  Widget _buildPagination() {
    final totalOrders = _totalOrders;
    final currentPage = _currentPage;
    final totalPages = _totalPages;
    final pageItems = _orders.length;

    if (totalOrders <= 0) {
      return const SizedBox.shrink();
    }

    final start = ((currentPage - 1) * _pageSize) + 1;
    final end = start + pageItems - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.lightGray.withValues(alpha: 0.18),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'عرض $start - $end من إجمالي $totalOrders طلب',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'الصفحة $currentPage من $totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            );

            final buttons = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: currentPage > 1 && !_isLoading
                      ? () => _goToPage(currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('السابق'),
                ),
                FilledButton.icon(
                  onPressed: currentPage < totalPages && !_isLoading
                      ? () => _goToPage(currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('التالي'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: buttons),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: info),
                buttons,
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDriverUser =
        user?.role == 'driver' && (user?.driverId?.trim().isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: const Text(
          AppStrings.orders,
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((item) => Tab(text: _tabLabel(item))).toList(),
        ),
        actions: [
          if (_extraFilters.isNotEmpty)
            IconButton(
              tooltip: 'مسح الفلاتر',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          IconButton(
            tooltip: 'تصفية إضافية',
            onPressed: _showFilters,
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return _buildHeaderSlivers();
              },
              body: _buildOrdersTable(isDriverUser),
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }
}

class _OrdersTabItem {
  final String key;
  final String label;

  const _OrdersTabItem({required this.key, required this.label});
}

class _OrdersStatCardData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _OrdersStatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
