import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

class EmploymentInfoSection extends StatelessWidget {
  final String department;
  final String position;
  final String? jobTitle;
  final String employmentType;
  final DateTime? hireDate;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final DateTime? probationPeriodEnd;
  final String workSchedule;
  final int weeklyHours;
  final String? residencyNumber;
  final DateTime? residencyIssueDate;
  final DateTime? residencyExpiryDate;
  final String? passportNumber;
  final DateTime? passportExpiryDate;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onPositionChanged;
  final ValueChanged<String?> onJobTitleChanged;
  final ValueChanged<String> onEmploymentTypeChanged;
  final ValueChanged<DateTime?> onHireDateChanged;
  final ValueChanged<DateTime?> onContractStartDateChanged;
  final ValueChanged<DateTime?> onContractEndDateChanged;
  final ValueChanged<DateTime?> onProbationPeriodEndChanged;
  final ValueChanged<String> onWorkScheduleChanged;
  final ValueChanged<int> onWeeklyHoursChanged;
  final ValueChanged<String?> onResidencyNumberChanged;
  final ValueChanged<DateTime?> onResidencyIssueDateChanged;
  final ValueChanged<DateTime?> onResidencyExpiryDateChanged;
  final ValueChanged<String?> onPassportNumberChanged;
  final ValueChanged<DateTime?> onPassportExpiryDateChanged;

  const EmploymentInfoSection({
    super.key,
    required this.department,
    required this.position,
    required this.jobTitle,
    required this.employmentType,
    required this.hireDate,
    required this.contractStartDate,
    required this.contractEndDate,
    required this.probationPeriodEnd,
    required this.workSchedule,
    required this.weeklyHours,
    required this.residencyNumber,
    required this.residencyIssueDate,
    required this.residencyExpiryDate,
    required this.passportNumber,
    required this.passportExpiryDate,
    required this.onDepartmentChanged,
    required this.onPositionChanged,
    required this.onJobTitleChanged,
    required this.onEmploymentTypeChanged,
    required this.onHireDateChanged,
    required this.onContractStartDateChanged,
    required this.onContractEndDateChanged,
    required this.onProbationPeriodEndChanged,
    required this.onWorkScheduleChanged,
    required this.onWeeklyHoursChanged,
    required this.onResidencyNumberChanged,
    required this.onResidencyIssueDateChanged,
    required this.onResidencyExpiryDateChanged,
    required this.onPassportNumberChanged,
    required this.onPassportExpiryDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField('القسم', department, onDepartmentChanged),
          const SizedBox(height: 12),
          _buildTextField('الوظيفة', position, onPositionChanged),
          const SizedBox(height: 12),
          _buildTextField('المسمى الوظيفي', jobTitle ?? '', onJobTitleChanged),
          const SizedBox(height: 12),
          _buildTextField('نوع التوظيف', employmentType, onEmploymentTypeChanged),
          const SizedBox(height: 12),
          _buildDatePicker(context, 'تاريخ التعيين', hireDate, onHireDateChanged),
          const SizedBox(height: 12),
          _buildDatePicker(
            context,
            'بداية العقد',
            contractStartDate,
            onContractStartDateChanged,
          ),
          const SizedBox(height: 12),
          _buildDatePicker(
            context,
            'نهاية العقد',
            contractEndDate,
            onContractEndDateChanged,
          ),
          const SizedBox(height: 12),
          _buildDatePicker(
            context,
            'نهاية الفترة التجريبية',
            probationPeriodEnd,
            onProbationPeriodEndChanged,
          ),
          const SizedBox(height: 12),
          _buildTextField('جدول العمل', workSchedule, onWorkScheduleChanged),
          const SizedBox(height: 12),
          _buildTextField(
            'ساعات العمل الأسبوعية',
            weeklyHours.toString(),
            (value) {
              final parsed = int.tryParse(value) ?? weeklyHours;
              onWeeklyHoursChanged(parsed);
            },
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'رقم الإقامة',
            residencyNumber ?? '',
            onResidencyNumberChanged,
          ),
          const SizedBox(height: 12),
          _buildDatePicker(
            context,
            'تاريخ إصدار الإقامة',
            residencyIssueDate,
            onResidencyIssueDateChanged,
          ),
          const SizedBox(height: 12),
          _buildDatePicker(
            context,
            'تاريخ انتهاء الإقامة',
            residencyExpiryDate,
            onResidencyExpiryDateChanged,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'رقم الجواز',
            passportNumber ?? '',
            onPassportNumberChanged,
          ),
          const SizedBox(height: 12),
          _buildDatePicker(
            context,
            'تاريخ انتهاء الجواز',
            passportExpiryDate,
            onPassportExpiryDateChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.glassBlue.withOpacity(0.1),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    final formatted = value != null
        ? DateFormat('yyyy/MM/dd').format(value)
        : 'اختر التاريخ';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2050),
          locale: const Locale('ar'),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppColors.glassBlue.withOpacity(0.1),
        ),
        child: Text(formatted),
      ),
    );
  }
}
