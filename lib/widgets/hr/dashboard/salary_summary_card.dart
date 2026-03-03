import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class SalarySummaryCard extends StatelessWidget {
  final Map<String, dynamic>? salarySummary;
  final bool isLargeScreen;
  final bool isLoading;
  final VoidCallback onViewAll;
  final VoidCallback onGenerateSalaries;

  const SalarySummaryCard({
    super.key,
    required this.salarySummary,
    required this.isLargeScreen,
    required this.isLoading,
    required this.onViewAll,
    required this.onGenerateSalaries,
  });

  @override
  Widget build(BuildContext context) {
    final total = salarySummary?['totalSalary'] ?? salarySummary?['totalSalaries'] ?? 0;
    final paid = salarySummary?['paidCount'] ?? salarySummary?['paidThisMonth'] ?? 0;
    final pending = salarySummary?['pendingCount'] ?? salarySummary?['pendingPayments'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ملخص الرواتب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildStat('الإجمالي', '$total ريال', AppColors.appBarWaterDeep),
                _buildStat('مدفوعة', '$paid راتب', AppColors.appBarWaterBright),
                _buildStat('معلقة', '$pending راتب', AppColors.appBarWaterMid),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: onViewAll, child: const Text('عرض التفاصيل')),
                ElevatedButton(
                  onPressed: onGenerateSalaries,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appBarWaterDeep,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('إنشاء كشوف'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.mediumGray),
          ),
        ],
      ),
    );
  }
}
