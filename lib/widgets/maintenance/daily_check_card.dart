import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyCheckCard extends StatelessWidget {
  final dynamic check;
  final VoidCallback onTap;

  const DailyCheckCard({
    super.key,
    required this.check,
    required this.onTap,
    required bool isLargeScreen,
    required bool isMediumScreen,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      case 'under_review':
        return 'قيد المراجعة';
      case 'pending':
        return 'معلق';
      default:
        return status;
    }
  }

  int _getCompletedChecksCount() {
    int count = 0;
    final checks = [
      'vehicleSafety',
      'driverSafety',
      'electricalMaintenance',
      'mechanicalMaintenance',
      'tankInspection',
      'tiresInspection',
      'brakesInspection',
      'lightsInspection',
      'fluidsCheck',
      'emergencyEquipment',
    ];

    for (var checkType in checks) {
      if (check[checkType] == 'تم') {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 420).clamp(0.9, 1.2);
    final padding = 16.0 * scale;
    final titleSize = 16.0 * scale;
    final bodySize = 12.0 * scale;
    final iconSize = 16.0 * scale;

    final status = check['status']?.toString() ?? 'pending';
    final completedChecks = _getCompletedChecksCount();
    final totalChecks = 10;
    final completionRate = ((completedChecks / totalChecks) * 100)
        .toStringAsFixed(0);

    final inspectionDate = DateTime.tryParse(check['date']?.toString() ?? '');
    final approvedAt = DateTime.tryParse(check['approvedAt']?.toString() ?? '');
    final approvedByName = check['approvedByName']?.toString();
    final rejectedByName = check['rejectedByName']?.toString();
    final reviewedByName = check['reviewedByName']?.toString();
    final supervisorName = check['supervisorName']?.toString();

    final reviewerName = status == 'approved'
        ? (approvedByName ?? reviewedByName ?? supervisorName)
        : status == 'rejected'
            ? (rejectedByName ??
                reviewedByName ??
                supervisorName ??
                approvedByName)
            : null;

    final inspectionTimeText = inspectionDate != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(inspectionDate)
        : '-';

    final approvedTimeText = approvedAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(approvedAt)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= Header =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    inspectionTimeText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: titleSize,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      _translateStatus(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ================= Summary =================
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: completedChecks > 0 ? Colors.green : Colors.grey,
                    size: iconSize,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$completedChecks من $totalChecks إجراء',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: bodySize,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completionRate%',
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              LinearProgressIndicator(
                value: completedChecks / totalChecks,
                backgroundColor: Colors.grey.shade200,
                color: _getStatusColor(status),
              ),

              // ================= Footer =================
              if (check['checkedByName'] != null || reviewerName != null)
                Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),

                    if (check['checkedByName'] != null)
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'تم بواسطة: ${check['checkedByName']}',
                            style: TextStyle(
                              fontSize: bodySize,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                    if (status == 'approved' && reviewerName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'اعتمد بواسطة: $reviewerName',
                            style: TextStyle(
                              fontSize: bodySize,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (status == 'rejected' && reviewerName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.cancel,
                            size: 14,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'رفض بواسطة: $reviewerName',
                            style: TextStyle(
                              fontSize: bodySize,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (approvedTimeText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'وقت الاعتماد: $approvedTimeText',
                        style: TextStyle(
                          fontSize: bodySize - 1,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
