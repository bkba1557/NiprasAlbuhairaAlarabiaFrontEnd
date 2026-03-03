import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/utils/constants.dart';

class SessionFilterDialog extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final List<Station> stations;

  const SessionFilterDialog({
    super.key,
    required this.currentFilters,
    required this.stations,
  });

  @override
  State<SessionFilterDialog> createState() => _SessionFilterDialogState();
}

class _SessionFilterDialogState extends State<SessionFilterDialog> {
  String? _status;
  String? _stationId;
  String? _fuelType;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _statuses = ['الكل', 'مفتوحة', 'مغلقة', 'معتمدة', 'ملغاة'];

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
      title: const Text('تصفية الجلسات'),
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
                hint: const Text('جميع المحطات'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('جميع المحطات'),
                  ),
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
          onPressed: () {
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
