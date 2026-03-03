import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/constants.dart';

class PersonalInfoSection extends StatelessWidget {
  final String name;
  final String nameEnglish;
  final String nationalId;
  final String gender;
  final DateTime? dateOfBirth;
  final String nationality;
  final String city;
  final String phone;
  final String email;
  final String? address;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onNameEnglishChanged;
  final ValueChanged<String> onNationalIdChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<DateTime?> onDateOfBirthChanged;
  final ValueChanged<String> onNationalityChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String?> onAddressChanged;

  const PersonalInfoSection({
    super.key,
    required this.name,
    required this.nameEnglish,
    required this.nationalId,
    required this.gender,
    required this.dateOfBirth,
    required this.nationality,
    required this.city,
    required this.phone,
    required this.email,
    required this.address,
    required this.onNameChanged,
    required this.onNameEnglishChanged,
    required this.onNationalIdChanged,
    required this.onGenderChanged,
    required this.onDateOfBirthChanged,
    required this.onNationalityChanged,
    required this.onCityChanged,
    required this.onPhoneChanged,
    required this.onEmailChanged,
    required this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField('الاسم', name, onNameChanged),
          const SizedBox(height: 12),
          _buildTextField('الاسم بالإنجليزية', nameEnglish, onNameEnglishChanged),
          const SizedBox(height: 12),
          _buildTextField('رقم الهوية', nationalId, onNationalIdChanged),
          const SizedBox(height: 12),
          _buildTextField('النوع', gender, onGenderChanged),
          const SizedBox(height: 12),
          _buildDateField(context),
          const SizedBox(height: 12),
          _buildTextField('الجنسية', nationality, onNationalityChanged),
          const SizedBox(height: 12),
          _buildTextField('المدينة', city, onCityChanged),
          const SizedBox(height: 12),
          _buildTextField('الهاتف', phone, onPhoneChanged),
          const SizedBox(height: 12),
          _buildTextField('البريد الإلكتروني', email, onEmailChanged),
          const SizedBox(height: 12),
          _buildTextField('العنوان', address ?? '', onAddressChanged),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    ValueChanged<String> onChanged,
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

  Widget _buildDateField(BuildContext context) {
    final formatted = dateOfBirth != null
        ? DateFormat('yyyy/MM/dd').format(dateOfBirth!)
        : 'اختر التاريخ';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: dateOfBirth ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          locale: const Locale('ar'),
        );
        if (picked != null) {
          onDateOfBirthChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تاريخ الميلاد',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppColors.glassBlue.withOpacity(0.1),
        ),
        child: Text(formatted),
      ),
    );
  }
}
