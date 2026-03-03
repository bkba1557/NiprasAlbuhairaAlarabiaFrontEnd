import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:intl/intl.dart';

class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onFingerprint;
  final VoidCallback? onFace;
  final VoidCallback? onDevice;
  final VoidCallback? onStatusChange;

  const EmployeeCard({
    super.key,
    required this.employee,
    required this.onTap,
    this.onEdit,
    this.onFingerprint,
    this.onFace,
    this.onDevice,
    this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final padding = isWide ? 12.0 : 16.0;
    final gapSm = isWide ? 6.0 : 8.0;
    final gapMd = isWide ? 8.0 : 12.0;
    final iconSize = isWide ? 14.0 : 16.0;
    final actionIconSize = isWide ? 18.0 : 20.0;
    final actionConstraints = BoxConstraints(
      minWidth: isWide ? 30 : 36,
      minHeight: isWide ? 30 : 36,
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(employee.status),
                    radius: isWide ? 18 : 20,
                    child: Text(
                      employee.name[0],
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
                          employee.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          employee.position,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(employee.status),
                ],
              ),
              SizedBox(height: gapMd),
              Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    size: iconSize,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    employee.employeeId,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.business, size: iconSize, color: AppColors.mediumGray),
                  const SizedBox(width: 6),
                  Text(
                    employee.department,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapSm),
              Row(
                children: [
                  Icon(Icons.phone, size: iconSize, color: AppColors.mediumGray),
                  const SizedBox(width: 6),
                  Text(
                    employee.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapSm),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: iconSize,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${employee.totalSalary} ر.س',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.hrCyan,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    employee.fingerprintEnrolled
                        ? Icons.fingerprint
                        : Icons.fingerprint_outlined,
                    size: iconSize,
                    color: employee.fingerprintEnrolled
                        ? AppColors.successGreen
                        : AppColors.mediumGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    employee.fingerprintEnrolled ? 'مسجلة' : 'غير مسجلة',
                    style: TextStyle(
                      fontSize: 11,
                      color: employee.fingerprintEnrolled
                          ? AppColors.successGreen
                          : AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapSm),
              Row(
                children: [
                  Icon(
                    employee.faceEnrolled
                        ? Icons.face_retouching_natural
                        : Icons.face_retouching_off,
                    size: iconSize,
                    color: employee.faceEnrolled
                        ? AppColors.successGreen
                        : AppColors.mediumGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    employee.faceEnrolled ? 'مسجل' : 'غير مسجل',
                    style: TextStyle(
                      fontSize: 11,
                      color: employee.faceEnrolled
                          ? AppColors.successGreen
                          : AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.phone_android,
                    size: iconSize,
                    color: employee.hasDevice
                        ? AppColors.successGreen
                        : AppColors.mediumGray,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      employee.hasDevice
                          ? 'الجهاز: ${employee.assignedDeviceId}'
                          : 'الجهاز غير مرتبط',
                      style: TextStyle(
                        fontSize: 11,
                        color: employee.hasDevice
                            ? AppColors.successGreen
                            : AppColors.mediumGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: Icon(Icons.edit, size: actionIconSize),
                      onPressed: onEdit,
                      tooltip: 'تعديل',
                      color: AppColors.infoBlue,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                    ),
                  if (onFingerprint != null)
                    IconButton(
                      icon: Icon(Icons.fingerprint, size: actionIconSize),
                      onPressed: onFingerprint,
                      tooltip: 'تسجيل بصمة',
                      color: AppColors.hrPurple,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                    ),
                  if (onFace != null)
                    IconButton(
                      icon: Icon(Icons.face_retouching_natural, size: actionIconSize),
                      onPressed: onFace,
                      tooltip: 'تسجيل الوجه',
                      color: AppColors.hrTeal,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                    ),
                  if (onDevice != null)
                    IconButton(
                      icon: Icon(Icons.phone_android, size: actionIconSize),
                      onPressed: onDevice,
                      tooltip: 'ربط الجهاز',
                      color: AppColors.infoBlue,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                    ),
                  if (onStatusChange != null)
                    IconButton(
                      icon: Icon(Icons.switch_account, size: actionIconSize),
                      onPressed: onStatusChange,
                      tooltip: 'تغيير الحالة',
                      color: AppColors.warningOrange,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: actionConstraints,
                    ),
                  const Spacer(),
                  Text(
                    'منذ ${DateFormat('yyyy/MM/dd').format(employee.hireDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.lightGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'نشط':
        return AppColors.employeeActive;
      case 'موقف':
        return AppColors.employeeSuspended;
      case 'استقال':
        return AppColors.employeeResigned;
      case 'مفصول':
        return AppColors.employeeTerminated;
      case 'إجازة':
        return AppColors.employeeOnLeave;
      default:
        return AppColors.mediumGray;
    }
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        status,
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
