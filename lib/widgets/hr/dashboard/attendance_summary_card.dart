import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final List<Attendance> attendanceRecords;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAll;

  const AttendanceSummaryCard({
    super.key,
    required this.attendanceRecords,
    required this.isLoading,
    required this.onRefresh,
    required this.onViewAll,
  });

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed[0];
  }

  @override
  Widget build(BuildContext context) {
    final recordsToShow = attendanceRecords.take(3).toList();
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
                  'حضور اليوم',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () {
                    onRefresh();
                  },
                  icon: Icon(
                    Icons.refresh,
                    color: AppColors.appBarWaterBright,
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const LinearProgressIndicator()
            else if (attendanceRecords.isEmpty)
              const Text('لا توجد سجلات حالياً')
            else
              ...recordsToShow.map(
                (attendance) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.appBarWaterBright.withOpacity(0.2),
                    child: Text(_initial(attendance.employeeName)),
                  ),
                  title: Text(attendance.employeeName),
                  subtitle: Text(attendance.status),
                  trailing: Text(attendance.formattedCheckIn),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewAll,
                child: const Text('عرض الكل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
