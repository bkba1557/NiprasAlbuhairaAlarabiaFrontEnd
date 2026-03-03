import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class FilterDialog extends StatelessWidget {
  final List<String> departments;
  final List<String> statuses;
  final String selectedDepartment;
  final String selectedStatus;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const FilterDialog({
    super.key,
    required this.departments,
    required this.statuses,
    required this.selectedDepartment,
    required this.selectedStatus,
    required this.onDepartmentChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تصفية الموظفين'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedDepartment,
              decoration: _inputDecoration('القسم'),
              items: departments
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onDepartmentChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: _inputDecoration('الحالة'),
              items: statuses
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onStatusChanged(value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onClear,
          child: const Text('مسح'),
        ),
        ElevatedButton(
          onPressed: onApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.hrPurple,
          ),
          child: const Text('تطبيق'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: AppColors.glassBlue.withOpacity(0.1),
    );
  }
}
