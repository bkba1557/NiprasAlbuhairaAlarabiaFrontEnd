import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final user = authProvider.user;
    bool hasPermission(String key) => user?.hasPermission(key) ?? false;
    final hasOrderCreation =
        user?.hasAnyPermission([
          'orders_create_customer',
          'orders_create_supplier',
        ]) ??
        false;
    final canViewInventory =
        user?.hasAnyPermission(['inventory_view', 'inventory_manage']) ?? false;
    final canViewActivities =
        user?.hasAnyPermission(['activities_view']) ?? false;
    final canViewTasks =
        user?.hasAnyPermission(['tasks_view', 'tasks_view_all']) ?? false;
    final canViewContracts =
        user?.hasAnyPermission(['contracts_view', 'contracts_manage']) ?? false;
    final canViewArchive =
        user?.hasAnyPermission(['archive_view', 'archive_manage']) ?? false;
    final canViewTracking =
        user?.hasAnyPermission(['drivers_view', 'tracking_view']) ?? false;
    final driverHomeRoute = user?.role == 'driver'
        ? AppRoutes.driverHome
        : AppRoutes.orders;
    final canAccessStationMaintenance =
        [
          'owner',
          'admin',
          'manager',
          'supervisor',
          'maintenance',
          'maintenance_car_management',
          'maintenance_technician',
          'Maintenance_Technician',
        ].contains(user?.role) ||
        (user?.hasAnyPermission([
              'station_maintenance_view',
              'station_maintenance_manage',
            ]) ??
            false);

    return Drawer(
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    user?.name
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .take(2)
                            .join('')
                            .toUpperCase() ??
                        'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (canViewInventory)
                  ListTile(
                    leading: const Icon(Icons.warehouse_outlined),
                    title: const Text('المخزون'),
                    onTap: () {
                      Navigator.popAndPushNamed(
                        context,
                        AppRoutes.inventoryDashboard,
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('لوحة التحكم'),
                  onTap: () {
                    Navigator.popAndPushNamed(
                      context,
                      user?.role == 'driver'
                          ? AppRoutes.driverHome
                          : user?.role == 'archive'
                          ? AppRoutes.movementArchiveOrders
                          : user?.role == 'employee'
                          ? AppRoutes.marketingStations
                          : AppRoutes.dashboard,
                    );
                  },
                ),
                if (hasPermission('orders_view'))
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(
                      user?.role == 'driver' ? 'صفحة السائق' : 'الطلبات',
                    ),
                    trailing: Badge.count(
                      count: 0,
                      textColor: Colors.white,
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    onTap: () {
                      Navigator.popAndPushNamed(context, driverHomeRoute);
                    },
                  ),
                if (hasPermission('customers_view'))
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('العملاء'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, '/customers');
                    },
                  ),
                if (hasPermission('suppliers_view'))
                  ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: const Text('الموردين'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, '/suppliers');
                    },
                  ),
                if (hasPermission('drivers_view'))
                  ListTile(
                    leading: const Icon(Icons.directions_car_outlined),
                    title: const Text('السائقين'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, AppRoutes.drivers);
                    },
                  ),
                if (canViewTracking)
                  ListTile(
                    leading: const Icon(Icons.local_taxi_outlined),
                    title: const Text('السيارات'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, AppRoutes.vehicles);
                    },
                  ),
                if (canViewTracking)
                  ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('الصهاريج'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, AppRoutes.tankers);
                    },
                  ),
                if (hasOrderCreation)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('طلب جديد'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, '/order/form');
                    },
                  ),
                if (canViewActivities)
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('الأنشطة'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, '/activities');
                    },
                  ),
                if (canViewTasks)
                  ListTile(
                    leading: const Icon(Icons.task_alt),
                    title: const Text('المهام'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, AppRoutes.tasks);
                    },
                  ),
                if (canAccessStationMaintenance)
                  ListTile(
                    leading: const Icon(Icons.home_repair_service_outlined),
                    title: const Text('تطوير وصيانة المحطات'),
                    onTap: () {
                      Navigator.popAndPushNamed(
                        context,
                        AppRoutes.stationMaintenanceDashboard,
                      );
                    },
                  ),
                if (canViewContracts)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('إدارة العقود'),
                    onTap: () {
                      Navigator.popAndPushNamed(
                        context,
                        AppRoutes.contractsManagement,
                      );
                    },
                  ),
                if (canViewArchive)
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('أرشفة طلبات الحركة'),
                    onTap: () {
                      Navigator.popAndPushNamed(
                        context,
                        AppRoutes.movementArchiveOrders,
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('الإشعارات'),
                  trailing: notificationProvider.unreadCount > 0
                      ? Badge.count(
                          count: notificationProvider.unreadCount,
                          textColor: Colors.white,
                          backgroundColor: AppColors.errorRed,
                        )
                      : null,
                  onTap: () {
                    Navigator.popAndPushNamed(context, '/notifications');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('الملف الشخصي'),
                  onTap: () {
                    Navigator.popAndPushNamed(context, '/profile');
                  },
                ),
                if (hasPermission('settings_access'))
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('الإعدادات'),
                    onTap: () {
                      Navigator.popAndPushNamed(context, '/settings');
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  title: const Text('الدعم'),
                  onTap: () {
                    Navigator.popAndPushNamed(context, AppRoutes.support);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('حول'),
                  onTap: () {
                    // TODO: About page
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'تسجيل خروج',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('تأكيد الخروج'),
                        content: const Text('هل تريد تسجيل الخروج فعلاً؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await authProvider.logout();
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.front,
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('تسجيل خروج'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
