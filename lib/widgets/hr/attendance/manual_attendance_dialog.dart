import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

class ManualAttendanceDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onSave;

  const ManualAttendanceDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<ManualAttendanceDialog> createState() => _ManualAttendanceDialogState();
}

class _ManualAttendanceDialogState extends State<ManualAttendanceDialog> {
  final TextEditingController _employeeController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _employeeController.dispose();
    _statusController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل حضور يدوي'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _employeeController,
              decoration: InputDecoration(
                labelText: 'رقم الموظف أو الاسم',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.glassBlue.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _statusController,
              decoration: InputDecoration(
                labelText: 'الحالة (حاضر، متأخر، غائب)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.glassBlue.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'التاريخ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.glassBlue.withOpacity(0.1),
                ),
                child: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.glassBlue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave({
              'employee': _employeeController.text,
              'status': _statusController.text,
              'date': _selectedDate.toIso8601String(),
              'notes': _notesController.text,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.hrCyan),
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}
