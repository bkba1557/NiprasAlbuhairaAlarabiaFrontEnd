import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/utils/constants.dart';

class ExpenseItem extends StatelessWidget {
  final Expense expense;

  const ExpenseItem({super.key, required this.expense});

  IconData _getExpenseIcon(String category) {
    switch (category) {
      case 'مرتبات':
        return Icons.person;
      case 'صيانة':
        return Icons.build;
      case 'كهرباء':
        return Icons.bolt;
      case 'إيجار':
        return Icons.home;
      default:
        return Icons.money_off;
    }
  }

  Color _getExpenseColor(String category) {
    switch (category) {
      case 'مرتبات':
        return AppColors.primaryBlue;
      case 'صيانة':
        return AppColors.warningOrange;
      case 'كهرباء':
        return AppColors.infoBlue;
      case 'إيجار':
        return AppColors.secondaryTeal;
      default:
        return AppColors.mediumGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getExpenseColor(expense.category).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getExpenseIcon(expense.category),
              color: _getExpenseColor(expense.category),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getExpenseColor(
                          expense.category,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getExpenseColor(
                            expense.category,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        expense.category,
                        style: TextStyle(
                          color: _getExpenseColor(expense.category),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (expense.approvedByName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.successGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: AppColors.successGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'معتمد',
                                style: TextStyle(
                                  color: AppColors.successGreen,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${expense.amount.toStringAsFixed(2)} ريال',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.errorRed,
                ),
              ),
              if (expense.approvedByName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'بواسطة ${expense.approvedByName!}',
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
