import 'package:flutter/material.dart';
import 'package:order_tracker/localization/app_localizations.dart' as loc;
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/screens/tracking/driver_delivery_tracking_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context.read<OrderProvider>().fetchOrders(
      filters: const {'includeHistory': true},
      silent: true,
    );
  }

  DateTime _combineDateAndTime(DateTime date, String? time) {
    final parts = (time ?? '').trim().split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _isDriverHistoryOrder(Order order) {
    if (order.isFinalStatus) return true;
    final arrivalDeadline = _combineDateAndTime(order.arrivalDate, order.arrivalTime);
    return DateTime.now().isAfter(arrivalDeadline);
  }

  Color _statusColor(String status) {
    switch (status.trim()) {
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

  Future<void> _openOrder(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDeliveryTrackingScreen(initialOrder: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;
    final historyOrders = orders
        .where(_isDriverHistoryOrder)
        .where((o) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return o.orderNumber.toLowerCase().contains(q) ||
              (o.customer?.name.toLowerCase().contains(q) ?? false) ||
              o.supplierName.toLowerCase().contains(q) ||
              (o.movementCustomerName?.toLowerCase().contains(q) ?? false);
        })
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(loc.AppStrings.driverHistoryTitle)),
        actions: [
          IconButton(
            tooltip: context.tr(loc.AppStrings.refreshTooltip),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(loc.AppStrings.driverHistorySubtitle),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: context.tr(loc.AppStrings.searchHint),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (historyOrders.isEmpty)
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(loc.AppStrings.driverHistoryEmptyTitle),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(loc.AppStrings.driverHistoryEmptyMessage),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...historyOrders.map((order) {
                    final color = _statusColor(order.status);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSurfaceCard(
                        onTap: () => _openOrder(order),
                        padding: const EdgeInsets.all(16),
                        border: Border.all(color: color.withValues(alpha: 0.14)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                Icons.history_rounded,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr(
                                      loc.AppStrings.driverOrderNumberTemplate,
                                      {'number': '${order.orderNumber}'},
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (order.movementCustomerName?.trim().isNotEmpty ==
                                                true
                                            ? order.movementCustomerName!.trim()
                                            : order.customer?.name.trim().isNotEmpty ==
                                                    true
                                                ? order.customer!.name.trim()
                                                : order.supplierName)
                                        .trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                order.status.trim(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
