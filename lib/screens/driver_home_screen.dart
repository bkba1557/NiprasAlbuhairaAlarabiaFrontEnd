import 'dart:async';
import 'package:flutter/material.dart';
import 'package:order_tracker/localization/app_localizations.dart' as loc;
import 'package:order_tracker/models/notification_model.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/language_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/screens/driver_history_screen.dart';
import 'package:order_tracker/screens/tracking/driver_delivery_tracking_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/driver_background_location_permission.dart';
import 'package:order_tracker/utils/driver_trip_lock.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/notification_item.dart';
import 'package:order_tracker/widgets/slide_action_button.dart';
import 'package:order_tracker/widgets/tracking/tracking_page_shell.dart';
import 'package:provider/provider.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  /* -------------------------------------------------------------
   * 1️⃣   الحالات النهائية للطلب
   * ------------------------------------------------------------ */
  static const Set<String> _finalStatuses = {
    // الحالات التي تعتبر منتهية نهائيًا
    'تم التسليم',
    'تم التنفيذ',
    'مكتمل',
    'ملغى',
    // الطلبات مثل "تم التحميل" و"في الطريق" تظل نشطة للسائق
  };

  static const List<loc.AppLanguage> _driverLanguageOptions = [
    loc.AppLanguage.english,
    loc.AppLanguage.arabic,
    loc.AppLanguage.hindi,
    loc.AppLanguage.bengali,
    loc.AppLanguage.filipino,
    loc.AppLanguage.urdu,
    loc.AppLanguage.pashto,
  ];

  static const double _floatingTabBarReservedSpace = 92;
  Timer? _refreshTimer;
  bool _isResumingLockedTrip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshAll();
      await _resumeLockedTripIfAny();
      await _requestBackgroundLocationIfNeeded();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshAll(silent: true),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /* -------------------------------------------------------------
   * 2️⃣   جلب بيانات الطلبات والإشعارات
   * ------------------------------------------------------------ */
  Future<void> _refreshAll({bool silent = false}) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final notifications = context.read<NotificationProvider>();
    if (auth.user != null) {
      notifications.setCurrentUserId(auth.user!.id);
    }
    await Future.wait([
      context.read<OrderProvider>().fetchOrders(silent: silent),
      notifications.fetchNotifications(),
    ]);
  }

  Future<void> _requestBackgroundLocationIfNeeded() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    await DriverBackgroundLocationPermission.maybePromptOnFirstLaunch(
      context,
      userId: user.id,
      isDriver: user.role == 'driver',
    );
  }

  Future<void> _resumeLockedTripIfAny() async {
    if (!mounted || _isResumingLockedTrip) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id.trim();
    if (userId == null || userId.isEmpty) return;
    final snapshot = await DriverTripLock.load(userId);
    if (snapshot == null || snapshot.orderId.isEmpty) return;
    _isResumingLockedTrip = true;
    try {
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.fetchOrderById(snapshot.orderId, silent: true);
      final order =
          orderProvider.selectedOrder ??
          orderProvider.getOrderById(snapshot.orderId);
      if (!mounted) return;
      if (order == null || _isDriverEndedOrder(order)) {
        await DriverTripLock.clear(userId);
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDeliveryTrackingScreen(
            initialOrder: order,
            showMap: snapshot.showMap,
          ),
        ),
      );
      if (!mounted) return;
      await _refreshAll(silent: true);
    } finally {
      _isResumingLockedTrip = false;
    }
  }

  /* -------------------------------------------------------------
   * 3️⃣   مساعدة تحديد المرحلة الحالية للطلب
   * ------------------------------------------------------------ */
  bool _isLoadingStationStage(Order order) {
    if (_isWaitingMovementDispatch(order)) {
      return false;
    }
    const delivered = <String>{
      'تم التحميل',
      'في الطريق',
      'تم التسليم',
      'تم التنفيذ',
      'مكتمل',
      'ملغى',
    };
    return !delivered.contains(order.status.trim());
  }

  bool _isWaitingMovementDispatch(Order order) {
    return order.isMovementOrder &&
        order.isMovementPendingDispatch &&
        order.status.trim() == 'تم التحميل';
  }

  bool _isDeliveringStage(Order order) {
    if (_isWaitingMovementDispatch(order)) return false;
    return const {'تم التحميل', 'في الطريق'}.contains(order.status.trim());
  }

  String _destinationText(Order order) {
    if (_isWaitingMovementDispatch(order)) {
      return context.tr(loc.AppStrings.driverWaitingForDispatchDestination);
    }
    if (_isLoadingStationStage(order)) {
      if (order.supplierAddress?.trim().isNotEmpty == true) {
        return order.supplierAddress!.trim();
      }
      if (order.loadingStationName?.trim().isNotEmpty == true) {
        return order.loadingStationName!.trim();
      }
      if (order.supplierName.trim().isNotEmpty) {
        return order.supplierName.trim();
      }
      return context.tr(loc.AppStrings.driverLoadingStationDefault);
    }
    if (order.address?.trim().isNotEmpty == true) return order.address!.trim();
    if (order.customerAddress?.trim().isNotEmpty == true) {
      return order.customerAddress!.trim();
    }
    final parts = <String>[
      if (order.city?.trim().isNotEmpty == true) order.city!.trim(),
      if (order.area?.trim().isNotEmpty == true) order.area!.trim(),
    ];
    return parts.isEmpty
        ? context.tr(loc.AppStrings.driverCurrentClientFallback)
        : parts.join(' - ');
  }

  String _stageLabel(Order order) {
    if (_isWaitingMovementDispatch(order)) {
      return context.tr(loc.AppStrings.driverWaitingForDispatch);
    }
    return _isLoadingStationStage(order)
        ? context.tr(loc.AppStrings.driverHeadingToLoadingStation)
        : context.tr(loc.AppStrings.driverHeadingToCustomer);
  }

  Future<void> _openOrder(Order order, {bool showMap = true}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DriverDeliveryTrackingScreen(initialOrder: order, showMap: showMap),
      ),
    );
    if (!mounted) return;
    await _refreshAll(silent: true);
  }

  Future<void> _startOrder(Order order) async {
    if (_isLoadingStationStage(order) || _isWaitingMovementDispatch(order)) {
      return _openOrder(order, showMap: true);
    }
    final option = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('فتح الخريطة'),
                  subtitle: const Text('عرض الاتجاهات داخل التطبيق'),
                  onTap: () => Navigator.pop(sheetContext, true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_outlined),
                  title: const Text('بدون خريطة'),
                  subtitle: const Text('تنفيذ الطلب بدون عرض الخريطة'),
                  onTap: () => Navigator.pop(sheetContext, false),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || option == null) return;
    await _openOrder(order, showMap: option);
  }

  Future<void> _confirmLogout() async {
    final auth = context.read<AuthProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final userId = auth.user?.id.trim();
    if (userId != null && userId.isNotEmpty) {
      final snapshot = await DriverTripLock.load(userId);
      if (snapshot != null && snapshot.orderId.isNotEmpty) {
        final orderProvider = context.read<OrderProvider>();
        await orderProvider.fetchOrderById(snapshot.orderId, silent: true);
        final lockedOrder =
            orderProvider.selectedOrder ??
            orderProvider.getOrderById(snapshot.orderId);
        if (lockedOrder == null || _isDriverEndedOrder(lockedOrder)) {
          await DriverTripLock.clear(userId);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.language == loc.AppLanguage.arabic
                    ? 'لا يمكن تسجيل الخروج أثناء وجود طلب جارٍ التنفيذ.'
                    : 'You cannot log out while an active trip is in progress.',
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
          return;
        }
      }
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(loc.AppStrings.driverLogoutConfirmTitle)),
        content: Text(context.tr(loc.AppStrings.driverLogoutConfirmMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(loc.AppStrings.cancelAction)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr(loc.AppStrings.logout)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.front,
      (route) => false,
    );
  }

  void _showLanguageSelector() {
    final languageProvider = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  context.tr(loc.AppStrings.languageDialogTitle),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ..._driverLanguageOptions.map((language) {
                final isSelected = languageProvider.language == language;
                return ListTile(
                  leading: isSelected ? const Icon(Icons.check) : null,
                  title: Text(language.nativeName),
                  onTap: () {
                    languageProvider.setLanguage(language);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /* -------------------------------------------------------------
   * 4️⃣   ترجمة الحالة إلى نص إنجليزي/عربي للـ UI
   * ------------------------------------------------------------ */
  String _localizedStatus(String status) {
    switch (status.trim()) {
      case 'تم التحميل':
        return context.tr(loc.AppStrings.driverStatusLoaded);
      case 'في الطريق':
        return context.tr(loc.AppStrings.driverStatusOnWay);
      case 'تم التسليم':
        return context.tr(loc.AppStrings.driverStatusDelivered);
      case 'تم التنفيذ':
        return context.tr(loc.AppStrings.driverStatusExecuted);
      case 'مكتمل':
        return context.tr(loc.AppStrings.driverStatusCompleted);
      case 'ملغى':
        return context.tr(loc.AppStrings.driverStatusCanceled);
      default:
        return status;
    }
  }

  String _localizedFuelType(String? fuelType) {
    final value = fuelType?.trim();
    if (value == null || value.isEmpty) {
      return context.tr(loc.AppStrings.driverUnknownFuel);
    }
    switch (value) {
      case 'بنزين 91':
        return context.tr(loc.AppStrings.filterFuelType91);
      case 'بنزين 95':
        return context.tr(loc.AppStrings.filterFuelType95);
      case 'ديزل':
        return context.tr(loc.AppStrings.filterFuelTypeDiesel);
      case 'غاز':
        return context.tr(loc.AppStrings.filterFuelTypeGas);
      default:
        return value;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    final provider = context.read<NotificationProvider>();
    provider.markAsRead(notification.id);
    final orderId = _extractOrderId(notification);
    if (orderId != null && orderId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDeliveryTrackingScreen(orderId: orderId),
        ),
      );
    }
  }

  String? _extractOrderId(NotificationModel notification) {
    final data = notification.data;
    if (data == null) return null;
    final direct = _extractEntityId(data['orderId'] ?? data['order_id']);
    if (direct != null) return direct;
    final order = data['order'];
    if (order is Map) {
      return _extractEntityId(order['id'] ?? order['_id']);
    }
    return null;
  }

  String? _extractEntityId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final value = raw.trim();
      return value.isEmpty ? null : value;
    }
    if (raw is Map) {
      final map = raw.cast<dynamic, dynamic>();
      final nested =
          map['_id'] ?? map['id'] ?? map[r'$oid'] ?? map['oid'] ?? map['value'];
      if (nested != null) {
        final value = nested.toString().trim();
        return value.isEmpty ? null : value;
      }
    }
    final fallback = raw.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  Color _statusColor(String status) {
    switch (status.trim()) {
      case 'تم التحميل':
      case 'في الطريق':
        return AppColors.primaryBlue;
      case 'تم التسليم':
      case 'تم التنفيذ':
      case 'مكتمل':
        return AppColors.successGreen;
      case 'ملغى':
        return AppColors.errorRed;
      default:
        return AppColors.statusGold;
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}/${_two(local.month)}/${_two(local.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatQuantity(Order order) {
    if (order.quantity == null) {
      return context.tr(loc.AppStrings.driverNotSpecified);
    }
    final quantity = order.quantity!;
    final decimals = quantity % 1 == 0 ? 0 : 2;
    return '${quantity.toStringAsFixed(decimals)} '
        '${order.unit ?? context.tr(loc.AppStrings.driverLitersUnit)}';
  }

  DateTime _combineDateAndTime(DateTime date, String? time) {
    final parts = (time ?? '').trim().split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _hasCustomerArrivalPassed(Order order) {
    final arrivalDeadline = _combineDateAndTime(
      order.arrivalDate,
      order.arrivalTime,
    );
    return DateTime.now().isAfter(arrivalDeadline);
  }

  /* -------------------------------------------------------------
   * 5️⃣   **التغيير الرئيسي** – تعريف ما إذا كان الطلب منتهيًا
   * ------------------------------------------------------------ */
  bool _isDriverEndedOrder(Order order) {
    final status = order.status.trim();

    // إذا كان الطلب منتهيًا فعليًا فلا يظهر ضمن الطلبات النشطة
    if (_finalStatuses.contains(status) || order.isFinalStatus) {
      return true;
    }

    if (status == 'تم دمجه مع العميل' &&
        _hasCustomerArrivalPassed(order)) {
      return true;
    }

    return false;
  }

  /* -------------------------------------------------------------
   * 6️⃣   بناء واجهة المستخدم
   * ------------------------------------------------------------ */
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name.trim().isNotEmpty == true
        ? auth.user!.name.trim()
        : context.tr(loc.AppStrings.driverUserFallback);
    return DefaultTabController(
      length: 2,
      child: Consumer2<OrderProvider, NotificationProvider>(
        builder: (context, orderProvider, notificationProvider, _) {
          final orders = orderProvider.orders;

          // **الطلبات النشطة** = كل طلب لا يُصنَّف كمنتهي الآن
          final activeOrders = orders
              .where((o) => !_isDriverEndedOrder(o))
              .toList();
          final warehouseOrders = activeOrders
              .where((o) => o.status.trim() == 'في المستودع')
              .toList();

          final unreadCount = notificationProvider.unreadCount;
          final loadingCount = warehouseOrders
              .where(_isLoadingStationStage)
              .length;
          final deliveringCount = 0;
          final completedCount = orders.where(_isDriverEndedOrder).length;

          return Scaffold(
            appBar: _buildAppBar(),
            body: Stack(
              children: [
                const AppSoftBackground(),
                Positioned.fill(
                  child: TabBarView(
                    children: [
                      _buildOrdersTab(
                        userName: userName,
                        orders: warehouseOrders,
                        unreadCount: unreadCount,
                        loadingCount: loadingCount,
                        deliveringCount: deliveringCount,
                        completedCount: completedCount,
                        orderProvider: orderProvider,
                      ),
                      _buildNotificationsTab(
                        userName: userName,
                        ordersCount: warehouseOrders.length,
                        unreadCount: unreadCount,
                        loadingCount: loadingCount,
                        deliveringCount: deliveringCount,
                        completedCount: completedCount,
                        notificationProvider: notificationProvider,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: _buildFloatingTabBar(unreadCount),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  PreferredSizeWidget _buildAppBar() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;
    return AppBar(
      toolbarHeight: isNarrow ? 58 : 66,
      leading: IconButton(
        tooltip: context.tr(loc.AppStrings.logoutTooltip),
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        context.tr(loc.AppStrings.driverDashboardTitle),
        style: TextStyle(
          fontSize: isNarrow ? 18 : 20,
          fontWeight: FontWeight.w900,
        ),
      ),
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
      actions: [
        IconButton(
          tooltip: context.tr(loc.AppStrings.driverHistoryTooltip),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverHistoryScreen()),
            );
            if (!mounted) return;
            await _refreshAll(silent: true);
          },
          icon: const Icon(Icons.history_rounded),
        ),
        IconButton(
          tooltip: context.tr(loc.AppStrings.languageTooltip),
          onPressed: _showLanguageSelector,
          icon: const Icon(Icons.language_rounded),
        ),
        IconButton(
          tooltip: context.tr(loc.AppStrings.refreshTooltip),
          onPressed: () => _refreshAll(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildFloatingTabBar(int unreadCount) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isNarrow ? 380 : 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(isNarrow ? 20 : 24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.16),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 4 : 6),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(isNarrow ? 15 : 18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isNarrow ? 12 : 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isNarrow ? 12 : 14,
                ),
                splashBorderRadius: BorderRadius.circular(isNarrow ? 15 : 18),
                tabs: [
                  Tab(text: context.tr(loc.AppStrings.driverTabOrders)),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.tr(loc.AppStrings.driverTabNotifications)),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: TextStyle(
                                fontSize: isNarrow ? 10 : 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersTab({
    required String userName,
    required List<Order> orders,
    required int unreadCount,
    required int loadingCount,
    required int deliveringCount,
    required int completedCount,
    required OrderProvider orderProvider,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: _buildScrollableContent(
        topInset: _floatingTabBarReservedSpace,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(
              userName: userName,
              ordersCount: orders.length,
              unreadCount: unreadCount,
              loadingCount: loadingCount,
              deliveringCount: deliveringCount,
              completedCount: completedCount,
              isOrdersTab: true,
            ),
            const SizedBox(height: 16),
            _DriverSectionCard(
              title: context.tr(loc.AppStrings.driverAssignedOrdersTitle),
              subtitle: context.tr(loc.AppStrings.driverAssignedOrdersSubtitle),
              badge: TrackingStatusBadge(
                label: context.tr(loc.AppStrings.driverOrdersCount, {
                  'count': '${orders.length}',
                }),
                color: AppColors.primaryBlue,
                icon: Icons.assignment_outlined,
              ),
              child: _buildOrdersSectionContent(orderProvider, orders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab({
    required String userName,
    required int ordersCount,
    required int unreadCount,
    required int loadingCount,
    required int deliveringCount,
    required int completedCount,
    required NotificationProvider notificationProvider,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: _buildScrollableContent(
        topInset: _floatingTabBarReservedSpace,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(
              userName: userName,
              ordersCount: ordersCount,
              unreadCount: unreadCount,
              loadingCount: loadingCount,
              deliveringCount: deliveringCount,
              completedCount: completedCount,
              isOrdersTab: false,
            ),
            const SizedBox(height: 16),
            _DriverSectionCard(
              title: context.tr(loc.AppStrings.driverNotificationsTitle),
              subtitle: context.tr(loc.AppStrings.driverNotificationsSubtitle),
              badge: TrackingStatusBadge(
                label: context.tr(loc.AppStrings.driverUnreadCount, {
                  'count': '$unreadCount',
                }),
                color: AppColors.errorRed,
                icon: Icons.notifications_active_outlined,
              ),
              action: unreadCount > 0
                  ? FilledButton.tonalIcon(
                      onPressed: notificationProvider.markAllAsRead,
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(context.tr(loc.AppStrings.driverMarkAllRead)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue.withValues(
                          alpha: 0.10,
                        ),
                        foregroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  : null,
              child: _buildNotificationsSectionContent(notificationProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent({required Widget child, double topInset = 0}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1200;
        final isTablet = constraints.maxWidth >= 760;
        final horizontalPadding = isDesktop ? 28.0 : (isTablet ? 20.0 : 12.0);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            (isDesktop ? 22 : 18) + topInset,
            horizontalPadding,
            96,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard({
    required String userName,
    required int ordersCount,
    required int unreadCount,
    required int loadingCount,
    required int deliveringCount,
    required int completedCount,
    required bool isOrdersTab,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;
    return AppSurfaceCard(
      padding: EdgeInsets.all(isNarrow ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final chips = Wrap(
                spacing: isNarrow ? 8 : 10,
                runSpacing: isNarrow ? 8 : 10,
                children: [
                  TrackingStatusBadge(
                    label: isOrdersTab
                        ? context.tr(loc.AppStrings.driverAutoRefreshChip)
                        : context.tr(loc.AppStrings.driverNotificationLiveChip),
                    color: AppColors.secondaryTeal,
                    icon: isOrdersTab
                        ? Icons.schedule_rounded
                        : Icons.notifications_active_outlined,
                  ),
                  TrackingStatusBadge(
                    label: context.tr(loc.AppStrings.driverUnreadCount, {
                      'count': '$unreadCount',
                    }),
                    color: AppColors.errorRed,
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ],
              );
              final content = _buildWelcomeContent(userName, isOrdersTab);
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 16),
                    chips,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  SizedBox(height: isNarrow ? 12 : 16),
                  chips,
                ],
              );
            },
          ),
          SizedBox(height: isNarrow ? 14 : 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final compactStats = width < 520;
              final columns = compactStats
                  ? 4
                  : (width >= 1240 ? 4 : (width >= 760 ? 2 : 1));
              final spacing = compactStats ? 8.0 : 12.0;
              final cardWidth = columns == 1
                  ? width
                  : (width - ((columns - 1) * spacing)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _DriverStatCard(
                      compact: compactStats,
                      label: context.tr(
                        loc.AppStrings.driverCurrentOrdersLabel,
                      ),
                      value: '$ordersCount',
                      icon: Icons.assignment_outlined,
                      color: AppColors.primaryBlue,
                      helper: context.tr(
                        loc.AppStrings.driverCurrentOrdersHelper,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _DriverStatCard(
                      compact: compactStats,
                      label: context.tr(loc.AppStrings.driverWaitingLoadLabel),
                      value: '$loadingCount',
                      icon: Icons.local_gas_station_outlined,
                      color: AppColors.statusGold,
                      helper: context.tr(
                        loc.AppStrings.driverWaitingLoadHelper,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _DriverStatCard(
                      compact: compactStats,
                      label: context.tr(loc.AppStrings.driverDeliveringLabel),
                      value: '$deliveringCount',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.secondaryTeal,
                      helper: context.tr(loc.AppStrings.driverDeliveringHelper),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _DriverStatCard(
                      compact: compactStats,
                      label: context.tr(loc.AppStrings.driverCompletedLabel),
                      value: '$completedCount',
                      icon: Icons.task_alt_rounded,
                      color: AppColors.successGreen,
                      helper: context.tr(loc.AppStrings.driverCompletedHelper),
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

  Widget _buildWelcomeContent(String userName, bool isOrdersTab) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isNarrow ? 48 : 60,
          height: isNarrow ? 48 : 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.appBarWaterGlow,
                AppColors.appBarWaterBright,
                AppColors.appBarWaterDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.drive_eta_rounded,
            color: Colors.white,
            size: isNarrow ? 22 : 28,
          ),
        ),
        SizedBox(width: isNarrow ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(loc.AppStrings.driverWelcomeTemplate, {
                  'name': userName,
                }),
                style: TextStyle(
                  fontSize: isNarrow ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: isNarrow ? 4 : 6),
              Text(
                isOrdersTab
                    ? context.tr(loc.AppStrings.driverWelcomeOrdersSubtitle)
                    : context.tr(
                        loc.AppStrings.driverWelcomeNotificationsSubtitle,
                      ),
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  fontSize: isNarrow ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersSectionContent(
    OrderProvider orderProvider,
    List<Order> orders,
  ) {
    if (orderProvider.isLoading && orders.isEmpty) {
      return TrackingStateCard(
        icon: Icons.sync_rounded,
        title: context.tr(loc.AppStrings.driverLoadingOrdersTitle),
        message: context.tr(loc.AppStrings.driverLoadingOrdersMessage),
        color: AppColors.infoBlue,
        action: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }
    if (orderProvider.error != null && orders.isEmpty) {
      return TrackingStateCard(
        icon: Icons.error_outline_rounded,
        title: context.tr(loc.AppStrings.driverLoadOrdersErrorTitle),
        message:
            orderProvider.error ??
            context.tr(loc.AppStrings.driverLoadingOrdersMessage),
        color: AppColors.errorRed,
        action: FilledButton.icon(
          onPressed: _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.tr(loc.AppStrings.driverRetry)),
        ),
      );
    }
    if (orders.isEmpty) {
      return TrackingStateCard(
        icon: Icons.assignment_outlined,
        title: context.tr(loc.AppStrings.driverNoOrdersTitle),
        message: context.tr(loc.AppStrings.driverNoOrdersMessage),
        color: AppColors.primaryBlue,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1320 ? 2 : 1;
        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: orders
              .map(
                (order) =>
                    SizedBox(width: cardWidth, child: _buildOrderCard(order)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    final color = _statusColor(order.status);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;
    return AppSurfaceCard(
      padding: EdgeInsets.all(isNarrow ? 14 : 18),
      color: Colors.white.withValues(alpha: 0.82),
      border: Border.all(color: color.withValues(alpha: 0.16)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isNarrow ? 44 : 52,
                height: isNarrow ? 44 : 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: color,
                  size: isNarrow ? 21 : 26,
                ),
              ),
              SizedBox(width: isNarrow ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(loc.AppStrings.driverOrderNumberTemplate, {
                        'number': '${order.orderNumber}',
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isNarrow ? 16 : 19,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: isNarrow ? 2 : 4),
                    Text(
                      _stageLabel(order),
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: isNarrow ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isNarrow ? 8 : 10),
              TrackingStatusBadge(
                label: _localizedStatus(order.status),
                color: color,
                icon: Icons.flag_outlined,
              ),
            ],
          ),
          SizedBox(height: isNarrow ? 12 : 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.local_gas_station_outlined,
                label: _localizedFuelType(order.fuelType),
                color: AppColors.statusGold,
              ),
              _InfoChip(
                icon: Icons.scale_outlined,
                label: _formatQuantity(order),
                color: AppColors.infoBlue,
              ),
            ],
          ),
          SizedBox(height: isNarrow ? 12 : 14),
          _DriverOrderInfoRow(
            label: context.tr(loc.AppStrings.driverCurrentDestinationLabel),
            value: _destinationText(order),
          ),
          _DriverOrderInfoRow(
            label: context.tr(loc.AppStrings.driverArrivalTimeLabel),
            value: '${_formatDate(order.arrivalDate)} • ${order.arrivalTime}',
          ),
          _DriverOrderInfoRow(
            label: context.tr(loc.AppStrings.driverLoadingTimeLabel),
            value: '${_formatDate(order.loadingDate)} • ${order.loadingTime}',
          ),
          if (order.actualLoadedLiters != null) ...[
            SizedBox(height: isNarrow ? 8 : 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isNarrow ? 10 : 12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(loc.AppStrings.driverActualLoadingDataTitle),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.actualLoadedLiters!.toStringAsFixed(order.actualLoadedLiters! % 1 == 0 ? 0 : 2)} '
                    '${context.tr(loc.AppStrings.driverLitersUnit)} • '
                    '${_localizedFuelType(order.actualFuelType)}',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isNarrow ? 14 : 16),
          SizedBox(
            width: double.infinity,
            child: SlideActionButton(
              label: context.tr(loc.AppStrings.driverSlideToStart),
              onSubmit: () => _startOrder(order),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSectionContent(
    NotificationProvider notificationProvider,
  ) {
    if (notificationProvider.isLoading &&
        notificationProvider.notifications.isEmpty) {
      return TrackingStateCard(
        icon: Icons.notifications_active_outlined,
        title: context.tr(loc.AppStrings.driverLoadingNotificationsTitle),
        message: context.tr(loc.AppStrings.driverLoadingNotificationsMessage),
        color: AppColors.infoBlue,
        action: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }
    if (notificationProvider.error != null &&
        notificationProvider.notifications.isEmpty) {
      return TrackingStateCard(
        icon: Icons.error_outline_rounded,
        title: context.tr(loc.AppStrings.driverLoadNotificationsErrorTitle),
        message:
            notificationProvider.error ??
            context.tr(loc.AppStrings.driverLoadingNotificationsMessage),
        color: AppColors.errorRed,
        action: FilledButton.icon(
          onPressed: _refreshAll,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.tr(loc.AppStrings.driverRetry)),
        ),
      );
    }
    if (notificationProvider.notifications.isEmpty) {
      return TrackingStateCard(
        icon: Icons.notifications_none,
        title: context.tr(loc.AppStrings.driverNoNotificationsTitle),
        message: context.tr(loc.AppStrings.driverNoNotificationsMessage),
        color: AppColors.primaryBlue,
      );
    }
    return Column(
      children: notificationProvider.notifications
          .map(
            (notification) => NotificationItem(
              notification: notification,
              currentUserId: notificationProvider.getCurrentUserId(),
              onTap: () => _handleNotificationTap(notification),
              onDelete: () =>
                  notificationProvider.deleteNotification(notification.id),
            ),
          )
          .toList(),
    );
  }
}

/* -----------------------------------------------------------------
   الأدوات المساعدة (Cards، Chips …) – لا تعديل ضروري
   ----------------------------------------------------------------- */
class _DriverSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? badge;
  final Widget? action;
  const _DriverSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.badge,
    this.action,
  });
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    return AppSurfaceCard(
      padding: EdgeInsets.all(isNarrow ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isNarrow ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: isNarrow ? 4 : 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      fontSize: isNarrow ? 12.5 : 14,
                    ),
                  ),
                ],
              );
              final trailing = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (badge != null) badge!,
                  if (action != null) action!,
                ],
              );
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: 12),
                    trailing,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  SizedBox(height: isNarrow ? 12 : 14),
                  trailing,
                ],
              );
            },
          ),
          SizedBox(height: isNarrow ? 14 : 18),
          child,
        ],
      ),
    );
  }
}

class _DriverStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String helper;
  final bool compact;
  const _DriverStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.helper,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    if (compact) {
      return AppSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w800,
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
    }
    return AppSurfaceCard(
      padding: EdgeInsets.all(isNarrow ? 14 : 16),
      color: Colors.white.withValues(alpha: 0.72),
      border: Border.all(color: color.withValues(alpha: 0.12)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      child: Row(
        children: [
          Container(
            width: isNarrow ? 40 : 46,
            height: isNarrow ? 40 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: isNarrow ? 20 : 24),
          ),
          SizedBox(width: isNarrow ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isNarrow ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w800,
                    fontSize: isNarrow ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: isNarrow ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverOrderInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _DriverOrderInfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    return Padding(
      padding: EdgeInsets.only(bottom: isNarrow ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isNarrow ? 96 : 122,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w800,
                fontSize: isNarrow ? 12 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                height: 1.4,
                fontSize: isNarrow ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 420;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 10 : 12,
        vertical: isNarrow ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isNarrow ? 13 : 15, color: color),
          SizedBox(width: isNarrow ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: isNarrow ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
