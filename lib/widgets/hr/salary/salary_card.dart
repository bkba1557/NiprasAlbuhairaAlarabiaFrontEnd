import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:intl/intl.dart';

class SalaryCard extends StatelessWidget {
  final Salary salary;
  final VoidCallback onTap;
  final VoidCallback? onPay;
  final VoidCallback? onApprove;
  final VoidCallback onExport;
  final VoidCallback onViewDetails;

  const SalaryCard({
    super.key,
    required this.salary,
    required this.onTap,
    this.onPay,
    this.onApprove,
    required this.onExport,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(salary.status);
    final statusIcon = _getStatusIcon(salary.status);
    final formattedDate = salary.createdAt != null
        ? DateFormat('yyyy/MM/dd', 'ar').format(salary.createdAt)
        : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الرأس: معلومات الموظف والحالة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salary.employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          salary.employeeNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mediumGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          salary.employeeId,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.lightGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          salary.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // معلومات الراتب
              Row(
                children: [
                  _buildInfoItem(
                    'الشهر',
                    salary.formattedMonthYear,
                    Icons.calendar_month,
                    AppColors.hrPurple,
                  ),
                  const SizedBox(width: 16),
                  _buildInfoItem(
                    'الراتب الصافي',
                    salary.formattedNetSalary,
                    Icons.attach_money,
                    AppColors.successGreen,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // تفاصيل الدخل والخصومات
              _buildEarningsAndDeductions(),

              const SizedBox(height: 16),

              // معلومات الدفع (إذا كانت مدفوعة)
              if (salary.isPaid && salary.paymentDate != null)
                _buildPaymentInfo(),

              const SizedBox(height: 16),

              // أزرار الإجراءات
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مسودة':
        return AppColors.salaryDraft;
      case 'معتمد':
        return AppColors.salaryApproved;
      case 'مصرف':
        return AppColors.salaryPaid;
      case 'ملغي':
        return AppColors.salaryCancelled;
      default:
        return AppColors.lightGray;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'مسودة':
        return Icons.drafts;
      case 'معتمد':
        return Icons.verified;
      case 'مصرف':
        return Icons.check_circle;
      case 'ملغي':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildInfoItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsAndDeductions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تفاصيل الراتب',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('الدخل', salary.formattedTotalEarnings, true),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    'الخصومات',
                    salary.formattedTotalDeductions,
                    false,
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    'الصافي',
                    salary.formattedNetSalary,
                    true,
                    isBold: true,
                  ),
                ],
              ),
            ),
            if (salary.deductions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.hrLightPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.list,
                        size: 16,
                        color: AppColors.hrPurple,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${salary.deductions.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.hrPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'خصومات',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.hrPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isEarning, {
    bool isBold = false,
  }) {
    final textColor = isEarning ? AppColors.successGreen : AppColors.errorRed;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.mediumGray,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isBold ? AppColors.darkGray : textColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment, size: 16, color: AppColors.successGreen),
              SizedBox(width: 8),
              Text(
                'معلومات الدفع',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentDetail(
                'التاريخ',
                DateFormat('yyyy/MM/dd', 'ar').format(salary.paymentDate!),
              ),
              const SizedBox(width: 16),
              _buildPaymentDetail(
                'الطريقة',
                salary.paymentMethod ?? 'غير محدد',
              ),
            ],
          ),
          if (salary.transactionReference != null &&
              salary.transactionReference!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildPaymentDetail(
                'رقم المرجع',
                salary.transactionReference!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetail(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // زر التفاصيل
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('عرض'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: AppColors.hrPurple),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // زر التصدير
        OutlinedButton(
          onPressed: onExport,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: const BorderSide(color: AppColors.infoBlue),
          ),
          child: const Icon(
            Icons.download,
            size: 18,
            color: AppColors.infoBlue,
          ),
        ),

        const SizedBox(width: 8),

        // زر الموافقة أو الدفع حسب الحالة
        if (!salary.isPaid && salary.isApproved && onPay != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('دفع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

        if (!salary.isApproved && !salary.isPaid && onApprove != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.verified, size: 16),
              label: const Text('اعتماد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warningOrange,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
      ],
    );
  }
}
