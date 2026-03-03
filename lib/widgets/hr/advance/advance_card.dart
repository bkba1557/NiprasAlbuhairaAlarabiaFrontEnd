import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class AdvanceCard extends StatelessWidget {
  final Advance advance;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPay;
  final VoidCallback? onRepayment;

  const AdvanceCard({
    super.key,
    required this.advance,
    required this.onTap,
    this.onApprove,
    this.onReject,
    this.onPay,
    this.onRepayment,
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
              Text(
                advance.employeeName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('الرقم الوظيفي: ${advance.employeeNumber}'),
              const SizedBox(height: 4),
              Text('المبلغ: ${advance.formattedAmount}'),
              const SizedBox(height: 4),
              Text('الحالة: ${advance.status}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (onApprove != null) _buildAction('موافقة', onApprove!, AppColors.successGreen),
                  if (onReject != null) _buildAction('رفض', onReject!, AppColors.errorRed),
                  if (onPay != null) _buildAction('دفع', onPay!, AppColors.infoBlue),
                  if (onRepayment != null) _buildAction('تسديد', onRepayment!, AppColors.hrPurple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(String label, VoidCallback onPressed, Color color) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        foregroundColor: color,
      ),
      child: Text(label),
    );
  }
}
