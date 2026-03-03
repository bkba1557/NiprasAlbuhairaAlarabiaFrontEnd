import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/constants.dart';

class FinancialInfoSection extends StatelessWidget {
  final double basicSalary;
  final double housingAllowance;
  final double transportationAllowance;
  final double otherAllowances;
  final String? bankName;
  final String? iban;
  final String? accountNumber;
  final List<String> selectedLocationIds;
  final List<WorkLocation> availableLocations;
  final ValueChanged<double> onBasicSalaryChanged;
  final ValueChanged<double> onHousingAllowanceChanged;
  final ValueChanged<double> onTransportationAllowanceChanged;
  final ValueChanged<double> onOtherAllowancesChanged;
  final ValueChanged<String?> onBankNameChanged;
  final ValueChanged<String?> onIbanChanged;
  final ValueChanged<String?> onAccountNumberChanged;
  final ValueChanged<List<String>> onLocationsChanged;

  const FinancialInfoSection({
    super.key,
    required this.basicSalary,
    required this.housingAllowance,
    required this.transportationAllowance,
    required this.otherAllowances,
    this.bankName,
    this.iban,
    this.accountNumber,
    required this.selectedLocationIds,
    required this.availableLocations,
    required this.onBasicSalaryChanged,
    required this.onHousingAllowanceChanged,
    required this.onTransportationAllowanceChanged,
    required this.onOtherAllowancesChanged,
    required this.onBankNameChanged,
    required this.onIbanChanged,
    required this.onAccountNumberChanged,
    required this.onLocationsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNumberField(
            'الراتب الأساسي',
            basicSalary,
            onBasicSalaryChanged,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            'بدل السكن',
            housingAllowance,
            onHousingAllowanceChanged,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            'بدل النقل',
            transportationAllowance,
            onTransportationAllowanceChanged,
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            'بدلات أخرى',
            otherAllowances,
            onOtherAllowancesChanged,
          ),
          const SizedBox(height: 12),
          _buildTextField('اسم البنك', bankName ?? '', onBankNameChanged),
          const SizedBox(height: 12),
          _buildTextField('IBAN', iban ?? '', onIbanChanged),
          const SizedBox(height: 12),
          _buildTextField('رقم الحساب', accountNumber ?? '', onAccountNumberChanged),
          const SizedBox(height: 12),
          Text(
            'مواقع العمل',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (availableLocations.isEmpty)
            const Text(
              'لا توجد مواقع عمل حالياً. الرجاء إضافة موقع جديد من إدارة المواقع.',
              style: TextStyle(color: AppColors.mediumGray),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableLocations.map((loc) {
                final selected = selectedLocationIds.contains(loc.id);
                return FilterChip(
                  label: Text('${loc.name} (${loc.radius.toStringAsFixed(0)}m)'),
                  selected: selected,
                  selectedColor: AppColors.hrTeal,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: selected ? Colors.white : null),
                  onSelected: (value) {
                    final updated = List<String>.from(selectedLocationIds);
                    if (value) {
                      updated.add(loc.id);
                    } else {
                      updated.remove(loc.id);
                    }
                    onLocationsChanged(updated);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.glassBlue.withOpacity(0.1),
      ),
      onChanged: (text) {
        final parsed = double.tryParse(text) ?? value;
        onChanged(parsed);
      },
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.glassBlue.withOpacity(0.1),
      ),
      onChanged: onChanged,
    );
  }
}
