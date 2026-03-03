import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class QuickActionsCard extends StatelessWidget {
  final bool isLargeScreen;
  final VoidCallback onAddEmployee;
  final VoidCallback onAddAttendance;
  final VoidCallback onAddSalary;
  final VoidCallback onAddAdvance;
  final VoidCallback onAddPenalty;
  final VoidCallback onAddLocation;
  final VoidCallback onDeviceRequests;

  const QuickActionsCard({
    super.key,
    required this.isLargeScreen,
    required this.onAddEmployee,
    required this.onAddAttendance,
    required this.onAddSalary,
    required this.onAddAdvance,
    required this.onAddPenalty,
    required this.onAddLocation,
    required this.onDeviceRequests,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _buildAction('موظف جديد', Icons.person_add, onAddEmployee),
      _buildAction('حضور', Icons.access_time, onAddAttendance),
      _buildAction('رواتب', Icons.attach_money, onAddSalary),
      _buildAction('سلفة', Icons.credit_card, onAddAdvance),
      _buildAction('جزاء', Icons.gavel, onAddPenalty),
      _buildAction('موقع', Icons.location_on, onAddLocation),
      _buildAction('طلبات الأجهزة', Icons.devices, onDeviceRequests),
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: actions,
        ),
      ),
    );
  }

  Widget _buildAction(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.appBarWaterDeep,
        foregroundColor: Colors.white,
      ),
    );
  }
}
