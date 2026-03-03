import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:intl/intl.dart';

class PaySalaryDialog extends StatefulWidget {
  final Salary salary;
  final Future<void> Function(String paymentMethod, DateTime paymentDate) onPay;

  const PaySalaryDialog({super.key, required this.salary, required this.onPay});

  @override
  State<PaySalaryDialog> createState() => _PaySalaryDialogState();
}

class _PaySalaryDialogState extends State<PaySalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _paymentDate;
  String _paymentMethod = 'تحويل بنكي';
  String? _transactionReference;
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paymentDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.salary.employeeName;
    final netSalary = widget.salary.netSalary;
    final monthYear = widget.salary.formattedMonthYear;

    return AlertDialog(
      title: const Text(
        'دفع الراتب',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات الراتب
              _buildSalaryInfo(employee, netSalary, monthYear),

              const SizedBox(height: 20),

              // تاريخ الدفع
              _buildPaymentDateField(),

              const SizedBox(height: 16),

              // طريقة الدفع
              _buildPaymentMethodField(),

              const SizedBox(height: 16),

              // رقم المرجع (للتحويل البنكي)
              if (_paymentMethod == 'تحويل بنكي') _buildReferenceField(),

              const SizedBox(height: 16),

              // ملاحظات
              _buildNotesField(),

              const SizedBox(height: 8),

              // تحذير
              _buildWarning(),
            ],
          ),
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
          onPressed: _submitPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.successGreen,
          ),
          child: const Text('تأكيد الدفع'),
        ),
      ],
    );
  }

  Widget _buildSalaryInfo(String employee, double netSalary, String monthYear) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 18, color: AppColors.hrPurple),
              const SizedBox(width: 8),
              Text(
                employee,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                size: 16,
                color: AppColors.mediumGray,
              ),
              const SizedBox(width: 8),
              Text(
                'شهر $monthYear',
                style: const TextStyle(color: AppColors.mediumGray),
              ),
              const Spacer(),
              Text(
                '${netSalary.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تاريخ الدفع',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectPaymentDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy/MM/dd', 'ar').format(_paymentDate),
                  style: const TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: AppColors.mediumGray,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'طريقة الدفع',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          items: const [
            DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي')),
            DropdownMenuItem(value: 'شيك', child: Text('شيك')),
            DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
          ],
          onChanged: (value) {
            setState(() {
              _paymentMethod = value!;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildReferenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'رقم المرجع البنكي',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _referenceController,
          decoration: const InputDecoration(
            hintText: 'أدخل رقم المرجع',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _transactionReference = value;
          },
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            hintText: 'أضف ملاحظات حول الدفع',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, size: 20, color: AppColors.warningOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تأكد من صحة المعلومات قبل تأكيد الدفع',
              style: TextStyle(fontSize: 12, color: AppColors.warningOrange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPaymentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (date != null) {
      setState(() {
        _paymentDate = date;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_paymentMethod == 'تحويل بنكي' &&
        (_transactionReference == null || _transactionReference!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم المرجع البنكي'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    Navigator.pop(context);

    await widget.onPay(_paymentMethod, _paymentDate);
  }

}
