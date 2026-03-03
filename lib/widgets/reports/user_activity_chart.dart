import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:order_tracker/utils/constants.dart';

class UserActivityChart extends StatelessWidget {
  final List<dynamic> users;

  const UserActivityChart({super.key, required this.users, required bool isLargeScreen});

  @override
  Widget build(BuildContext context) {
    final topOrdersUsers = users
        .where((u) => (u['totalOrders'] ?? 0) > 0)
        .take(5)
        .toList();

    final topAmountUsers = users
        .where((u) => (u['totalAmount'] ?? 0) > 0)
        .take(5)
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBarChart(
              title: 'نشاط المستخدمين (عدد الطلبات)',
              data: topOrdersUsers,
              valueKey: 'totalOrders',
              color: AppColors.primaryBlue,
              suffix: '',
            ),
            const SizedBox(height: 16),
            _buildBarChart(
              title: 'المبالغ الإجمالية',
              data: topAmountUsers,
              valueKey: 'totalAmount',
              color: AppColors.successGreen,
              suffix: ' ريال',
            ),
            const SizedBox(height: 16),
            _buildUserDistribution(),
          ],
        ),
      ),
    );
  }

  /// ================= Bar Chart =================
  Widget _buildBarChart({
    required String title,
    required List data,
    required String valueKey,
    required Color color,
    required String suffix,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: 45,
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(width: 0.5),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  BarSeries<dynamic, String>(
                    dataSource: data,
                    xValueMapper: (item, _) => item['userName'] ?? 'غير معروف',
                    yValueMapper: (item, _) => (item[valueKey] ?? 0).toDouble(),
                    color: color,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.middle,
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

  /// ================= Pie Chart =================
  Widget _buildUserDistribution() {
    final Map<String, int> roleCounts = {};

    for (final user in users) {
      final role = user['userRole'] ?? 'غير محدد';
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }

    final roleData = roleCounts.entries
        .map(
          (e) => _RoleData(
            role: e.key,
            count: e.value,
            color: _getRoleColor(e.key),
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع المستخدمين حسب الدور',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: SfCircularChart(
                legend: const Legend(
                  isVisible: true,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CircularSeries>[
                  PieSeries<_RoleData, String>(
                    dataSource: roleData,
                    xValueMapper: (data, _) => data.role,
                    yValueMapper: (data, _) => data.count,
                    pointColorMapper: (data, _) => data.color,
                    dataLabelMapper: (data, _) =>
                        '${data.role} (${data.count})',
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.primaryBlue;
      case 'manager':
        return AppColors.secondaryTeal;
      case 'maintenance':
        return AppColors.successGreen;
      case 'viewer':
        return AppColors.warningOrange;
      default:
        return AppColors.lightGray;
    }
  }
}

/// ================= Model =================
class _RoleData {
  final String role;
  final int count;
  final Color color;

  _RoleData({required this.role, required this.count, required this.color});
}
