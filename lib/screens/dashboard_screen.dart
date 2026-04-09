// ignore_for_file: unused_local_variable, dead_code

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/services/backup_service.dart';
import 'package:order_tracker/services/whatsapp_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/widgets/recent_orders_widget.dart';
import 'package:order_tracker/widgets/candlestick_chart_widget.dart';
import 'package:order_tracker/widgets/overdue_orders_widget.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/whatsapp_compose_dialog.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

enum _StatsVisualizationMode {
  grid,
  candlestick,
  bar,
  line,
  area,
  pie,
  indicators,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _desktopSidebarWidth = 280;
  static const double _desktopContentMaxWidth = 1480;
  static const double _desktopCompactBreakpoint = 1180;
  static const double _desktopStackedChartsBreakpoint = 1280;

  List<OrderTimer> _approachingTimers = [];
  List<OrderTimer> _allOrderTimers = [];
  bool _loadingTimers = false;
  Timer? _liveTimer;
  String _selectedCountdownFilter = 'all';
  String _selectedStatusFilter = 'all';
  DateTimeRange? _selectedCountdownDateRange;
  String _statsDateFilter = 'monthly';
  int _statsSelectedMonth = DateTime.now().month;
  int _statsSelectedYear = DateTime.now().year;
  String _exportDateFilter = 'monthly';
  int _exportSelectedMonth = DateTime.now().month;
  int _exportSelectedYear = DateTime.now().year;
  DateTime _exportSelectedDate = DateTime.now();
  int _exportEstimatedSeconds = 6;
  String _exportPdfScope = 'completed';
  String _exportExcelScope = 'completed';
  bool _backupBusy = false;
  final ScrollController _ordersHorizontalController = ScrollController();

  final ScrollController _ordersVerticalController = ScrollController();
  int _statsVisualizationIndex = 1;

  static const List<_StatsVisualizationMode> _statsVisualizationModes = [
    _StatsVisualizationMode.grid,
    _StatsVisualizationMode.candlestick,
    _StatsVisualizationMode.bar,
    _StatsVisualizationMode.line,
    _StatsVisualizationMode.area,
    _StatsVisualizationMode.pie,
    _StatsVisualizationMode.indicators,
  ];
  final Map<String, bool> _desktopFolderExpanded = {
    'inventory': false,
    'circulars': false,
    'orders': true,
    'order_management': false,
    'archive': false,
    'qualification': false,
  };

  static const String _supplierOrderSource = 'مورد';

  static const String _customerOrderSource = 'عميل';

  static const String _mergedOrderSource = 'مدمج';

  static const List<Map<String, String>> _ordersFilterOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'customer', 'label': 'طلبات العملاء'},
    {'key': 'supplier', 'label': 'طلبات الموردين'},
    {'key': 'merged', 'label': 'الطلبات المدمجة'},
    {'key': 'overdue', 'label': 'الطلبات المتأخرة'},
  ];

  static const List<Map<String, String>> _statusFilterOptions = [
    {'key': 'all', 'label': 'جميع الحالات'},
    {'key': 'warehouse', 'label': 'في المستودع'},
    {'key': 'waiting', 'label': 'في انتظار التخصيص'},
    {'key': 'merged', 'label': 'تم الدمج'},
    {'key': 'completed', 'label': 'تم التنفيذ'},
  ];

  static const List<Map<String, String>> _statsDateFilterOptions = [
    {'key': 'daily', 'label': 'يومي'},
    {'key': 'weekly', 'label': 'أسبوعي'},
    {'key': 'monthly', 'label': 'شهري'},
    {'key': 'yearly', 'label': 'سنوي'},
  ];

  static const List<Map<String, String>> _exportDateFilterOptions = [
    {'key': 'daily', 'label': 'يومي'},
    {'key': 'monthly', 'label': 'شهري'},
    {'key': 'yearly', 'label': 'سنوي'},
  ];
  static const List<Map<String, String>> _exportScopeOptions = [
    {'key': 'customers', 'label': 'طلبات العملاء'},
    {'key': 'suppliers', 'label': 'طلبات الموردين'},
    {'key': 'completed', 'label': 'الطلبات المكتملة'},
  ];

  static const List<String> _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  List<Map<String, dynamic>> _buildCandlestickData(List<Order> orders) {
    final Map<String, Map<String, int>> categoryData = {};

    for (final order in orders) {
      final source = order.orderSource;
      final status = order.status;
      final key = '$source-$status';

      if (!categoryData.containsKey(source)) {
        categoryData[source] = {};
      }
      categoryData[source]![status] = (categoryData[source]![status] ?? 0) + 1;
    }

    final List<Map<String, dynamic>> candlestickData = [];

    final supplierData = categoryData['مورد'] ?? {};
    if (supplierData.isNotEmpty) {
      final total = supplierData.values.reduce((a, b) => a + b);
      final maxStatus = supplierData.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final minStatus = supplierData.entries.reduce(
        (a, b) => a.value < b.value ? a : b,
      );

      candlestickData.add({
        'label': 'طلبات الموردين',
        'value': total,
        'open': minStatus.value,
        'high': maxStatus.value,
        'low': supplierData.values.reduce((a, b) => a < b ? a : b),
        'close': total ~/ supplierData.length,
        'color': AppColors.primaryBlue,
        'details': supplierData,
      });
    }

    final customerData = categoryData['عميل'] ?? {};
    if (customerData.isNotEmpty) {
      final total = customerData.values.reduce((a, b) => a + b);
      final maxStatus = customerData.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final minStatus = customerData.entries.reduce(
        (a, b) => a.value < b.value ? a : b,
      );

      candlestickData.add({
        'label': 'طلبات العملاء',
        'value': total,
        'open': minStatus.value,
        'high': maxStatus.value,
        'low': customerData.values.reduce((a, b) => a < b ? a : b),
        'close': total ~/ customerData.length,
        'color': Colors.orange,
        'details': customerData,
      });
    }

    final mergedData = categoryData['مدمج'] ?? {};
    if (mergedData.isNotEmpty) {
      final total = mergedData.values.reduce((a, b) => a + b);
      final maxStatus = mergedData.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final minStatus = mergedData.entries.reduce(
        (a, b) => a.value < b.value ? a : b,
      );

      candlestickData.add({
        'label': 'الطلبات المدمجة',
        'value': total,
        'open': minStatus.value,
        'high': maxStatus.value,
        'low': mergedData.values.reduce((a, b) => a < b ? a : b),
        'close': total ~/ mergedData.length,
        'color': Colors.purple,
        'details': mergedData,
      });
    }

    final statusStats = [
      {
        'label': 'في المستودع',
        'value': orders.where((o) => o.status == 'في المستودع').length,
        'color': Colors.blue.shade700,
      },
      {
        'label': 'في انتظار التخصيص',
        'value': orders.where((o) => o.status == 'في انتظار التخصيص').length,
        'color': Colors.orange,
      },
      {
        'label': 'تم الدمج',
        'value': orders.where((o) => o.status.contains('تم الدمج')).length,
        'color': Colors.purple,
      },
      {
        'label': 'في الطريق',
        'value': orders.where((o) => o.status == 'في الطريق').length,
        'color': Colors.indigo,
      },
      {
        'label': 'تم التسليم',
        'value': orders.where((o) => o.status == 'تم التسليم').length,
        'color': Colors.green,
      },
      {
        'label': 'ملغاة',
        'value': orders.where((o) => o.status.contains('ملغ')).length,
        'color': AppColors.errorRed,
      },
    ];

    candlestickData.addAll(
      statusStats.where((stat) => (stat['value'] as int) > 0),
    );

    return candlestickData;
  }

  List<Map<String, dynamic>> _buildDailySalesData(List<Order> orders) {
    final Map<String, int> dailyOrders = {};
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('EEE', 'ar').format(date);

      final dayOrders = orders.where((order) {
        return order.arrivalDate.year == date.year &&
            order.arrivalDate.month == date.month &&
            order.arrivalDate.day == date.day;
      }).length;

      dailyOrders[dateKey] = dayOrders;
    }

    return dailyOrders.entries.map((entry) {
      return {
        'label': entry.key,
        'value': entry.value,
        'color': entry.value > 0 ? AppColors.successGreen : AppColors.lightGray,
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapDashboard());
    });
  }

  Future<void> _bootstrapDashboard() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );

    await Future.wait<void>([
      orderProvider.fetchOrders(),
      notificationProvider.fetchNotifications(),
    ]);

    if (!mounted) return;
    await _loadApproachingTimers();
    if (!mounted) return;
    _startLiveTimer();
  }

  void _startLiveTimer() {
    _liveTimer?.cancel();

    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      bool hasActiveCountdown = false;

      for (final order in orderProvider.orders) {
        if (_isFinalStatus(order.status)) {
          continue;
        }

        final loadingDateTime = DateTime(
          order.loadingDate.year,
          order.loadingDate.month,
          order.loadingDate.day,
          int.parse(order.loadingTime.split(':')[0]),
          int.parse(order.loadingTime.split(':')[1]),
        );

        final remaining = loadingDateTime.difference(DateTime.now());

        if (remaining <= Duration.zero &&
            order.orderSource == 'مدمج' &&
            !_isFinalStatus(order.status)) {
          final oneDayAfterLoading = loadingDateTime.add(
            const Duration(days: 1),
          );
          if (DateTime.now().isAfter(oneDayAfterLoading)) {
            orderProvider.markOrderAsCompleted(order.id);
          }
        } else if (remaining > Duration.zero) {
          hasActiveCountdown = true;
        }
      }

      if (!hasActiveCountdown) {
        _liveTimer?.cancel();
        _liveTimer = null;
      }

      setState(() {});
    });
  }

  bool _isFinalStatus(String status) {
    final s = status.trim();

    return s.contains('تم التسليم') ||
        s.contains('تم التنفيذ') ||
        s.contains('مكتمل') ||
        s.contains('ملغ');
  }

  Future<void> _loadApproachingTimers() async {
    setState(() {
      _loadingTimers = true;
    });

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final orders = orderProvider.orders;

    final timers = orders
        .map(_buildTimerFromOrder)
        .whereType<OrderTimer>()
        .toList();

    final approaching = timers
        .where((timer) => timer.shouldShowCountdown)
        .toList();

    setState(() {
      _approachingTimers = approaching;
      _allOrderTimers = timers;
      _loadingTimers = false;
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _ordersHorizontalController.dispose();
    _ordersVerticalController.dispose();
    super.dispose();
  }

  OrderTimer? _buildTimerFromOrder(Order order) {
    try {
      final arrivalDateTime = _combineDateWithTime(
        order.arrivalDate,
        order.arrivalTime,
        fallbackHour: 10,
      );
      final loadingDateTime = _combineDateWithTime(
        order.loadingDate,
        order.loadingTime,
        fallbackHour: 8,
      );

      final mergedInfoSummary =
          (order.mergedWithInfo != null && order.mergedWithInfo!.isNotEmpty)
          ? order.mergedWithInfo!.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(' | ')
          : null;

      return OrderTimer(
        orderId: order.id,
        arrivalDateTime: arrivalDateTime,
        loadingDateTime: loadingDateTime,
        orderNumber: order.orderNumber,
        supplierName: order.supplierName.isNotEmpty
            ? order.supplierName
            : order.supplier?.name ?? 'غير معروف',
        customerName: order.customer?.name ?? '',
        city: order.city,
        area: order.area,
        address: order.address,
        driver: order.driver,
        driverNameFallback: order.driverName ?? order.driver?.name,
        driverPhoneFallback: order.driverPhone ?? order.driver?.phone,
        vehicleNumberFallback:
            order.vehicleNumber ?? order.driver?.vehicleNumber,
        status: order.status,
        orderSource: order.orderSource,
        supplierOrderNumber: order.supplierOrderNumber,
        fuelType: order.fuelType,
        quantity: order.quantity,
        unit: order.unit,
        mergedInfoSummary: mergedInfoSummary,
        mergeStatus: order.mergeStatus,

        notes: order.notes,
      );
    } catch (e) {
      debugPrint('Error creating timer for order: $e');
      return null;
    }
  }

  DateTime _combineDateWithTime(
    DateTime date,
    String time, {
    int fallbackHour = 0,
  }) {
    final parts = time.split(':');
    final hour = parts.isNotEmpty
        ? int.tryParse(parts[0]) ?? fallbackHour
        : fallbackHour;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _userInitials(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'U';
    }

    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return parts.isEmpty ? 'U' : parts;
  }

  void _navigateFromMobileDrawer(BuildContext drawerContext, String route) {
    Navigator.pop(drawerContext);
    Future.microtask(() {
      if (!mounted) return;
      Navigator.pushNamed(context, route);
    });
  }

  void _openWhatsAppFromMobileDrawer(BuildContext drawerContext) {
    Navigator.pop(drawerContext);
    Future.microtask(() {
      if (!mounted) return;
      WhatsAppComposeDialog.show(context);
    });
  }

  void _openWhatsAppFromSidebar() {
    WhatsAppComposeDialog.show(context);
  }

  Future<void> _logoutFromMobileDrawer(
    BuildContext drawerContext,
    AuthProvider authProvider,
  ) async {
    Navigator.pop(drawerContext);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    await _confirmLogout(context, authProvider);
  }

  Widget _navItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> buildStatusChartData(List<Order> orders) {
    final Map<String, int> counter = {};

    for (final order in orders) {
      final key = '${order.orderSource} | ${order.status}';
      counter[key] = (counter[key] ?? 0) + 1;
    }

    return counter.entries.map((entry) {
      final parts = entry.key.split(' | ');
      final source = parts[0];
      final status = parts[1];

      return {
        'status': _formatStatusLabel(source, status),
        'count': entry.value,
        'color': _getStatusColor(source, status),
      };
    }).toList();
  }

  String _formatStatusLabel(String source, String status) {
    switch (source) {
      case 'مورد':
        return 'طلب مورد - $status';
      case 'عميل':
        return 'طلب عميل - $status';
      case 'مدمج':
        return 'طلب مدمج - $status';
      default:
        return status;
    }
  }

  Color _getStatusColor(String source, String status) {
    if (status.contains('انتظار')) return Colors.orange;
    if (status.contains('تحميل')) return Colors.blue;
    if (status.contains('في الطريق')) return Colors.indigo;
    if (status.contains('تم التسليم') || status.contains('مكتمل'))
      return Colors.green;
    if (status.contains('ملغى')) return AppColors.errorRed;

    switch (source) {
      case 'مورد':
        return Colors.blueGrey;
      case 'عميل':
        return Colors.deepOrange;
      case 'مدمج':
        return Colors.purple;
      default:
        return AppColors.primaryBlue;
    }
  }

  List<Map<String, dynamic>> _getOverdueOrders(List orders) {
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));

    return orders
        .where((order) {
          final waitingStatuses = [
            'في انتظار التخصيص',
            'في انتظار الدمج',
            'في المستودع',
            'تم الإنشاء',
          ];

          return waitingStatuses.contains(order.status) &&
              order.createdAt.isBefore(twoHoursAgo) &&
              order.notificationSentAt == null;
        })
        .map((order) {
          final hoursSinceCreation = DateTime.now()
              .difference(order.createdAt)
              .inHours;
          return {'order': order, 'hours': hoursSinceCreation};
        })
        .toList();
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 4;
    } else if (width > 800) {
      return 3;
    } else if (width > 600) {
      return 2;
    } else {
      return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);

    final orders = orderProvider.orders;
    final overdueOrders = _getOverdueOrders(orders);
    final statsFilteredOrders = _filterOrdersForStats(orders);
    final statsCounts = _computeStatsCounts(
      allOrders: orders,
      filteredOrders: statsFilteredOrders,
    );

    final bool isDesktop = MediaQuery.of(context).size.width > 750;

    final totalOrders = orderProvider.totalOrders;

    final supplierPending = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' &&
              [
                'في المستودع',
                'تم الإنشاء',
                'في انتظار الدمج',
              ].contains(order.status),
        )
        .length;
    final supplierMerged = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' &&
              order.status == 'تم دمجه مع العميل',
        )
        .length;
    final supplierReady = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' && order.status == 'جاهز للتحميل',
        )
        .length;
    final supplierLoaded = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' && order.status == 'تم التحميل',
        )
        .length;
    final supplierInTransit = orders
        .where(
          (order) => order.orderSource == 'مورد' && order.status == 'في الطريق',
        )
        .length;
    final supplierDelivered = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' && order.status == 'تم التسليم',
        )
        .length;

    final customerWaiting = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' &&
              order.status == 'في انتظار التخصيص',
        )
        .length;
    final customerAssigned = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' &&
              order.status == 'تم تخصيص طلب المورد',
        )
        .length;
    final customerMerged = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' &&
              order.status == 'تم دمجه مع المورد',
        )
        .length;
    final customerWaitingForLoad = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' &&
              order.status == 'في انتظار التحميل',
        )
        .length;
    final customerInTransit = orders
        .where(
          (order) => order.orderSource == 'عميل' && order.status == 'في الطريق',
        )
        .length;
    final customerDelivered = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' && order.status == 'تم التسليم',
        )
        .length;

    final mergedOrders = orders
        .where((order) => order.orderSource == 'مدمج')
        .length;
    final mergedReady = orders
        .where(
          (order) =>
              order.orderSource == 'مدمج' &&
              ['تم الدمج', 'مخصص للعميل'].contains(order.status),
        )
        .length;
    final mergedForLoading = orders
        .where(
          (order) =>
              order.orderSource == 'مدمج' && order.status == 'جاهز للتحميل',
        )
        .length;
    final mergedLoaded = orders
        .where(
          (order) =>
              order.orderSource == 'مدمج' && order.status == 'تم التحميل',
        )
        .length;
    final mergedInTransit = orders
        .where(
          (order) => order.orderSource == 'مدمج' && order.status == 'في الطريق',
        )
        .length;
    final mergedDelivered = orders
        .where(
          (order) =>
              order.orderSource == 'مدمج' && order.status == 'تم التسليم',
        )
        .length;
    final mergedCompleted = orders
        .where(
          (order) =>
              order.orderSource == 'مدمج' && order.status == 'تم التنفيذ',
        )
        .length;

    final completedOrders = orders
        .where(
          (order) => _isFinalStatus(order.status) && order.status != 'ملغى',
        )
        .length;
    final cancelledOrders = orders
        .where((order) => order.status == 'ملغى')
        .length;

    final today = DateTime.now();
    final todayOrders = orders.where((order) {
      final d = order.arrivalDate;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).length;

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final thisWeekOrders = orders.where((order) {
      return order.arrivalDate.isAfter(weekStart);
    }).length;

    final monthStart = DateTime(today.year, today.month, 1);
    final thisMonthOrders = orders.where((order) {
      return order.arrivalDate.isAfter(monthStart);
    }).length;

    final statusData = [
      if (supplierPending > 0)
        {
          'status': 'طلبات مورد - قيد الإنتظار',
          'count': supplierPending,
          'color': AppColors.pendingYellow,
        },
      if (supplierMerged > 0)
        {
          'status': 'طلبات مورد - مدمجة',
          'count': supplierMerged,
          'color': Colors.deepPurple,
        },
      if (supplierReady > 0)
        {
          'status': 'طلبات مورد - جاهزة للتحميل',
          'count': supplierReady,
          'color': Colors.lightBlue,
        },
      if (supplierLoaded > 0)
        {
          'status': 'طلبات مورد - تم التحميل',
          'count': supplierLoaded,
          'color': Colors.blue,
        },
      if (supplierInTransit > 0)
        {
          'status': 'طلبات مورد - في الطريق',
          'count': supplierInTransit,
          'color': Colors.indigo,
        },
      if (supplierDelivered > 0)
        {
          'status': 'طلبات مورد - تم التسليم',
          'count': supplierDelivered,
          'color': Colors.green,
        },

      if (customerWaiting > 0)
        {
          'status': 'طلبات عميل - في انتظار التخصيص',
          'count': customerWaiting,
          'color': Colors.orange[300]!,
        },
      if (customerAssigned > 0)
        {
          'status': 'طلبات عميل - مخصصة للمورد',
          'count': customerAssigned,
          'color': Colors.orange,
        },
      if (customerMerged > 0)
        {
          'status': 'طلبات عميل - مدمجة',
          'count': customerMerged,
          'color': Colors.deepOrange,
        },
      if (customerWaitingForLoad > 0)
        {
          'status': 'طلبات عميل - في انتظار التحميل',
          'count': customerWaitingForLoad,
          'color': Colors.amber,
        },
      if (customerInTransit > 0)
        {
          'status': 'طلبات عميل - في الطريق',
          'count': customerInTransit,
          'color': Colors.amber[700]!,
        },
      if (customerDelivered > 0)
        {
          'status': 'طلبات عميل - تم التسليم',
          'count': customerDelivered,
          'color': Colors.lightGreen,
        },

      if (mergedReady > 0)
        {
          'status': 'طلبات مدمجة - جاهزة',
          'count': mergedReady,
          'color': Colors.purple,
        },
      if (mergedForLoading > 0)
        {
          'status': 'طلبات مدمجة - للتحميل',
          'count': mergedForLoading,
          'color': Colors.purple[300]!,
        },
      if (mergedLoaded > 0)
        {
          'status': 'طلبات مدمجة - تم التحميل',
          'count': mergedLoaded,
          'color': Colors.purple[400]!,
        },
      if (mergedInTransit > 0)
        {
          'status': 'طلبات مدمجة - في الطريق',
          'count': mergedInTransit,
          'color': Colors.purple[600]!,
        },
      if (mergedDelivered > 0)
        {
          'status': 'طلبات مدمجة - تم التسليم',
          'count': mergedDelivered,
          'color': Colors.purple[800]!,
        },
      if (mergedCompleted > 0)
        {
          'status': 'طلبات مدمجة - تم التنفيذ',
          'count': mergedCompleted,
          'color': Colors.green[800]!,
        },

      if (cancelledOrders > 0)
        {
          'status': 'ملغاة',
          'count': cancelledOrders,
          'color': AppColors.errorRed,
        },
    ];

    return Scaffold(
      backgroundColor: isDesktop ? null : Colors.white,
      drawer: isDesktop
          ? null
          : _buildMobileDrawer(
              context,
              authProvider: authProvider,
              notificationProvider: notificationProvider,
            ),
      appBar: isDesktop
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 74,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              leadingWidth: 72,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
              ),
              leading: Builder(
                builder: (appBarContext) => Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: IconButton(
                    onPressed: () => Scaffold.of(appBarContext).openDrawer(),
                    tooltip: 'القائمة الجانبية',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ),
              ),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    AppStrings.dashboard,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMMM', 'ar').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                if (authProvider.isAdminLike)
                  IconButton(
                    onPressed: _backupBusy
                        ? null
                        : () => _showBackupDialog(context),
                    tooltip: 'النسخ الاحتياطي',
                    icon: const Icon(Icons.backup_outlined),
                  ),
              ],
            ),
      body: isDesktop
          ? _buildDesktopLayout(
              context,
              authProvider,
              orderProvider,
              notificationProvider,
              orders,
              overdueOrders,
              totalOrders,
              supplierPending,
              supplierMerged,
              customerWaiting,
              customerAssigned,
              mergedOrders,
              completedOrders,
              cancelledOrders,
              todayOrders,
              thisWeekOrders,
              thisMonthOrders,
              statsCounts,
              statusData,
            )
          : Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.white)),
                RefreshIndicator(
                  color: AppColors.primaryBlue,
                  displacement: 26,
                  onRefresh: () async {
                    await orderProvider.fetchOrders();
                    await notificationProvider.fetchNotifications();
                    await _loadApproachingTimers();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (bodyContext) => _buildWelcomeCard(
                            context,
                            authProvider,
                            unreadNotifications:
                                notificationProvider.unreadCount,
                            onOpenSidebar: () =>
                                Scaffold.of(bodyContext).openDrawer(),
                          ),
                        ),

                        // Builder(
                        //   builder: (bodyContext) => _buildMobileSidebarPrompt(
                        //     bodyContext,
                        //     unreadNotifications:
                        //         notificationProvider.unreadCount,
                        //   ),
                        // ),
                        if (!_loadingTimers && _approachingTimers.isNotEmpty)
                          CountdownSection(
                            timers: _approachingTimers,
                            onViewAll: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.orders,
                                arguments: {'showCountdown': true},
                              );
                            },
                          ),

                        if (!_loadingTimers && _approachingTimers.isNotEmpty)
                          const SizedBox(height: 20),

                        if (overdueOrders.isNotEmpty)
                          OverdueOrdersWidget(
                            orders: orders,
                            onViewAll: () {
                              Navigator.pushNamed(context, AppRoutes.orders);
                            },
                          ),

                        if (overdueOrders.isNotEmpty)
                          const SizedBox(height: 20),

                        _buildStatisticsSection(
                          context,
                          orders,
                          statsFilteredOrders,
                          statsCounts,
                        ),

                        const SizedBox(height: 30),

                        _buildChartSection(context, statusData),
                        const SizedBox(height: 30),

                        _buildRecentOrdersSection(context, orders),
                        const SizedBox(height: 20),

                        _buildPerformanceCard(
                          totalOrders,
                          completedOrders,
                          supplierReady + mergedForLoading,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context, {
    required AuthProvider authProvider,
    required NotificationProvider notificationProvider,
  }) {
    final user = authProvider.user;
    final canViewOrders = user?.hasPermission('orders_view') ?? false;
    final canCreateSupplierOrder =
        user?.hasPermission('orders_create_supplier') ?? false;
    final canCreateCustomerOrder =
        user?.hasPermission('orders_create_customer') ?? false;
    final canMergeOrders = user?.hasPermission('orders_merge') ?? false;
    final canViewCustomers = user?.hasPermission('customers_view') ?? false;
    final canViewSuppliers = user?.hasPermission('suppliers_view') ?? false;
    final canViewDrivers = user?.hasPermission('drivers_view') ?? false;
    final canViewTracking = user?.hasPermission('tracking_view') ?? false;
    final canAccessSettings = user?.hasPermission('settings_access') ?? false;
    final canViewUsers =
        user?.hasAnyPermission(const [
          'users_view',
          'users_create',
          'users_edit',
          'users_delete',
          'users_block',
          'users_manage',
        ]) ??
        false;
    final canViewReports = user?.hasPermission('reports_view') ?? false;
    final canViewTasks =
        user?.hasAnyPermission(const ['tasks_view', 'tasks_view_all']) ?? false;
    final canViewInventory =
        user?.hasAnyPermission(const ['inventory_view', 'inventory_manage']) ??
        false;
    final canViewFuelSales =
        user?.hasAnyPermission(const [
          'fuel_sales_view',
          'fuel_sales_manage',
        ]) ??
        false;
    final canViewMarketing =
        user?.hasAnyPermission(const [
          'marketing_stations_view',
          'marketing_stations_manage',
        ]) ??
        false;
    final canViewPeriodicMaintenance =
        user?.hasAnyPermission(const [
          'maintenance_periodic_view',
          'maintenance_periodic_manage',
        ]) ??
        false;
    final canViewQualification =
        user?.hasAnyPermission(const [
          'qualification_view',
          'qualification_manage',
        ]) ??
        false;
    final canViewHr =
        user?.hasAnyPermission(const ['hr_view', 'hr_manage']) ?? false;
    final canViewActivities = user?.hasPermission('activities_view') ?? false;
    final canViewAuthDevices =
        user?.hasPermission('auth_devices_view') ?? false;
    final canViewBlockedDevices =
        user?.hasPermission('blocked_devices_view') ?? false;
    final canAccessStationMaintenance = [
      'owner',
      'admin',
      'manager',
      'supervisor',
      'maintenance',
      'maintenance_car_management',
      'maintenance_technician',
      'Maintenance_Technician',
    ].contains(user?.role);
    final canAccessWhatsApp = WhatsAppService.canAccessForRole(user?.role);

    final canViewCirculars = user?.role == 'owner' || user?.role == 'manager';
    final canViewMovementPage = user?.role == 'owner' || user?.role == 'admin';
    final canManageSystemPause = user?.role == 'owner';
    final canSendDailyReport = user != null;

    final orderItems = <_DashboardDrawerItemData>[
      if (canViewOrders)
        _DashboardDrawerItemData(
          icon: Icons.list_alt_rounded,
          title: 'الطلبات',
          color: AppColors.primaryBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.orders),
        ),
      if (canCreateSupplierOrder)
        _DashboardDrawerItemData(
          icon: Icons.add_business_rounded,
          title: 'إنشاء طلب مورد',
          color: AppColors.successGreen,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.supplierOrderForm),
        ),
      if (canCreateCustomerOrder)
        _DashboardDrawerItemData(
          icon: Icons.person_add_alt_1_rounded,
          title: 'إنشاء طلب عميل',
          color: AppColors.successGreen,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.customerOrderForm),
        ),
      if (canMergeOrders)
        _DashboardDrawerItemData(
          icon: Icons.merge_type_rounded,
          title: 'دمج الطلبات',
          color: AppColors.secondaryTeal,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.mergeOrders),
        ), 
      if (canViewMovementPage)
        _DashboardDrawerItemData(
          icon: Icons.alt_route_rounded,
          title: 'الحركة',
          color: AppColors.appBarBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.movement),
        ),
    ];

    final partyItems = <_DashboardDrawerItemData>[
      if (canViewCustomers)
        _DashboardDrawerItemData(
          icon: Icons.groups_rounded,
          title: 'العملاء',
          color: AppColors.secondaryTeal,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.customers),
        ),
      if (canViewSuppliers)
        _DashboardDrawerItemData(
          icon: Icons.business_center_rounded,
          title: 'الموردين',
          color: AppColors.primaryBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.suppliers),
        ),
      if (canViewDrivers)
        _DashboardDrawerItemData(
          icon: Icons.drive_eta_rounded,
          title: 'السائقين',
          color: AppColors.warningOrange,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.drivers),
        ),
      if (canViewTracking)
        _DashboardDrawerItemData(
          icon: Icons.directions_car_filled_rounded,
          title: 'السيارات',
          color: AppColors.primaryBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.vehicles),
        ),
      if (canViewTracking)
        _DashboardDrawerItemData(
          icon: Icons.local_shipping_rounded,
          title: 'الصهاريج',
          color: AppColors.infoBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.tankers),
        ),
      if (canViewTracking)
        _DashboardDrawerItemData(
          icon: Icons.location_searching_rounded,
          title: 'المتابعة',
          color: AppColors.infoBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.tracking),
        ),
    ];

    final operationsItems = <_DashboardDrawerItemData>[
      if (canViewInventory)
        _DashboardDrawerItemData(
          icon: Icons.warehouse_outlined,
          title: 'المخزون',
          color: AppColors.primaryDarkBlue,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.inventoryDashboard),
        ),
      if (canViewCirculars)
        _DashboardDrawerItemData(
          icon: Icons.announcement_outlined,
          title: 'تعميم',
          color: AppColors.primaryBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.circulars),
        ),
      if (canSendDailyReport)
        _DashboardDrawerItemData(
          icon: Icons.description_outlined,
          title: 'تقرير يومي',
          color: AppColors.primaryDarkBlue,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.dailyReports),
        ),
      if (canViewTasks)
        _DashboardDrawerItemData(
          icon: Icons.task_alt_rounded,
          title: 'المهام',
          color: AppColors.warningOrange,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.tasks),
        ),
      if (canViewFuelSales)
        _DashboardDrawerItemData(
          icon: Icons.local_gas_station_rounded,
          title: 'مبيعات المحطات',
          color: AppColors.successGreen,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.mainHome),
        ),
      if (canViewMarketing)
        _DashboardDrawerItemData(
          icon: Icons.campaign_outlined,
          title: 'تسويق المحطات',
          color: AppColors.secondaryTeal,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.marketingStations),
        ),
      if (canViewPeriodicMaintenance)
        _DashboardDrawerItemData(
          icon: Icons.directions_car_filled_rounded,
          title: 'الصيانة الدورية',
          color: AppColors.warningOrange,
          onTap: () => _navigateFromMobileDrawer(
            context,
            AppRoutes.maintenanceDashboard,
          ),
        ),
      if (canAccessStationMaintenance)
        _DashboardDrawerItemData(
          icon: Icons.home_repair_service_rounded,
          title: 'تطوير وصيانة المحطات',
          color: AppColors.primaryBlue,
          onTap: () => _navigateFromMobileDrawer(
            context,
            AppRoutes.stationMaintenanceDashboard,
          ),
        ),
      if (canViewQualification)
        _DashboardDrawerItemData(
          icon: Icons.verified_outlined,
          title: 'مواقع المحطات',
          color: AppColors.primaryBlue,
          onTap: () => _navigateFromMobileDrawer(
            context,
            AppRoutes.qualificationDashboard,
          ),
        ),
      if (canViewHr)
        _DashboardDrawerItemData(
          icon: Icons.people_alt_rounded,
          title: 'الموارد البشرية',
          color: AppColors.successGreen,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.hrDashboard),
        ),
      if (canViewHr)
        _DashboardDrawerItemData(
          icon: Icons.people_alt_rounded,
          title: 'الارشيف',
          color: AppColors.successGreen,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.archiveDocuments),
        ),
      if (canViewActivities)
        _DashboardDrawerItemData(
          icon: Icons.local_activity_rounded,
          title: 'الأنشطة',
          color: AppColors.warningOrange,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.activities),
        ),
      if (canViewReports)
        _DashboardDrawerItemData(
          icon: Icons.analytics_outlined,
          title: 'التقارير',
          color: AppColors.primaryDarkBlue,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.reports),
        ),
    ];

    final accountItems = <_DashboardDrawerItemData>[
      _DashboardDrawerItemData(
        icon: Icons.notifications_outlined,
        title: 'الإشعارات',
        color: AppColors.accentBlue,
        badge: notificationProvider.unreadCount,
        onTap: () =>
            _navigateFromMobileDrawer(context, AppRoutes.notifications),
      ),
      if (canAccessWhatsApp)
        _DashboardDrawerItemData(
          icon: Icons.chat_rounded,
          title: 'واتساب',
          color: AppColors.successGreen,
          onTap: () => _openWhatsAppFromMobileDrawer(context),
        ),
      if (canManageSystemPause)
        _DashboardDrawerItemData(
          icon: Icons.pause_circle_outline_rounded,
          title: 'إشعار التوقف المؤقت',
          color: AppColors.warningOrange,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.systemPause),
        ),
      _DashboardDrawerItemData(
        icon: Icons.person_outline_rounded,
        title: 'الملف الشخصي',
        color: AppColors.infoBlue,
        onTap: () => _navigateFromMobileDrawer(context, AppRoutes.profile),
      ),
      if (canViewUsers)
        _DashboardDrawerItemData(
          icon: Icons.manage_accounts_outlined,
          title: 'إدارة المستخدمين',
          color: AppColors.successGreen,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.userManagement),
        ),
      if (canViewAuthDevices)
        _DashboardDrawerItemData(
          icon: Icons.devices_outlined,
          title: 'إدارة الأجهزة',
          color: AppColors.primaryBlue,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.authDevices),
        ),
      if (canViewBlockedDevices)
        _DashboardDrawerItemData(
          icon: Icons.phonelink_lock_outlined,
          title: 'الأجهزة المحظورة',
          color: AppColors.errorRed,
          onTap: () =>
              _navigateFromMobileDrawer(context, AppRoutes.blockedDevices),
        ),
      if (canAccessSettings)
        _DashboardDrawerItemData(
          icon: Icons.settings_outlined,
          title: 'الإعدادات',
          color: AppColors.mediumGray,
          onTap: () => _navigateFromMobileDrawer(context, AppRoutes.settings),
        ),
      _DashboardDrawerItemData(
        icon: Icons.logout_rounded,
        title: 'تسجيل خروج',
        color: AppColors.errorRed,
        onTap: () => _logoutFromMobileDrawer(context, authProvider),
      ),
    ];

    return Drawer(
      width: math.min(MediaQuery.of(context).size.width * 0.88, 340),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFF), Color(0xFFF2F5FC)],
          ),
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18 + MediaQuery.of(context).padding.top,
                    20,
                    20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: AppColors.appBarGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(26),
                      bottomRight: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _userInitials(user?.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'المستخدم',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user != null && user.company.isNotEmpty
                                      ? user.company
                                      : user?.email ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Text(
                      //   'كل أقسام التنقل على الجوال أصبحت داخل القائمة الجانبية.',
                      //   style: TextStyle(
                      //     color: Colors.white.withValues(alpha: 0.86),
                      //     fontSize: 12,
                      //     height: 1.45,
                      //   ),
                      // ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                    children: [
                      _buildMobileDrawerSection(
                        title: 'لوحة التحكم',
                        items: [
                          _DashboardDrawerItemData(
                            icon: Icons.dashboard_customize_rounded,
                            title: 'الرئيسية',
                            color: AppColors.primaryBlue,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      if (orderItems.isNotEmpty)
                        _buildMobileDrawerSection(
                          title: 'الطلبات',
                          items: orderItems,
                        ),
                      if (partyItems.isNotEmpty)
                        _buildMobileDrawerSection(
                          title: 'الأطراف والمتابعة',
                          items: partyItems,
                        ),
                      if (operationsItems.isNotEmpty)
                        _buildMobileDrawerSection(
                          title: 'التشغيل',
                          items: operationsItems,
                        ),
                      _buildMobileDrawerSection(
                        title: 'الحساب',
                        items: accountItems,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawerSection({
    required String title,
    required List<_DashboardDrawerItemData> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryDarkBlue,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...items.map(_buildMobileDrawerTile),
        ],
      ),
    );
  }

  Widget _buildMobileDrawerTile(_DashboardDrawerItemData item) {
    final badge = item.badge;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(item.icon, color: item.color, size: 20),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null && badge > 0)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Icon(Icons.chevron_left_rounded, color: item.color),
        ],
      ),
      onTap: item.onTap,
    );
  }

  // Widget _buildMobileSidebarPrompt(
  //   BuildContext context, {
  //   required int unreadNotifications,
  // }) {
  //   return AppSurfaceCard(
  //     borderRadius: const BorderRadius.all(Radius.circular(24)),
  //     padding: const EdgeInsets.all(18),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Container(
  //               width: 46,
  //               height: 46,
  //               decoration: BoxDecoration(
  //                 borderRadius: BorderRadius.circular(14),
  //                 gradient: const LinearGradient(
  //                   colors: [AppColors.accentBlue, AppColors.secondaryTeal],
  //                 ),
  //               ),
  //               child: const Icon(
  //                 Icons.space_dashboard_rounded,
  //                 color: Colors.white,
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             // Expanded(
  //             //   child: Column(
  //             //     crossAxisAlignment: CrossAxisAlignment.start,
  //             //     children: [
  //             //       const Text(
  //             //         'التنقل أصبح جانبيًا',
  //             //         style: TextStyle(
  //             //           fontSize: 16,
  //             //           fontWeight: FontWeight.w800,
  //             //           color: AppColors.primaryDarkBlue,
  //             //         ),
  //             //       ),
  //             //       const SizedBox(height: 4),
  //             //       Text(
  //             //         'كل انتقالات الجوال داخل القائمة الجانبية لواجهة أبسط وأنظف.',
  //             //         style: TextStyle(
  //             //           fontSize: 12,
  //             //           height: 1.5,
  //             //           color: Colors.grey.shade700,
  //             //         ),
  //             //       ),
  //             //     ],
  //             //   ),
  //             // ),
  //           ],
  //         ),
  //         const SizedBox(height: 14),
  //         Wrap(
  //           spacing: 8,
  //           runSpacing: 8,
  //           children: [
  //             _buildSidebarInfoChip(
  //               icon: Icons.notifications_active_outlined,
  //               label: unreadNotifications > 0
  //                   ? '$unreadNotifications إشعار جديد'
  //                   : 'لا توجد إشعارات جديدة',
  //               color: unreadNotifications > 0
  //                   ? AppColors.errorRed
  //                   : AppColors.primaryBlue,
  //             ),
  //             _buildSidebarInfoChip(
  //               icon: Icons.swipe_rounded,
  //               label: 'افتح القائمة من الأعلى',
  //               color: AppColors.secondaryTeal,
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         SizedBox(
  //           width: double.infinity,
  //           child: FilledButton.icon(
  //             onPressed: () => Scaffold.of(context).openDrawer(),
  //             style: FilledButton.styleFrom(
  //               backgroundColor: AppColors.primaryBlue,
  //               foregroundColor: Colors.white,
  //               padding: const EdgeInsets.symmetric(vertical: 14),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(16),
  //               ),
  //             ),
  //             icon: const Icon(Icons.menu_open_rounded),
  //             label: const Text(
  //               'فتح القائمة الجانبية',
  //               style: TextStyle(fontWeight: FontWeight.w700),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSidebarInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadius.circular(999);
    final decoration = BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: borderRadius,
      border: Border.all(color: color.withValues(alpha: 0.20)),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        decoration: decoration,
        child: content,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
            decoration: decoration,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AuthProvider authProvider,
    OrderProvider orderProvider,
    NotificationProvider notificationProvider,
    List orders,
    List<Map<String, dynamic>> overdueOrders,
    int totalOrders,
    int supplierPending,
    int supplierMerged,
    int customerWaiting,
    int customerAssigned,
    int mergedOrders,
    int completedOrders,
    int cancelledOrders,
    int todayOrders,
    int thisWeekOrders,
    int thisMonthOrders,
    StatsCounts statsCounts,
    List<Map<String, dynamic>> statusData,
  ) {
    final user = authProvider.user;
    final canViewOrders = user?.hasPermission('orders_view') ?? false;
    final canCreateSupplierOrder =
        user?.hasPermission('orders_create_supplier') ?? false;
    final canCreateCustomerOrder =
        user?.hasPermission('orders_create_customer') ?? false;
    final canMergeOrders = user?.hasPermission('orders_merge') ?? false;
    final canViewCustomers = user?.hasPermission('customers_view') ?? false;
    final canViewSuppliers = user?.hasPermission('suppliers_view') ?? false;
    final canViewDrivers = user?.hasPermission('drivers_view') ?? false;
    final canAccessSettings = user?.hasPermission('settings_access') ?? false;
    final canViewUsers =
        user?.hasAnyPermission(const [
          'users_view',
          'users_create',
          'users_edit',
          'users_delete',
          'users_block',
          'users_manage',
        ]) ??
        false;
    bool canSeeStat(String key) => user?.hasPermission(key) ?? false;
    final statsFilteredOrders = _filterOrdersForStats(orderProvider.orders);
    final candlestickData = _buildCandlestickData(statsFilteredOrders);
    final dailySalesData = _buildDailySalesData(statsFilteredOrders);
    final statusDistributionData = _buildStatusDistributionData(
      statsFilteredOrders,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'طلبات البحيرة العربة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildDesktopSidebarFolders(
                    context: context,
                    authProvider: authProvider,
                    notificationProvider: notificationProvider,
                    canViewOrders: canViewOrders,
                    canCreateSupplierOrder: canCreateSupplierOrder,
                    canCreateCustomerOrder: canCreateCustomerOrder,
                    canMergeOrders: canMergeOrders,
                    canViewCustomers: canViewCustomers,
                    canViewSuppliers: canViewSuppliers,
                    canViewDrivers: canViewDrivers,
                    canAccessSettings: canAccessSettings,
                    canViewUsers: canViewUsers,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryBlue,
                      child: Text(
                        authProvider.user?.name
                                .split(' ')
                                .map((n) => n.isNotEmpty ? n[0] : '')
                                .take(2)
                                .join('')
                                .toUpperCase() ??
                            'U',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authProvider.user?.name ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            authProvider.user?.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await orderProvider.fetchOrders();
              await notificationProvider.fetchNotifications();
              await _loadApproachingTimers();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'شركة البحيرة العربية للنقليات',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.notifications,
                              );
                            },
                            icon: Badge(
                              isLabelVisible:
                                  notificationProvider.unreadCount > 0,
                              label: Text(
                                notificationProvider.unreadCount.toString(),
                              ),
                              backgroundColor: AppColors.errorRed,
                              textColor: Colors.white,
                              child: const Icon(Icons.notifications_outlined),
                            ),
                          ),
                          if (authProvider.isAdminLike)
                            IconButton(
                              onPressed: _backupBusy
                                  ? null
                                  : () => _showBackupDialog(context),
                              tooltip: 'النسخ الاحتياطي',
                              icon: const Icon(Icons.backup_outlined),
                            ),
                          IconButton(
                            onPressed: () =>
                                _confirmLogout(context, authProvider),
                            icon: const Icon(Icons.logout),
                            tooltip: 'تسجيل الخروج',
                            color: AppColors.errorRed,
                          ),
                          const SizedBox(width: 16),
                          _buildDesktopDateInfo(),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (!_loadingTimers && _approachingTimers.isNotEmpty)
                    _buildDesktopCountdownBanner(context, _approachingTimers),

                  _buildDesktopWelcomeCard(context, authProvider),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Text(
                        'الإحصائيات',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showExportOptions,
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 18,
                        ),
                        label: const Text('تصدير'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatsFilterBar(context, orderProvider.orders),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsVisualizationControls(context),
                          const SizedBox(height: 12),
                          _buildStatsVisualizationBody(
                            context: context,
                            orders: statsFilteredOrders,
                            candlestickData: candlestickData,
                            dailySalesData: dailySalesData,
                            statusDistributionData: statusDistributionData,
                            statsCounts: statsCounts,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 30),

                  if (!_loadingTimers && orderProvider.orders.isNotEmpty)
                    _buildDesktopOrdersTable(context, _allOrderTimers),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'توزيع أنواع الطلبات - أعمدة',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                    ),
                                    Icon(
                                      Icons.bar_chart,
                                      color: AppColors.primaryBlue,
                                      size: 24,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildCandlestickStyleBarChart(
                                  statsFilteredOrders,
                                  showShell: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 1,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'الطلبات الحديثة',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.orders,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.arrow_back_ios,
                                        size: 20,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (orders.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 60,
                                          color: AppColors.primaryBlue
                                              .withOpacity(0.3),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد طلبات حالياً',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppColors.mediumGray,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (orders.length < 5)
                                  Column(
                                    children: [
                                      RecentOrdersWidget(
                                        orders: List<Order>.from(orders),
                                      ),
                                      const SizedBox(height: 16),
                                      if (orders.isEmpty)
                                        Center(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.orderForm,
                                              );
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text('إنشاء طلب جديد'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryBlue,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                else
                                  RecentOrdersWidget(
                                    orders: List<Order>.from(orders.take(5)),
                                    isDesktop: true,
                                  ),
                                const SizedBox(height: 16),
                                if (orders.isNotEmpty && orders.length > 5)
                                  Center(
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.orders,
                                        );
                                      },
                                      child: const Text('عرض جميع الطلبات'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildDesktopPerformanceCard(
                    totalOrders,
                    completedOrders,
                    supplierPending + customerWaiting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopCountdownBanner(
    BuildContext context,
    List<OrderTimer> approachingTimers,
  ) {
    final urgentTimers = approachingTimers.where((timer) {
      final arrivalRemaining = timer.remainingTimeToArrival;
      return arrivalRemaining <= const Duration(hours: 2, minutes: 30) &&
          arrivalRemaining > Duration.zero;
    }).toList();

    if (urgentTimers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.orange.shade50],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: Colors.orange.shade800,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات تقترب من وقت الوصول!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${urgentTimers.length} طلب سيصل خلال ساعتين ونصف',
                  style: TextStyle(fontSize: 14, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.orders,
                arguments: {'showUrgent': true},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('عرض الطلبات'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOrdersTable(
    BuildContext context,
    List<OrderTimer> timers,
  ) {
    final filteredByDate = _filterOrderTimersByDate(timers);
    final filteredByType = _filterOrderTimersByType(
      filteredByDate,
      _selectedCountdownFilter,
    );
    final filteredByStatus = _filterOrderTimersByStatus(
      filteredByType,
      _selectedStatusFilter,
    );

    final overdueOrders = filteredByType.where((timer) {
      if (_isMergedSource(timer.orderSource)) return false;
      final isOverdue = timer.isOverdue;
      if (_isSupplierSource(timer.orderSource)) {
        return isOverdue && _isWarehouseStatus(timer.status);
      }
      if (_isCustomerSource(timer.orderSource)) {
        return isOverdue && _isWaitingStatus(timer.status);
      }
      return isOverdue;
    }).toList();

    final warningOrders = filteredByType.where((timer) {
      if (_isMergedSource(timer.orderSource)) return false;
      final isApproaching =
          timer.isApproachingArrival || timer.isApproachingLoading;
      if (_isSupplierSource(timer.orderSource)) {
        return isApproaching && _isWarehouseStatus(timer.status);
      }
      if (_isCustomerSource(timer.orderSource)) {
        return isApproaching && _isWaitingStatus(timer.status);
      }
      return false;
    }).toList();

    final overdueRows = filteredByStatus
        .where((timer) => timer.isOverdue)
        .toList();
    final approachingRows = filteredByStatus
        .where(
          (timer) =>
              !timer.isOverdue &&
              (timer.isApproachingArrival || timer.isApproachingLoading),
        )
        .toList();
    final restRows = filteredByStatus
        .where(
          (timer) =>
              !timer.isOverdue &&
              !(timer.isApproachingArrival || timer.isApproachingLoading),
        )
        .toList();
    final tableOrders = [...overdueRows, ...approachingRows, ...restRows];

    final statsTimers = filteredByDate;
    final statsOverdueCount = statsTimers
        .where(
          (timer) => timer.isOverdue && !_isMergedSource(timer.orderSource),
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملخص لجميع الطلبات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorRed,
                  ),
                ),
                if (overdueOrders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.errorRed),
                          ),
                          child: Text(
                            '${overdueOrders.length} طلب متأخر',
                            style: TextStyle(
                              color: AppColors.errorRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.warningOrange),
                          ),
                          child: Text(
                            '${warningOrders.length} طلب مقترب',
                            style: TextStyle(
                              color: AppColors.warningOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                if (tableOrders.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBlue),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${tableOrders.length} طلب يحتاج انتباه',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.orders,
                      arguments: {'showOverdue': true},
                    );
                  },
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildOrdersFilterPanel(context),
        const SizedBox(height: 12),
        _buildOrderTypeStatsRow(statsTimers, statsOverdueCount),
        const SizedBox(height: 8),
        // _buildOrderStatusStatsRow(statsTimers),
        const SizedBox(height: 16),
        if (tableOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: AppColors.successGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد طلبات',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لا يوجد طلبات الان',
                  style: TextStyle(fontSize: 14, color: AppColors.lightGray),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const columnWidths = [
                190.0,
                110.0,
                100.0,
                250.0,
                155.0,
                100.0,
                100.0,
                80.0,
                80.0,
                140.0,
                100.0,
                100.0,
                110.0,
              ];
              final baseWidth = columnWidths.fold<double>(
                0.0,
                (sum, width) => sum + width,
              );
              final tableWidth = math.max(constraints.maxWidth, baseWidth);
              const tableHeight = 600.0;

              return SingleChildScrollView(
                controller: _ordersHorizontalController,
                scrollDirection: Axis.horizontal,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrdersTableHeader(columnWidths),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: tableHeight,
                          child: Scrollbar(
                            controller: _ordersVerticalController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _ordersVerticalController,
                              padding: EdgeInsets.zero,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: tableOrders.length,
                              itemBuilder: (context, index) {
                                final timer = tableOrders[index];
                                return _buildOrdersTableRow(
                                  context,
                                  timer,
                                  columnWidths,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOrdersTableHeader(List<double> columnWidths) {
    const headers = [
      'رقم الطلب الداخلي',
      'رقم طلب المورد',
      'النوع',
      'المورد / العميل',
      'الحالة',
      'تحميل',
      'وصول',
      'نوع الوقود',
      'الكمية',
      'السائق',
      'تأخير',
      'الملاحظات',
      'الإجرائات',
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: List.generate(headers.length, (index) {
          return _buildOrdersTableCell(
            width: columnWidths[index],
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              headers[index],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOrdersTableRow(
    BuildContext context,
    OrderTimer timer,
    List<double> columnWidths,
  ) {
    final delayDuration = DateTime.now().difference(timer.loadingDateTime);
    final String delayText = _formatDelayDuration(delayDuration);
    final bool isSevereDelay = delayDuration.inHours >= 24;
    final bool isCriticalDelay = delayDuration.inHours >= 48;
    final bool showExecutionLabel =
        timer.orderSource == _mergedOrderSource ||
        timer.status == 'قيد التنفيذ';

    final String loadingDateLabel = DateFormat(
      'yyyy/MM/dd',
    ).format(timer.loadingDateTime);
    final String loadingTimeLabel = DateFormat(
      'hh:mm a',
    ).format(timer.loadingDateTime);
    final String arrivalDateLabel = DateFormat(
      'yyyy/MM/dd',
    ).format(timer.arrivalDateTime);
    final String arrivalTimeLabel = DateFormat(
      'hh:mm a',
    ).format(timer.arrivalDateTime);

    final Color? rowColor = isCriticalDelay
        ? Colors.red.withOpacity(0.05)
        : isSevereDelay
        ? Colors.orange.withOpacity(0.05)
        : timer.isOverdue
        ? Colors.yellow.withOpacity(0.05)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildOrdersTableCell(
            width: columnWidths[0],
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCriticalDelay || isSevereDelay) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    timer.orderNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: timer.isCompleted
                          ? AppColors.errorRed
                          : AppColors.primaryBlue,
                    ),
                    overflow: TextOverflow.fade,
                  ),
                ),
              ],
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[1],
            alignment: Alignment.center,
            child: Text(
              timer.supplierOrderNumber ?? '--',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: timer.isCompleted
                    ? AppColors.errorRed
                    : AppColors.primaryBlue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[2],
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getOrderSourceColor(timer.orderSource).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getOrderSourceColor(timer.orderSource),
                ),
              ),
              child: Text(
                _getOrderSourceText(timer.orderSource),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getOrderSourceColor(timer.orderSource),
                ),
              ),
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[3],
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  timer.supplierName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                // 📍 موقع الاستلام
                if (buildPickupLocation(timer).trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'استلام: ${buildPickupLocation(timer)}',
                    style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],

                if (timer.customerName != null &&
                    timer.customerName!.trim().isNotEmpty)
                  const SizedBox(height: 6),

                if (timer.customerName != null &&
                    timer.customerName!.trim().isNotEmpty)
                  Text(
                    'للعميل: ${timer.customerName!}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                if (buildDeliveryLocation(timer).trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'تسليم: ${buildDeliveryLocation(timer)}',
                    style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),

          _buildOrdersTableCell(
            width: columnWidths[4],
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusBadgeColor(timer.status).withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusBadgeColor(timer.status)),
              ),
              child: Center(
                child: Text(
                  timer.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusBadgeColor(timer.status),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[5],
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loadingDateLabel, style: const TextStyle(fontSize: 12)),
                Text(
                  loadingTimeLabel,
                  style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                ),
              ],
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[6],
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(arrivalDateLabel, style: const TextStyle(fontSize: 12)),
                Text(
                  arrivalTimeLabel,
                  style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                ),
              ],
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[7],
            alignment: Alignment.center,
            child: Text(
              timer.fuelType ?? '--',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[8],
            alignment: Alignment.center,
            child: Text(
              _formatQuantityDisplay(timer),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          _buildOrdersTableCell(
            width: columnWidths[9],
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timer.driverName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: timer.isCompleted
                        ? AppColors.accentBlue
                        : timer.isApproachingLoading
                        ? AppColors.warningOrange
                        : AppColors.successGreen,
                  ),
                ),
                if (timer.driverPhone.isNotEmpty)
                  Text(timer.driverPhone, style: const TextStyle(fontSize: 11)),
                if (timer.vehicleNumber.isNotEmpty)
                  Text(
                    timer.vehicleNumber,
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),

          _buildOrdersTableCell(
            width: columnWidths[10],
            alignment: Alignment.center,
            child: showExecutionLabel
                ? Text(
                    'تم التنفيذ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.successGreen,
                    ),
                  )
                : timer.isOverdue
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getDelayColor(delayDuration).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getDelayColor(delayDuration)),
                    ),
                    child: Text(
                      delayText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getDelayColor(delayDuration),
                      ),
                    ),
                  )
                : const Text('--'),
          ),

          _buildOrdersTableCell(
            width: columnWidths[11],
            alignment: Alignment.centerRight,
            child: timer.notes != null && timer.notes!.isNotEmpty
                ? Tooltip(
                    message: timer.notes!,
                    child: Text(
                      timer.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  )
                : const Text(
                    '--',
                    style: TextStyle(color: AppColors.lightGray),
                  ),
          ),

          _buildOrdersTableCell(
            width: columnWidths[12],
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  splashRadius: 18,
                  color: AppColors.primaryBlue,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.orderDetails,
                      arguments: timer.orderId,
                    );
                  },
                ),
                if (timer.isOverdue && !showExecutionLabel)
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18),
                    color: AppColors.warningOrange,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    onPressed: () {
                      _showOverdueActions(context, timer, delayDuration);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String buildPickupLocation(OrderTimer timer) {
    final parts = <String>[];

    if (timer.city != null && timer.city!.isNotEmpty) {
      parts.add(timer.city!);
    }
    if (timer.area != null && timer.area!.isNotEmpty) {
      parts.add(timer.area!);
    }

    return parts.isNotEmpty ? parts.join(' - ') : '';
  }

  String buildDeliveryLocation(OrderTimer timer) {
    if (timer.address != null && timer.address!.isNotEmpty) {
      return timer.address!;
    }

    final parts = <String>[];

    if (timer.city != null && timer.city!.isNotEmpty) {
      parts.add(timer.city!);
    }
    if (timer.area != null && timer.area!.isNotEmpty) {
      parts.add(timer.area!);
    }

    return parts.isNotEmpty ? parts.join(' - ') : '';
  }

  Widget _buildOrdersTableCell({
    required double width,
    required Widget child,
    Alignment alignment = Alignment.centerRight,
    EdgeInsets? padding,
  }) {
    return Container(
      width: width,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: alignment,
      child: child,
    );
  }

  Widget _buildOrderTypeStatsRow(List<OrderTimer> timers, int overdueCount) {
    final supplierCount = timers
        .where((timer) => _isSupplierSource(timer.orderSource))
        .length;
    final customerCount = timers
        .where((timer) => _isCustomerSource(timer.orderSource))
        .length;
    final mergedCount = timers
        .where((timer) => _isMergedSource(timer.orderSource))
        .length;

    final warehouseCount = timers
        .where((timer) => _isWarehouseStatus(timer.status))
        .length;
    final waitingCount = timers
        .where((timer) => _isWaitingStatus(timer.status))
        .length;
    final merged1Count = timers
        .where((timer) => _isMergedStatus(timer.status))
        .length;
    final completedCount = timers
        .where((timer) => _isCompletedStatus(timer.status))
        .length;

    final stats = [
      {
        'label': 'طلبات الموردين',
        'value': supplierCount,
        'icon': Icons.store,
        'color': AppColors.primaryBlue,
      },
      {
        'label': 'طلبات العملاء',
        'value': customerCount,
        'icon': Icons.person,
        'color': Colors.orange,
      },
      {
        'label': 'الطلبات المدمجة',
        'value': mergedCount,
        'icon': Icons.merge_type,
        'color': Colors.purple,
      },
      {
        'label': 'الطلبات المتأخرة',
        'value': overdueCount,
        'icon': Icons.warning_amber,
        'color': AppColors.errorRed,
      },

      {
        'label': 'في المستودع',
        'value': warehouseCount,
        'icon': Icons.inventory_2,
        'color': Colors.blue,
      },
      {
        'label': 'في انتظار التخصيص للعميل',
        'value': waitingCount,
        'icon': Icons.access_time,
        'color': Colors.grey.shade700,
      },
      {
        'label': 'تم الدمج / مدمجة',
        'value': mergedCount,
        'icon': Icons.merge_type,
        'color': Colors.amber.shade700,
      },
      {
        'label': 'مكتملة',
        'value': completedCount,
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((stat) {
        return _buildCountdownStatTile(
          label: stat['label'] as String,
          value: stat['value'] as int,
          icon: stat['icon'] as IconData,
          color: stat['color'] as Color,
        );
      }).toList(),
    );
  }

  // Widget _buildOrderStatusStatsRow(List<OrderTimer> timers) {
  //   final warehouseCount = timers
  //       .where((timer) => _isWarehouseStatus(timer.status))
  //       .length;
  //   final waitingCount = timers
  //       .where((timer) => _isWaitingStatus(timer.status))
  //       .length;
  //   final mergedCount = timers
  //       .where((timer) => _isMergedStatus(timer.status))
  //       .length;
  //   final completedCount = timers
  //       .where((timer) => _isCompletedStatus(timer.status))
  //       .length;

  //   final stats = [
  //     {
  //       'label': 'في المستودع',
  //       'value': warehouseCount,
  //       'icon': Icons.inventory_2,
  //       'color': Colors.blue,
  //     },
  //     {
  //       'label': 'في انتظار التخصيص للعميل',
  //       'value': waitingCount,
  //       'icon': Icons.access_time,
  //       'color': Colors.grey.shade700,
  //     },
  //     {
  //       'label': 'تم الدمج / مدمجة',
  //       'value': mergedCount,
  //       'icon': Icons.merge_type,
  //       'color': Colors.amber.shade700,
  //     },
  //     {
  //       'label': 'مكتملة',
  //       'value': completedCount,
  //       'icon': Icons.check_circle,
  //       'color': Colors.green,
  //     },
  //   ];

  //   return Wrap(
  //     spacing: 12,
  //     runSpacing: 12,
  //     children: stats.map((stat) {
  //       return _buildCountdownStatTile(
  //         label: stat['label'] as String,
  //         value: stat['value'] as int,
  //         icon: stat['icon'] as IconData,
  //         color: stat['color'] as Color,
  //       );
  //     }).toList(),
  //   );
  // }

  Widget _buildOrdersFilterPanel(BuildContext context) {
    final hasDateRange = _selectedCountdownDateRange != null;
    final textStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade800,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('تصفية الطلبات', style: textStyle),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickOrderDateRange,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  _orderDateFilterLabel(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (hasDateRange)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'مسح التاريخ',
                  onPressed: _clearOrderDateFilter,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('حسب النوع', style: textStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _typeFilterOptions.map((option) {
              final key = option['key']!;
              final label = option['label']!;
              final color = _ordersFilterChipColor(key);
              final isSelected = _selectedCountdownFilter == key;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: color.withOpacity(0.2),
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
                side: BorderSide(
                  color: isSelected ? color : Colors.transparent,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedCountdownFilter = key;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('حسب الحالة', style: textStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statusFilterChoices.map((option) {
              final key = option['key']!;
              final label = option['label']!;
              final color = _statusFilterChipColor(key);
              final isSelected = _selectedStatusFilter == key;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: color.withOpacity(0.2),
                backgroundColor: color.withOpacity(0.08),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
                side: BorderSide(
                  color: isSelected ? color : color.withOpacity(0.5),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedStatusFilter = key;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _ordersFilterChipColor(String key) {
    switch (key) {
      case 'all':
        return AppColors.primaryBlue;
      case 'customer':
        return Colors.orange;
      case 'supplier':
        return Colors.indigo;
      case 'merged':
        return Colors.purple;
      case 'overdue':
        return AppColors.errorRed;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildCountdownStatTile({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
        ],
      ),
    );
  }

  static const List<String> _supplierOrderSourceVariants = ['U.U^OñO_', 'مورد'];

  static const List<String> _customerOrderSourceVariants = ['O1U.USU,', 'عميل'];

  static const List<String> _mergedOrderSourceVariants = ['U.O_U.Oª', 'مدمج'];

  static const List<String> _warehouseStatusKeywords = ['في المستودع'];

  static const List<String> _waitingStatusKeywords = ['في انتظار التخصيص'];

  static const List<String> _mergedStatusKeywords = ['تم الدمج', 'مدمج'];

  static const List<String> _completedStatusKeywords = [
    'تم التنفيذ',
    'تم التسليم',
    'مكتمل',
  ];
  static const List<String> _canceledStatusKeywords = [
    'ملغي',
    'ملغى',
    'ملغاة',
    'تم الإلغاء',
    'إلغاء',
  ];

  static const List<String> _purchaseRequestTypeKeywords = [
    'purchase',
    'buy',
    '\u0634\u0631\u0627\u0621',
  ];

  static const List<String> _transportRequestTypeKeywords = [
    'transport',
    'delivery',
    '\u0646\u0642\u0644',
  ];

  static const List<Map<String, String>> _typeFilterOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'customer', 'label': 'طلبات العملاء'},
    {'key': 'supplier', 'label': 'طلبات الموردين'},
    {'key': 'merged', 'label': 'الطلبات المدمجة'},
    {'key': 'overdue', 'label': 'الطلبات المتأخرة'},
  ];

  static const List<Map<String, String>> _statusFilterChoices = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'warehouse', 'label': 'في المستودع'},
    {'key': 'waiting', 'label': 'في إنتظار التخصيص للعميل'},
    {'key': 'merged', 'label': 'تم الدمج'},
    {'key': 'completed', 'label': 'تم التنفيذ'},
    {'key': 'canceled', 'label': 'ملغي'},
  ];

  bool _isSupplierSource(String source) {
    return _supplierOrderSourceVariants.contains(source);
  }

  bool _isCustomerSource(String source) {
    return _customerOrderSourceVariants.contains(source);
  }

  bool _isMergedSource(String source) {
    return _mergedOrderSourceVariants.contains(source);
  }

  bool _statusMatches(String status, List<String> keywords) {
    if (status.isEmpty) return false;
    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;
      if (status.contains(keyword)) return true;
    }
    return false;
  }

  bool _isWarehouseStatus(String status) {
    return _statusMatches(status, _warehouseStatusKeywords);
  }

  bool _isWaitingStatus(String status) {
    return _statusMatches(status, _waitingStatusKeywords);
  }

  bool _isMergedStatus(String status) {
    return _statusMatches(status, _mergedStatusKeywords);
  }

  bool _isCompletedStatus(String status) {
    return _statusMatches(status, _completedStatusKeywords);
  }

  bool _isCanceledStatus(String status) {
    return _statusMatches(status, _canceledStatusKeywords);
  }

  bool _requestTypeMatches(String? requestType, List<String> keywords) {
    final normalized = (requestType ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final keyword in keywords) {
      final needle = keyword.trim().toLowerCase();
      if (needle.isEmpty) continue;
      if (normalized == needle || normalized.contains(needle)) return true;
    }
    return false;
  }

  bool _isPurchaseRequestType(String? requestType) {
    return _requestTypeMatches(requestType, _purchaseRequestTypeKeywords);
  }

  bool _isTransportRequestType(String? requestType) {
    return _requestTypeMatches(requestType, _transportRequestTypeKeywords);
  }

  String _dashboardRequestTypeCategory(Order order) {
    final requestType = order.effectiveRequestType.trim();
    if (requestType == 'شراء') return 'purchase';
    if (requestType == 'نقل') return 'transport';
    return '';
  }

  List<OrderTimer> _filterOrderTimersByType(
    List<OrderTimer> timers,
    String filterKey,
  ) {
    switch (filterKey) {
      case 'supplier':
        return timers
            .where((timer) => _isSupplierSource(timer.orderSource))
            .toList();
      case 'customer':
        return timers
            .where((timer) => _isCustomerSource(timer.orderSource))
            .toList();
      case 'merged':
        return timers
            .where((timer) => _isMergedSource(timer.orderSource))
            .toList();
      case 'overdue':
        return timers.where((timer) => timer.isOverdue).toList();
      default:
        return timers;
    }
  }

  List<OrderTimer> _filterOrderTimersByStatus(
    List<OrderTimer> timers,
    String filterKey,
  ) {
    switch (filterKey) {
      case 'warehouse':
        return timers
            .where((timer) => _isWarehouseStatus(timer.status))
            .toList();
      case 'waiting':
        return timers.where((timer) => _isWaitingStatus(timer.status)).toList();
      case 'merged':
        return timers.where((timer) => _isMergedStatus(timer.status)).toList();
      case 'completed':
        return timers
            .where((timer) => _isCompletedStatus(timer.status))
            .toList();
      case 'canceled':
        return timers
            .where((timer) => _isCanceledStatus(timer.status))
            .toList();
      default:
        return timers;
    }
  }

  List<OrderTimer> _filterOrderTimersByDate(List<OrderTimer> timers) {
    final range = _selectedCountdownDateRange;
    if (range == null) return timers;

    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    return timers.where((timer) {
      final loading = timer.loadingDateTime;
      return !loading.isBefore(start) && !loading.isAfter(end);
    }).toList();
  }

  String _orderDateFilterLabel() {
    if (_selectedCountdownDateRange == null) {
      return 'كل التواريخ';
    }

    final start = DateFormat(
      'yyyy/MM/dd',
    ).format(_selectedCountdownDateRange!.start);
    final end = DateFormat(
      'yyyy/MM/dd',
    ).format(_selectedCountdownDateRange!.end);
    return '$start - $end';
  }

  Future<void> _pickOrderDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _selectedCountdownDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) {
      setState(() {
        _selectedCountdownDateRange = picked;
      });
    }
  }

  void _clearOrderDateFilter() {
    setState(() {
      _selectedCountdownDateRange = null;
    });
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<int> _availableStatsYears(List<Order> orders) {
    final yearsSet = orders.map((o) => o.arrivalDate.year).toSet();
    yearsSet.add(DateTime.now().year);
    final years = yearsSet.toList()..sort();
    return years;
  }

  int _effectiveStatsYear(List<Order> orders) {
    final years = _availableStatsYears(orders);
    if (years.isEmpty) return DateTime.now().year;
    if (years.contains(_statsSelectedYear)) return _statsSelectedYear;
    return years.last;
  }

  List<Order> _filterOrdersForStats(List<Order> orders) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final effectiveYear = _effectiveStatsYear(orders);

    switch (_statsDateFilter) {
      case 'daily':
        return orders
            .where((order) => _isSameDay(order.arrivalDate, today))
            .toList();
      case 'weekly':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return orders.where((order) {
          final d = _dateOnly(order.arrivalDate);
          return !d.isBefore(weekStart) && d.isBefore(weekEnd);
        }).toList();
      case 'monthly':
        return orders
            .where(
              (order) =>
                  order.arrivalDate.year == effectiveYear &&
                  order.arrivalDate.month == _statsSelectedMonth,
            )
            .toList();
      case 'yearly':
        return orders
            .where((order) => order.arrivalDate.year == effectiveYear)
            .toList();
      default:
        return orders;
    }
  }

  bool _matchesStatsPeriod(DateTime date, List<Order> orders) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yearsSet = orders.map((o) => o.arrivalDate.year).toSet();
    yearsSet.add(DateTime.now().year);
    final years = yearsSet.toList()..sort();
    final effectiveYear = years.contains(_statsSelectedYear)
        ? _statsSelectedYear
        : (years.isNotEmpty ? years.last : DateTime.now().year);

    switch (_statsDateFilter) {
      case 'daily':
        return _isSameDay(date, today);
      case 'weekly':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final d = _dateOnly(date);
        return !d.isBefore(weekStart) && d.isBefore(weekEnd);
      case 'monthly':
        return date.year == effectiveYear && date.month == _statsSelectedMonth;
      case 'yearly':
        return date.year == effectiveYear;
      default:
        return true;
    }
  }

  bool _matchesExportPeriodForDate(DateTime date) {
    final today = _dateOnly(DateTime.now());
    switch (_exportDateFilter) {
      case 'daily':
        return _isSameDay(date, _exportSelectedDate);
      case 'monthly':
        return date.year == _exportSelectedYear &&
            date.month == _exportSelectedMonth;
      case 'yearly':
        return date.year == _exportSelectedYear;
      default:
        return _isSameDay(date, today);
    }
  }

  List<Order> _filterOrdersByExportPeriod(
    List<Order> orders, {
    DateTime Function(Order order)? dateSelector,
  }) {
    final resolvedDateSelector = dateSelector ?? ((order) => order.arrivalDate);
    return orders
        .where(
          (order) => _matchesExportPeriodForDate(resolvedDateSelector(order)),
        )
        .toList();
  }

  bool _isPdfCompletedOrder(Order order) {
    return _isFinalStatus(order.status) && !_isCanceledStatus(order.status);
  }

  List<Order> _filterOrdersForPdf(List<Order> orders) {
    switch (_exportPdfScope) {
      case 'customers':
        return _filterOrdersByExportPeriod(
          orders,
        ).where((order) => _isCustomerSource(order.orderSource)).toList();
      case 'suppliers':
        return _filterOrdersByExportPeriod(
          orders,
        ).where((order) => _isSupplierSource(order.orderSource)).toList();
      case 'completed':
      default:
        return _filterOrdersByExportPeriod(
          orders,
        ).where((order) => _isPdfCompletedOrder(order)).toList();
    }
  }

  List<Order> _filterOrdersForPdfStats(List<Order> orders) {
    final periodOrders = _filterOrdersByExportPeriod(orders);
    switch (_exportPdfScope) {
      case 'customers':
        return periodOrders
            .where((order) => _isCustomerSource(order.orderSource))
            .toList();
      case 'suppliers':
        return periodOrders
            .where((order) => _isSupplierSource(order.orderSource))
            .toList();
      case 'completed':
      default:
        return periodOrders.where(_isPdfCompletedOrder).toList();
    }
  }

  List<Order> _filterOrdersForExcel(List<Order> orders) {
    final filtered = _filterOrdersByExportPeriod(orders);
    switch (_exportExcelScope) {
      case 'customers':
        return filtered
            .where((order) => _isCustomerSource(order.orderSource))
            .toList();
      case 'suppliers':
        return filtered
            .where((order) => _isSupplierSource(order.orderSource))
            .toList();
      case 'completed':
      default:
        return filtered
            .where(
              (order) =>
                  _isCompletedStatus(order.status) &&
                  !_isCanceledStatus(order.status),
            )
            .toList();
    }
  }

  String _exportPeriodLabel() {
    switch (_exportDateFilter) {
      case 'daily':
        return 'يومي (${DateFormat('yyyy/MM/dd').format(_exportSelectedDate)})';
      case 'monthly':
        return 'شهرى (${_arabicMonths[_exportSelectedMonth - 1]} $_exportSelectedYear)';
      case 'yearly':
        return 'سنوي ($_exportSelectedYear)';
      default:
        return 'يومي (${DateFormat('yyyy/MM/dd').format(_exportSelectedDate)})';
    }
  }

  String _exportPdfScopeLabel() {
    switch (_exportPdfScope) {
      case 'customers':
        return 'طلبات العملاء';
      case 'suppliers':
        return 'طلبات الموردين';
      case 'completed':
      default:
        return 'الطلبات المكتملة';
    }
  }

  String _exportExcelScopeLabel() {
    switch (_exportExcelScope) {
      case 'customers':
        return 'طلبات العملاء';
      case 'suppliers':
        return 'طلبات الموردين';
      case 'completed':
      default:
        return 'الطلبات المكتملة';
    }
  }

  String _sanitizePdfText(String? value) {
    if (value == null) return '';
    final normalized = value
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  String _truncatePdfText(String value, {int maxChars = 120}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  String _formatPdfQuantity(double? quantity, String? unit) {
    if (quantity == null) return '-';
    final bool isWhole = quantity % 1 == 0;
    final value = isWhole
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    final safeUnit = _sanitizePdfText(unit);
    return safeUnit.isEmpty ? value : '$value $safeUnit';
  }

  Future<void> _pickExportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _exportSelectedDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() => _exportSelectedDate = picked);
    }
  }

  StatsCounts _computeStatsCounts({
    required List<Order> allOrders,
    required List<Order> filteredOrders,
  }) {
    final orders = filteredOrders;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);

    final totalOrders = orders.length;
    final supplierPending = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' &&
              [
                'في المستودع',
                'تم الإنشاء',
                'في انتظار الدمج',
              ].contains(order.status),
        )
        .length;
    final supplierMerged = orders
        .where(
          (order) =>
              order.orderSource == 'مورد' &&
              order.status == 'تم دمجه مع العميل',
        )
        .length;
    final customerWaiting = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' &&
              order.status == 'في انتظار التخصيص',
        )
        .length;
    final customerAssigned = orders
        .where(
          (order) =>
              order.orderSource == 'عميل' &&
              order.status == 'تم تخصيص طلب المورد',
        )
        .length;
    final mergedOrders = orders
        .where((order) => order.orderSource == 'مدمج')
        .length;
    final completedOrdersByArrivalDate = allOrders
        .where(
          (order) =>
              _isFinalStatus(order.status) &&
              !_isCanceledStatus(order.status) &&
              _matchesStatsPeriod(order.arrivalDate, allOrders),
        )
        .length;
    final cancelledOrders = orders
        .where((order) => order.status == 'ملغى')
        .length;
    final todayOrders = orders.where((order) {
      return _isSameDay(order.arrivalDate, today);
    }).length;
    final thisWeekOrders = orders.where((order) {
      final d = _dateOnly(order.arrivalDate);
      return !d.isBefore(weekStart);
    }).length;
    final thisMonthOrders = orders.where((order) {
      return order.arrivalDate.isAfter(monthStart);
    }).length;

    return StatsCounts(
      totalOrders: totalOrders,
      supplierPending: supplierPending,
      supplierMerged: supplierMerged,
      customerWaiting: customerWaiting,
      customerAssigned: customerAssigned,
      mergedOrders: mergedOrders,
      completedOrders: completedOrdersByArrivalDate,
      cancelledOrders: cancelledOrders,
      todayOrders: todayOrders,
      thisWeekOrders: thisWeekOrders,
      thisMonthOrders: thisMonthOrders,
    );
  }

  Widget _buildStatsFilterBar(BuildContext context, List<Order> orders) {
    final effectiveYear = _effectiveStatsYear(orders);
    final years = _availableStatsYears(orders);
    final showMonthPicker = _statsDateFilter == 'monthly';
    final showYearPicker =
        _statsDateFilter == 'monthly' || _statsDateFilter == 'yearly';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.filter_alt_outlined,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فلترة الإحصائيات',
                      style: TextStyle(
                        color: AppColors.primaryDarkBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اختر الفترة الزمنية لعرض ملخص الإحصائيات',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statsDateFilterOptions.map((option) {
              final key = option['key'] ?? '';
              final label = option['label'] ?? '';
              final isSelected = _statsDateFilter == key;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _statsDateFilter = key);
                },
                selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.mediumGray,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.lightGray,
                ),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),
          if (showMonthPicker || showYearPicker) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (showMonthPicker)
                  _buildFilterDropdown<int>(
                    label: 'الشهر',
                    value: _statsSelectedMonth,
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem<int>(
                        value: month,
                        child: Text(_arabicMonths[index]),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _statsSelectedMonth = value);
                    },
                  ),
                if (showYearPicker)
                  _buildFilterDropdown<int>(
                    label: 'السنة',
                    value: effectiveYear,
                    items: years.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _statsSelectedYear = value);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.lightGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.lightGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryBlue),
          ),
        ),
        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.mediumGray),
      ),
    );
  }

  void _showExportOptions() {
    final orders = context.read<OrderProvider>().orders;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    final availableYears = _availableStatsYears(orders);
    if (!availableYears.contains(_exportSelectedYear)) {
      _exportSelectedYear = availableYears.isNotEmpty
          ? availableYears.last
          : DateTime.now().year;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final isDesktop = MediaQuery.of(context).size.width > 750;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تصدير الإحصائيات',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'اختر فترة التصدير',
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _exportDateFilterOptions.map((option) {
                  final key = option['key'] ?? '';
                  final label = option['label'] ?? '';
                  final isSelected = _exportDateFilter == key;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _exportDateFilter = key);
                    },
                    selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.mediumGray,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.lightGray,
                    ),
                    backgroundColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_exportDateFilter == 'daily')
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _pickExportDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      DateFormat('yyyy/MM/dd').format(_exportSelectedDate),
                    ),
                  ),
                ),
              if (_exportDateFilter == 'monthly' ||
                  _exportDateFilter == 'yearly')
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (_exportDateFilter == 'monthly')
                      _buildFilterDropdown<int>(
                        label: 'الشهر',
                        value: _exportSelectedMonth,
                        items: List.generate(12, (index) {
                          final month = index + 1;
                          return DropdownMenuItem<int>(
                            value: month,
                            child: Text(_arabicMonths[index]),
                          );
                        }),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _exportSelectedMonth = value);
                        },
                      ),
                    _buildFilterDropdown<int>(
                      label: 'السنة',
                      value: _exportSelectedYear,
                      items: availableYears.map((year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _exportSelectedYear = value);
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفاصيل التصدير',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDarkBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('الفترة: ${_exportPeriodLabel()}'),
                    Text('المستخدم المصدّر: ${user?.name ?? ''}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'نوع بيانات PDF',
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _exportScopeOptions.map((option) {
                  final key = option['key'] ?? '';
                  final label = option['label'] ?? '';
                  final isSelected = _exportPdfScope == key;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _exportPdfScope = key);
                    },
                    selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.mediumGray,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.lightGray,
                    ),
                    backgroundColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'نوع بيانات Excel',
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _exportScopeOptions.map((option) {
                  final key = option['key'] ?? '';
                  final label = option['label'] ?? '';
                  final isSelected = _exportExcelScope == key;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _exportExcelScope = key);
                    },
                    selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.mediumGray,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.lightGray,
                    ),
                    backgroundColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _exportOrdersPdf();
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('تصدير PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _exportOrdersExcel();
                      },
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('تصدير Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (isDesktop) const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportOrdersPdf() async {
    final orderProvider = context.read<OrderProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    try {
      final filteredOrders = _filterOrdersForPdf(orderProvider.orders);
      final pdfStatsOrders = _filterOrdersForPdfStats(orderProvider.orders);
      if (filteredOrders.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد بيانات للتصدير.')),
        );
        return;
      }
      _exportEstimatedSeconds = _estimateExportSeconds(filteredOrders.length);
      _showExportLoading();

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
      final estimatedPages = (filteredOrders.length / 22).ceil() + 8;
      final maxPages = math.max(60, math.min(6000, estimatedPages));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          maxPages: maxPages,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
          theme: pw.ThemeData.withFont(
            base: arabicFontRegular,
            bold: arabicFontBold,
            fontFallback: [arabicFontRegular],
          ),
          header: (context) => context.pageNumber == 1
              ? _buildOrdersPdfHeader(logo, user)
              : pw.SizedBox(),
          footer: (context) => context.pageNumber == context.pagesCount
              ? _buildOrdersPdfFooter(context)
              : pw.SizedBox(),
          build: (_) => [
            _buildOrdersPdfTable(filteredOrders),
            pw.NewPage(),
            ..._buildOrdersPdfStatsWidgets(pdfStatsOrders),
          ],
        ),
      );

      final bytes = await pdf.save();
      await saveAndLaunchFile(
        bytes,
        'تقرير_الطلبات_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } on Exception catch (e) {
      if (!mounted) return;
      if (e.toString().contains('TooManyPagesException')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '\u062A\u0639\u0630\u0631 \u0625\u0646\u0634\u0627\u0621 PDF \u0628\u0633\u0628\u0628 \u062D\u062C\u0645 \u0627\u0644\u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0643\u0628\u064A\u0631. \u0642\u0644\u0644 \u0627\u0644\u0641\u062A\u0631\u0629 \u0623\u0648 \u0646\u0648\u0639 \u0627\u0644\u062A\u0642\u0631\u064A\u0631 \u062B\u0645 \u0623\u0639\u062F \u0627\u0644\u0645\u062D\u0627\u0648\u0644\u0629.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    } finally {
      _hideExportLoading();
    }
  }

  Future<void> _exportOrdersExcel() async {
    final orderProvider = context.read<OrderProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    try {
      final filteredOrders = _filterOrdersForExcel(orderProvider.orders);
      if (filteredOrders.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد بيانات للتصدير.')),
        );
        return;
      }
      _exportEstimatedSeconds = _estimateExportSeconds(filteredOrders.length);
      _showExportLoading();

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'تقرير الطلبات';

      sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;
      sheet.pageSetup.isCenterHorizontally = true;

      final companyName = user?.company ?? 'شركة البحيرة العربية للنقليات';
      const unifiedNumber = '7011144750';

      sheet.getRangeByName('A1:H1').merge();
      sheet.getRangeByIndex(1, 1).setText(companyName);
      final titleStyle = workbook.styles.add('titleStyleDashboard');
      titleStyle.bold = true;
      titleStyle.fontSize = 16;
      titleStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(1, 1).cellStyle = titleStyle;
      sheet.getRangeByIndex(1, 1).rowHeight = 28;

      sheet.getRangeByName('A2:H2').merge();
      sheet
          .getRangeByIndex(2, 1)
          .setText('الرقم الوطني الموحد: $unifiedNumber');
      final subStyle = workbook.styles.add('subStyleDashboard');
      subStyle.fontSize = 11;
      subStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(2, 1).cellStyle = subStyle;

      sheet.getRangeByName('A3:H3').merge();
      sheet
          .getRangeByIndex(3, 1)
          .setText(
            'تفاصيل التصدير: ${_exportPeriodLabel()} | المستخدم المصدّر: ${user?.name ?? ''} | تاريخ التصدير: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
          );
      sheet.getRangeByIndex(3, 1).cellStyle = subStyle;

      final headers = [
        'رقم طلب المورد',
        'اسم المورد',
        'اسم العميل',
        'اسم السائق',
        'التاريخ',
        'الملاحظات',
        'المستخدم المنشئ',
        'رقم الطلب',
      ];

      final headerStyle = workbook.styles.add('headerStyleDashboard');
      headerStyle.bold = true;
      headerStyle.fontSize = 11;
      headerStyle.hAlign = xlsio.HAlignType.center;
      headerStyle.vAlign = xlsio.VAlignType.center;
      headerStyle.backColor = '#E3F2FD';
      headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(5, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle = headerStyle;
        sheet.setColumnWidthInPixels(i + 1, 160);
      }

      final dataStyle = workbook.styles.add('dataStyleDashboard');
      dataStyle.fontSize = 10;
      dataStyle.hAlign = xlsio.HAlignType.center;
      dataStyle.vAlign = xlsio.VAlignType.center;
      dataStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      int row = 6;
      for (final order in filteredOrders) {
        final supplierOrderNumber = order.supplierOrderNumber ?? '';
        final supplierName = order.supplierName;
        final customerName = order.customer?.name ?? '';
        final driverName = order.driver?.name ?? order.driverName ?? '';
        final dateText = DateFormat('yyyy/MM/dd').format(order.orderDate);
        final notes = order.notes ?? '';
        final createdBy = order.createdByName ?? '';
        final orderNumber = order.orderNumber;

        final c1 = sheet.getRangeByIndex(row, 1);
        c1.setText(supplierOrderNumber);
        c1.cellStyle = dataStyle;

        final c2 = sheet.getRangeByIndex(row, 2);
        c2.setText(supplierName);
        c2.cellStyle = dataStyle;

        final c3 = sheet.getRangeByIndex(row, 3);
        c3.setText(customerName);
        c3.cellStyle = dataStyle;

        final c4 = sheet.getRangeByIndex(row, 4);
        c4.setText(driverName);
        c4.cellStyle = dataStyle;

        final c5 = sheet.getRangeByIndex(row, 5);
        c5.setText(dateText);
        c5.cellStyle = dataStyle;

        final c6 = sheet.getRangeByIndex(row, 6);
        c6.setText(notes);
        c6.cellStyle = dataStyle;

        final c7 = sheet.getRangeByIndex(row, 7);
        c7.setText(createdBy);
        c7.cellStyle = dataStyle;

        final c8 = sheet.getRangeByIndex(row, 8);
        c8.setText(orderNumber);
        c8.cellStyle = dataStyle;

        row++;
      }

      final footerRow = row + 2;
      sheet.getRangeByName('A$footerRow:H$footerRow').merge();
      sheet
          .getRangeByIndex(footerRow, 1)
          .setText(
            'توقيع المدير العام: ____________________    توقيع رئيس مجلس الإدارة: ____________________',
          );
      sheet.getRangeByIndex(footerRow, 1).cellStyle = subStyle;

      final footerRow2 = footerRow + 1;
      sheet.getRangeByName('A$footerRow2:H$footerRow2').merge();
      sheet
          .getRangeByIndex(footerRow2, 1)
          .setText(' شركة البحيرة العربية  | نظام نبراس');
      sheet.getRangeByIndex(footerRow2, 1).cellStyle = subStyle;

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      await saveAndLaunchFile(
        bytes,
        'تقرير_الطلبات_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
    } finally {
      _hideExportLoading();
    }
  }

  int _estimateExportSeconds(int rows) {
    final estimated = 4 + (rows / 40).ceil();
    if (estimated < 4) return 4;
    if (estimated > 20) return 20;
    return estimated;
  }

  void _showExportLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري تجهيز الملف',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDarkBlue,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'يرجى الانتظار قليلاً...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الوقت المتوقع: $_exportEstimatedSeconds ثوانٍ',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.lightGray,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: AppColors.lightGray.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideExportLoading() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  String _pdfStatsTitle() {
    switch (_exportDateFilter) {
      case 'daily':
        return 'إحصائيات يوم ${DateFormat('yyyy/MM/dd').format(_exportSelectedDate)}';
      case 'monthly':
        return 'إحصائيات شهر ${_arabicMonths[_exportSelectedMonth - 1]} $_exportSelectedYear';
      case 'yearly':
        return 'إحصائيات سنة $_exportSelectedYear';
      default:
        return 'إحصائيات ${_exportPeriodLabel()}';
    }
  }

  bool _includeOrderInSupplierPdfStats(Order order) {
    if (_exportPdfScope == 'completed') {
      return _pdfSupplierDisplayName(order).isNotEmpty;
    }
    return _isSupplierSource(order.orderSource);
  }

  bool _includeOrderInCustomerPdfStats(Order order) {
    if (_exportPdfScope == 'completed') {
      return _pdfCustomerDisplayName(order).isNotEmpty;
    }
    return _isCustomerSource(order.orderSource);
  }

  bool _includeOrderInRequestTypePdfStats(Order order) {
    if (_exportPdfScope == 'completed') {
      return order.isCustomerOrder || order.isMergedOrder;
    }
    if (_exportPdfScope == 'suppliers') {
      return false;
    }
    return _isCustomerSource(order.orderSource);
  }

  String _pdfSupplierDisplayName(Order order) {
    final directName = _sanitizePdfText(order.supplierName);
    if (directName.isNotEmpty) {
      return directName;
    }

    final nestedName = _sanitizePdfText(order.supplier?.name);
    if (nestedName.isNotEmpty) {
      return nestedName;
    }

    final mergedName = _sanitizePdfText(
      order.mergedWithInfo?['supplierName']?.toString(),
    );
    if (mergedName.isNotEmpty) {
      return mergedName;
    }

    return '';
  }

  String _pdfCustomerDisplayName(Order order) {
    final customerName = _sanitizePdfText(order.customer?.name);
    if (customerName.isNotEmpty) {
      return customerName;
    }

    final mergedName = _sanitizePdfText(
      order.mergedWithInfo?['customerName']?.toString(),
    );
    if (mergedName.isNotEmpty) {
      return mergedName;
    }

    final customerAddress = _sanitizePdfText(order.customerAddress);
    if (customerAddress.isNotEmpty) {
      return customerAddress;
    }

    return '';
  }

  List<pw.Widget> _buildOrdersPdfStatsWidgets(List<Order> orders) {
    final statsTitle = _pdfStatsTitle();
    final activeOrders = orders
        .where((order) => !_isCanceledStatus(order.status))
        .toList();
    final completedCount = _exportPdfScope == 'completed'
        ? activeOrders.length
        : activeOrders
              .where((order) => _isCompletedStatus(order.status))
              .length;
    final purchaseCount = activeOrders
        .where(
          (order) =>
              _includeOrderInRequestTypePdfStats(order) &&
              _dashboardRequestTypeCategory(order) == 'purchase',
        )
        .length;
    final transportCount = activeOrders
        .where(
          (order) =>
              _includeOrderInRequestTypePdfStats(order) &&
              _dashboardRequestTypeCategory(order) == 'transport',
        )
        .length;

    final Map<String, int> supplierCounts = {};
    final Map<String, int> customerCounts = {};
    for (final order in activeOrders) {
      final supplier = _pdfSupplierDisplayName(order);
      if (supplier.isNotEmpty && _includeOrderInSupplierPdfStats(order)) {
        supplierCounts[supplier] = (supplierCounts[supplier] ?? 0) + 1;
      }

      final customer = _pdfCustomerDisplayName(order);
      if (customer.isNotEmpty && _includeOrderInCustomerPdfStats(order)) {
        customerCounts[customer] = (customerCounts[customer] ?? 0) + 1;
      }
    }

    final supplierRows = supplierCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final customerRows = customerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      pw.Text(
        statsTitle,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildPdfStatCard(
            label: 'عدد الطلبات المكتملة',
            value: completedCount.toString(),
            color: PdfColors.green700,
          ),
          _buildPdfStatCard(
            label: 'عدد طلبات النقل',
            value: transportCount.toString(),
            color: PdfColors.orange700,
          ),
          _buildPdfStatCard(
            label: 'عدد طلبات الشراء',
            value: purchaseCount.toString(),
            color: PdfColors.blue700,
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      ..._buildSplitNamedCountSections(
        customerRows: customerRows,
        supplierRows: supplierRows,
      ),
    ];
  }

  pw.Widget _buildPdfStatCard({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 6.8,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSplitNamedCountTable({
    required List<MapEntry<String, int>> customerRows,
    required List<MapEntry<String, int>> supplierRows,
  }) {
    final totalRows = math.max(customerRows.length, supplierRows.length);
    final data = List<List<String>>.generate(totalRows == 0 ? 1 : totalRows, (
      index,
    ) {
      final customer = index < customerRows.length ? customerRows[index] : null;
      final supplier = index < supplierRows.length ? supplierRows[index] : null;

      return [
        customer?.key ?? '-',
        customer?.value.toString() ?? '0',
        supplier?.key ?? '-',
        supplier?.value.toString() ?? '0',
      ];
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'العملاء وطلباتهم / الموردين وطلباتهم',
          style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Table.fromTextArray(
          headers: const ['العميل', 'عدد الطلبات', 'المورد', 'عدد الطلبات'],
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 6.4,
          ),
          cellStyle: const pw.TextStyle(fontSize: 6.1),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.center,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 1,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.3),
            1: const pw.FlexColumnWidth(0.7),
            2: const pw.FlexColumnWidth(2.3),
            3: const pw.FlexColumnWidth(0.7),
          },
        ),
      ],
    );
  }

  // دالة مساعدة لتنسيق مدة التأخير
  List<pw.Widget> _buildSplitNamedCountSections({
    required List<MapEntry<String, int>> customerRows,
    required List<MapEntry<String, int>> supplierRows,
  }) {
    const rowsPerSection = 18;
    final sectionCount = math.max(
      (customerRows.length / rowsPerSection).ceil(),
      (supplierRows.length / rowsPerSection).ceil(),
    );

    if (sectionCount == 0) {
      return [
        _buildSplitNamedCountSection(
          customerRows: const <MapEntry<String, int>>[],
          supplierRows: const <MapEntry<String, int>>[],
        ),
      ];
    }

    return List.generate(sectionCount, (index) {
      final customerStart = index * rowsPerSection;
      final supplierStart = index * rowsPerSection;
      final customerEnd = math.min(
        customerStart + rowsPerSection,
        customerRows.length,
      );
      final supplierEnd = math.min(
        supplierStart + rowsPerSection,
        supplierRows.length,
      );

      return pw.Padding(
        padding: pw.EdgeInsets.only(top: index == 0 ? 0 : 8),
        child: _buildSplitNamedCountSection(
          customerRows: customerStart < customerRows.length
              ? customerRows.sublist(customerStart, customerEnd)
              : const <MapEntry<String, int>>[],
          supplierRows: supplierStart < supplierRows.length
              ? supplierRows.sublist(supplierStart, supplierEnd)
              : const <MapEntry<String, int>>[],
          sectionIndex: index,
        ),
      );
    });
  }

  pw.Widget _buildSplitNamedCountSection({
    required List<MapEntry<String, int>> customerRows,
    required List<MapEntry<String, int>> supplierRows,
    int sectionIndex = 0,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildNamedCountTable(
            title: sectionIndex == 0
                ? 'العملاء وعدد طلباتهم للشهر'
                : 'العملاء وعدد طلباتهم للشهر (${sectionIndex + 1})',
            nameHeader: 'العميل',
            rows: customerRows,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildNamedCountTable(
            title: sectionIndex == 0
                ? 'الموردين وعدد طلباتهم للشهر'
                : 'الموردين وعدد طلباتهم للشهر (${sectionIndex + 1})',
            nameHeader: 'المورد',
            rows: supplierRows,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildNamedCountTable({
    required String title,
    required String nameHeader,
    required List<MapEntry<String, int>> rows,
  }) {
    final data = rows.isEmpty
        ? const [
            ['-', '0'],
          ]
        : rows.map((entry) => [entry.key, entry.value.toString()]).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 3),
        pw.Table.fromTextArray(
          headers: [nameHeader, 'عدد الطلبات'],
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 6.4,
          ),
          cellStyle: const pw.TextStyle(fontSize: 6.1),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.center,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 1,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.4),
            1: const pw.FlexColumnWidth(0.8),
          },
        ),
      ],
    );
  }

  pw.Widget _buildOrdersPdfHeader(pw.MemoryImage logoImage, User? user) {
    final companyName = _sanitizePdfText(
      user?.company ??
          '\u0634\u0631\u0643\u0629 \u0627\u0644\u0628\u062D\u064A\u0631\u0629 \u0627\u0644\u0639\u0631\u0628\u064A\u0629',
    );
    const unifiedNumber = '7011144750';
    final exportDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    final periodLabel = _sanitizePdfText(_exportPeriodLabel());
    final scopeLabel = _sanitizePdfText(_exportPdfScopeLabel());

    return pw.SizedBox(
      height: 60,
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.7),
        ),
        child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: 3,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 34,
                    height: 34,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                          maxLines: 1,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0648\u0637\u0646\u064A: $unifiedNumber  |  \u0646\u0648\u0639 \u0627\u0644\u062A\u0642\u0631\u064A\u0631: $scopeLabel',
                          style: const pw.TextStyle(fontSize: 6.2),
                          maxLines: 1,
                        ),
                        pw.Text(
                          '\u0627\u0644\u0641\u062A\u0631\u0629: $periodLabel  |  \u062A\u0627\u0631\u064A\u062E \u0627\u0644\u062A\u0635\u062F\u064A\u0631: $exportDate',
                          style: const pw.TextStyle(fontSize: 6.2),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  pw.Widget _buildOrdersPdfTable(List<Order> orders) {
    final headers = [
      '\u0631\u0642\u0645 \u0637\u0644\u0628 \u0627\u0644\u0645\u0648\u0631\u062F',
      '\u0627\u0633\u0645 \u0627\u0644\u0645\u0648\u0631\u062F',
      '\u0627\u0633\u0645 \u0627\u0644\u0639\u0645\u064A\u0644',
      '\u0627\u0633\u0645 \u0627\u0644\u0633\u0627\u0626\u0642',
      '\u0646\u0648\u0639 \u0627\u0644\u0648\u0642\u0648\u062F',
      '\u0627\u0644\u0643\u0645\u064A\u0629',
      '\u0627\u0644\u062A\u0627\u0631\u064A\u062E',
      '\u0627\u0644\u0645\u0644\u0627\u062D\u0638\u0627\u062A',
      '\u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645 \u0627\u0644\u0645\u0646\u0634\u0626',
      '\u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628',
    ];

    final data = orders.map((order) {
      final supplierOrderNumber = _sanitizePdfText(order.supplierOrderNumber);
      final supplierName = _sanitizePdfText(order.supplierName);
      final customerName = _sanitizePdfText(order.customer?.name);
      final driverName = _sanitizePdfText(
        order.driver?.name ?? order.driverName,
      );
      final fuelType = _sanitizePdfText(order.fuelType).isEmpty
          ? '-'
          : _sanitizePdfText(order.fuelType);
      final quantity = _formatPdfQuantity(order.quantity, order.unit);
      final dateText = DateFormat('yyyy/MM/dd').format(order.orderDate);
      final notes = _truncatePdfText(
        _sanitizePdfText(order.notes),
        maxChars: 80,
      );
      final createdBy = _sanitizePdfText(order.createdByName);
      final orderNumber = _sanitizePdfText(order.orderNumber);

      return [
        supplierOrderNumber,
        supplierName,
        customerName,
        driverName,
        fuelType,
        quantity,
        dateText,
        notes,
        createdBy,
        orderNumber,
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.2),
      cellStyle: const pw.TextStyle(fontSize: 5.6),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 1.2,
        vertical: 0.6,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(1.1),
        2: const pw.FlexColumnWidth(1.3),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(0.85),
        5: const pw.FlexColumnWidth(0.9),
        6: const pw.FlexColumnWidth(0.9),
        7: const pw.FlexColumnWidth(2.4),
        8: const pw.FlexColumnWidth(1.0),
        9: const pw.FlexColumnWidth(1.0),
      },
    );
  }

  pw.Widget _buildOrdersPdfFooter(pw.Context context) {
    return pw.SizedBox(
      height: 20,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey600, width: 0.6),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '\u062A\u0648\u0642\u064A\u0639 \u0627\u0644\u0645\u062F\u064A\u0631 \u0627\u0644\u0639\u0627\u0645: __________',
              style: const pw.TextStyle(fontSize: 5.8),
            ),
            pw.Text(
              '\u0635\u0641\u062D\u0629 ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 5.8),
            ),
            pw.Text(
              '\u062A\u0648\u0642\u064A\u0639 \u0631\u0626\u064A\u0633 \u0645\u062C\u0644\u0633 \u0627\u0644\u0625\u062F\u0627\u0631\u0629: __________',
              style: const pw.TextStyle(fontSize: 5.8),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDelayDuration(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      if (hours > 0) {
        return '${days}يوم ${hours}س';
      }
      return '${days}يوم';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '${hours}س ${minutes}د';
      }
      return '${hours}س';
    } else {
      final minutes = duration.inMinutes;
      return '${minutes}د';
    }
  }

  String _formatQuantityDisplay(OrderTimer timer) {
    final quantity = timer.quantity;
    if (quantity == null) return '--';
    final unit = timer.unit ?? '';
    final bool isWhole = quantity % 1 == 0;
    final formatted = isWhole
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  // دالة لتحديد لون التأخير
  Color _getDelayColor(Duration duration) {
    if (duration.inHours >= 48) {
      return AppColors.errorRed; // تأخير حرج (أكثر من يومين)
    } else if (duration.inHours >= 24) {
      return Colors.orange.shade700; // تأخير شديد (أكثر من يوم)
    } else if (duration.inHours >= 12) {
      return AppColors.warningOrange; // تأخير متوسط
    } else if (duration.inHours >= 6) {
      return Colors.yellow.shade700; // تأخير طفيف
    } else {
      return Colors.blue.shade600; // تأخير قليل
    }
  }

  // دالة لعرض إجراءات الطلبات المتأخرة
  void _showOverdueActions(
    BuildContext context,
    OrderTimer timer,
    Duration delayDuration,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // رأس مع تفاصيل التأخير
              ListTile(
                leading: Icon(
                  Icons.warning_amber,
                  color: _getDelayColor(delayDuration),
                ),
                title: Text(
                  'طلب #${timer.orderNumber} متأخر',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getDelayColor(delayDuration),
                  ),
                ),
                subtitle: Text(
                  'مدة التأخير: ${_formatDelayDuration(delayDuration)}',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),
              const Divider(),

              // الإجراءات حسب نوع الطلب
              if (timer.orderSource == 'مورد') ...[
                ListTile(
                  leading: const Icon(
                    Icons.phone,
                    color: AppColors.primaryBlue,
                  ),
                  title: const Text('الاتصال بالمورد'),
                  subtitle: Text('اتصال ب${timer.supplierName}'),
                  onTap: () {
                    Navigator.pop(context);
                    _contactSupplier(context, timer);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.successGreen,
                  ),
                  title: const Text('تحديث حالة الطلب'),
                  subtitle: const Text('تغيير الحالة إلى تم الإنشاء'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateSupplierOrderStatus(context, timer);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.merge_type, color: Colors.purple),
                  title: const Text('دمج مع طلب عميل'),
                  subtitle: const Text('بحث عن طلب عميل للدمج'),
                  onTap: () {
                    Navigator.pop(context);
                    _mergeWithCustomerOrder(context, timer);
                  },
                ),
              ],

              if (timer.orderSource == 'عميل') ...[
                ListTile(
                  leading: const Icon(
                    Icons.phone,
                    color: AppColors.primaryBlue,
                  ),
                  title: const Text('الاتصال بالعميل'),
                  subtitle: Text('اتصال ب${timer.customerName ?? "العميل"}'),
                  onTap: () {
                    Navigator.pop(context);
                    _contactCustomer(context, timer);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.assignment_ind,
                    color: AppColors.successGreen,
                  ),
                  title: const Text('تخصيص طلب مورد'),
                  subtitle: const Text('العثور على مورد لهذا الطلب'),
                  onTap: () {
                    Navigator.pop(context);
                    _assignToSupplier(context, timer);
                  },
                ),
              ],

              // إجراءات مشتركة
              ListTile(
                leading: const Icon(
                  Icons.notification_important,
                  color: AppColors.warningOrange,
                ),
                title: const Text('إرسال تنبيه عاجل'),
                onTap: () {
                  Navigator.pop(context);
                  _sendUrgentAlert(context, timer, delayDuration);
                },
              ),

              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.deepPurple),
                title: const Text('تأجيل الموعد'),
                subtitle: const Text('إعادة جدولة وقت التحميل'),
                onTap: () {
                  Navigator.pop(context);
                  _rescheduleOrder(context, timer);
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.cancel, color: AppColors.errorRed),
                title: const Text('إلغاء الطلب'),
                subtitle: const Text('في حالة عدم إمكانية التنفيذ'),
                onTap: () {
                  Navigator.pop(context);
                  _cancelOrder(context, timer);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // دالة للاتصال بالمورد
  void _contactSupplier(BuildContext context, OrderTimer timer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الاتصال بالمورد'),
        content: Text(
          'طلب المورد #${timer.orderNumber} متأخر\nهل تريد الاتصال بالمورد ${timer.supplierName}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري الاتصال ب${timer.supplierName}...'),
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
              // هنا يمكنك إضافة كود الاتصال الفعلي
            },
            child: const Text('اتصال'),
          ),
        ],
      ),
    );
  }

  // دالة للاتصال بالعميل
  void _contactCustomer(BuildContext context, OrderTimer timer) {
    final customerName = timer.customerName ?? 'العميل';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الاتصال بالعميل'),
        content: Text(
          'طلب العميل #${timer.orderNumber} متأخر\nهل تريد الاتصال بالعميل $customerName؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري الاتصال ب$customerName...'),
                  backgroundColor: AppColors.primaryBlue,
                ),
              );
            },
            child: const Text('اتصال'),
          ),
        ],
      ),
    );
  }

  // دالة لتحديث حالة طلب المورد
  void _updateSupplierOrderStatus(BuildContext context, OrderTimer timer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث حالة الطلب'),
        content: const Text(
          'هل تريد تغيير حالة الطلب من "في المستودع" إلى "تم الإنشاء"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم تحديث حالة الطلب #${timer.orderNumber}'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
              // هنا يمكنك إضافة كود تحديث الحالة الفعلي
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // دالة لدمج طلب مورد مع طلب عميل
  void _mergeWithCustomerOrder(BuildContext context, OrderTimer timer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دمج الطلب'),
        content: Text(
          'طلب المورد #${timer.orderNumber}\nهل تريد البحث عن طلب عميل للدمج؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                AppRoutes.mergeOrders,
                arguments: {'supplierOrderId': timer.orderId},
              );
            },
            child: const Text('بحث عن طلب عميل'),
          ),
        ],
      ),
    );
  }

  // دالة لتخصيص طلب عميل لمورد
  void _assignToSupplier(BuildContext context, OrderTimer timer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تخصيص طلب مورد'),
        content: Text(
          'طلب العميل #${timer.orderNumber} في انتظار التخصيص\nهل تريد البحث عن مورد مناسب؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                AppRoutes.suppliers,
                arguments: {'assignToOrder': timer.orderId},
              );
            },
            child: const Text('بحث عن مورد'),
          ),
        ],
      ),
    );
  }

  // دالة لإرسال تنبيه عاجل
  void _sendUrgentAlert(
    BuildContext context,
    OrderTimer timer,
    Duration delay,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال تنبيه عاجل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'طلب #${timer.orderNumber} متأخر لمدة ${_formatDelayDuration(delay)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'رسالة التنبيه',
                border: OutlineInputBorder(),
                hintText: 'أدخل رسالة التنبيه...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال التنبيه بنجاح'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  // دالة لإعادة جدولة الطلب
  void _rescheduleOrder(BuildContext context, OrderTimer timer) {
    showDialog(
      context: context,
      builder: (context) {
        DateTime selectedDate = timer.loadingDateTime;
        TimeOfDay selectedTime = TimeOfDay.fromDateTime(timer.loadingDateTime);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إعادة جدولة وقت التحميل'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // اختيار التاريخ
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('اختر التاريخ'),
                      subtitle: Text(
                        DateFormat('yyyy/MM/dd').format(selectedDate),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),

                    // اختيار الوقت
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('اختر الوقت'),
                      subtitle: Text(selectedTime.format(context)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم إعادة جدولة الطلب #${timer.orderNumber}',
                        ),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  },
                  child: const Text('تأكيد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _cancelOrder(BuildContext context, OrderTimer timer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: Text(
          'هل أنت متأكد من إلغاء الطلب #${timer.orderNumber}؟\nهذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إلغاء الطلب #${timer.orderNumber}'),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  String _getOrderSourceText(String orderSource) {
    switch (orderSource) {
      case 'مورد':
        return 'طلب مورد';
      case 'عميل':
        return 'طلب عميل';
      default:
        return orderSource;
    }
  }

  Color _getOrderSourceColor(String orderSource) {
    switch (orderSource) {
      case 'مورد':
        return Colors.blue;
      case 'عميل':
        return Colors.orange;
      case 'مدمج':
        return Colors.purple;
      default:
        return AppColors.primaryBlue;
    }
  }

  Color _getStatusBadgeColor(String status) {
    if (_isCanceledStatus(status)) {
      return AppColors.errorRed;
    }
    if (_isWarehouseStatus(status)) {
      return Colors.blue.shade700;
    }
    if (_isWaitingStatus(status)) {
      return Colors.grey.shade700;
    }
    if (_isMergedStatus(status)) {
      return Colors.amber.shade700;
    }
    if (_isCompletedStatus(status)) {
      return Colors.green;
    }
    return Colors.grey.shade600;
  }

  Color _statusFilterChipColor(String key) {
    switch (key) {
      case 'warehouse':
        return Colors.blue;
      case 'waiting':
        return Colors.grey.shade600;
      case 'merged':
        return Colors.amber.shade700;
      case 'completed':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  List<Widget> _buildDesktopSidebarFolders({
    required BuildContext context,
    required AuthProvider authProvider,
    required NotificationProvider notificationProvider,
    required bool canViewOrders,
    required bool canCreateSupplierOrder,
    required bool canCreateCustomerOrder,
    required bool canMergeOrders,
    required bool canViewCustomers,
    required bool canViewSuppliers,
    required bool canViewDrivers,
    required bool canAccessSettings,
    required bool canViewUsers,
  }) {
    final user = authProvider.user;
    final canViewTracking = user?.hasPermission('tracking_view') ?? false;
    final canViewFuelSales =
        user?.hasAnyPermission(['fuel_sales_view', 'fuel_sales_manage']) ??
        false;
    final canViewMarketing =
        user?.hasAnyPermission([
          'marketing_stations_view',
          'marketing_stations_manage',
        ]) ??
        false;
    final canViewQualification =
        user?.hasAnyPermission([
          'qualification_view',
          'qualification_manage',
        ]) ??
        false;
    final canViewPeriodicMaintenance =
        user?.hasAnyPermission([
          'maintenance_periodic_view',
          'maintenance_periodic_manage',
        ]) ??
        false;
    final canViewCustodyDocuments =
        user?.hasAnyPermission([
          'custody_documents_view',
          'custody_documents_manage',
        ]) ??
        false;
    final canViewActivities = user?.hasPermission('activities_view') ?? false;
    final canViewTasks =
        user?.hasAnyPermission(['tasks_view', 'tasks_view_all']) ?? false;
    final canViewInventory =
        user?.hasAnyPermission(['inventory_view', 'inventory_manage']) ?? false;
    final canViewContracts =
        user?.hasAnyPermission(['contracts_view', 'contracts_manage']) ?? false;
    final canViewHr = user?.hasAnyPermission(['hr_view', 'hr_manage']) ?? false;
    final canViewArchive =
        user?.hasAnyPermission(['archive_view', 'archive_manage']) ?? false;
    final canViewAuthDevices =
        user?.hasPermission('auth_devices_view') ?? false;
    final canViewBlockedDevices =
        user?.hasPermission('blocked_devices_view') ?? false;
    final canAccessStationMaintenance = [
      'owner',
      'admin',
      'manager',
      'supervisor',
      'maintenance',
      'maintenance_car_management',
      'maintenance_technician',
      'Maintenance_Technician',
    ].contains(authProvider.user?.role);
    final canAccessWhatsApp = WhatsAppService.canAccessForRole(user?.role);

    final canViewCirculars =
        authProvider.user?.role == 'owner' ||
        authProvider.user?.role == 'manager';
    final canViewMovementPage =
        authProvider.user?.role == 'owner' ||
        authProvider.user?.role == 'admin';
    final canViewSupplierPortal = [
      'owner',
      'admin',
      'manager',
      'movement',
    ].contains(authProvider.user?.role);
    final canSendDailyReport = authProvider.user != null;

    final ordersChildren = <Widget>[
      if (canViewOrders)
        _buildDesktopFolderItem(
          icon: Icons.list_alt,
          title: 'الطلبات',
          onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
        ),
      if (canCreateSupplierOrder)
        _buildDesktopFolderItem(
          icon: Icons.add_circle_outline,
          title: 'إنشاء طلب توريد',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.supplierOrderForm),
        ),
      if (canCreateCustomerOrder)
        _buildDesktopFolderItem(
          icon: Icons.add_circle_outline,
          title: 'إنشاء طلب عميل',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.customerOrderForm),
        ),
      if (canMergeOrders)
        _buildDesktopFolderItem(
          icon: Icons.add_circle_outline,
          title: 'دمج الطلبات',
          onTap: () => Navigator.pushNamed(context, AppRoutes.mergeOrders),
        ),
      if (canViewMovementPage)
        _buildDesktopFolderItem(
          icon: Icons.alt_route_outlined,
          title: 'سير الحركة',
          onTap: () => Navigator.pushNamed(context, AppRoutes.movement),
        ),
    ];

    final orderManagementChildren = <Widget>[
      if (canViewOrders)
        _buildDesktopFolderItem(
          icon: Icons.percent_outlined,
          title: 'إعدادات الضريبة',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.orderManagementTaxSettings,
          ),
        ),
      if (canViewOrders)
        _buildDesktopFolderItem(
          icon: Icons.folder_special_outlined,
          title: 'إدارة الطلبات',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.orderManagementDashboard),
        ),
      if (canViewOrders)
        _buildDesktopFolderItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'الخزينة',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.orderManagementTreasury),
        ),
      if (canViewCustomers)
        _buildDesktopFolderItem(
          icon: Icons.people_alt_outlined,
          title: 'حسابات العملاء',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.orderManagementCustomerAccounts,
          ),
        ),
      if (canViewCustomers)
        _buildDesktopFolderItem(
          icon: Icons.local_gas_station_outlined,
          title: 'تسعيرة الوقود للعملاء',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.orderManagementFuelPricing,
          ),
        ),
      if (canViewCustomers)
        _buildDesktopFolderItem(
          icon: Icons.price_change_outlined,
          title: 'تسعيرة النقل',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.orderManagementTransportPricing,
          ),
        ),
      if (canViewOrders)
        _buildDesktopFolderItem(
          icon: Icons.local_shipping_outlined,
          title: 'إدارة طلبات النقل',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.orderManagementTransportOrders,
          ),
        ),
      if (canViewSupplierPortal)
        _buildDesktopFolderItem(
          icon: Icons.add_business_rounded,
          title: 'بوابة الموردين',
          onTap: () => Navigator.pushNamed(context, AppRoutes.supplierPortal),
        ),
      if (canViewCustomers)
        _buildDesktopFolderItem(
          icon: Icons.bar_chart_outlined,
          title: 'تقرير اللترات للعملاء',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.orderManagementCustomerLitersReport,
          ),
        ),
    ];

    final partiesChildren = <Widget>[
      if (canViewCustomers)
        _buildDesktopFolderItem(
          icon: Icons.people_outline,
          title: 'العملاء',
          onTap: () => Navigator.pushNamed(context, AppRoutes.customers),
        ),
      if (canViewSuppliers)
        _buildDesktopFolderItem(
          icon: Icons.people,
          title: 'الموردين',
          onTap: () => Navigator.pushNamed(context, AppRoutes.suppliers),
        ),
      if (canViewDrivers)
        _buildDesktopFolderItem(
          icon: Icons.people_outline,
          title: 'السائقين',
          onTap: () => Navigator.pushNamed(context, AppRoutes.drivers),
        ),
      if (canViewTracking)
        _buildDesktopFolderItem(
          icon: Icons.directions_car_filled_outlined,
          title: 'السيارات',
          onTap: () => Navigator.pushNamed(context, AppRoutes.vehicles),
        ),
      if (canViewTracking)
        _buildDesktopFolderItem(
          icon: Icons.local_shipping_outlined,
          title: 'الصهاريج',
          onTap: () => Navigator.pushNamed(context, AppRoutes.tankers),
        ),
      // if (canViewDrivers)
      //   _buildDesktopFolderItem(
      //     icon: Icons.location_searching,
      //     title: 'المتابعة',
      //     onTap: () => Navigator.pushNamed(context, AppRoutes.tracking),
      //   ),
    ];
    final moChildren = <Widget>[
      if (canViewDrivers)
        _buildDesktopFolderItem(
          icon: Icons.location_searching,
          title: 'المتابعة',
          onTap: () => Navigator.pushNamed(context, AppRoutes.tracking),
        ),
    ];

    final stationsChildren = <Widget>[
      // if (isAdminOrOwner)
      //   _buildDesktopFolderItem(
      //     icon: Icons.local_gas_station,
      //     title: 'إدارة محطات الوقود',
      //     onTap: () => Navigator.pushNamed(context, AppRoutes.fuelStations),
      //   ),
      if (canViewFuelSales)
        _buildDesktopFolderItem(
          icon: Icons.local_gas_station,
          title: 'إدارة مبيعات محطات الوقود',
          onTap: () => Navigator.pushNamed(context, AppRoutes.mainHome),
        ),
      if (canViewMarketing)
        _buildDesktopFolderItem(
          icon: Icons.campaign_outlined,
          title: 'تسويق المحطات',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.marketingStations),
        ),
    ];

    final qualificationChildren = <Widget>[
      if (canViewQualification)
        _buildDesktopFolderItem(
          icon: Icons.verified_outlined,
          title: 'مواقع تحت الدراسة',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.qualificationDashboard),
        ),
      if (canViewQualification)
        _buildDesktopFolderItem(
          icon: Icons.map_outlined,
          title: 'خريطة المواقع',
          onTap: () => Navigator.pushNamed(context, AppRoutes.qualificationMap),
        ),
    ];

    final maintenanceChildren = <Widget>[
      if (canViewPeriodicMaintenance)
        _buildDesktopFolderItem(
          icon: Icons.directions_car,
          title: 'صيانة المركبات الدورية',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.maintenanceDashboard),
        ),
      if (canAccessStationMaintenance)
        _buildDesktopFolderItem(
          icon: Icons.home_repair_service_outlined,
          title: 'تطوير وصيانة المحطات',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.stationMaintenanceDashboard,
          ),
        ),
      if (canViewCustodyDocuments)
        _buildDesktopFolderItem(
          icon: Icons.assignment_turned_in,
          title: 'سندات العهدة',
          onTap: () => Navigator.pushNamed(context, AppRoutes.custodyDocuments),
        ),
      if (canViewActivities)
        _buildDesktopFolderItem(
          icon: Icons.local_activity,
          title: 'الأنشطة',
          onTap: () => Navigator.pushNamed(context, AppRoutes.activities),
        ),
    ];

    final tasksChildren = <Widget>[
      if (canViewTasks)
        _buildDesktopFolderItem(
          icon: Icons.task_alt,
          title: 'المهام',
          onTap: () => Navigator.pushNamed(context, AppRoutes.tasks),
        ),
    ];

    final inventoryChildren = <Widget>[
      if (canViewInventory)
        _buildDesktopFolderItem(
          icon: Icons.warehouse_outlined,
          title: 'لوحة المخزون',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.inventoryDashboard),
        ),
      if (canViewInventory)
        _buildDesktopFolderItem(
          icon: Icons.receipt_long_outlined,
          title: 'فاتورة مخزون جديدة',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.inventoryInvoiceForm),
        ),
      if (canViewInventory)
        _buildDesktopFolderItem(
          icon: Icons.inventory_2_outlined,
          title: 'عرض المخزون',
          onTap: () => Navigator.pushNamed(context, AppRoutes.inventoryStock),
        ),
    ];

    final circularsChildren = <Widget>[
      if (canViewCirculars)
        _buildDesktopFolderItem(
          icon: Icons.announcement_outlined,
          title: 'التعاميم',
          onTap: () => Navigator.pushNamed(context, AppRoutes.circulars),
        ),
      if (canSendDailyReport)
        _buildDesktopFolderItem(
          icon: Icons.description_outlined,
          title: 'تقرير يومي',
          onTap: () => Navigator.pushNamed(context, AppRoutes.dailyReports),
        ),
    ];

    final contractsChildren = <Widget>[
      if (canViewContracts)
        _buildDesktopFolderItem(
          icon: Icons.description_outlined,
          title: 'إدارة العقود',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.contractsManagement),
        ),
    ];

    final hrChildren = <Widget>[
      if (canViewHr)
        _buildDesktopFolderItem(
          icon: Icons.people_alt,
          title: 'إدارة الموارد البشرية',
          onTap: () => Navigator.pushNamed(context, AppRoutes.hrDashboard),
        ),
    ];

    final archiveChildren = <Widget>[
      if (canViewArchive)
        _buildDesktopFolderItem(
          icon: Icons.inventory_2_outlined,
          title: 'الأرشفة (وارد / صادر)',
          onTap: () => Navigator.pushNamed(context, AppRoutes.archiveDocuments),
        ),
    ];

    final accountChildren = <Widget>[
      _buildDesktopFolderItem(
        icon: Icons.notifications_outlined,
        title: 'الإشعارات',
        badge: notificationProvider.unreadCount,
        onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
      ),
      if (canAccessWhatsApp)
        _buildDesktopFolderItem(
          icon: Icons.chat_rounded,
          title: 'واتساب',
          onTap: _openWhatsAppFromSidebar,
          color: AppColors.successGreen,
        ),
      if (authProvider.user?.role == 'owner')
        _buildDesktopFolderItem(
          icon: Icons.pause_circle_outline_rounded,
          title: 'إشعار التوقف المؤقت',
          onTap: () => Navigator.pushNamed(context, AppRoutes.systemPause),
          color: AppColors.warningOrange,
        ),
      _buildDesktopFolderItem(
        icon: Icons.person,
        title: 'الملف الشخصي',
        onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
      ),
      if (canViewUsers)
        _buildDesktopFolderItem(
          icon: Icons.person_add,
          title: 'إدارة المستخدمين',
          onTap: () => Navigator.pushNamed(context, AppRoutes.userManagement),
        ),
      if (canViewAuthDevices)
        _buildDesktopFolderItem(
          icon: Icons.devices_outlined,
          title: 'إدارة الأجهزة',
          onTap: () => Navigator.pushNamed(context, AppRoutes.authDevices),
        ),
      if (canViewBlockedDevices)
        _buildDesktopFolderItem(
          icon: Icons.phonelink_lock_outlined,
          title: 'الأجهزة المحظورة',
          onTap: () => Navigator.pushNamed(context, AppRoutes.blockedDevices),
        ),
      if (canAccessSettings)
        _buildDesktopFolderItem(
          icon: Icons.settings,
          title: 'الإعدادات',
          onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
      _buildDesktopFolderItem(
        icon: Icons.logout,
        title: 'تسجيل خروج',
        onTap: () => _confirmLogout(context, authProvider),
        color: AppColors.errorRed,
      ),
    ];

    return [
      _buildDesktopNavItem(
        icon: Icons.dashboard,
        title: 'لوحة التحكم',
        isSelected: true,
        onTap: () {},
      ),
      const SizedBox(height: 12),

      if (ordersChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'orders',
          title: 'الطلبات',
          icon: Icons.folder,
          initiallyExpanded: true,
          children: ordersChildren,
        ),
      if (orderManagementChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'order_management',
          title: 'إدارة الطلبات',
          icon: Icons.folder_special_outlined,
          children: orderManagementChildren,
        ),
      if (partiesChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'parties',
          title: 'الأطراف',
          icon: Icons.folder,
          children: partiesChildren,
        ),
      if (moChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'tracking',
          title: 'المتابعة',
          icon: Icons.folder,
          children: moChildren,
        ),
      if (stationsChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'stations',
          title: 'المحطات',
          icon: Icons.folder,
          children: stationsChildren,
        ),
      if (qualificationChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'qualification',
          title: 'مواقع المحطات ',
          icon: Icons.verified_outlined,
          children: qualificationChildren,
        ),
      if (maintenanceChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'maintenance',
          title: 'التشغيل والصيانة',
          icon: Icons.folder,
          children: maintenanceChildren,
        ),
      if (inventoryChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'inventory',
          title: 'المخزون',
          icon: Icons.folder,
          children: inventoryChildren,
        ),
      if (circularsChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'circulars',
          title: 'التعاميم',
          icon: Icons.folder,
          children: circularsChildren,
        ),
      if (tasksChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'tasks',
          title: 'المهام',
          icon: Icons.folder,
          children: tasksChildren,
        ),
      if (contractsChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'contracts',
          title: 'العقود',
          icon: Icons.folder,
          children: contractsChildren,
        ),
      if (hrChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'hr',
          title: 'الموارد البشرية',
          icon: Icons.folder,
          children: hrChildren,
        ),
      if (archiveChildren.isNotEmpty)
        _buildDesktopFolderSection(
          folderKey: 'archive',
          title: 'الأرشفة',
          icon: Icons.folder_copy_outlined,
          children: archiveChildren,
        ),
      _buildDesktopFolderSection(
        folderKey: 'account',
        title: 'الحساب',
        icon: Icons.folder,
        children: accountChildren,
      ),
    ];
  }

  Widget _buildDesktopFolderSection({
    required String folderKey,
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final isExpanded = _desktopFolderExpanded[folderKey] ?? initiallyExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubicEmphasized,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? AppColors.primaryBlue.withOpacity(0.20)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpanded ? AppColors.primaryBlue : Colors.black)
                .withOpacity(isExpanded ? 0.08 : 0.03),
            blurRadius: isExpanded ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _desktopFolderExpanded[folderKey] = !isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeInOutCubicEmphasized,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? AppColors.primaryBlue.withOpacity(0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 660),
                        curve: Curves.easeInOutCubicEmphasized,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isExpanded
                              ? AppColors.primaryBlue
                              : Colors.black87,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: isExpanded ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOutCubicEmphasized,
                builder: (context, value, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  );
                },
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(children: children),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFolderItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int? badge,
    Color? color,
  }) {
    final itemColor = color ?? Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: itemColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: itemColor, fontWeight: FontWeight.w600),
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.errorRed,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    int? badge,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : Colors.grey.shade700,
                ),
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.errorRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopDateInfo() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, d MMMM y', 'ar');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          dateFormat.format(now),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          DateFormat('hh:mm a').format(now),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildDesktopWelcomeCard(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  authProvider.user?.name
                          .split(' ')
                          .map((n) => n.isNotEmpty ? n[0] : '')
                          .take(2)
                          .join('')
                          .toUpperCase() ??
                      'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً ${authProvider.user?.name ?? ''}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.user?.company ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authProvider.user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightGray,
                    ),
                  ),
                ],
              ),
            ),
            // Quick actions for desktop
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.supplierOrderForm);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('طلب مورد جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (authProvider.user?.hasAnyPermission(const [
                      'users_view',
                      'users_create',
                      'users_edit',
                      'users_delete',
                      'users_block',
                      'users_manage',
                    ]) ??
                    false) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.userManagement);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('إدارة المستخدمين'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.reports);
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('التقارير'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPerformanceCard(
    int totalOrders,
    int completedOrders,
    int waitingOrders,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص الأداء',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.5,
              children: [
                _buildDesktopPerformanceItem(
                  icon: Icons.timer_outlined,
                  title: 'متوسط وقت الاستجابة',
                  value: '2.5 ساعة',
                  color: AppColors.successGreen,
                ),
                _buildDesktopPerformanceItem(
                  icon: Icons.thumb_up_outlined,
                  title: 'معدل الإنجاز',
                  value:
                      '${totalOrders > 0 ? ((completedOrders / totalOrders) * 100).toStringAsFixed(1) : '0'}%',
                  color: AppColors.primaryBlue,
                ),
                _buildDesktopPerformanceItem(
                  icon: Icons.group_outlined,
                  title: 'الطلبات المنتظرة',
                  value: waitingOrders.toString(),
                  color: Colors.orange,
                ),
                _buildDesktopPerformanceItem(
                  icon: Icons.local_shipping_outlined,
                  title: 'طلبات جاهزة للتحميل',
                  value: '0', // يمكن تحديثها لاحقاً
                  color: AppColors.warningOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPerformanceItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // المكونات المشتركة للموبايل والكمبيوتر
  // ============================================

  Widget _buildWelcomeCard(
    BuildContext context,
    AuthProvider authProvider, {
    required int unreadNotifications,
    required VoidCallback onOpenSidebar,
  }) {
    final user = authProvider.user;
    final dateLabel = DateFormat('EEEE, d MMMM y', 'ar').format(DateTime.now());

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppColors.appBarGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _userInitials(user?.name),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحبًا ${user?.name ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onOpenSidebar,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.menu_open_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null && user.company.isNotEmpty)
                  Text(
                    user.company,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarkBlue,
                    ),
                  ),
                if (user != null && user.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),

                // Text(
                //   'واجهة الجوال أصبحت أخف، والتنقل الآن من القائمة الجانبية بدل شبكة الأيقونات.',
                //   style: TextStyle(
                //     height: 1.55,
                //     color: Colors.grey.shade700,
                //     fontSize: 12.5,
                //   ),
                // ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSidebarInfoChip(
                      icon: Icons.notifications_outlined,
                      label: unreadNotifications > 0
                          ? '$unreadNotifications إشعار غير مقروء'
                          : 'الإشعارات محدثة',
                      color: unreadNotifications > 0
                          ? AppColors.errorRed
                          : AppColors.successGreen,
                      onTap: unreadNotifications > 0
                          ? () => Navigator.pushNamed(
                              context,
                              AppRoutes.notifications,
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(
    BuildContext context,
    List<Order> allOrders,
    List<Order> filteredOrders,
    StatsCounts statsCounts,
  ) {
    final orders = filteredOrders;

    // بيانات الشموع اليابانية
    final candlestickData = _buildCandlestickData(orders);
    final dailySalesData = _buildDailySalesData(orders);

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    bool canShowStat(String key) => user?.hasPermission(key) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العنوان الرئيسي مع أيقونة
        Row(
          children: [
            Icon(Icons.insights, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              'الإحصائيات التفصيلية',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primaryBlue,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showExportOptions,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('تصدير'),
            ),
            if (candlestickData.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${candlestickData.length} فئة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _buildStatsFilterBar(context, allOrders),
        const SizedBox(height: 16),

        // 1. مخطط الشموع اليابانية المتحرك الرئيسي
        if (candlestickData.isNotEmpty)
          _buildAnimatedCandlestickChart(
            candlestickData.take(6).toList(),
            title: 'توزيع الطلبات حسب النوع والحالة',
          ),
        const SizedBox(height: 20),

        // 2. مخطط المبيعات اليومية المتحرك
        if (dailySalesData.isNotEmpty)
          Column(
            children: [
              _buildAnimatedCandlestickChart(
                dailySalesData,
                title: 'الطلبات خلال 7 أيام',
                isCompact: true,
              ),
              const SizedBox(height: 20),
            ],
          ),

        // 3. مخطط حالات الطلبات (مخطط دائري بديل)
        if (candlestickData.isNotEmpty)
          Column(
            children: [
              _buildStatusDistributionChart(orders),
              const SizedBox(height: 20),
            ],
          ),

        // 4. بطاقات الإحصائيات السريعة مع تحريك متتالي
        if (statsCounts.totalOrders > 0) ...[
          Text(
            'ملخص سريع',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildAnimatedStatsGrid(
            context: context,
            totalOrders: statsCounts.totalOrders,
            supplierPending: statsCounts.supplierPending,
            supplierMerged: statsCounts.supplierMerged,
            customerWaiting: statsCounts.customerWaiting,
            customerAssigned: statsCounts.customerAssigned,
            mergedOrders: statsCounts.mergedOrders,
            completedOrders: statsCounts.completedOrders,
            cancelledOrders: statsCounts.cancelledOrders,
            todayOrders: statsCounts.todayOrders,
            thisWeekOrders: statsCounts.thisWeekOrders,
            canShowStat: canShowStat,
          ),
          const SizedBox(height: 20),
          _buildPerformanceIndicators(
            totalOrders: statsCounts.totalOrders,
            completedOrders: statsCounts.completedOrders,
            todayOrders: statsCounts.todayOrders,
          ),
        ],
      ],
    );
  }

  String _statsVisualizationLabel(_StatsVisualizationMode mode) {
    switch (mode) {
      case _StatsVisualizationMode.grid:
        return 'شبكة';
      case _StatsVisualizationMode.candlestick:
        return 'شموع';
      case _StatsVisualizationMode.bar:
        return 'أعمدة';
      case _StatsVisualizationMode.line:
        return 'خط';
      case _StatsVisualizationMode.area:
        return 'مساحة';
      case _StatsVisualizationMode.pie:
        return 'دائري';
      case _StatsVisualizationMode.indicators:
        return 'مؤشرات';
    }
  }

  IconData _statsVisualizationIcon(_StatsVisualizationMode mode) {
    switch (mode) {
      case _StatsVisualizationMode.grid:
        return Icons.grid_view;
      case _StatsVisualizationMode.candlestick:
        return Icons.auto_graph;
      case _StatsVisualizationMode.bar:
        return Icons.bar_chart;
      case _StatsVisualizationMode.line:
        return Icons.show_chart;
      case _StatsVisualizationMode.area:
        return Icons.area_chart;
      case _StatsVisualizationMode.pie:
        return Icons.pie_chart;
      case _StatsVisualizationMode.indicators:
        return Icons.speed;
    }
  }

  void _changeStatsVisualization(int delta) {
    setState(() {
      final count = _statsVisualizationModes.length;
      _statsVisualizationIndex =
          (_statsVisualizationIndex + delta + count) % count;
    });
  }

  Widget _buildStatsVisualizationControls(BuildContext context) {
    final activeMode = _statsVisualizationModes[_statsVisualizationIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _statsVisualizationLabel(activeMode),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _statsVisualizationIcon(activeMode),
              size: 18,
              color: AppColors.primaryBlue,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _changeStatsVisualization(-1),
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('السابق'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _changeStatsVisualization(1),
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('التالي'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._statsVisualizationModes.map((mode) {
              final isSelected = mode == activeMode;
              final color = isSelected ? Colors.white : AppColors.primaryBlue;
              return ChoiceChip(
                selected: isSelected,
                selectedColor: AppColors.primaryBlue,
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.3)),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statsVisualizationIcon(mode), size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(_statsVisualizationLabel(mode)),
                  ],
                ),
                labelStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() {
                    _statsVisualizationIndex = _statsVisualizationModes.indexOf(
                      mode,
                    );
                  });
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsVisualizationBody({
    required BuildContext context,
    required List<Order> orders,
    required List<Map<String, dynamic>> candlestickData,
    required List<Map<String, dynamic>> dailySalesData,
    required List<Map<String, dynamic>> statusDistributionData,
    required StatsCounts statsCounts,
  }) {
    final mode = _statsVisualizationModes[_statsVisualizationIndex];

    Widget child;
    switch (mode) {
      case _StatsVisualizationMode.grid:
        child = _buildStatsGridVisualization(context, statusDistributionData);
        break;
      case _StatsVisualizationMode.candlestick:
        if (candlestickData.isEmpty) {
          child = _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
          break;
        }
        child = _buildCandlestickStyleBarChart(orders);
        break;
      case _StatsVisualizationMode.bar:
        child = _buildStatusBarChart(
          _buildStatusDistributionData(orders, includeZeros: true),
        );
        break;
      case _StatsVisualizationMode.line:
        child = _buildDailyLineChart(dailySalesData);
        break;
      case _StatsVisualizationMode.area:
        child = _buildDailyAreaChart(dailySalesData);
        break;
      case _StatsVisualizationMode.pie:
        child = _buildStatusPieChart(statusDistributionData);
        break;
      case _StatsVisualizationMode.indicators:
        child = _buildStatsIndicatorsPanel(statsCounts);
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -50) {
          _changeStatsVisualization(1);
        } else if (velocity > 50) {
          _changeStatsVisualization(-1);
        }
      },
      child: child,
    );
  }

  Widget _buildStatsChartShell({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _statsVisualizationIcon(
                  _statsVisualizationModes[_statsVisualizationIndex],
                ),
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatsGridVisualization(
    BuildContext context,
    List<Map<String, dynamic>> data,
  ) {
    if (data.isEmpty) {
      return _buildEmptyStatsVisual('لا توجد بيانات للحالة الحالية');
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200
        ? 4
        : width >= 900
        ? 3
        : 2;

    return _buildStatsChartShell(
      title: 'شبكة الحالات',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: data.map((item) {
          final color = item['color'] as Color;
          final label = item['label'] as String;
          final value = item['value'] as int;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.grid_on, color: color, size: 18),
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _buildStatusDistributionData(
    List<Order> orders, {
    bool includeZeros = false,
  }) {
    int warehouse = 0;
    int completed = 0;
    int canceled = 0;

    for (final order in orders) {
      final status = order.status;
      if (_isCanceledStatus(status)) {
        canceled++;
        continue;
      }
      if (_isCompletedStatus(status)) {
        completed++;
        continue;
      }
      if (_isWarehouseStatus(status)) {
        warehouse++;
        continue;
      }
    }

    final data = [
      {'label': 'في المستودع', 'value': warehouse, 'color': Colors.blue},
      {'label': 'طلبات مكتملة', 'value': completed, 'color': Colors.green},
      {'label': 'ملغي', 'value': canceled, 'color': AppColors.errorRed},
    ];

    final total = warehouse + completed + canceled;
    if (total == 0) {
      return includeZeros ? data : [];
    }

    int percent(int value) => ((value / total) * 100).round();

    final mapped = data.map((item) {
      final value = item['value'] as int;
      final pct = percent(value);
      return {...item, 'labelValue': value == 0 ? '' : '$value (${pct}%)'};
    }).toList();

    return includeZeros
        ? mapped
        : mapped.where((item) => (item['value'] as int) > 0).toList();
  }

  Widget _buildStatusBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
    }

    return _buildStatsChartShell(
      title: 'توزيع أنواع الطلبات - أعمدة',
      child: SizedBox(
        height: 260,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelIntersectAction: AxisLabelIntersectAction.rotate45,
            labelRotation: 45,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries>[
            ColumnSeries<Map<String, dynamic>, String>(
              dataSource: data,
              xValueMapper: (item, _) => (item['label'] ?? '').toString(),
              yValueMapper: (item, _) => item['value'] as int,
              pointColorMapper: (item, _) => item['color'] as Color,
              dataLabelMapper: (item, _) =>
                  (item['labelValue'] ?? '').toString(),
              borderColor: Colors.black.withOpacity(0.25),
              borderWidth: 1,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              width: 0.45,
              spacing: 0.35,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.middle,
                textStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandlestickStyleBarChart(
    List<Order> orders, {
    bool showShell = true,
  }) {
    final data = _buildOrderTypeDistributionData(orders);
    if (data.isEmpty) {
      return _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
    }

    final maxValue = data
        .map<int>((item) => item['value'] as int)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 1.0 : (maxValue * 1.2).toDouble();

    final chart = SizedBox(
      height: 260,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        plotAreaBackgroundColor: Colors.grey.shade200,
        primaryXAxis: CategoryAxis(
          labelIntersectAction: AxisLabelIntersectAction.rotate45,
          labelRotation: 45,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDarkBlue,
          ),
        ),
        primaryYAxis: NumericAxis(
          maximum: maxY,
          axisLine: const AxisLine(width: 0),
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.grey.shade300,
          ),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          ColumnSeries<Map<String, dynamic>, String>(
            dataSource: data,
            xValueMapper: (item, _) => (item['label'] ?? '').toString(),
            yValueMapper: (item, _) => item['value'] as int,
            pointColorMapper: (item, _) => item['color'] as Color,
            dataLabelMapper: (item, _) => (item['labelValue'] ?? '').toString(),
            borderColor: Colors.black.withOpacity(0.25),
            borderWidth: 1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            width: 0.45,
            spacing: 0.35,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.middle,
              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showShell) {
      return chart;
    }

    return _buildStatsChartShell(
      title: 'توزيع أنواع الطلبات - أعمدة',
      child: chart,
    );
  }

  List<Map<String, dynamic>> _buildOrderTypeDistributionData(
    List<Order> orders,
  ) {
    if (orders.isEmpty) return [];

    int completed = 0;
    int transport = 0;
    int purchase = 0;
    int warehouse = 0;
    int canceled = 0;

    for (final order in orders) {
      final status = order.status;
      if (_isCanceledStatus(status)) {
        canceled++;
        continue;
      }
      if (_isCompletedStatus(status)) {
        if (order.isCustomerOrder || order.isMergedOrder) {
          final requestTypeCategory = _dashboardRequestTypeCategory(order);
          if (requestTypeCategory == 'transport') {
            transport++;
            continue;
          }
          if (requestTypeCategory == 'purchase') {
            purchase++;
            continue;
          }
        }
        continue;
      }

      if (_isWarehouseStatus(status)) {
        warehouse++;
        continue;
      }
    }

    completed = transport + purchase;
    final total = completed + transport + purchase + warehouse + canceled;
    if (total == 0) return [];

    int percent(int value) => ((value / total) * 100).round();

    final data =
        [
          {
            'label': 'الطلبات المكتملة',
            'value': completed,
            'color': AppColors.successGreen,
          },
          {'label': 'طلبات نقل', 'value': transport, 'color': Colors.orange},
          {'label': 'طلبات الشراء', 'value': purchase, 'color': Colors.indigo},
          {
            'label': 'في المستودع',
            'value': warehouse,
            'color': Colors.blueGrey,
          },
          {'label': 'ملغي', 'value': canceled, 'color': AppColors.errorRed},
        ].map((item) {
          final value = item['value'] as int;
          final pct = percent(value);
          return {...item, 'labelValue': value == 0 ? '' : '$pct% · $value'};
        }).toList();

    return data;
  }

  Widget _buildDailyLineChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
    }

    return _buildStatsChartShell(
      title: 'الطلبات خلال 7 أيام - خطي',
      child: SizedBox(
        height: 240,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelRotation: 45,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries>[
            LineSeries<Map<String, dynamic>, String>(
              dataSource: data,
              xValueMapper: (item, _) => item['label'] as String,
              yValueMapper: (item, _) => item['value'] as int,
              pointColorMapper: (item, _) => item['color'] as Color,
              markerSettings: const MarkerSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyAreaChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
    }

    return _buildStatsChartShell(
      title: 'الطلبات خلال 7 أيام - مساحة',
      child: SizedBox(
        height: 240,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelRotation: 45,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries>[
            AreaSeries<Map<String, dynamic>, String>(
              dataSource: data,
              xValueMapper: (item, _) => item['label'] as String,
              yValueMapper: (item, _) => item['value'] as int,
              pointColorMapper: (item, _) => item['color'] as Color,
              borderColor: AppColors.primaryBlue,
              borderWidth: 2,
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withOpacity(0.4),
                  AppColors.primaryBlue.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPieChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
    }

    return _buildStatsChartShell(
      title: 'توزيع الحالات - دائري',
      child: SizedBox(
        height: 260,
        child: SfCircularChart(
          legend: const Legend(
            isVisible: true,
            overflowMode: LegendItemOverflowMode.wrap,
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CircularSeries>[
            DoughnutSeries<Map<String, dynamic>, String>(
              dataSource: data,
              xValueMapper: (item, _) => item['label'] as String,
              yValueMapper: (item, _) => item['value'] as int,
              pointColorMapper: (item, _) => item['color'] as Color,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
              innerRadius: '55%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsIndicatorsPanel(StatsCounts statsCounts) {
    if (statsCounts.totalOrders == 0) {
      return _buildEmptyStatsVisual('لا توجد بيانات كافية للعرض');
    }

    final completionRate = statsCounts.totalOrders > 0
        ? statsCounts.completedOrders / statsCounts.totalOrders
        : 0.0;
    final todayRate = statsCounts.totalOrders > 0
        ? statsCounts.todayOrders / statsCounts.totalOrders
        : 0.0;
    final cancelRate = statsCounts.totalOrders > 0
        ? statsCounts.cancelledOrders / statsCounts.totalOrders
        : 0.0;

    return _buildStatsChartShell(
      title: 'مؤشرات مختصرة',
      child: Row(
        children: [
          Expanded(
            child: _buildCircularIndicator(
              label: 'الإنجاز',
              value: completionRate,
              color: AppColors.successGreen,
              display: '${(completionRate * 100).toStringAsFixed(1)}%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCircularIndicator(
              label: 'اليوم',
              value: todayRate,
              color: AppColors.primaryBlue,
              display: statsCounts.todayOrders.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildCircularIndicator(
              label: 'الإلغاء',
              value: cancelRate,
              color: AppColors.errorRed,
              display: '${(cancelRate * 100).toStringAsFixed(1)}%',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIndicator({
    required String label,
    required double value,
    required Color color,
    required String display,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 70,
            width: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStatsVisual(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCandlestickChart(
    List<Map<String, dynamic>> data, {
    required String title,
    bool isCompact = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: Opacity(opacity: value, child: child),
          ),
        );
      },
      child: CandlestickStatChart(
        statsData: data,
        title: title,
        showGrid: true,
        isCompact: isCompact,
      ),
    );
  }

  Widget _buildAnimatedStatsGrid({
    required BuildContext context,
    required int totalOrders,
    required int supplierPending,
    required int supplierMerged,
    required int customerWaiting,
    required int customerAssigned,
    required int mergedOrders,
    required int completedOrders,
    required int cancelledOrders,
    required int todayOrders,
    required int thisWeekOrders,
    required bool Function(String) canShowStat,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(context);

    // 🔹 تحكم أدق في طول الكرت
    final childAspectRatio = screenWidth >= 1400
        ? 1.7
        : screenWidth >= 1100
        ? 1.55
        : screenWidth >= 900
        ? 1.35
        : screenWidth >= 700
        ? 1.15
        : 0.85; // موبايل أطول لتفادي الـ overflow

    final statsCards = <Widget>[];

    if (canShowStat('stats_total_orders')) {
      statsCards.add(
        _buildAnimatedStatCard(
          index: statsCards.length,
          title: 'إجمالي الطلبات',
          value: totalOrders.toString(),
          icon: Icons.bar_chart,
          color: AppColors.primaryBlue,
          trend: (totalOrders > 0 && thisWeekOrders > 0)
              ? '↑ ${((thisWeekOrders / totalOrders) * 100).toStringAsFixed(1)}%'
              : '',
          percentage: totalOrders > 0 ? 100 : 0,
        ),
      );
    }

    if (canShowStat('stats_today_orders')) {
      statsCards.add(
        _buildAnimatedStatCard(
          index: statsCards.length,
          title: 'طلبات اليوم',
          value: todayOrders.toString(),
          icon: Icons.today,
          color: AppColors.successGreen,
          trend: todayOrders > 0 ? '🔥 نشط' : '',
          percentage: (todayOrders / 50 * 100).clamp(0, 100),
        ),
      );
    }

    if (canShowStat('stats_completed_orders')) {
      final percent = totalOrders > 0
          ? (completedOrders / totalOrders * 100)
          : 0.0;

      statsCards.add(
        _buildAnimatedStatCard(
          index: statsCards.length,
          title: 'مكتملة',
          value: completedOrders.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
          percentage: percent,
          subValue: '${percent.toStringAsFixed(1)}%',
        ),
      );
    }

    if (canShowStat('stats_cancelled_orders')) {
      statsCards.add(
        _buildAnimatedStatCard(
          index: statsCards.length,
          title: 'ملغاة',
          value: cancelledOrders.toString(),
          icon: Icons.cancel,
          color: AppColors.errorRed,
          trend: cancelledOrders > 0 ? '⚠️ انتباه' : '',
          percentage: totalOrders > 0
              ? (cancelledOrders / totalOrders * 100)
              : 0,
        ),
      );
    }

    if (canShowStat('stats_supplier_pending')) {
      final totalSupplier = supplierPending + supplierMerged;
      final percent = totalSupplier > 0
          ? (supplierMerged / totalSupplier * 100)
          : 0.0;

      statsCards.add(
        _buildAnimatedStatCard(
          index: statsCards.length,
          title: 'طلبات مورد',
          value: supplierPending.toString(),
          icon: Icons.store,
          color: Colors.blue,
          subValue: 'مدمجة: $supplierMerged',
          percentage: percent,
        ),
      );
    }

    if (canShowStat('stats_customer_waiting')) {
      final totalCustomer = customerWaiting + customerAssigned;
      final percent = totalCustomer > 0
          ? (customerAssigned / totalCustomer * 100)
          : 0.0;

      statsCards.add(
        _buildAnimatedStatCard(
          index: statsCards.length,
          title: 'طلبات عميل',
          value: customerWaiting.toString(),
          icon: Icons.person,
          color: Colors.orange,
          subValue: 'مخصصة: $customerAssigned',
          percentage: percent,
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statsCards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio, // ✅ أطول وأنعم
      ),
      itemBuilder: (context, index) => statsCards[index],
    );
  }

  // دالة لإنشاء بطاقة إحصائية متحركة
  Widget _buildAnimatedStatCard({
    required int index,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String trend = '',
    String subValue = '',
    double percentage = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.05), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header with icon and trend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (trend.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        trend,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),

              // Value and title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                      ).createShader(bounds);
                    },
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Sub-value and progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subValue.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subValue,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (percentage > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 6,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${percentage.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة لإنشاء مخطط توزيع الحالات
  Widget _buildStatusDistributionChart(List<Order> orders) {
    final statusCounts = {
      'في المستودع': orders.where((o) => o.status == 'في المستودع').length,
      'في انتظار': orders.where((o) => o.status == 'في انتظار التخصيص').length,
      'مدمج': orders.where((o) => o.status.contains('تم الدمج')).length,
      'في الطريق': orders.where((o) => o.status == 'في الطريق').length,
      'تم التسليم': orders.where((o) => o.status == 'تم التسليم').length,
      'ملغى': orders.where((o) => o.status.contains('ملغ')).length,
    };

    final chartData = statusCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
          Color color;
          switch (entry.key) {
            case 'في المستودع':
              color = Colors.blue;
              break;
            case 'في انتظار':
              color = Colors.orange;
              break;
            case 'مدمج':
              color = Colors.purple;
              break;
            case 'في الطريق':
              color = Colors.indigo;
              break;
            case 'تم التسليم':
              color = Colors.green;
              break;
            case 'ملغى':
              color = AppColors.errorRed;
              break;
            default:
              color = Colors.grey;
          }

          return {'label': entry.key, 'value': entry.value, 'color': color};
        })
        .toList();

    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuad,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: CandlestickStatChart(
        statsData: chartData,
        title: 'توزيع الحالات',
        showGrid: false,
        isCompact: true,
      ),
    );
  }

  // دالة لإنشاء مؤشرات الأداء
  Widget _buildPerformanceIndicators({
    required int totalOrders,
    required int completedOrders,
    required int todayOrders,
  }) {
    final completionRate = totalOrders > 0
        ? (completedOrders / totalOrders * 100)
        : 0;
    final dailyAverage = todayOrders.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                Icons.analytics_outlined,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'مؤشرات الأداء',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDarkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceIndicator(
                  label: 'معدل الإنجاز',
                  value: '${completionRate.toStringAsFixed(1)}%',
                  color: completionRate >= 80
                      ? AppColors.successGreen
                      : completionRate >= 50
                      ? AppColors.warningOrange
                      : AppColors.errorRed,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceIndicator(
                  label: 'متوسط اليوم',
                  value: dailyAverage.toStringAsFixed(1),
                  color: dailyAverage >= 10
                      ? AppColors.successGreen
                      : dailyAverage >= 5
                      ? AppColors.warningOrange
                      : AppColors.errorRed,
                  icon: Icons.speed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لمؤشر الأداء
  Widget _buildPerformanceIndicator({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavigation(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final canViewOrders = user?.hasPermission('orders_view') ?? false;
    final canCreateSupplierOrder =
        user?.hasPermission('orders_create_supplier') ?? false;
    final canCreateCustomerOrder =
        user?.hasPermission('orders_create_customer') ?? false;
    final canMergeOrders = user?.hasPermission('orders_merge') ?? false;
    final canViewCustomers = user?.hasPermission('customers_view') ?? false;
    final canViewSuppliers = user?.hasPermission('suppliers_view') ?? false;
    final canViewDrivers = user?.hasPermission('drivers_view') ?? false;
    final canViewTracking = user?.hasPermission('tracking_view') ?? false;
    final canAccessSettings = user?.hasPermission('settings_access') ?? false;
    final canViewInventory =
        user?.hasAnyPermission(const ['inventory_view', 'inventory_manage']) ??
        false;
    final canViewUsers =
        user?.hasAnyPermission(const [
          'users_view',
          'users_create',
          'users_edit',
          'users_delete',
          'users_block',
          'users_manage',
        ]) ??
        false;
    final canViewTasks =
        user?.hasAnyPermission(const ['tasks_view', 'tasks_view_all']) ?? false;
    final canViewPeriodicMaintenance =
        user?.hasAnyPermission(const [
          'maintenance_periodic_view',
          'maintenance_periodic_manage',
        ]) ??
        false;
    final canViewFuelSales =
        user?.hasAnyPermission(const [
          'fuel_sales_view',
          'fuel_sales_manage',
        ]) ??
        false;
    final canViewMarketing =
        user?.hasAnyPermission(const [
          'marketing_stations_view',
          'marketing_stations_manage',
        ]) ??
        false;
    final canViewQualification =
        user?.hasAnyPermission(const [
          'qualification_view',
          'qualification_manage',
        ]) ??
        false;
    final canViewHr =
        user?.hasAnyPermission(const ['hr_view', 'hr_manage']) ?? false;
    final canViewCustodyDocuments =
        user?.hasAnyPermission(const [
          'custody_documents_view',
          'custody_documents_manage',
        ]) ??
        false;
    final canViewActivities = user?.hasPermission('activities_view') ?? false;
    final canViewBlockedDevices =
        user?.hasPermission('blocked_devices_view') ?? false;
    final canViewAuthDevices =
        user?.hasPermission('auth_devices_view') ?? false;
    final canViewReports = user?.hasPermission('reports_view') ?? false;
    final canViewMovementPage = user?.role == 'owner' || user?.role == 'admin';
    final canAccessStationMaintenance = [
      'owner',
      'admin',
      'manager',
      'supervisor',
      'maintenance',
      'maintenance_car_management',
      'maintenance_technician',
      'Maintenance_Technician',
    ].contains(authProvider.user?.role);
    bool canSeeStat(String key) => user?.hasPermission(key) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التنقل السريع',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: _getCrossAxisCount(context),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.1 : 1.2,
          children: [
            if (canViewOrders)
              _navItem(
                icon: Icons.list_alt,
                title: 'الطلبات',
                color: AppColors.primaryBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
              ),
            if (canViewInventory)
              _navItem(
                icon: Icons.warehouse_outlined,
                title: 'المخزون',
                color: AppColors.primaryDarkBlue,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.inventoryDashboard),
              ),
            if (canCreateSupplierOrder)
              _navItem(
                icon: Icons.add_circle_outline,
                title: 'إنشاء طلب مورد',
                color: AppColors.successGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.supplierOrderForm),
              ),
            if (canCreateCustomerOrder)
              _navItem(
                icon: Icons.add_circle_outline,
                title: 'إنشاء طلب عميل',
                color: AppColors.successGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.customerOrderForm),
              ),
            if (canMergeOrders)
              _navItem(
                icon: Icons.merge_outlined,
                title: 'دمج الطلبات',
                color: AppColors.successGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.mergeOrders),
              ),
            if (canViewMovementPage)
              _navItem(
                icon: Icons.alt_route_outlined,
                title: 'الحركة',
                color: AppColors.appBarBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.movement),
              ),
            if (canViewCustomers)
              _navItem(
                icon: Icons.people_outline,
                title: 'العملاء',
                color: AppColors.secondaryTeal,
                onTap: () => Navigator.pushNamed(context, AppRoutes.customers),
              ),
            if (canViewSuppliers)
              _navItem(
                icon: Icons.people_outline,
                title: 'الموردين',
                color: AppColors.primaryBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.suppliers),
              ),
            if (canViewDrivers)
              _navItem(
                icon: Icons.people_outline,
                title: 'السائقين',
                color: AppColors.attendanceLate,
                onTap: () => Navigator.pushNamed(context, AppRoutes.drivers),
              ),
            if (canViewTracking)
              _navItem(
                icon: Icons.directions_car_filled_outlined,
                title: 'السيارات',
                color: AppColors.primaryBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.vehicles),
              ),
            if (canViewTracking)
              _navItem(
                icon: Icons.local_shipping_outlined,
                title: 'الصهاريج',
                color: AppColors.infoBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.tankers),
              ),
            if (canViewTracking)
              _navItem(
                icon: Icons.location_searching,
                title: 'المتابعة',
                color: AppColors.infoBlue,
                onTap: () => Navigator.pushNamed(context, AppRoutes.tracking),
              ),
            if (canViewPeriodicMaintenance)
              _navItem(
                icon: Icons.directions_car,
                title: 'صيانة المركبات الدورية',
                color: AppColors.warningOrange,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.maintenanceDashboard,
                ),
              ),
            if (canViewTasks)
              _navItem(
                icon: Icons.directions_car,
                title: 'المهام',
                color: AppColors.warningOrange,
                onTap: () => Navigator.pushNamed(context, AppRoutes.tasks),
              ),
            if (canAccessStationMaintenance)
              _navItem(
                icon: Icons.home_repair_service_outlined,
                title: 'تتبع وصيانة المحطات',
                color: AppColors.primaryBlue,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.stationMaintenanceDashboard,
                ),
              ),
            // if (authProvider.user?.role == 'owner' ||
            //     authProvider.user?.role == 'admin')
            //   _navItem(
            //     icon: Icons.local_gas_station,
            //     title: 'إدارة محطات الوقود',
            //     color: AppColors.advanceInstallment,
            //     onTap: () =>
            //         Navigator.pushNamed(context, AppRoutes.fuelStations),
            //   ),
            if (canViewFuelSales)
              _navItem(
                icon: Icons.local_gas_station,
                title: 'إدارة مبيعات محطات الوقود',
                color: AppColors.successGreen,
                onTap: () => Navigator.pushNamed(context, AppRoutes.mainHome),
              ),
            if (canViewMarketing)
              _navItem(
                icon: Icons.campaign_outlined,
                title: 'تسويق المحطات',
                color: AppColors.secondaryTeal,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.marketingStations),
              ),
            if (canViewQualification)
              _navItem(
                icon: Icons.verified_outlined,
                title: 'مواقع المحطات ',
                color: AppColors.primaryBlue,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.qualificationDashboard,
                ),
              ),
            if (canViewHr)
              _navItem(
                icon: Icons.people,
                title: 'إدارة الموارد البشرية',
                color: AppColors.successGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.hrDashboard),
              ),
            if (canViewCustodyDocuments)
              _navItem(
                icon: Icons.assignment_turned_in,
                title: 'سندات العهدة',
                color: AppColors.successGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.custodyDocuments),
              ),
            if (canViewActivities)
              _navItem(
                icon: Icons.local_activity,
                title: 'الأنشطة',
                color: AppColors.warningOrange,
                onTap: () => Navigator.pushNamed(context, AppRoutes.activities),
              ),

            _navItem(
              icon: Icons.notifications_outlined,
              title: 'الإشعارات',
              color: AppColors.accentBlue,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            ),
            _navItem(
              icon: Icons.person,
              title: 'الملف الشخصي',
              color: AppColors.infoBlue,
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            ),
            _navItem(
              icon: Icons.logout,
              title: 'تسجيل خروج',
              color: AppColors.errorRed,
              onTap: () => _confirmLogout(context, authProvider),
            ),
            if (canAccessSettings)
              _navItem(
                icon: Icons.settings,
                title: 'الإعدادات',
                color: AppColors.mediumGray,
                onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
              ),
            if (canViewUsers)
              _navItem(
                icon: Icons.person_add,
                title: 'إدارة المستخدمين',
                color: AppColors.successGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.userManagement),
              ),
            if (canViewBlockedDevices)
              _navItem(
                icon: Icons.phonelink_lock_outlined,
                title: 'الأجهزة المحظورة',
                color: AppColors.errorRed,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.blockedDevices),
              ),
            if (canViewAuthDevices)
              _navItem(
                icon: Icons.devices_outlined,
                title: 'إدارة الأجهزة',
                color: AppColors.primaryBlue,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.authDevices),
              ),
            if (canViewReports)
              _navItem(
                icon: Icons.insert_chart_outlined,
                title: 'التقارير',
                color: AppColors.primaryDarkBlue,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.reports);
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<T?> _runBackupOperation<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() action,
  }) async {
    if (_backupBusy) return null;

    setState(() {
      _backupBusy = true;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );

    try {
      final result = await action();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return result;
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      return text.replaceFirst('Exception:', '').trim();
    }
    return text;
  }

  Future<void> _showBackupDialog(BuildContext context) async {
    if (_backupBusy) return;

    final role = Provider.of<AuthProvider>(context, listen: false).role;
    final canImport = role == 'owner' || role == 'admin';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('النسخ الاحتياطي'),
        content: const Text(
          'يتم إنشاء نسخة احتياطية تلقائياً كل 12 ساعة (حسب إعدادات الخادم)، ويتم إرسالها لبريد المالك. '
          'يمكنك تحميل نسخة الآن أو استيراد نسخة لاسترجاع البيانات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_downloadBackupNow(context));
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('تحميل'),
          ),
          if (canImport)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_importBackupNow(context));
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('استيراد'),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadBackupNow(BuildContext context) async {
    try {
      final savedPath = await _runBackupOperation<String?>(
        context,
        message: 'جاري إنشاء/تحميل النسخة الاحتياطية...',
        action: () => BackupService.downloadLatestBackup(fresh: true),
      );

      if (!mounted || savedPath == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'تم تحميل النسخة الاحتياطية.'
                : 'تم حفظ النسخة: $savedPath',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final hint = kIsWeb && error.toString().contains('Failed to fetch')
          ? ' (على الويب: تأكد أن رابط الـ API صحيح ومتاح: لو السيرفر https استخدم https، ولو صفحة https ما ينفع API http)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل النسخ الاحتياطي: ${_friendlyError(error)}$hint'),
        ),
      );
    }
  }

  Future<void> _importBackupNow(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استيراد نسخة احتياطية'),
        content: const Text(
          'الاستيراد سيستبدل البيانات الحالية على قاعدة البيانات (حذف ثم استيراد). هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gz', 'ndjson', 'json'],
      withData: kIsWeb,
    );

    if (pickerResult == null || pickerResult.files.isEmpty) return;

    final file = pickerResult.files.first;

    try {
      final response = await _runBackupOperation<Map<String, dynamic>>(
        context,
        message: 'جاري استيراد النسخة الاحتياطية...',
        action: () =>
            BackupService.restoreFromBackup(file: file, dropExisting: true),
      );

      if (!mounted || response == null) return;

      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final totalInserted = data['totalInserted'];
      final insertedText = totalInserted == null
          ? ''
          : ' (تم إدخال $totalInserted سجل)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الاستيراد بنجاح$insertedText. يفضل إعادة تشغيل التطبيق.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاستيراد: ${_friendlyError(error)}')),
      );
    }
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل ترغب في تسجيل الخروج الآن؟'),
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
            child: const Text('تسجيل خروج'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await authProvider.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.front,
      (route) => false,
    );
  }

  Widget _buildChartSection(
    BuildContext context,
    List<Map<String, dynamic>> statusData,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ✅ مرن
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'توزيع الطلبات حسب الحالة',
                    softWrap: true,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.pie_chart_outline,
                  color: AppColors.primaryBlue,
                  size: 26,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// =============================
            /// 📊 Chart (مرن)
            /// =============================
            LayoutBuilder(
              builder: (context, constraints) {
                return AspectRatio(
                  aspectRatio: constraints.maxWidth < 500 ? 1 : 1.3,
                  child: SfCircularChart(
                    margin: const EdgeInsets.all(8),

                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap,
                      alignment: ChartAlignment.center,
                      itemPadding: 8,
                      textStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                      ),
                    ),

                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      format: 'point.x : point.y طلب',
                    ),

                    series: <CircularSeries>[
                      DoughnutSeries<Map<String, dynamic>, String>(
                        dataSource: statusData,
                        xValueMapper: (data, _) => data['status'] as String,
                        yValueMapper: (data, _) => data['count'] as int,
                        pointColorMapper: (data, _) => data['color'] as Color,

                        radius: '75%',
                        innerRadius: '45%',

                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          labelPosition: ChartDataLabelPosition.outside,
                          textStyle: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                          ),
                          connectorLineSettings: ConnectorLineSettings(
                            type: ConnectorType.curve,
                            length: '12%',
                          ),
                        ),

                        animationDuration: 900,
                        enableTooltip: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrdersSection(BuildContext context, List orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الطلبات الحديثة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.orders);
              },
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text('عرض الكل'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          EmptyOrdersWidget(
            onCreateOrder: () {
              Navigator.pushNamed(context, AppRoutes.supplierOrderForm);
            },
          )
        else if (orders.length < 5)
          Column(
            children: [
              RecentOrdersWidget(orders: orders as List<Order>),
              if (orders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: AppColors.primaryBlue.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد طلبات حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ بإنشاء طلبك الأول',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.lightGray,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.supplierOrderForm,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إنشاء طلب جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )
        else
          RecentOrdersWidget(orders: List<Order>.from(orders.take(5))),
      ],
    );
  }

  Widget _buildPerformanceCard(
    int totalOrders,
    int completedOrders,
    int readyOrders,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص الأداء',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    icon: Icons.timer_outlined,
                    title: 'متوسط وقت الاستجابة',
                    value: '2.5 ساعة',
                    color: AppColors.successGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPerformanceItem(
                    icon: Icons.thumb_up_outlined,
                    title: 'معدل الإنجاز',
                    value:
                        '${totalOrders > 0 ? ((completedOrders / totalOrders) * 100).toStringAsFixed(1) : '0'}%',
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    icon: Icons.group_outlined,
                    title: 'العملاء النشطين',
                    value: '12', // يمكن تحديثها لاحقاً
                    color: AppColors.secondaryTeal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPerformanceItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'طلبات جاهزة للتحميل',
                    value: readyOrders.toString(),
                    color: AppColors.warningOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: AppColors.mediumGray, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownCard extends StatelessWidget {
  final OrderTimer timer;
  final VoidCallback? onTap;
  final bool isDesktop;

  const CountdownCard({
    super.key,
    required this.timer,
    this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgentArrival =
        timer.remainingTimeToArrival <= const Duration(hours: 2, minutes: 30);
    final authProvider = Provider.of<AuthProvider>(context);
    final String role = authProvider.user?.role ?? '';
    final bool isEmployee = role == 'employee';
    final bool isAdminOrOwner = role == 'admin' || role == 'owner';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUrgentArrival
              ? Colors.orange.shade400
              : timer.countdownColor.withOpacity(0.3),
          width: isUrgentArrival ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: isDesktop
              ? const EdgeInsets.all(20)
              : const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with urgent badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${timer.orderNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 18 : 16,
                            color: isUrgentArrival
                                ? Colors.orange.shade800
                                : AppColors.darkGray,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // ⭐ عرض نوع الطلب
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getOrderSourceColor(
                              timer.orderSource,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getOrderSourceText(timer.orderSource),
                            style: TextStyle(
                              color: _getOrderSourceColor(timer.orderSource),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUrgentArrival) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'قريب من وقت الوصول',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    timer.countdownIcon,
                    color: isUrgentArrival
                        ? Colors.orange.shade600
                        : timer.countdownColor,
                    size: isDesktop ? 24 : 20,
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 12 : 8),

              // Supplier and Customer
              Text(
                timer.supplierName,
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: isDesktop ? 15 : 14,
                ),
              ),
              if (timer.customerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'للعميل: ${timer.customerName!}',
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: isDesktop ? 14 : 13,
                  ),
                ),
              ],
              SizedBox(height: isDesktop ? 16 : 12),

              // Countdown Timers
              _buildCountdownRow(
                icon: Icons.flag_outlined,
                label: 'وقت الوصول',
                countdown: timer.formattedArrivalCountdown,
                color: isUrgentArrival ? Colors.orange : Colors.blue,
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 12 : 8),
              _buildCountdownRow(
                icon: Icons.local_shipping_outlined,
                label: 'وقت التحميل',
                countdown: timer.formattedLoadingCountdown,
                color: timer.isApproachingLoading
                    ? Colors.orange
                    : Colors.green,
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 16 : 12),

              // Status Badge
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: timer.countdownColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: timer.countdownColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: isDesktop ? 16 : 14,
                        color: timer.countdownColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timer.status,
                        style: TextStyle(
                          color: timer.countdownColor,
                          fontSize: isDesktop ? 13 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownRow({
    required IconData icon,
    required String label,
    required String countdown,
    required Color color,
    required bool isDesktop,
  }) {
    return Row(
      children: [
        Icon(icon, size: isDesktop ? 18 : 16, color: color),
        SizedBox(width: isDesktop ? 12 : 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.mediumGray,
              fontSize: isDesktop ? 15 : 13,
            ),
          ),
        ),
        Text(
          countdown,
          style: TextStyle(
            color: color,
            fontSize: isDesktop ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // دالة مساعدة للحصول على نص نوع الطلب
  String _getOrderSourceText(String orderSource) {
    switch (orderSource) {
      case 'مورد':
        return 'طلب مورد';
      case 'عميل':
        return 'طلب عميل';
      case 'مدمج':
        return 'طلب مدمج';
      default:
        return orderSource;
    }
  }

  // دالة مساعدة للحصول على لون نوع الطلب
  Color _getOrderSourceColor(String orderSource) {
    switch (orderSource) {
      case 'مورد':
        return Colors.blue;
      case 'عميل':
        return Colors.orange;
      case 'مدمج':
        return Colors.purple;
      default:
        return AppColors.primaryBlue;
    }
  }
}

class _DashboardDrawerItemData {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const _DashboardDrawerItemData({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.badge,
  });
}

class StatsCounts {
  final int totalOrders;
  final int supplierPending;
  final int supplierMerged;
  final int customerWaiting;
  final int customerAssigned;
  final int mergedOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int todayOrders;
  final int thisWeekOrders;
  final int thisMonthOrders;

  const StatsCounts({
    required this.totalOrders,
    required this.supplierPending,
    required this.supplierMerged,
    required this.customerWaiting,
    required this.customerAssigned,
    required this.mergedOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.todayOrders,
    required this.thisWeekOrders,
    required this.thisMonthOrders,
  });
}

// Countdown Section Widget
class CountdownSection extends StatefulWidget {
  final List<OrderTimer> timers;
  final VoidCallback onViewAll;
  final String title;

  const CountdownSection({
    super.key,
    required this.timers,
    required this.onViewAll,
    this.title = 'الطلبات القريبة من وقتها',
  });

  @override
  State<CountdownSection> createState() => _CountdownSectionState();
}

class _CountdownSectionState extends State<CountdownSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.timers.isEmpty) {
      return const SizedBox.shrink();
    }

    final approachingTimers = widget.timers
        .where(
          (timer) => timer.isApproachingArrival || timer.isApproachingLoading,
        )
        .toList();

    if (approachingTimers.isEmpty) {
      return const SizedBox.shrink();
    }

    final urgentTimers = approachingTimers.where((timer) {
      return timer.remainingTimeToArrival <=
          const Duration(hours: 2, minutes: 30);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.warningOrange,
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Urgent Countdown Banner (when less than 2.5 hours)
        if (urgentTimers.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade100, Colors.orange.shade50],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${urgentTimers.length} طلب سيصل خلال ساعتين ونصف',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: approachingTimers.take(4).map((timer) {
            return CountdownCard(
              timer: timer,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.orderDetails,
                  arguments: timer.orderId,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Empty Orders Widget
class EmptyOrdersWidget extends StatelessWidget {
  final VoidCallback? onCreateOrder;

  const EmptyOrdersWidget({super.key, this.onCreateOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: AppColors.primaryBlue.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات حالياً',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإنشاء طلبك الأول',
            style: TextStyle(fontSize: 14, color: AppColors.lightGray),
            textAlign: TextAlign.center,
          ),
          if (onCreateOrder != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateOrder,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء طلب جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Order Timer Model Extension - محدثة
class OrderTimer {
  final String orderId;
  final DateTime arrivalDateTime;
  final DateTime loadingDateTime;
  final String orderNumber;
  final String? supplierOrderNumber;
  final String supplierName;
  final String? customerName;
  final String status;
  final String orderSource;
  final String? fuelType;
  final double? quantity;
  final String? unit;

  // 📍 الموقع
  final String? city;
  final String? area;
  final String? address;

  /// 👤 السائق
  final Driver? driver;

  /// 🆕 fallback لو driver مش موجود
  final String? driverNameFallback;
  final String? driverPhoneFallback;
  final String? vehicleNumberFallback;

  // 🔹 الدمج
  final String? mergedInfoSummary;
  final String? mergeStatus;

  // 📝 ملاحظات
  final String? notes;

  OrderTimer({
    required this.orderId,
    required this.arrivalDateTime,
    required this.loadingDateTime,
    required this.orderNumber,
    required this.supplierName,
    required this.status,
    required this.orderSource,
    this.supplierOrderNumber,
    this.customerName,
    this.fuelType,
    this.city,
    this.area,
    this.address,
    this.quantity,
    this.unit,
    this.driver,
    this.driverNameFallback,
    this.driverPhoneFallback,
    this.vehicleNumberFallback,
    this.mergedInfoSummary,
    this.mergeStatus,
    this.notes,
  });

  // =======================
  // ⏱️ الحسابات الزمنية
  // =======================

  Duration get remainingTimeToArrival =>
      arrivalDateTime.difference(DateTime.now());

  Duration get remainingTimeToLoading =>
      loadingDateTime.difference(DateTime.now());

  // =======================
  // 📌 الحالات
  // =======================

  bool get isCanceled => status.trim().contains('ملغ');

  bool get isCompleted {
    final s = status.trim();
    return s.contains('تم التنفيذ') ||
        s.contains('تم التسليم') ||
        s.contains('مكتمل');
  }

  bool get isFinalStatus => isCanceled || isCompleted;

  bool get shouldShowCountdown => !isFinalStatus;

  // =======================
  // ⏰ اقتراب / تأخير
  // =======================

  bool get isApproachingArrival =>
      remainingTimeToArrival <= const Duration(hours: 2, minutes: 30) &&
      remainingTimeToArrival > Duration.zero;

  bool get isApproachingLoading =>
      remainingTimeToLoading <= const Duration(hours: 2, minutes: 30) &&
      remainingTimeToLoading > Duration.zero;

  bool get isOverdue => remainingTimeToLoading < Duration.zero;

  // =======================
  // 👤 بيانات السائق
  // =======================

  String get driverName => driver?.name ?? driverNameFallback ?? '—';

  String get driverPhone => driver?.phone ?? driverPhoneFallback ?? '';

  String get vehicleNumber =>
      driver?.vehicleNumber ?? vehicleNumberFallback ?? '';

  // =======================
  // 📍 الموقع (🆕)
  // =======================

  /// 📦 موقع الاستلام (للمورد)
  String get pickupLocationText {
    if (address != null && address!.trim().isNotEmpty) {
      return address!;
    }

    final parts = <String>[];
    if (city != null && city!.trim().isNotEmpty) {
      parts.add(city!);
    }
    if (area != null && area!.trim().isNotEmpty) {
      parts.add(area!);
    }

    return parts.isNotEmpty ? parts.join(' - ') : '';
  }

  /// 🚚 موقع التسليم (للعميل)
  String get deliveryLocationText {
    // نفس المنطق حاليًا، مع قابلية التوسع لاحقًا
    return pickupLocationText;
  }

  bool get hasPickupLocation => pickupLocationText.isNotEmpty;
  bool get hasDeliveryLocation => deliveryLocationText.isNotEmpty;

  // =======================
  // ⌛ النصوص
  // =======================

  String get formattedArrivalCountdown {
    if (!shouldShowCountdown) return '—';
    if (remainingTimeToArrival < Duration.zero) return 'تأخر';
    if (remainingTimeToArrival == Duration.zero) return 'حان وقت الوصول';
    return _formatDuration(remainingTimeToArrival);
  }

  String get formattedLoadingCountdown {
    if (!shouldShowCountdown) return '—';
    if (remainingTimeToLoading < Duration.zero) return 'تأخر';
    if (remainingTimeToLoading == Duration.zero) return 'حان وقت التحميل';
    return _formatDuration(remainingTimeToLoading);
  }

  // =======================
  // 🎨 ألوان
  // =======================

  Color get countdownColor {
    if (isCanceled || isOverdue) return AppColors.errorRed;
    if (isApproachingArrival || isApproachingLoading) {
      return Colors.orange;
    }
    return AppColors.successGreen;
  }

  IconData get countdownIcon {
    if (isCanceled) return Icons.cancel;
    if (isOverdue) return Icons.warning;
    if (isApproachingArrival || isApproachingLoading) {
      return Icons.access_time_filled;
    }
    return Icons.check_circle_outline;
  }

  // =======================
  // 🧮 تنسيق المدة
  // =======================

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return '0 ثانية';

    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0 || days > 0) parts.add('$hours ساعة');
    if (minutes > 0 || hours > 0 || days > 0) {
      parts.add('$minutes دقيقة');
    }
    parts.add('$seconds ثانية');

    return parts.join(' ');
  }
}
