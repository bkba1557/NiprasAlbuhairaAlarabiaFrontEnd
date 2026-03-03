import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class AdvanceFilterDialog extends StatefulWidget {
  final String selectedStatus;
  final String selectedDepartment;
  final String selectedSort;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const AdvanceFilterDialog({
    super.key,
    required this.selectedStatus,
    required this.selectedDepartment,
    required this.selectedSort,
    required this.onStatusChanged,
    required this.onDepartmentChanged,
    required this.onSortChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<AdvanceFilterDialog> createState() => _AdvanceFilterDialogState();
}

class _AdvanceFilterDialogState extends State<AdvanceFilterDialog> {
  late String _status;
  late String _department;
  late String _sort;

  final List<String> _statusOptions = [
    'جميع الحالات',
    'معلق',
    'معتمد',
    'مسدد',
    'متأخر',
  ];
  final List<String> _departmentOptions = [
    'جميع الأقسام',
    'المبيعات',
    'المحاسبة',
    'الخدمات',
  ];
  final List<String> _sortOptions = [
    'الأحدث',
    'الأقدم',
    'المبلغ',
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _department = widget.selectedDepartment;
    _sort = widget.selectedSort;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فلترة السلف'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdown(
              label: 'الحالة',
              value: _status,
              items: _statusOptions,
              onChanged: (value) {
                setState(() => _status = value);
                widget.onStatusChanged(value);
              },
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'القسم',
              value: _department,
              items: _departmentOptions,
              onChanged: (value) {
                setState(() => _department = value);
                widget.onDepartmentChanged(value);
              },
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'الفرز',
              value: _sort,
              items: _sortOptions,
              onChanged: (value) {
                setState(() => _sort = value);
                widget.onSortChanged(value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onClear,
          child: const Text('مسح'),
        ),
        ElevatedButton(
          onPressed: widget.onApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.advanceInstallment,
          ),
          child: const Text('تطبيق'),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.glassBlue.withOpacity(0.1),
      ),
      items: items
          .map((entry) => DropdownMenuItem(value: entry, child: Text(entry)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
