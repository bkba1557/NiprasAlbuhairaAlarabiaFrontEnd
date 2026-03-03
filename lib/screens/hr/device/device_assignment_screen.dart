import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class DeviceAssignmentScreen extends StatefulWidget {
  final Employee employee;

  const DeviceAssignmentScreen({super.key, required this.employee});

  @override
  State<DeviceAssignmentScreen> createState() => _DeviceAssignmentScreenState();
}

class _DeviceAssignmentScreenState extends State<DeviceAssignmentScreen> {
  final TextEditingController _deviceController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _deviceController.text = widget.employee.assignedDeviceId ?? '';
  }

  @override
  void dispose() {
    _deviceController.dispose();
    super.dispose();
  }

  Future<void> _assignDevice() async {
    final deviceId = _deviceController.text.trim();
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال معرف الجهاز'),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<HRProvider>(context, listen: false);
      await provider.assignEmployeeDevice(widget.employee.id, deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم ربط الجهاز بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearDevice() async {
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<HRProvider>(context, listen: false);
      await provider.clearEmployeeDevice(widget.employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إزالة ربط الجهاز'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط جهاز الموظف'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الموظف: ${widget.employee.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deviceController,
              decoration: InputDecoration(
                labelText: 'معرف الجهاز',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.glassBlue.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ملاحظة: يتم عرض معرف الجهاز داخل تطبيق الحضور للموظف.',
              style: TextStyle(color: AppColors.mediumGray),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _clearDevice,
                    icon: const Icon(Icons.link_off),
                    label: const Text('إزالة الربط'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _assignDevice,
                    icon: const Icon(Icons.link),
                    label: const Text('حفظ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.hrTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
