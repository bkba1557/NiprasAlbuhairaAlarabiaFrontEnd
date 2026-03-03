import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class LocationFilterDialog extends StatefulWidget {
  final String selectedType;
  final String selectedStatus;
  final String selectedSort;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const LocationFilterDialog({
    super.key,
    required this.selectedType,
    required this.selectedStatus,
    required this.selectedSort,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<LocationFilterDialog> createState() => _LocationFilterDialogState();
}

class _LocationFilterDialogState extends State<LocationFilterDialog> {
  late String _type;
  late String _status;
  late String _sort;

  final List<String> _typeOptions = [
    'جميع الأنواع',
    'مكتب رئيسي',
    'مستودع',
    'فرع',
  ];
  final List<String> _statusOptions = [
    'جميع الحالات',
    'نشط',
    'غير نشط',
  ];
  final List<String> _sortOptions = [
    'الأحدث',
    'الأقدم',
    'الاسم',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _status = widget.selectedStatus;
    _sort = widget.selectedSort;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فلترة المواقع'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdown('النوع', _type, _typeOptions, (value) {
              setState(() => _type = value);
              widget.onTypeChanged(value);
            }),
            const SizedBox(height: 12),
            _buildDropdown('الحالة', _status, _statusOptions, (value) {
              setState(() => _status = value);
              widget.onStatusChanged(value);
            }),
            const SizedBox(height: 12),
            _buildDropdown('الفرز', _sort, _sortOptions, (value) {
              setState(() => _sort = value);
              widget.onSortChanged(value);
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onClear, child: const Text('مسح')),
        ElevatedButton(
          onPressed: widget.onApply,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.hrTeal),
          child: const Text('تطبيق'),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> options,
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
      items: options
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
