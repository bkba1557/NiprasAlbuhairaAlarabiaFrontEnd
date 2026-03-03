import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class AttendanceRecordCard extends StatelessWidget {
  final Attendance attendance;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const AttendanceRecordCard({
    super.key,
    required this.attendance,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(attendance.status),
                    radius: 20,
                    child: Text(
                      attendance.employeeName[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attendance.employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          attendance.employeeNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(attendance.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTimeInfo(
                    'الحضور',
                    attendance.formattedCheckIn,
                    attendance.checkIn?.isLate ?? false,
                    Icons.login,
                  ),
                  Container(width: 1, height: 40, color: AppColors.lightGray),
                  _buildTimeInfo(
                    'الانصراف',
                    attendance.formattedCheckOut,
                    attendance.checkOut?.isEarly ?? false,
                    Icons.logout,
                  ),
                  Container(width: 1, height: 40, color: AppColors.lightGray),
                  _buildTimeInfo(
                    'المجموع',
                    '${attendance.formattedTotalHours} س',
                    attendance.overtimeHours != null &&
                        attendance.overtimeHours! > 0,
                    Icons.access_time,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (attendance.isLate)
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: AppColors.attendanceLate,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'تأخير ${attendance.checkIn?.lateMinutes} دقيقة',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.attendanceLate,
                      ),
                    ),
                  ],
                ),
              if (attendance.isEarly)
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: AppColors.attendanceEarly,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'انصراف مبكر ${attendance.checkOut?.earlyMinutes} دقيقة',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.attendanceEarly,
                      ),
                    ),
                  ],
                ),
              if (attendance.checkIn?.locationStatus == 'خارج النطاق')
                Row(
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 16,
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'خارج موقع العمل',
                      style: TextStyle(fontSize: 12, color: AppColors.errorRed),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    attendance.formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.lightGray,
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: onEdit,
                      tooltip: 'تعديل',
                      color: AppColors.infoBlue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(
    String label,
    String time,
    bool hasIssue,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: hasIssue ? AppColors.attendanceLate : AppColors.mediumGray,
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: hasIssue ? AppColors.attendanceLate : AppColors.darkGray,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'حاضر':
        return AppColors.attendancePresent;
      case 'متأخر':
        return AppColors.attendanceLate;
      case 'غياب':
        return AppColors.attendanceAbsent;
      case 'إجازة':
        return AppColors.attendanceLeave;
      case 'عطلة':
        return AppColors.attendanceLeave;
      case 'مبكر':
        return AppColors.attendanceEarly;
      case 'نصف_يوم':
        return AppColors.warningOrange;
      default:
        return AppColors.mediumGray;
    }
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        status.replaceAll('_', ' '),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _getStatusColor(status),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
