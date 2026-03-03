import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StationFilterDialog extends StatefulWidget {
  const StationFilterDialog({super.key});

  @override
  State<StationFilterDialog> createState() => _StationFilterDialogState();
}

class _StationFilterDialogState extends State<StationFilterDialog> {
  String? _status;
  String? _stationType;
  String? _region;
  String? _city;
  DateTime? _lastMaintenanceFrom;
  DateTime? _lastMaintenanceTo;

  final List<String> _statuses = ['الكل', 'نشطة', 'صيانة', 'متوقفة', 'مغلقة'];
  final List<String> _stationTypes = ['الكل', 'رئيسية', 'فرعية', 'متنقلة'];
  final List<String> _regions = [
    'الكل',
    'الرياض',
    'جدة',
    'مكة',
    'الدمام',
    'المدينة',
  ];
  final List<String> _cities = [
    'الكل',
    'الرياض',
    'جدة',
    'مكة',
    'الدمام',
    'المدينة',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تصفية محطات الوقود'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _status == 'الكل' ? null : _status,
              decoration: InputDecoration(
                labelText: 'حالة المحطة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _statuses.map((String value) {
                return DropdownMenuItem<String>(
                  value: value == 'الكل' ? null : value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _status = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _stationType == 'الكل' ? null : _stationType,
              decoration: InputDecoration(
                labelText: 'نوع المحطة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _stationTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value == 'الكل' ? null : value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _stationType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _region == 'الكل' ? null : _region,
              decoration: InputDecoration(
                labelText: 'المنطقة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _regions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value == 'الكل' ? null : value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _region = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _city == 'الكل' ? null : _city,
              decoration: InputDecoration(
                labelText: 'المدينة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _cities.map((String value) {
                return DropdownMenuItem<String>(
                  value: value == 'الكل' ? null : value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _city = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _lastMaintenanceFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _lastMaintenanceFrom = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _lastMaintenanceFrom != null
                                ? DateFormat(
                                    'yyyy/MM/dd',
                                  ).format(_lastMaintenanceFrom!)
                                : 'من تاريخ الصيانة',
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _lastMaintenanceTo ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _lastMaintenanceTo = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _lastMaintenanceTo != null
                                ? DateFormat(
                                    'yyyy/MM/dd',
                                  ).format(_lastMaintenanceTo!)
                                : 'إلى تاريخ الصيانة',
                          ),
                          const Icon(Icons.calendar_today),
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
            final filters = <String, dynamic>{};
            if (_status != null && _status != 'الكل') {
              filters['status'] = _status!;
            }
            if (_stationType != null && _stationType != 'الكل') {
              filters['stationType'] = _stationType!;
            }
            if (_region != null && _region != 'الكل') {
              filters['region'] = _region!;
            }
            if (_city != null && _city != 'الكل') {
              filters['city'] = _city!;
            }
            if (_lastMaintenanceFrom != null) {
              filters['lastMaintenanceFrom'] = _lastMaintenanceFrom!
                  .toIso8601String();
            }
            if (_lastMaintenanceTo != null) {
              filters['lastMaintenanceTo'] = _lastMaintenanceTo!
                  .toIso8601String();
            }
            Navigator.pop(context, filters);
          },
          child: const Text('تطبيق'),
        ),
      ],
    );
  }
}

