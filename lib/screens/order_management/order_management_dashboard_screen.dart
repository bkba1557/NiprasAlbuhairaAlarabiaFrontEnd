import 'package:flutter/material.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class OrderManagementDashboardScreen extends StatelessWidget {
  const OrderManagementDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_OrderManagementItem>[
      _OrderManagementItem(
        title: 'إعدادات الضريبة',
        subtitle: 'تعديل نسبة VAT للحسابات',
        icon: Icons.percent_outlined,
        route: AppRoutes.orderManagementTaxSettings,
      ),
      _OrderManagementItem(
        title: 'الخزينة',
        subtitle: 'سندات قبض + أرصدة العملاء',
        icon: Icons.account_balance_wallet_outlined,
        route: AppRoutes.orderManagementTreasury,
      ),
      _OrderManagementItem(
        title: 'حسابات العملاء',
        subtitle: 'كشف حساب + المتبقي',
        icon: Icons.people_alt_outlined,
        route: AppRoutes.orderManagementCustomerAccounts,
      ),
      _OrderManagementItem(
        title: 'تسعيرة الوقود للعملاء',
        subtitle: 'سعر اللتر لكل عميل',
        icon: Icons.local_gas_station_outlined,
        route: AppRoutes.orderManagementFuelPricing,
      ),
      _OrderManagementItem(
        title: 'تسعيرة النقل',
        subtitle: 'إيجار النقل/لتر لكل عميل',
        icon: Icons.price_change_outlined,
        route: AppRoutes.orderManagementTransportPricing,
      ),
      _OrderManagementItem(
        title: 'إدارة طلبات النقل',
        subtitle: 'طلبات (نقل) فقط + فلترة',
        icon: Icons.local_shipping_outlined,
        route: AppRoutes.orderManagementTransportOrders,
      ),
      _OrderManagementItem(
        title: 'تقرير اللترات للعملاء',
        subtitle: 'سحب إجمالي اللترات حسب الفترة',
        icon: Icons.bar_chart_outlined,
        route: AppRoutes.orderManagementCustomerLitersReport,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 1000
                        ? 3
                        : width >= 680
                        ? 2
                        : 1;

                    return GridView.builder(
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: crossAxisCount == 1 ? 2.9 : 2.2,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _OrderManagementCard(item: item);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderManagementItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _OrderManagementItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

class _OrderManagementCard extends StatelessWidget {
  final _OrderManagementItem item;

  const _OrderManagementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      onTap: () => Navigator.pushNamed(context, item.route),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black87.withValues(alpha: 0.66),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_left, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}
