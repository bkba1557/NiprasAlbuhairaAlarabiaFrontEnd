import 'package:flutter/material.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class PenaltyFormScreen extends StatefulWidget {
  const PenaltyFormScreen({super.key});

  @override
  State<PenaltyFormScreen> createState() => _PenaltyFormScreenState();
}

class _PenaltyFormScreenState extends State<PenaltyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'تأخير';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final provider = Provider.of<HRProvider>(context, listen: false);
      await provider.issuePenalty({
        'employeeId': _employeeIdController.text.trim(),
        'type': _type,
        'description': _descriptionController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الجزاء بنجاح'),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل جزاء')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _employeeIdController,
              decoration: const InputDecoration(
                labelText: 'رقم الموظف (EmployeeId)',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'نوع الجزاء',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'تأخير', child: Text('تأخير')),
                DropdownMenuItem(value: 'غياب', child: Text('غياب')),
                DropdownMenuItem(value: 'مخالفة', child: Text('مخالفة')),
                DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قيمة الجزاء',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الجزاء'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warningOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
