import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class SalaryFilterDialog extends StatefulWidget {
  final String selectedStatus;
  final String selectedDepartment;
  final String selectedMonth;
  final String selectedYear;
  final bool showPaidOnly;
  final bool showUnpaidOnly;
  final bool showByPaymentMethod;
  final String? selectedPaymentMethod;
  final Function(String) onStatusChanged;
  final Function(String) onDepartmentChanged;
  final Function(String) onMonthChanged;
  final Function(String) onYearChanged;
  final Function(bool) onPaidOnlyChanged;
  final Function(bool) onUnpaidOnlyChanged;
  final Function(bool) onShowByPaymentMethodChanged;
  final Function(String)? onPaymentMethodChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const SalaryFilterDialog({
    super.key,
    required this.selectedStatus,
    required this.selectedDepartment,
    required this.selectedMonth,
    required this.selectedYear,
    required this.showPaidOnly,
    required this.showUnpaidOnly,
    required this.showByPaymentMethod,
    this.selectedPaymentMethod,
    required this.onStatusChanged,
    required this.onDepartmentChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onPaidOnlyChanged,
    required this.onUnpaidOnlyChanged,
    required this.onShowByPaymentMethodChanged,
    this.onPaymentMethodChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<SalaryFilterDialog> createState() => _SalaryFilterDialogState();
}

class _SalaryFilterDialogState extends State<SalaryFilterDialog> {
  late String _status;
  late String _department;
  late String _month;
  late String _year;
  late bool _paidOnly;
  late bool _unpaidOnly;
  late bool _showByPaymentMethod;
  late String? _paymentMethod;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _department = widget.selectedDepartment;
    _month = widget.selectedMonth;
    _year = widget.selectedYear;
    _paidOnly = widget.showPaidOnly;
    _unpaidOnly = widget.showUnpaidOnly;
    _showByPaymentMethod = widget.showByPaymentMethod;
    _paymentMethod = widget.selectedPaymentMethod;
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'جميع الأشهر',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final years = ['جميع السنوات', '2024', '2023', '2022', '2021', '2020'];

    final statuses = ['جميع الحالات', 'مسودة', 'معتمد', 'مصرف', 'ملغي'];

    final departments = [
      'جميع الأقسام',
      'المبيعات',
      'التسويق',
      'المحاسبة',
      'التقنية',
      'الخدمات',
      'الإدارة',
      'الإنتاج',
    ];

    final paymentMethods = ['جميع الطرق', 'تحويل بنكي', 'شيك', 'نقدي'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // العنوان
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.hrPurple,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'تصفية الرواتب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // المحتوى
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الحالة
                    _buildFilterSection(
                      'حالة الراتب',
                      DropdownButtonFormField<String>(
                        value: _status,
                        items: statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _status = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        isExpanded: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // القسم
                    _buildFilterSection(
                      'القسم',
                      DropdownButtonFormField<String>(
                        value: _department,
                        items: departments.map((dept) {
                          return DropdownMenuItem(
                            value: dept,
                            child: Text(dept),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _department = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        isExpanded: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // الشهر
                    _buildFilterSection(
                      'الشهر',
                      DropdownButtonFormField<String>(
                        value: _month,
                        items: months.map((month) {
                          return DropdownMenuItem(
                            value: month,
                            child: Text(month),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _month = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        isExpanded: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // السنة
                    _buildFilterSection(
                      'السنة',
                      DropdownButtonFormField<String>(
                        value: _year,
                        items: years.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _year = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        isExpanded: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // خيارات خاصة
                    _buildFilterSection(
                      'خيارات خاصة',
                      Column(
                        children: [
                          _buildFilterOption('عرض المدفوعة فقط', _paidOnly, (
                            value,
                          ) {
                            setState(() {
                              _paidOnly = value;
                              if (value) _unpaidOnly = false;
                            });
                          }),
                          const SizedBox(height: 12),
                          _buildFilterOption(
                            'عرض غير المدفوعة فقط',
                            _unpaidOnly,
                            (value) {
                              setState(() {
                                _unpaidOnly = value;
                                if (value) _paidOnly = false;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildFilterOption(
                            'عرض حسب طريقة الدفع',
                            _showByPaymentMethod,
                            (value) {
                              setState(() {
                                _showByPaymentMethod = value;
                              });
                            },
                          ),
                          if (_showByPaymentMethod) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _paymentMethod,
                              items: paymentMethods.map((method) {
                                return DropdownMenuItem(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _paymentMethod = value;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: 'اختر طريقة الدفع',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              isExpanded: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // الأزرار
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.lightGray)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClear,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.hrPurple),
                      ),
                      child: const Text('مسح الفلاتر'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        widget.onApply();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hrPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildFilterOption(
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.hrPurple,
        ),
      ],
    );
  }

  void _applyFilters() {
    widget.onStatusChanged(_status);
    widget.onDepartmentChanged(_department);
    widget.onMonthChanged(_month);
    widget.onYearChanged(_year);
    widget.onPaidOnlyChanged(_paidOnly);
    widget.onUnpaidOnlyChanged(_unpaidOnly);
    widget.onShowByPaymentMethodChanged(_showByPaymentMethod);
    if (widget.onPaymentMethodChanged != null && _paymentMethod != null) {
      widget.onPaymentMethodChanged!(_paymentMethod!);
    }
  }
}
