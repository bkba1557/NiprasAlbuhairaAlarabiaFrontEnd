import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/utils/constants.dart';

class InventoryFilterDialog extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final List<Station> stations;

  const InventoryFilterDialog({
    super.key,
    required this.currentFilters,
    required this.stations,
  });

  @override
  State<InventoryFilterDialog> createState() => _InventoryFilterDialogState();
}

class _InventoryFilterDialogState extends State<InventoryFilterDialog> {
  String? _status;
  String? _stationId;
  String? _fuelType;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _statuses = ['الكل', 'مسودة', 'مكتمل', 'معتمد', 'ملغى'];

  final List<String> _fuelTypes = [
    'الكل',
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.currentFilters['status'] ?? 'الكل';
    _stationId = widget.currentFilters['stationId'];
    _fuelType = widget.currentFilters['fuelType'];
    _startDate = widget.currentFilters['startDate'];
    _endDate = widget.currentFilters['endDate'];
  }

  Future<void> _selectSingleDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _endDate = picked;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final start = DateTime(picked.year, picked.month, 1);
      final end = DateTime(picked.year, picked.month + 1, 0);
      setState(() {
        _startDate = start;
        _endDate = end;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تصفية الجرد اليومي'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: DropdownButton<String>(
                value: _status,
                isExpanded: true,
                underline: const SizedBox(),
                items: _statuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _status = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Station Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: DropdownButton<String>(
                value: _stationId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('اختر محطة'),
                items: [
                  ...widget.stations.map((station) {
                    return DropdownMenuItem<String>(
                      value: station.id,
                      child: Text(station.stationName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _stationId = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Fuel Type Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: DropdownButton<String>(
                value: _fuelType,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('جميع أنواع الوقود'),
                items: _fuelTypes.map((fuelType) {
                  return DropdownMenuItem<String>(
                    value: fuelType == 'الكل' ? null : fuelType,
                    child: Text(fuelType),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _fuelType = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Date Range Filter
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _selectSingleDay(context),
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('عرض يوم'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _selectMonth(context),
                  icon: const Icon(Icons.calendar_view_month_outlined),
                  label: const Text('عرض شهر'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _startDate != null
                                ? DateFormat('yyyy/MM/dd').format(_startDate!)
                                : 'من تاريخ',
                            style: TextStyle(
                              color: _startDate != null
                                  ? AppColors.darkGray
                                  : AppColors.mediumGray,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _endDate != null
                                ? DateFormat('yyyy/MM/dd').format(_endDate!)
                                : 'إلى تاريخ',
                            style: TextStyle(
                              color: _endDate != null
                                  ? AppColors.darkGray
                                  : AppColors.mediumGray,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _stationId == null
              ? null
              : () {
            final filters = {
              'status': _status == 'الكل' ? null : _status,
              'stationId': _stationId,
              'fuelType': _fuelType,
              'startDate': _startDate,
              'endDate': _endDate,
            };
            Navigator.pop(context, filters);
          },
          child: const Text('تطبيق الفلاتر'),
        ),
      ],
    );
  }
}
