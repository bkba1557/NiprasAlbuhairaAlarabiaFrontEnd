import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class AttendanceReportScreen extends StatelessWidget {
  final String employeeId;
  final int month;
  final int year;

  const AttendanceReportScreen({
    super.key,
    required this.employeeId,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الحضور'),
      ),
      body: Center(
        child: Text('تقرير الحضور للموظف $employeeId - $month/$year'),
      ),
    );
  }
}
