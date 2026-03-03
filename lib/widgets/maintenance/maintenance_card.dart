import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaintenanceCard extends StatelessWidget {
  final dynamic record;
  final VoidCallback onTap;

  const MaintenanceCard({super.key, required this.record, required this.onTap, required bool isLargeScreen});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مكتمل':
        return Colors.green;
      case 'غير مكتمل':
        return Colors.red;
      case 'تحت المراجعة':
        return Colors.orange;
      case 'مرفوض':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedDays = record['completedDays'] ?? 0;
    final totalDays = record['totalDays'] ?? 30;
    final completionRate = totalDays > 0
        ? ((completedDays / totalDays) * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with plate number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record['plateNumber'] ?? 'غير محدد',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        record['driverName'] ?? 'غير محدد',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        record['monthlyStatus'] ?? 'غير مكتمل',
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(
                          record['monthlyStatus'] ?? 'غير مكتمل',
                        ),
                      ),
                    ),
                    child: Text(
                      record['monthlyStatus'] ?? 'غير مكتمل',
                      style: TextStyle(
                        color: _getStatusColor(
                          record['monthlyStatus'] ?? 'غير مكتمل',
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'نسبة الإنجاز: $completionRate%',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text('$completedDays/$totalDays يوم'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: completedDays / totalDays,
                    backgroundColor: Colors.grey.shade200,
                    color: _getStatusColor(
                      record['monthlyStatus'] ?? 'غير مكتمل',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Footer with details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_gas_station,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record['tankNumber'] ?? 'غير محدد',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat(
                      'MMM yyyy',
                    ).format(DateTime.parse('${record['inspectionMonth']}-01')),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
