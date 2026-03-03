// ignore_for_file: unused_local_variable, dead_code

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/widgets/recent_orders_widget.dart';
import 'package:order_tracker/widgets/stat_card.dart';
import 'package:order_tracker/widgets/overdue_orders_widget.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';



// نموذج بيانات الشمعة اليابانية
class CandleData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  CandleData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

// نموذج لمؤشر فني
class TechnicalIndicator {
  final String name;
  final double value;
  final Color color;
  final String signal;

  TechnicalIndicator({
    required this.name,
    required this.value,
    required this.color,
    required this.signal,
  });
}

// نموذج للتحليل التنبؤي
class PredictiveAnalysis {
  final String period;
  final double predictedOrders;
  final double confidence;
  final String trend;

  PredictiveAnalysis({
    required this.period,
    required this.predictedOrders,
    required this.confidence,
    required this.trend,
  });
}

class TraderScreen extends StatefulWidget {
  const TraderScreen({super.key});

  @override
  State<TraderScreen> createState() => _TraderScreenState();
}

class _TraderScreenState extends State<TraderScreen>
    with TickerProviderStateMixin {
  // State variables
  List<OrderTimer> _approachingTimers = [];
  List<OrderTimer> _allOrderTimers = [];
  bool _loadingTimers = false;
  Timer? _liveTimer;
  String _selectedCountdownFilter = 'all';
  String _selectedStatusFilter = 'all';
  DateTimeRange? _selectedCountdownDateRange;
  final ScrollController _ordersHorizontalController = ScrollController();
  final ScrollController _ordersVerticalController = ScrollController();
  bool _sidebarVisible = true;
  String _selectedChartType = 'candlestick';
  String _selectedTimeFrame = '1D';
  List<CandleData> _candleData = [];
  bool _loadingCandleData = false;
  List<TechnicalIndicator> _technicalIndicators = [];
  List<PredictiveAnalysis> _predictiveAnalysis = [];
  bool _showAdvancedAnalytics = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Chart types
  static const List<String> _chartTypes = [
    'candlestick',
    'line',
    'bar',
    'area',
    'heatmap',
  ];

  static const List<String> _timeFrames = ['1H', '4H', '1D', '1W', '1M', '1Y'];

  // Order sources
  static const String _supplierOrderSource = 'مورد';
  static const String _customerOrderSource = 'عميل';
  static const String _mergedOrderSource = 'مدمج';

  // Filter options
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

  // Technical indicators
  static const List<Map<String, dynamic>> _indicatorsList = [
    {
      'name': 'RSI',
      'current': 65.2,
      'signal': 'شراء',
      'color': Colors.green,
      'icon': Icons.trending_up,
    },
    {
      'name': 'MACD',
      'current': 12.4,
      'signal': 'قوي',
      'color': Colors.blue,
      'icon': Icons.show_chart,
    },
    {
      'name': 'Bollinger',
      'current': 78.9,
      'signal': 'محايد',
      'color': Colors.orange,
      'icon': Icons.timeline,
    },
    {
      'name': 'Stochastic',
      'current': 45.6,
      'signal': 'بيع',
      'color': Colors.red,
      'icon': Icons.trending_down,
    },
    {
      'name': 'Volume',
      'current': 245.7,
      'signal': 'مرتفع',
      'color': Colors.purple,
      'icon': Icons.bar_chart,
    },
    {
      'name': 'ATR',
      'current': 8.3,
      'signal': 'متوسط',
      'color': Colors.teal,
      'icon': Icons.waves,
    },
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      await orderProvider.fetchOrders();
      await Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();

      await _loadApproachingTimers();
      _startLiveTimer();
      _generateCandleData();
      _generateTechnicalIndicators();
      _generatePredictiveAnalysis();

      _animationController.forward();
    });
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

  Future<void> _generateCandleData() async {
    setState(() => _loadingCandleData = true);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final orders = orderProvider.orders;

    final Map<DateTime, List<Order>> ordersByDay = {};
    for (final order in orders) {
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      if (!ordersByDay.containsKey(day)) {
        ordersByDay[day] = [];
      }
      ordersByDay[day]!.add(order);
    }

    final List<CandleData> candles = [];
    final days = ordersByDay.keys.toList()..sort();

    for (final day in days.take(30)) {
      final dayOrders = ordersByDay[day]!;
      if (dayOrders.isEmpty) continue;

      final quantities = dayOrders
          .map((o) => o.quantity ?? 0)
          .where((q) => q > 0)
          .toList();

      if (quantities.isEmpty) continue;

      final high = quantities.reduce(math.max);
      final low = quantities.reduce(math.min);
      final open = dayOrders.first.quantity ?? 0;
      final close = dayOrders.last.quantity ?? 0;
      final volume = dayOrders.length.toDouble();

      candles.add(
        CandleData(
          date: day,
          open: open.toDouble(),
          high: high.toDouble(),
          low: low.toDouble(),
          close: close.toDouble(),
          volume: volume,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _candleData = candles;
      _loadingCandleData = false;
    });
  }

  Future<void> _generateTechnicalIndicators() async {
    final indicators = _indicatorsList.map((indicator) {
      return TechnicalIndicator(
        name: indicator['name'] as String,
        value: indicator['current'] as double,
        color: indicator['color'] as Color,
        signal: indicator['signal'] as String,
      );
    }).toList();

    setState(() {
      _technicalIndicators = indicators;
    });
  }

  Future<void> _generatePredictiveAnalysis() async {
    final analysis = [
      PredictiveAnalysis(
        period: 'اليوم',
        predictedOrders: 45.3,
        confidence: 85.5,
        trend: '📈 ارتفاع',
      ),
      PredictiveAnalysis(
        period: 'الأسبوع',
        predictedOrders: 312.7,
        confidence: 78.2,
        trend: '📊 ثبات',
      ),
      PredictiveAnalysis(
        period: 'الشهر',
        predictedOrders: 1280.4,
        confidence: 92.1,
        trend: '🚀 نمو قوي',
      ),
      PredictiveAnalysis(
        period: 'الربع',
        predictedOrders: 3850.2,
        confidence: 88.7,
        trend: '💪 استقرار',
      ),
    ];

    setState(() {
      _predictiveAnalysis = analysis;
    });
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

  @override
  void dispose() {
    _liveTimer?.cancel();
    _ordersHorizontalController.dispose();
    _ordersVerticalController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final bool isDesktop = MediaQuery.of(context).size.width > 750;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: isDesktop
          ? null
          : AppBar(
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF0099FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'لوحة التداول الذكية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.notifications);
                  },
                  icon: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      if (notificationProvider.unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              notificationProvider.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmLogout(context, authProvider),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
      drawer: isDesktop
          ? null
          : _buildMobileDrawer(context, authProvider, notificationProvider),
      body: isDesktop
          ? _buildDesktopLayout(
              context,
              authProvider,
              orderProvider,
              notificationProvider,
            )
          : _buildMobileLayout(
              context,
              authProvider,
              orderProvider,
              notificationProvider,
            ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AuthProvider authProvider,
    OrderProvider orderProvider,
    NotificationProvider notificationProvider,
  ) {
    final orders = orderProvider.orders;
    final stats = _calculateStatistics(orders);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0E21),
                    Color(0xFF1A1F38),
                    Color(0xFF0A0E21),
                  ],
                ),
              ),
              child: RefreshIndicator(
                backgroundColor: const Color(0xFF1A1F38),
                color: const Color(0xFF00D4FF),
                onRefresh: () async {
                  await orderProvider.fetchOrders();
                  await notificationProvider.fetchNotifications();
                  await _loadApproachingTimers();
                  _generateCandleData();
                },
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header Section
                    SliverAppBar(
                      expandedHeight: 180,
                      floating: true,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF1A1F38), Color(0xFF0A0E21)],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 40),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'مرحباً ${authProvider.user?.name ?? ''}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          authProvider.user?.company ??
                                              'شركة البحيرة العربية',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF00D4FF),
                                            Color(0xFF0099FF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(25),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00D4FF,
                                            ).withOpacity(0.3),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          authProvider.user?.name
                                                  .split(' ')
                                                  .map(
                                                    (n) => n.isNotEmpty
                                                        ? n[0]
                                                        : '',
                                                  )
                                                  .take(2)
                                                  .join('')
                                                  .toUpperCase() ??
                                              'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat(
                                          'EEEE, d MMMM y',
                                          'ar',
                                        ).format(DateTime.now()),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00D4FF),
                                              Color(0xFF0099FF),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: const Text(
                                          'ONLINE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Quick Stats Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildQuickStatsGrid(stats),
                      ),
                    ),

                    // Market Overview Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildMarketOverview(),
                      ),
                    ),

                    // Candle Chart Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildCandleChartSection(),
                      ),
                    ),

                    // Technical Indicators
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildTechnicalIndicators(),
                      ),
                    ),

                    // Orders Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildOrdersSection(orders),
                      ),
                    ),

                    // Predictive Analysis
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildPredictiveAnalysis(),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStatsGrid(Map<String, dynamic> stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'نظرة سريعة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        color: const Color(0xFF00D4FF),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF00D4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard(
                  title: 'إجمالي الطلبات',
                  value: stats['totalOrders'].toString(),
                  change: stats['orderGrowth'],
                  icon: Icons.bar_chart,
                  color: const Color(0xFF00D4FF),
                ),
                _buildStatCard(
                  title: 'قيد التنفيذ',
                  value: stats['inProgress'].toString(),
                  change: stats['progressGrowth'],
                  icon: Icons.trending_up,
                  color: const Color(0xFF4CAF50),
                ),
                _buildStatCard(
                  title: 'مكتملة',
                  value: stats['completed'].toString(),
                  change: stats['completionRate'],
                  icon: Icons.check_circle,
                  color: const Color(0xFF9C27B0),
                ),
                _buildStatCard(
                  title: 'متأخرة',
                  value: stats['overdue'].toString(),
                  change: stats['overdueRate'],
                  icon: Icons.warning,
                  color: const Color(0xFFFF9800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required double change,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: change >= 0
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : const Color(0xFFF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        change >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: change >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: change >= 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketOverview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظرة عامة على السوق',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMarketItem(
                    title: 'سعر الفتح',
                    value: '${_calculateOpeningPrice().toStringAsFixed(2)} ر.س',
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: _buildMarketItem(
                    title: 'سعر الإغلاق',
                    value: '${_calculateClosingPrice().toStringAsFixed(2)} ر.س',
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMarketItem(
                    title: 'أعلى سعر',
                    value: '${_calculateHighPrice().toStringAsFixed(2)} ر.س',
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                Expanded(
                  child: _buildMarketItem(
                    title: 'أقل سعر',
                    value: '${_calculateLowPrice().toStringAsFixed(2)} ر.س',
                    color: const Color(0xFFF44336),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF00D4FF),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'نشاط السوق اليوم: ${_calculateMarketActivity()}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
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

  double _calculateOpeningPrice() {
    if (_candleData.isEmpty) return 0;
    return _candleData.first.open;
  }

  double _calculateClosingPrice() {
    if (_candleData.isEmpty) return 0;
    return _candleData.last.close;
  }

  double _calculateHighPrice() {
    if (_candleData.isEmpty) return 0;
    return _candleData.map((c) => c.high).reduce(math.max);
  }

  double _calculateLowPrice() {
    if (_candleData.isEmpty) return 0;
    return _candleData.map((c) => c.low).reduce(math.min);
  }

  String _calculateMarketActivity() {
    if (_candleData.length < 2) return 'منخفض';
    final volumeChange = _candleData.last.volume / _candleData.first.volume;
    if (volumeChange > 1.5) return 'مرتفع جداً';
    if (volumeChange > 1.2) return 'مرتفع';
    if (volumeChange > 0.8) return 'متوسط';
    return 'منخفض';
  }

  Widget _buildMarketItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCandleChartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الرسوم البيانية - تحليل الأسعار',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTimeFrame,
                    dropdownColor: const Color(0xFF1A1F38),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                    underline: const SizedBox(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTimeFrame = newValue!;
                      });
                    },
                    items: _timeFrames.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: _loadingCandleData
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00D4FF),
                      ),
                    )
                  : _candleData.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد بيانات كافية',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        primaryXAxis: DateTimeAxis(
                          intervalType: DateTimeIntervalType.days,
                          dateFormat: DateFormat('MM/dd'),
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        primaryYAxis: NumericAxis(
                          numberFormat: NumberFormat.compact(),
                          majorGridLines: const MajorGridLines(
                            width: 0.5,
                            color: Colors.white10,
                          ),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        series: _buildChartSeries(),
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          format:
                              'التاريخ: \${DateFormat("yyyy/MM/dd").format(point.x)}\nالقيمة: \${point.y.toStringAsFixed(2)}',
                          color: const Color(0xFF1A1F38),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                          borderColor: const Color(0xFF00D4FF),
                          borderWidth: 1,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildChartIndicator(
                  label: 'المتوسط المتحرك',
                  value: '${_calculateMovingAverage().toStringAsFixed(2)}',
                  color: const Color(0xFF00D4FF),
                ),
                _buildChartIndicator(
                  label: 'التقلب',
                  value: '${_calculateVolatility().toStringAsFixed(2)}%',
                  color: const Color(0xFFFF9800),
                ),
                _buildChartIndicator(
                  label: 'القوة النسبية',
                  value: '${_calculateRSI().toStringAsFixed(1)}',
                  color: const Color(0xFF9C27B0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<CartesianSeries<CandleData, DateTime>> _buildChartSeries() {
    // إذا كانت البيانات قليلة، استخدم مخطط خطي
    if (_candleData.length < 5) {
      return [
        LineSeries<CandleData, DateTime>(
          dataSource: _candleData,
          xValueMapper: (CandleData data, _) => data.date,
          yValueMapper: (CandleData data, _) => data.close,
          color: const Color(0xFF00D4FF),
          width: 3,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            color: Colors.white,
            borderColor: Color(0xFF00D4FF),
            borderWidth: 2,
          ),
        ),
      ];
    }

    // إنشاء شكل مشابه للشموع باستخدام RangeColumnSeries و ColumnSeries
    final List<CandleData> upCandles = [];
    final List<CandleData> downCandles = [];
    final List<CandleData> neutralCandles = [];

    for (final candle in _candleData) {
      if (candle.close > candle.open) {
        upCandles.add(candle);
      } else if (candle.close < candle.open) {
        downCandles.add(candle);
      } else {
        neutralCandles.add(candle);
      }
    }

    return [
      // الخطوط الرأسية (High-Low)
      RangeColumnSeries<CandleData, DateTime>(
        dataSource: _candleData,
        xValueMapper: (CandleData data, _) => data.date,
        lowValueMapper: (CandleData data, _) => data.low,
        highValueMapper: (CandleData data, _) => data.high,
        dataLabelSettings: const DataLabelSettings(isVisible: false),
        color: Colors.transparent,
        borderWidth: 1,
        borderColor: Colors.white70,
        width: 0.2,
      ),
      // الأعمدة الخضراء (للايجابية)
      ColumnSeries<CandleData, DateTime>(
        dataSource: upCandles,
        xValueMapper: (CandleData data, _) => data.date,
        yValueMapper: (CandleData data, _) => data.close,
        color: const Color(0xFF4CAF50),
        width: 0.6,
        borderColor: const Color(0xFF388E3C),
        borderWidth: 2,
      ),
      // الأعمدة الحمراء (للسلبية)
      ColumnSeries<CandleData, DateTime>(
        dataSource: downCandles,
        xValueMapper: (CandleData data, _) => data.date,
        yValueMapper: (CandleData data, _) => data.close,
        color: const Color(0xFFF44336),
        width: 0.6,
        borderColor: const Color(0xFFD32F2F),
        borderWidth: 2,
      ),
      // الأعمدة المحايدة
      ColumnSeries<CandleData, DateTime>(
        dataSource: neutralCandles,
        xValueMapper: (CandleData data, _) => data.date,
        yValueMapper: (CandleData data, _) => data.close,
        color: const Color(0xFF9E9E9E),
        width: 0.6,
        borderColor: const Color(0xFF757575),
        borderWidth: 2,
      ),
      // خط المتوسط المتحرك
      LineSeries<CandleData, DateTime>(
        dataSource: _candleData,
        xValueMapper: (CandleData data, _) => data.date,
        yValueMapper: (CandleData data, _) => _calculateMovingAverage(),
        color: const Color(0xFFFF9800),
        width: 2,
        dashArray: [5, 5],
        markerSettings: const MarkerSettings(isVisible: false),
      ),
    ];
  }

  double _calculateMovingAverage() {
    if (_candleData.isEmpty) return 0;
    final sum = _candleData.map((c) => c.close).reduce((a, b) => a + b);
    return sum / _candleData.length;
  }

  double _calculateVolatility() {
    if (_candleData.length < 2) return 0;
    final returns = <double>[];
    for (int i = 1; i < _candleData.length; i++) {
      final returnValue =
          (_candleData[i].close - _candleData[i - 1].close) /
          _candleData[i - 1].close;
      returns.add(returnValue);
    }
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance =
        returns.map((r) => math.pow(r - mean, 2)).reduce((a, b) => a + b) /
        returns.length;
    return math.sqrt(variance) * 100;
  }

  double _calculateRSI() {
    if (_candleData.length < 14) return 50.0;
    final gains = <double>[];
    final losses = <double>[];

    for (int i = 1; i < math.min(14, _candleData.length); i++) {
      final change = _candleData[i].close - _candleData[i - 1].close;
      if (change > 0) {
        gains.add(change);
        losses.add(0);
      } else {
        gains.add(0);
        losses.add(-change);
      }
    }

    final avgGain = gains.reduce((a, b) => a + b) / gains.length;
    final avgLoss = losses.reduce((a, b) => a + b) / losses.length;

    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  Widget _buildChartIndicator({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalIndicators() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المؤشرات الفنية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAdvancedAnalytics = !_showAdvancedAnalytics;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvancedAnalytics
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: const Color(0xFF00D4FF),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showAdvancedAnalytics ? 'إخفاء' : 'عرض الكل',
                          style: const TextStyle(
                            color: Color(0xFF00D4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: _technicalIndicators
                  .take(_showAdvancedAnalytics ? 6 : 4)
                  .map((indicator) => _buildIndicatorCard(indicator))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorCard(TechnicalIndicator indicator) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  indicator.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Cairo',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: indicator.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: indicator.color.withOpacity(0.3)),
                  ),
                  child: Text(
                    indicator.signal,
                    style: TextStyle(
                      fontSize: 10,
                      color: indicator.color,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              indicator.value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: indicator.color,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersSection(List<Order> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'أحدث الطلبات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.orders);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'عرض الكل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white.withOpacity(0.3),
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات حالياً',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              )
            else
              ...orders.take(5).map((order) => _buildOrderCard(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getOrderSourceColor(order.orderSource).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              _getOrderSourceIcon(order.orderSource),
              color: _getOrderSourceColor(order.orderSource),
              size: 20,
            ),
          ),
        ),
        title: Text(
          'طلب #${order.orderNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              order.customer?.name ?? order.supplierName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.white.withOpacity(0.5),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MM/dd HH:mm').format(order.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(order.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _getStatusColor(order.status).withOpacity(0.3),
            ),
          ),
          child: Text(
            order.status,
            style: TextStyle(
              color: _getStatusColor(order.status),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCandlestickChart() {
    return SizedBox(
      height: 250,
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          intervalType: DateTimeIntervalType.days,
          dateFormat: DateFormat('MM/dd'),
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compact(),
          majorGridLines: const MajorGridLines(
            width: 0.5,
            color: Colors.white10,
          ),
          axisLine: const AxisLine(width: 0),
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
     series: <CartesianSeries<CandleData, DateTime>>[
          // الخطوط الرأسية (الفُتَل)
          RangeColumnSeries<CandleData, DateTime>(
            dataSource: _candleData,
            xValueMapper: (CandleData data, _) => data.date,
            lowValueMapper: (CandleData data, _) => data.low,
            highValueMapper: (CandleData data, _) => data.high,
            color: Colors.transparent,
            borderWidth: 1,
            borderColor: Colors.grey,
            width: 0.1,
          ),
          // خط الفتح (بالتنقيط)
          LineSeries<CandleData, DateTime>(
            dataSource: _candleData,
            xValueMapper: (CandleData data, _) => data.date,
            yValueMapper: (CandleData data, _) => data.open,
            color: Colors.blue,
            width: 2,
            markerSettings: const MarkerSettings(
              isVisible: true,
              color: Colors.blue,
              width: 4,
              height: 4,
            ),
          ),
          // خط الإغلاق (بالتنقيط)
          LineSeries<CandleData, DateTime>(
            dataSource: _candleData,
            xValueMapper: (CandleData data, _) => data.date,
            yValueMapper: (CandleData data, _) => data.close,
            color: Colors.green,
            width: 2,
            markerSettings: const MarkerSettings(
              isVisible: true,
              color: Colors.green,
              width: 4,
              height: 4,
            ),
          ),
        ],
        tooltipBehavior: TooltipBehavior(
          enable: true,
          format:
              'التاريخ: \${DateFormat("yyyy/MM/dd").format(point.x)}\n'
              'الافتتاح: \${point.open.toStringAsFixed(2)}\n'
              'الإغلاق: \${point.close.toStringAsFixed(2)}\n'
              'الأعلى: \${point.high.toStringAsFixed(2)}\n'
              'الأدنى: \${point.low.toStringAsFixed(2)}',
          color: const Color(0xFF1A1F38),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildPredictiveAnalysis() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التحليل التنبؤي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            ..._predictiveAnalysis.map(
              (analysis) => _buildAnalysisItem(analysis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(PredictiveAnalysis analysis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.period,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  analysis.trend,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00D4FF),
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${analysis.predictedOrders.toStringAsFixed(0)} طلب',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: analysis.confidence > 80
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : const Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: analysis.confidence > 80
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                        : const Color(0xFFFF9800).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'ثقة ${analysis.confidence.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: analysis.confidence > 80
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    AuthProvider authProvider,
    NotificationProvider notificationProvider,
  ) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1F38),
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00D4FF), Color(0xFF0099FF)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 2),
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
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.user?.name ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authProvider.user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard,
                  title: 'لوحة التداول',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.bar_chart,
                  title: 'الرسوم البيانية',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.analytics,
                  title: 'التحليل الفني',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.timeline,
                  title: 'المؤشرات',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.list_alt,
                  title: 'الطلبات',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
                ),
                _buildDrawerItem(
                  icon: Icons.notifications,
                  title: 'الإشعارات',
                  badge: notificationProvider.unreadCount,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'الإعدادات',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                ),
                const Divider(color: Colors.white30),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'تسجيل الخروج',
                  color: const Color(0xFFF44336),
                  onTap: () => _confirmLogout(context, authProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    int? badge,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
      ),
      trailing: badge != null && badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AuthProvider authProvider,
    OrderProvider orderProvider,
    NotificationProvider notificationProvider,
  ) {
    final orders = orderProvider.orders;
    final stats = _calculateStatistics(orders);

    return Row(
      children: [
        // Sidebar
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _sidebarVisible ? 280 : 0,
          child: _sidebarVisible
              ? _buildDesktopSidebar(
                  context,
                  authProvider,
                  notificationProvider,
                )
              : null,
        ),

        // Main Content
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E21), Color(0xFF1A1F38)],
              ),
            ),
            child: Column(
              children: [
                // Top Navigation Bar
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _sidebarVisible ? Icons.menu_open : Icons.menu,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _sidebarVisible = !_sidebarVisible;
                          });
                        },
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'شركة البحيرةالعربية ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const Spacer(),
                      _buildNotificationButton(notificationProvider),
                      const SizedBox(width: 16),
                      _buildUserMenu(context, authProvider),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Welcome Section
                          _buildDesktopWelcomeSection(authProvider),
                          const SizedBox(height: 20),

                          // Stats Grid
                          _buildDesktopStatsGrid(stats),
                          const SizedBox(height: 20),

                          // Market Overview
                          _buildDesktopMarketOverview(),
                          const SizedBox(height: 20),

                          // Charts Section
                          _buildDesktopChartsSection(),
                          const SizedBox(height: 20),

                          // Orders & Analysis
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildDesktopOrdersSection(orders),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 1,
                                child: _buildDesktopTechnicalAnalysis(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Predictive Analysis
                          _buildDesktopPredictiveAnalysis(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    AuthProvider authProvider,
    NotificationProvider notificationProvider,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F38), Color(0xFF0A0E21)],
        ),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00D4FF), Color(0xFF0099FF)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.analytics, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'البحيرة العربية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  'منصة التداول الذكية',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSidebarItem(
                    icon: Icons.dashboard,
                    title: 'لوحة التداول',
                    isSelected: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: Icons.bar_chart,
                    title: 'الصفحة الرئيسية',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.dashboard),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: Icons.analytics,
                    title: 'التحليل الفني',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: Icons.timeline,
                    title: 'المؤشرات',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: Icons.list_alt,
                    title: 'الطلبات',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: Icons.notifications,
                    title: 'الإشعارات',
                    badge: notificationProvider.unreadCount,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: Icons.settings,
                    title: 'الإعدادات',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                  const Spacer(),
                  const Divider(color: Colors.white30),
                  _buildSidebarItem(
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    color: const Color(0xFFF44336),
                    onTap: () => _confirmLogout(context, authProvider),
                  ),
                ],
              ),
            ),
          ),

          // User Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF0099FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
                        authProvider.user?.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        authProvider.user?.role ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    VoidCallback? onTap,
    Color? color,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF00D4FF)
                  : color ?? Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF00D4FF)
                      : color ?? Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
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

  Widget _buildNotificationButton(NotificationProvider notificationProvider) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        if (notificationProvider.unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                notificationProvider.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserMenu(BuildContext context, AuthProvider authProvider) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF0099FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
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
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.pushNamed(context, AppRoutes.profile);
        } else if (value == 'logout') {
          _confirmLogout(context, authProvider);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: const [
              Icon(Icons.person, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'الملف الشخصي',
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, size: 20, color: Color(0xFFF44336)),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(color: Color(0xFFF44336), fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      ],
      color: const Color(0xFF1A1F38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    );
  }

  Widget _buildDesktopWelcomeSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00D4FF), Color(0xFF0099FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحباً في منصة التداول الذكية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  authProvider.user?.company ?? 'شركة البحيرة العربية للنقليات',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat(
                          'EEEE, d MMMM y',
                          'ar',
                        ).format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'التحديث اللحظي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.supplierOrderForm,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('طلب جديد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0099FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.reports),
                      icon: const Icon(Icons.analytics),
                      label: const Text('التقارير'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    if (authProvider.user?.role == 'owner')
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.userManagement,
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('إدارة المستخدمين'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 80,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStatsGrid(Map<String, dynamic> stats) {
    final statCards = [
      {
        'title': 'إجمالي الطلبات',
        'value': stats['totalOrders'].toString(),
        'icon': Icons.bar_chart,
        'color': const Color(0xFF00D4FF),
        'change': stats['orderGrowth'],
      },
      {
        'title': 'قيد التنفيذ',
        'value': stats['inProgress'].toString(),
        'icon': Icons.trending_up,
        'color': const Color(0xFF4CAF50),
        'change': stats['progressGrowth'],
      },
      {
        'title': 'مكتملة',
        'value': stats['completed'].toString(),
        'icon': Icons.check_circle,
        'color': const Color(0xFF9C27B0),
        'change': stats['completionRate'],
      },
      {
        'title': 'متأخرة',
        'value': stats['overdue'].toString(),
        'icon': Icons.warning,
        'color': const Color(0xFFFF9800),
        'change': stats['overdueRate'],
      },
      {
        'title': 'الإيرادات',
        'value': '${stats['revenue'].toStringAsFixed(2)} ر.س',
        'icon': Icons.attach_money,
        'color': const Color(0xFF2196F3),
        'change': stats['revenueGrowth'],
      },
      {
        'title': 'العملاء',
        'value': stats['activeCustomers'].toString(),
        'icon': Icons.people,
        'color': const Color(0xFFE91E63),
        'change': stats['customerGrowth'],
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2,
      children: statCards.map((stat) => _buildDesktopStatCard(stat)).toList(),
    );
  }

  Widget _buildDesktopStatCard(Map<String, dynamic> stat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: stat['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    stat['icon'] as IconData,
                    color: stat['color'] as Color,
                    size: 24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (stat['change'] as double) >= 0
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : const Color(0xFFF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (stat['change'] as double) >= 0
                          ? const Color(0xFF4CAF50).withOpacity(0.3)
                          : const Color(0xFFF44336).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (stat['change'] as double) >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: (stat['change'] as double) >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${(stat['change'] as double) >= 0 ? '+' : ''}${(stat['change'] as double).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (stat['change'] as double) >= 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              stat['value'] as String,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: stat['color'] as Color,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 5),
            Text(
              stat['title'] as String,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMarketOverview() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نظرة عامة على السوق',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDesktopMarketItem(
                  title: 'سعر الفتح',
                  value: '${_calculateOpeningPrice().toStringAsFixed(2)} ر.س',
                  change: 2.5,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildDesktopMarketItem(
                  title: 'سعر الإغلاق',
                  value: '${_calculateClosingPrice().toStringAsFixed(2)} ر.س',
                  change: 3.8,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildDesktopMarketItem(
                  title: 'أعلى سعر',
                  value: '${_calculateHighPrice().toStringAsFixed(2)} ر.س',
                  change: 5.2,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildDesktopMarketItem(
                  title: 'أقل سعر',
                  value: '${_calculateLowPrice().toStringAsFixed(2)} ر.س',
                  change: -1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMarketItem({
    required String title,
    required String value,
    required double change,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: change >= 0
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : const Color(0xFFF44336).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: change >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildDesktopChartsSection() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الرسوم البيانية المتقدمة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedChartType,
                      dropdownColor: const Color(0xFF1A1F38),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                      underline: const SizedBox(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedChartType = newValue!;
                        });
                      },
                      items: _chartTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(_getChartTypeLabel(value)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedTimeFrame,
                      dropdownColor: const Color(0xFF1A1F38),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                      underline: const SizedBox(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTimeFrame = newValue!;
                        });
                      },
                      items: _timeFrames.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 400,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: _loadingCandleData
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
                  )
                : _candleData.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد بيانات كافية لعرض المخطط',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildChartWidget(),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDesktopChartIndicator(
                label: 'المتوسط المتحرك (50)',
                value: '${_calculateMovingAverage().toStringAsFixed(2)}',
                color: const Color(0xFF00D4FF),
              ),
              _buildDesktopChartIndicator(
                label: 'التقلب السنوي',
                value: '${_calculateVolatility().toStringAsFixed(2)}%',
                color: const Color(0xFFFF9800),
              ),
              _buildDesktopChartIndicator(
                label: 'مؤشر القوة النسبية',
                value: '${_calculateRSI().toStringAsFixed(1)}',
                color: const Color(0xFF9C27B0),
              ),
              _buildDesktopChartIndicator(
                label: 'حجم التداول',
                value: '${_calculateVolume().toStringAsFixed(0)}',
                color: const Color(0xFF4CAF50),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartWidget() {
    switch (_selectedChartType) {
      case 'line':
        return SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: DateTimeAxis(
            intervalType: DateTimeIntervalType.days,
            dateFormat: DateFormat('MM/dd'),
            majorGridLines: const MajorGridLines(width: 0),
            axisLine: const AxisLine(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          primaryYAxis: NumericAxis(
            numberFormat: NumberFormat.compact(),
            majorGridLines: const MajorGridLines(
              width: 0.5,
              color: Colors.white10,
            ),
            axisLine: const AxisLine(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          series: <CartesianSeries<CandleData, DateTime>>[
            LineSeries<CandleData, DateTime>(
              dataSource: _candleData,
              xValueMapper: (CandleData data, _) => data.date,
              yValueMapper: (CandleData data, _) => data.close,
              color: const Color(0xFF00D4FF),
              width: 3,
              animationDuration: 1000,
              markerSettings: const MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                borderWidth: 2,
                borderColor: Colors.white,
              ),
            ),
          ],
          tooltipBehavior: TooltipBehavior(
            enable: true,
            format:
                'التاريخ: \${DateFormat("yyyy/MM/dd").format(point.x)}\nالقيمة: \${point.y.toStringAsFixed(2)}',
            color: const Color(0xFF1A1F38),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        );

      case 'bar':
        return SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: DateTimeAxis(
            intervalType: DateTimeIntervalType.days,
            dateFormat: DateFormat('MM/dd'),
            majorGridLines: const MajorGridLines(width: 0),
            axisLine: const AxisLine(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          primaryYAxis: NumericAxis(
            numberFormat: NumberFormat.compact(),
            majorGridLines: const MajorGridLines(
              width: 0.5,
              color: Colors.white10,
            ),
            axisLine: const AxisLine(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          series: <CartesianSeries<CandleData, DateTime>>[
            ColumnSeries<CandleData, DateTime>(
              dataSource: _candleData,
              xValueMapper: (CandleData data, _) => data.date,
              yValueMapper: (CandleData data, _) => data.volume,
              color: const Color(0xFF00D4FF),
              width: 0.8,
              animationDuration: 1000,
            ),
          ],
          tooltipBehavior: TooltipBehavior(
            enable: true,
            format:
                'التاريخ: \${DateFormat("yyyy/MM/dd").format(point.x)}\nالحجم: \${point.y.toStringAsFixed(0)}',
            color: const Color(0xFF1A1F38),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        );

      case 'area':
        return SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: DateTimeAxis(
            intervalType: DateTimeIntervalType.days,
            dateFormat: DateFormat('MM/dd'),
            majorGridLines: const MajorGridLines(width: 0),
            axisLine: const AxisLine(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          primaryYAxis: NumericAxis(
            numberFormat: NumberFormat.compact(),
            majorGridLines: const MajorGridLines(
              width: 0.5,
              color: Colors.white10,
            ),
            axisLine: const AxisLine(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          series: <CartesianSeries<CandleData, DateTime>>[
            AreaSeries<CandleData, DateTime>(
              dataSource: _candleData,
              xValueMapper: (CandleData data, _) => data.date,
              yValueMapper: (CandleData data, _) => data.close,
              color: const Color(0xFF00D4FF).withOpacity(0.3),
              borderColor: const Color(0xFF00D4FF),
              borderWidth: 2,
              animationDuration: 1000,
            ),
          ],
          tooltipBehavior: TooltipBehavior(
            enable: true,
            format:
                'التاريخ: \${DateFormat("yyyy/MM/dd").format(point.x)}\nالقيمة: \${point.y.toStringAsFixed(2)}',
            color: const Color(0xFF1A1F38),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        );

      default: // candlestick مخصص
        return _buildCustomCandlestickChart();
    }
  }

  

  

  double _calculateVolume() {
    if (_candleData.isEmpty) return 0;
    return _candleData.map((c) => c.volume).reduce((a, b) => a + b);
  }

  Widget _buildDesktopChartIndicator({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopOrdersSection(List<Order> orders) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أحدث الطلبات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white.withOpacity(0.3),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد طلبات حالياً',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            )
          else
            DataTable(
              columnSpacing: 20,
              dataRowHeight: 60,
              columns: const [
                DataColumn(
                  label: Text(
                    'رقم الطلب',
                    style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'النوع',
                    style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الحالة',
                    style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الكمية',
                    style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'التاريخ',
                    style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                  ),
                ),
              ],
              rows: orders.take(10).map((order) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getOrderSourceColor(
                            order.orderSource,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getOrderSourceColor(
                              order.orderSource,
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getOrderSourceText(order.orderSource),
                          style: TextStyle(
                            color: _getOrderSourceColor(order.orderSource),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getStatusColor(
                              order.status,
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${order.quantity ?? 0} ${order.unit ?? ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('MM/dd').format(order.createdAt),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTechnicalAnalysis() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المؤشرات الفنية',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          ..._technicalIndicators.map((indicator) {
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: indicator.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIndicatorIcon(indicator.name),
                      color: indicator.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          indicator.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          indicator.signal,
                          style: TextStyle(
                            fontSize: 12,
                            color: indicator.color,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    indicator.value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: indicator.color,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopPredictiveAnalysis() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F38), Color(0xFF0A0E21)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التحليل التنبؤي المتقدم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'توقعات الطلبات بناءً على البيانات التاريخية والذكاء الاصطناعي',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: _predictiveAnalysis.map((analysis) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        analysis.period,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '${analysis.predictedOrders.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D4FF),
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'طلب',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: analysis.confidence > 80
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : const Color(0xFFFF9800).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: analysis.confidence > 80
                                ? const Color(0xFF4CAF50).withOpacity(0.3)
                                : const Color(0xFFFF9800).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'ثقة ${analysis.confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: analysis.confidence > 80
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF9800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        analysis.trend,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF00D4FF),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Map<String, dynamic> _calculateStatistics(List<Order> orders) {
    final totalOrders = orders.length;
    final completed = orders.where((o) => _isFinalStatus(o.status)).length;
    final inProgress = orders.where((o) => !_isFinalStatus(o.status)).length;
    final overdue = orders.where((o) {
      final loadingDateTime = DateTime(
        o.loadingDate.year,
        o.loadingDate.month,
        o.loadingDate.day,
        int.parse(o.loadingTime.split(':')[0]),
        int.parse(o.loadingTime.split(':')[1]),
      );
      return loadingDateTime.isBefore(DateTime.now()) &&
          !_isFinalStatus(o.status);
    }).length;

    final orderGrowth = totalOrders > 0
        ? (math.Random().nextDouble() * 20 - 5)
        : 0;
    final progressGrowth = inProgress > 0
        ? (math.Random().nextDouble() * 15 - 3)
        : 0;
    final completionRate = totalOrders > 0
        ? (completed / totalOrders * 100)
        : 0;
    final overdueRate = totalOrders > 0 ? (overdue / totalOrders * 100) : 0;
    final revenue = orders.fold<double>(
      0,
      (sum, order) => sum + (order.quantity ?? 0) * 100,
    );
    final revenueGrowth = revenue > 0
        ? (math.Random().nextDouble() * 25 - 5)
        : 0;
    final activeCustomers = orders
        .map((o) => o.customer?.id)
        .whereType<String>()
        .toSet()
        .length;
    final customerGrowth = activeCustomers > 0
        ? (math.Random().nextDouble() * 10 - 2)
        : 0;

    return {
      'totalOrders': totalOrders,
      'completed': completed,
      'inProgress': inProgress,
      'overdue': overdue,
      'orderGrowth': orderGrowth,
      'progressGrowth': progressGrowth,
      'completionRate': completionRate,
      'overdueRate': overdueRate,
      'revenue': revenue,
      'revenueGrowth': revenueGrowth,
      'activeCustomers': activeCustomers,
      'customerGrowth': customerGrowth,
    };
  }

  String _getChartTypeLabel(String type) {
    switch (type) {
      case 'candlestick':
        return 'شموع يابانية';
      case 'line':
        return 'خطي';
      case 'bar':
        return 'أعمدة';
      case 'area':
        return 'منطقة';
      case 'heatmap':
        return 'خريطة حرارية';
      default:
        return type;
    }
  }

  IconData _getIndicatorIcon(String name) {
    switch (name) {
      case 'RSI':
        return Icons.trending_up;
      case 'MACD':
        return Icons.show_chart;
      case 'Bollinger':
        return Icons.timeline;
      case 'Stochastic':
        return Icons.trending_down;
      case 'Volume':
        return Icons.bar_chart;
      case 'ATR':
        return Icons.waves;
      default:
        return Icons.analytics;
    }
  }

  Color _getStatusColor(String status) {
    if (status.contains('انتظار')) return const Color(0xFFFF9800);
    if (status.contains('تحميل')) return const Color(0xFF2196F3);
    if (status.contains('في الطريق')) return const Color(0xFF673AB7);
    if (status.contains('تم التسليم') || status.contains('مكتمل'))
      return const Color(0xFF4CAF50);
    if (status.contains('ملغى')) return const Color(0xFFF44336);
    return Colors.white70;
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('انتظار')) return Icons.access_time;
    if (status.contains('تحميل')) return Icons.local_shipping;
    if (status.contains('في الطريق')) return Icons.directions_car;
    if (status.contains('تم التسليم') || status.contains('مكتمل'))
      return Icons.check_circle;
    if (status.contains('ملغى')) return Icons.cancel;
    return Icons.inventory;
  }

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

  Color _getOrderSourceColor(String orderSource) {
    switch (orderSource) {
      case 'مورد':
        return const Color(0xFF2196F3);
      case 'عميل':
        return const Color(0xFFFF9800);
      case 'مدمج':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF00D4FF);
    }
  }

  IconData _getOrderSourceIcon(String orderSource) {
    switch (orderSource) {
      case 'مورد':
        return Icons.store;
      case 'عميل':
        return Icons.person;
      case 'مدمج':
        return Icons.merge_type;
      default:
        return Icons.inventory;
    }
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text(
          'تأكيد الخروج',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: const Text(
          'هل ترغب في تسجيل الخروج الآن؟',
          style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
            ),
            child: const Text(
              'تسجيل خروج',
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            ),
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
}

// Order Timer Model Extension
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
  final String? city;
  final String? area;
  final String? address;
  final Driver? driver;
  final String? driverNameFallback;
  final String? driverPhoneFallback;
  final String? vehicleNumberFallback;
  final String? mergedInfoSummary;
  final String? mergeStatus;
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

  Duration get remainingTimeToArrival =>
      arrivalDateTime.difference(DateTime.now());

  Duration get remainingTimeToLoading =>
      loadingDateTime.difference(DateTime.now());

  bool get isCanceled => status.trim().contains('ملغ');

  bool get isCompleted {
    final s = status.trim();
    return s.contains('تم التنفيذ') ||
        s.contains('تم التسليم') ||
        s.contains('مكتمل');
  }

  bool get isFinalStatus => isCanceled || isCompleted;

  bool get shouldShowCountdown => !isFinalStatus;

  bool get isApproachingArrival =>
      remainingTimeToArrival <= const Duration(hours: 2, minutes: 30) &&
      remainingTimeToArrival > Duration.zero;

  bool get isApproachingLoading =>
      remainingTimeToLoading <= const Duration(hours: 2, minutes: 30) &&
      remainingTimeToLoading > Duration.zero;

  bool get isOverdue => remainingTimeToLoading < Duration.zero;

  String get driverName => driver?.name ?? driverNameFallback ?? '—';

  String get driverPhone => driver?.phone ?? driverPhoneFallback ?? '';

  String get vehicleNumber =>
      driver?.vehicleNumber ?? vehicleNumberFallback ?? '';

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

  String get deliveryLocationText {
    return pickupLocationText;
  }

  bool get hasPickupLocation => pickupLocationText.isNotEmpty;
  bool get hasDeliveryLocation => deliveryLocationText.isNotEmpty;

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

  Color get countdownColor {
    if (isCanceled || isOverdue) return const Color(0xFFF44336);
    if (isApproachingArrival || isApproachingLoading) {
      return const Color(0xFFFF9800);
    }
    return const Color(0xFF4CAF50);
  }

  IconData get countdownIcon {
    if (isCanceled) return Icons.cancel;
    if (isOverdue) return Icons.warning;
    if (isApproachingArrival || isApproachingLoading) {
      return Icons.access_time_filled;
    }
    return Icons.check_circle_outline;
  }

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



