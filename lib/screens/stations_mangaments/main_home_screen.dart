import 'package:flutter/material.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/chat_floating_button.dart';
import 'package:order_tracker/widgets/stations/service_card.dart';
import 'package:provider/provider.dart';

class MainHomeScreen extends StatelessWidget {
  const MainHomeScreen({super.key});

  bool isisWeb(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1100;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final bool isSalesManager = authProvider.role == 'sales_manager_statiun';

    final bool tablet = isTablet(context);
    final bool isWeb = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isSalesManager, // ❌ إخفاء سهم الرجوع له
        elevation: 2,
        title: const Text(
          'نظام إدارة مبيعات المحطات وتكاليفها',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          // 🔔 الإشعارات
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
          ),

          // 👤 البروفايل (احترافي)
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  // 🔵 Avatar
                  Container(
                    width: isWeb ? 36 : 32,
                    height: isWeb ? 36 : 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.lightTeal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : 'U'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWeb ? 16 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // الاسم في الويب فقط
                  if (isWeb) ...[
                    const SizedBox(width: 10),
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 🚪 تسجيل الخروج (sales_manager فقط)
          if (isSalesManager)
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authProvider.logout();
                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              },
            ),

          const SizedBox(width: 8),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.primaryBlue.withOpacity(0.06),
              AppColors.backgroundGray,
            ],
          ),
        ),
        child: Center(
          // ⭐ يمنع التمدد الزائد على الويب
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.all(isWeb ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================== Welcome Card ==================
                  Card(
                    elevation: isWeb ? 2 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: EdgeInsets.all(isWeb ? 16 : 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحباً ${user?.name ?? ''}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isWeb ? 18 : 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user?.company ?? '',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isWeb ? 13 : 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 12 : 16,
                                    vertical: isWeb ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getGreeting(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isWeb ? 12 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: isWeb ? 56 : 80,
                            height: isWeb ? 40 : 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_gas_station,
                              size: isWeb ? 28 : 40,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ================== Title ==================
                  Text(
                    'الخدمات المتاحة',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ================== Services Grid ==================
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: isWeb
                          ? 4
                          : tablet
                          ? 3
                          : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 10,
                      childAspectRatio: isWeb ? 1.1 : 0.8,
                      children: [
                        // _service(
                        //   context,
                        //   'متابعة الطلبات',
                        //   'إدارة طلبات تزويد الوقود',
                        //   Icons.inventory_2_outlined,
                        //   [AppColors.primaryBlue, AppColors.primaryDarkBlue],
                        //   '/orders',
                        // ),
                        _service(
                          context,
                          'مبيعات المحطات',
                          'إدارة محطات الوقود والمبيعات',
                          Icons.local_gas_station,
                          [AppColors.secondaryTeal, const Color(0xFF1D976C)],
                          '/stations/dashboard',
                        ),
                        _service(
                          context,
                          'إدارة المحطات',
                          'إضافة وتعديل محطات الوقود',
                          Icons.business,
                          [AppColors.warningOrange, Colors.orange],
                          '/stations/list',
                        ),
                        _service(
                          context,
                          'قرائات المضخات',
                          'فتح وإغلاق قرائات المبيعات',
                          Icons.play_circle_outline,
                          [AppColors.successGreen, Colors.green],
                          '/sessions/list',
                        ),
                        _service(
                          context,
                          'المخزون اليومي',
                          'متابعة مخزون الوقود',
                          Icons.inventory,
                          [AppColors.infoBlue, Colors.blue],
                          '/inventory/list',
                        ),
                        _service(
                          context,
                          'المهام اليومية',
                          'متابعة المهام اليومية',
                          Icons.assignment_turned_in,
                          [AppColors.primaryBlue, AppColors.secondaryTeal],
                          AppRoutes.tasks,
                        ),
                        _service(
                          context,
                          'صرف سندات العهدة',
                          'صرف سندات العهدة ومتابعتها',
                          Icons.assignment_turned_in,
                          [AppColors.infoBlue, Colors.blueGrey],
                          AppRoutes.custodyDocuments,
                        ),
                        if (user?.role == 'admin') ...[
                          _service(
                            context,
                            'المستخدمين',
                            'إدارة حسابات المستخدمين',
                            Icons.people_outline,
                            [Colors.pink, Colors.pinkAccent],
                            '',
                          ),
                          // _service(
                          //   context,
                          //   'الإعدادات',
                          //   'إعدادات النظام',
                          //   Icons.settings_outlined,
                          //   [Colors.grey, Colors.grey.shade700],
                          //   '/settings',
                          // ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ================== Quick Stats ==================
                  Card(
                    elevation: isWeb ? 1 : 3,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isWeb ? 10 : 16,
                        horizontal: isWeb ? 12 : 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickStat(
                            Icons.local_gas_station,
                            '12',
                            'محطة',
                            AppColors.primaryBlue,
                            isWeb,
                          ),
                          _buildQuickStat(
                            Icons.play_circle_outline,
                            '48',
                            'جلسة نشطة',
                            AppColors.successGreen,
                            isWeb,
                          ),
                          _buildQuickStat(
                            Icons.attach_money,
                            '٥٠٨٫٢٥٠',
                            'ريال اليوم',
                            AppColors.warningOrange,
                            isWeb,
                          ),
                          _buildQuickStat(
                            Icons.inventory,
                            '٩٨٫٥٪',
                            'مطابقة',
                            AppColors.infoBlue,
                            isWeb,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: const ChatFloatingButton(
        heroTag: 'main_home_chat_fab',
      ),
    );
  }

  // ================== Helpers ==================

  Widget _service(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    List<Color> colors,
    String route,
  ) {
    return ServiceCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      gradient: LinearGradient(colors: colors),
      onTap: route.isEmpty ? null : () => Navigator.pushNamed(context, route),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'مساء الخير';
  }

  Widget _buildQuickStat(
    IconData icon,
    String value,
    String label,
    Color color,
    bool isWeb,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isWeb ? 3 : 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: isWeb ? 18 : 24),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isWeb ? 9 : 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isWeb ? 11 : 12,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }
}
