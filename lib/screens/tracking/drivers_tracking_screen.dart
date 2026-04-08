import 'dart:async';

import 'package:flutter/material.dart';
import 'package:order_tracker/models/driver_tracking_models.dart';
import 'package:order_tracker/providers/driver_tracking_provider.dart';
import 'package:order_tracker/screens/tracking/driver_live_tracking_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/tracking/tracking_page_shell.dart';
import 'package:provider/provider.dart';

class DriversTrackingScreen extends StatefulWidget {
  const DriversTrackingScreen({super.key});

  @override
  State<DriversTrackingScreen> createState() => _DriversTrackingScreenState();
}

class _DriversTrackingScreenState extends State<DriversTrackingScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverTrackingProvider>().fetchTrackingDrivers();
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => context.read<DriverTrackingProvider>().fetchTrackingDrivers(
        silent: true,
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Color _driverAvailabilityColor(DriverTrackingSummary summary) {
    if (summary.hasActiveOrder) return AppColors.statusGold;

    final status = summary.driver.status.trim();
    if (status == 'في إجازة') return AppColors.pendingYellow;
    if (status == 'مرفود' || status == 'غير نشط') return AppColors.errorRed;
    return AppColors.successGreen;
  }

  String _driverAvailabilityLabel(DriverTrackingSummary summary) {
    if (summary.hasActiveOrder) return 'معه طلب';

    final status = summary.driver.status.trim();
    if (status == 'في إجازة') return 'إجازة';
    if (status == 'مرفود') return 'مرفود';
    if (status == 'غير نشط') return 'غير نشط';
    if (status.isNotEmpty) return status;
    return 'فاضي';
  }

  List<DriverTrackingSummary> _applySearch(List<DriverTrackingSummary> items) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return items;

    return items.where((summary) {
      final driver = summary.driver;
      return driver.name.toLowerCase().contains(q) ||
          driver.phone.toLowerCase().contains(q) ||
          driver.licenseNumber.toLowerCase().contains(q) ||
          (driver.vehicleNumber ?? '').toLowerCase().contains(q) ||
          (driver.linkedTankerNumber ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openLiveTracking(DriverTrackingSummary summary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverLiveTrackingScreen(driverId: summary.driver.id),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}/${_twoDigits(local.month)}/${_twoDigits(local.day)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverTrackingProvider>(
      builder: (context, provider, _) {
        final allItems = provider.drivers;
        final items = _applySearch(allItems);
        final activeOrders = allItems
            .where((item) => item.hasActiveOrder)
            .length;
        final availableDrivers = allItems
            .where((item) => !item.hasActiveOrder && item.driver.isActive)
            .length;
        final liveDrivers = allItems
            .where((item) => item.lastLocation != null)
            .length;

        return RefreshIndicator(
          onRefresh: () => provider.fetchTrackingDrivers(silent: true),
          child: TrackingPageShell(
            icon: Icons.person_pin_circle_rounded,
            title: 'متابعة السائقين',
            subtitle:
                'عرض حالة السائقين الحالية، ارتباطهم بالطلبات، وآخر نقاط التتبع الواردة من التطبيق.',
            metrics: [
              TrackingMetric(
                label: 'إجمالي السائقين',
                value: '${allItems.length}',
                icon: Icons.people_alt_rounded,
                color: AppColors.primaryBlue,
                helper: 'كل السائقين المرتبطين بالمتابعة',
              ),
              TrackingMetric(
                label: 'متاحون حالياً',
                value: '$availableDrivers',
                icon: Icons.check_circle_rounded,
                color: AppColors.successGreen,
                helper: 'سائقون بلا طلبات بحالة في المستودع',
              ),
              TrackingMetric(
                label: 'طلبات بالمستودع',
                value: '$activeOrders',
                icon: Icons.assignment_turned_in_rounded,
                color: AppColors.statusGold,
                helper: 'سائقون مرتبطون بطلبات حالتها في المستودع فقط',
              ),
              TrackingMetric(
                label: 'مواقع حية',
                value: '$liveDrivers',
                icon: Icons.my_location_rounded,
                color: AppColors.secondaryTeal,
                helper: 'وصلتهم تحديثات موقع حديثة',
              ),
            ],
            headerActions: _buildHeaderActions(provider),
            toolbar: _buildToolbar(items.length),
            child: _buildContent(provider, items),
          ),
        );
      },
    );
  }

  Widget _buildHeaderActions(DriverTrackingProvider provider) {
    return FilledButton.icon(
      onPressed: provider.isLoading
          ? null
          : () => provider.fetchTrackingDrivers(silent: true),
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('تحديث الآن'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildToolbar(int resultCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final chips = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            TrackingStatusBadge(
              label: '$resultCount نتيجة',
              color: AppColors.infoBlue,
              icon: Icons.filter_list_rounded,
            ),
            const TrackingStatusBadge(
              label: 'تحديث تلقائي كل 12 ثانية',
              color: AppColors.secondaryTeal,
              icon: Icons.timer_outlined,
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: TrackingSearchField(
                  controller: _searchController,
                  hintText: 'ابحث باسم السائق أو الهاتف أو رقم المركبة...',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              chips,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackingSearchField(
              controller: _searchController,
              hintText: 'ابحث باسم السائق أو الهاتف أو رقم المركبة...',
              onChanged: (_) => setState(() {}),
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            chips,
          ],
        );
      },
    );
  }

  Widget _buildContent(
    DriverTrackingProvider provider,
    List<DriverTrackingSummary> items,
  ) {
    if (provider.isLoading && provider.drivers.isEmpty) {
      return const TrackingStateCard(
        icon: Icons.person_search_rounded,
        title: 'جاري تحميل السائقين',
        message: 'يتم الآن تجهيز قائمة السائقين وحالات المتابعة الحالية.',
        color: AppColors.infoBlue,
        action: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }

    if (provider.error != null && provider.drivers.isEmpty) {
      return TrackingStateCard(
        icon: Icons.error_outline_rounded,
        title: 'تعذر تحميل السائقين',
        message: provider.error ?? 'تعذر جلب بيانات السائقين حالياً.',
        color: AppColors.errorRed,
        action: FilledButton.icon(
          onPressed: () => provider.fetchTrackingDrivers(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }

    if (items.isEmpty) {
      return TrackingStateCard(
        icon: Icons.person_off_outlined,
        title: 'لا توجد نتائج حالياً',
        message: _searchController.text.trim().isEmpty
            ? 'لا توجد بيانات متابعة متاحة للسائقين حالياً.'
            : 'لم يتم العثور على سائقين مطابقين للبحث الحالي.',
        color: AppColors.primaryBlue,
        action: _searchController.text.trim().isEmpty
            ? null
            : OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('مسح البحث'),
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1320 ? 3 : (width >= 860 ? 2 : 1);
        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (summary) => SizedBox(
                  width: cardWidth,
                  child: _buildDriverCard(summary, provider),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildDriverCard(
    DriverTrackingSummary summary,
    DriverTrackingProvider provider,
  ) {
    final color = _driverAvailabilityColor(summary);
    final label = _driverAvailabilityLabel(summary);
    final orderColor = summary.hasActiveOrder
        ? AppColors.statusGold
        : AppColors.infoBlue;
    final lastLocation = summary.lastLocation;
    final lastUpdateText = lastLocation == null
        ? 'لا يوجد تتبع مباشر'
        : 'آخر تحديث ${_formatTimestamp(lastLocation.timestamp)}';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      color: Colors.white.withValues(alpha: 0.82),
      border: Border.all(color: color.withValues(alpha: 0.18)),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.person_pin_circle_rounded,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.driver.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.driver.vehicleType.trim().isEmpty
                          ? 'بدون نوع مركبة'
                          : summary.driver.vehicleType,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TrackingStatusBadge(
                label: label,
                color: color,
                icon: summary.hasActiveOrder
                    ? Icons.assignment_turned_in_rounded
                    : Icons.circle_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone_rounded, summary.driver.phone),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.directions_car_filled_outlined,
            summary.driver.vehicleNumber?.trim().isNotEmpty == true
                ? 'مركبة ${summary.driver.vehicleNumber}'
                : 'لا يوجد رقم مركبة',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.local_shipping_outlined,
            summary.driver.linkedTankerNumber?.trim().isNotEmpty == true
                ? 'صهريج ${summary.driver.linkedTankerNumber}'
                : 'لا يوجد صهريج مرتبط',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.badge_outlined, summary.driver.licenseNumber),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.schedule_rounded, lastUpdateText),
          if (summary.activeOrder != null &&
              summary.activeOrder!.orderNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: orderColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: orderColor.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${summary.hasActiveOrder ? 'طلب بالمستودع' : 'الطلب الحالي'} ${summary.activeOrder!.orderNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: summary.hasActiveOrder
                          ? const Color(0xFF7C5A03)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.activeOrder!.status,
                    style: TextStyle(
                      color: summary.hasActiveOrder
                          ? const Color(0xFF92400E)
                          : const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openLiveTracking(summary),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('عرض المسار'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.infoBlue.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'تحديث القائمة',
                onPressed: provider.isLoading
                    ? null
                    : () => provider.fetchTrackingDrivers(silent: true),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: AppColors.primaryBlue,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
