import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:provider/provider.dart';

class GenerateSalaryDialog extends StatefulWidget {
  final VoidCallback onGenerate;

  const GenerateSalaryDialog({
    super.key,
    required this.onGenerate,
  });

  @override
  State<GenerateSalaryDialog> createState() => _GenerateSalaryDialogState();
}

class _GenerateSalaryDialogState extends State<GenerateSalaryDialog> {
  late DateTime _selectedDate;
  late int _selectedMonth;
  late int _selectedYear;
  String? _selectedDepartment;
  bool _includeAdvances = true;
  bool _includePenalties = true;
  bool _includeOvertime = true;
  bool _calculateBonuses = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final hrProvider = Provider.of<HRProvider>(context, listen: false);
    final departments = ['جميع الأقسام', ...hrProvider.employees.map((e) => e.department).toSet().toList()];

    return AlertDialog(
      title: const Text(
        'إنشاء كشوف رواتب جديدة',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اختيار الشهر والسنة
            _buildMonthYearSelector(),
            
            const SizedBox(height: 20),
            
            // اختيار القسم
            _buildDepartmentSelector(departments),
            
            const SizedBox(height: 20),
            
            // خيارات الحساب
            _buildCalculationOptions(),
            
            const SizedBox(height: 20),
            
            // معلومات إضافية
            _buildAdditionalInfo(),
            
            const SizedBox(height: 8),
            
            // تحذير
            _buildWarning(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () {
            Navigator.pop(context);
          },
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : _generateSalaries,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.hrPurple,
          ),
          child: _isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('إنشاء الكشوف'),
        ),
      ],
    );
  }

  Widget _buildMonthYearSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر الشهر والسنة',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                items: List.generate(12, (index) => index + 1)
                    .map((month) {
                  final monthName = DateFormat('MMMM', 'ar').format(
                    DateTime(2024, month),
                  );
                  return DropdownMenuItem(
                    value: month,
                    child: Text(monthName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'الشهر',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                items: List.generate(11, (index) => DateTime.now().year - 5 + index)
                    .map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'السنة',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDepartmentSelector(List<String> departments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'القسم',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          items: departments.map((dept) {
            return DropdownMenuItem(
              value: dept,
              child: Text(dept),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDepartment = value;
            });
          },
          decoration: const InputDecoration(
            hintText: 'اختر القسم (اختياري)',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildCalculationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'خيارات الحساب',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundGray,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.lightGray),
          ),
          child: Column(
            children: [
              _buildOptionSwitch(
                'تضمين خصم السلف',
                _includeAdvances,
                (value) {
                  setState(() {
                    _includeAdvances = value;
                  });
                },
                'خصم السلف المستحقة لهذا الشهر',
              ),
              const SizedBox(height: 12),
              _buildOptionSwitch(
                'تضمين خصم الجزاءات',
                _includePenalties,
                (value) {
                  setState(() {
                    _includePenalties = value;
                  });
                },
                'خصم الجزاءات المطبقة',
              ),
              const SizedBox(height: 12),
              _buildOptionSwitch(
                'حساب الوقت الإضافي',
                _includeOvertime,
                (value) {
                  setState(() {
                    _includeOvertime = value;
                  });
                },
                'حساب ساعات العمل الإضافي',
              ),
              const SizedBox(height: 12),
              _buildOptionSwitch(
                'حساب المكافآت والحوافز',
                _calculateBonuses,
                (value) {
                  setState(() {
                    _calculateBonuses = value;
                  });
                },
                'حساب المكافآت بناءً على الأداء',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSwitch(String title, bool value, Function(bool) onChanged, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.hrPurple,
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo() {
    final hrProvider = Provider.of<HRProvider>(context, listen: false);
    final activeEmployees = hrProvider.employees.where((e) => e.isActive).length;
    final monthName = DateFormat('MMMM', 'ar').format(DateTime(_selectedYear, _selectedMonth));
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, size: 16, color: AppColors.infoBlue),
              SizedBox(width: 8),
              Text(
                'معلومات',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.infoBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم إنشاء كشوف رواتب لـ $activeEmployees موظف نشط لشهر $monthName $_selectedYear',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'القسم: ${_selectedDepartment ?? "جميع الأقسام"}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'سيتم حساب: ${_getCalculationsSummary()}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
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
      child: const Row(
        children: [
          Icon(Icons.warning, size: 16, color: AppColors.warningOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تأكد من وجود سجلات الحضور لهذا الشهر قبل الإنشاء',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warningOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCalculationsSummary() {
    List<String> calculations = [];
    if (_includeAdvances) calculations.add('السلف');
    if (_includePenalties) calculations.add('الجزاءات');
    if (_includeOvertime) calculations.add('الوقت الإضافي');
    if (_calculateBonuses) calculations.add('المكافآت');
    
    if (calculations.isEmpty) return 'الراتب الأساسي فقط';
    return calculations.join(' + ');
  }

  Future<void> _generateSalaries() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final hrProvider = Provider.of<HRProvider>(context, listen: false);
      
      final data = {
        'month': _selectedMonth,
        'year': _selectedYear,
        if (_selectedDepartment != null && _selectedDepartment != 'جميع الأقسام')
          'department': _selectedDepartment,
        'includeAdvances': _includeAdvances,
        'includePenalties': _includePenalties,
        'includeOvertime': _includeOvertime,
        'calculateBonuses': _calculateBonuses,
      };

      await hrProvider.generateSalarySheets(_selectedMonth, _selectedYear);
      
      if (!mounted) return;
      
      Navigator.pop(context);
      widget.onGenerate();
      
      final monthName = DateFormat('MMMM', 'ar').format(DateTime(_selectedYear, _selectedMonth));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء كشوف رواتب $monthName $_selectedYear'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      
    } catch (error) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إنشاء الكشوف: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}