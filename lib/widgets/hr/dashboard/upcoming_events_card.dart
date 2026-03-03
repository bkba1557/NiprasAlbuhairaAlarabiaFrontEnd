import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class UpcomingEventsCard extends StatelessWidget {
  final List<Employee> events;
  final bool isLoading;
  final VoidCallback onViewAll;
  final VoidCallback onAddEvent;

  const UpcomingEventsCard({
    super.key,
    required this.events,
    required this.isLoading,
    required this.onViewAll,
    required this.onAddEvent,
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
    final displayEvents = events.take(4).toList();
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
                  'المناسبات القادمة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (isLoading)
                  const SizedBox(width: 100, child: LinearProgressIndicator())
              ],
            ),
            const SizedBox(height: 12),
            if (displayEvents.isEmpty)
              const Text('لا توجد مناسبات في الوقت الحالي')
            else
              ...displayEvents.map(
                (event) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.appBarWaterBright.withOpacity(0.2),
                    child: Text(_initial(event.name)),
                  ),
                  title: Text(event.name),
                  subtitle: Text('الحالة: ${event.status}'),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: onViewAll, child: const Text('عرض كل')),
                ElevatedButton.icon(
                  onPressed: onAddEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appBarWaterDeep,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
