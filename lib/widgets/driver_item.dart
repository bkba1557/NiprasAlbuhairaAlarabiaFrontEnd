import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/driver_model.dart';

class DriverItem extends StatelessWidget {
  final Driver driver;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? linkedUsername;

  const DriverItem({
    super.key,
    required this.driver,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.linkedUsername,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'نشط':
        return Colors.green;
      case 'غير نشط':
        return Colors.red;
      case 'في إجازة':
        return Colors.orange;
      case 'مرفود':
        return Colors.red;
      case 'معلق':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getVehicleStatusColor(String status) {
    switch (status) {
      case 'في طلب':
        return const Color(0xFFD4AF37);
      case 'تحت الصيانة':
        return Colors.orange;
      case 'فاضي':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool _isNearExpiry(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return !date.isBefore(now) &&
        date.isBefore(now.add(const Duration(days: 30)));
  }

  Widget _buildExpiryRow({
    required IconData icon,
    required String label,
    required DateTime? value,
  }) {
    if (value == null) {
      return const SizedBox.shrink();
    }

    final isNearExpiry = _isNearExpiry(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ${DateFormat('yyyy/MM/dd').format(value)}',
            style: TextStyle(
              color: isNearExpiry ? Colors.red : Colors.grey,
              fontSize: 13,
              fontWeight: isNearExpiry ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(driver.status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= Header =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Driver info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                size: 20,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                driver.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.card_membership,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    driver.licenseNumber,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      driver.phone,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      (driver.nationalId?.trim().isNotEmpty ??
                                              false)
                                          ? driver.nationalId!.trim()
                                          : 'بدون هوية مسجلة',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      linkedUsername?.trim().isNotEmpty == true
                                          ? Icons.verified_user_outlined
                                          : Icons.person_off_outlined,
                                      size: 16,
                                      color:
                                          linkedUsername?.trim().isNotEmpty ==
                                              true
                                          ? Colors.teal
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        linkedUsername?.trim().isNotEmpty == true
                                            ? 'حساب السائق: $linkedUsername'
                                            : 'لا يوجد حساب driver_truck مرتبط',
                                        style: TextStyle(
                                          color:
                                              linkedUsername
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? Colors.teal
                                              : Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ================= Status + Actions =================
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                driver.status,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(driver.status),
                              ),
                            ),
                            child: Text(
                              driver.status,
                              style: TextStyle(
                                color: _getStatusColor(driver.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // 🗑 Delete button
                          if (onDelete != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'حذف السائق',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: onDelete,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Vehicle number
                      if (driver.vehicleNumber != null &&
                          driver.vehicleNumber!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            driver.vehicleNumber!,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (driver.vehicleStatus.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getVehicleStatusColor(
                              driver.vehicleStatus,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            driver.vehicleStatus,
                            style: TextStyle(
                              color: _getVehicleStatusColor(driver.vehicleStatus),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // ================= Additional info =================
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (driver.vehicleType.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.category,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              driver.vehicleType,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((driver.linkedVehiclePlateNumber ?? '')
                        .trim()
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_taxi_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'السيارة: ${driver.linkedVehiclePlateNumber!.trim()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((driver.linkedTankerNumber ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_shipping_outlined,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الصهريج: ${driver.linkedTankerNumber!.trim()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (driver.licenseExpiryDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'انتهاء الرخصة: ${DateFormat('yyyy/MM/dd').format(driver.licenseExpiryDate!)}',
                              style: TextStyle(
                                color:
                                    driver.licenseExpiryDate!.isBefore(
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                    )
                                    ? Colors.red
                                    : Colors.grey,
                                fontSize: 13,
                                fontWeight:
                                    driver.licenseExpiryDate!.isBefore(
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                    )
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),

                    _buildExpiryRow(
                      icon: Icons.badge_outlined,
                      label: 'إصدار الإقامة',
                      value: driver.iqamaIssueDate,
                    ),
                    _buildExpiryRow(
                      icon: Icons.event_busy_outlined,
                      label: 'انتهاء الإقامة',
                      value: driver.iqamaExpiryDate,
                    ),
                    _buildExpiryRow(
                      icon: Icons.health_and_safety_outlined,
                      label: 'انتهاء التأمين',
                      value: driver.insuranceExpiryDate,
                    ),
                    _buildExpiryRow(
                      icon: Icons.credit_card_outlined,
                      label: 'انتهاء بطاقة التشغيل',
                      value: driver.operationCardExpiryDate,
                    ),

                    if (driver.notes != null && driver.notes!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.note,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                driver.notes!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ================= Footer =================
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 40),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تم الإنشاء: ${DateFormat('yyyy/MM/dd').format(driver.createdAt)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    if (driver.createdByName != null)
                      Text(
                        'بواسطة: ${driver.createdByName!}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
