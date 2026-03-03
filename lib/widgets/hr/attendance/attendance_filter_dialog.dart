import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class AttendanceFilterDialog extends StatefulWidget {
  final String selectedStatus;
  final String selectedDepartment;
  final String selectedSort;
  final bool showManualRecords;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onManualRecordsChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const AttendanceFilterDialog({
    super.key,
    required this.selectedStatus,
    required this.selectedDepartment,
    required this.selectedSort,
    required this.showManualRecords,
    required this.onStatusChanged,
    required this.onDepartmentChanged,
    required this.onSortChanged,
    required this.onManualRecordsChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<AttendanceFilterDialog> createState() => _AttendanceFilterDialogState();
}

class _AttendanceFilterDialogState extends State<AttendanceFilterDialog> {
  late String _status;
  late String _department;
  late String _sort;
  late bool _manual;

  final List<String> _statusOptions = [
    'جميع الحالات',
    'حاضر',
    'متأخر',
    'غائب',
  ];
  final List<String> _departmentOptions = [
    'جميع الأقسام',
    'المبيعات',
    'المحاسبة',
    'العمليات',
  ];
  final List<String> _sortOptions = [
    'الأحدث',
    'الأقدم',
    'الاسم',
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _department = widget.selectedDepartment;
    _sort = widget.selectedSort;
    _manual = widget.showManualRecords;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فلترة الحضور'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdown('الحالة', _status, _statusOptions, (value) {
              setState(() => _status = value);
              widget.onStatusChanged(value);
            }),
            const SizedBox(height: 12),
            _buildDropdown('القسم', _department, _departmentOptions, (value) {
              setState(() => _department = value);
              widget.onDepartmentChanged(value);
            }),
            const SizedBox(height: 12),
            _buildDropdown('الفرز', _sort, _sortOptions, (value) {
              setState(() => _sort = value);
              widget.onSortChanged(value);
            }),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _manual,
              title: const Text('مراكز التسجيل اليدوي'),
              onChanged: (value) {
                setState(() => _manual = value);
                widget.onManualRecordsChanged(value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onClear, child: const Text('مسح')),
        ElevatedButton(
          onPressed: widget.onApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.hrCyan,
          ),
          child: const Text('تطبيق'),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
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
