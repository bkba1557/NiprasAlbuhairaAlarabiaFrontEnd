import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class PenaltyCard extends StatelessWidget {
  final Penalty penalty;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;
  final VoidCallback? onAppeal;

  const PenaltyCard({
    super.key,
    required this.penalty,
    required this.onTap,
    this.onApprove,
    this.onCancel,
    this.onAppeal,
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
                penalty.employeeName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('المبلغ: ${penalty.formattedAmount}'),
              Text('الحالة: ${penalty.status}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (onApprove != null)
                    _actionButton('موافقة', onApprove!, AppColors.successGreen),
                  if (onCancel != null)
                    _actionButton('إلغاء', onCancel!, AppColors.infoBlue),
                  if (onAppeal != null)
                    _actionButton('تظلم', onAppeal!, AppColors.warningOrange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed, Color color) {
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
