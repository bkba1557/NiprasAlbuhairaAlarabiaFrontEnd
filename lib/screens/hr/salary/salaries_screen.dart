import 'package:flutter/material.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/salary/salary_card.dart';
import 'package:order_tracker/widgets/hr/salary/salary_filter_dialog.dart';
import 'package:order_tracker/widgets/hr/salary/generate_salary_dialog.dart';
import 'package:order_tracker/widgets/hr/salary/pay_salary_dialog.dart';
import 'package:provider/provider.dart';

class SalariesScreen extends StatefulWidget {
  const SalariesScreen({super.key});

  @override
  State<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends State<SalariesScreen> {
  late HRProvider _hrProvider;
  final TextEditingController _searchController = TextEditingController();
  int? _selectedMonth;
  int? _selectedYear;
  String _selectedStatus = 'جميع الحالات';
  String _selectedDepartment = 'جميع الأقسام';
  bool _showUnpaidOnly = false;
  bool _showPaidOnly = false;
  bool _showByPaymentMethod = false;
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalaries();
    });
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  Future<void> _loadSalaries() async {
    await _hrProvider.fetchSalaries(
      month: _selectedMonth,
      year: _selectedYear,
      status: _selectedStatus == 'جميع الحالات' ? null : _selectedStatus,
      department: _selectedDepartment == 'جميع الأقسام'
          ? null
          : _selectedDepartment,
    );
  }

  @override
  Widget build(BuildContext context) {
    _hrProvider = Provider.of<HRProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة الرواتب',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'فلترة',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportSalaries,
            tooltip: 'تصدير',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _generateSalaries,
            tooltip: 'إنشاء رواتب',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSalaries,
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط الفلترة
          _buildFilterBar(),

          // إحصائيات الرواتب
          _buildSalaryStats(),

          // قائمة الرواتب
          Expanded(child: _buildSalariesList(isLargeScreen)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateSalaries,
        backgroundColor: AppColors.hrCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_chart),
      ),
    );
  }

  Widget _buildFilterBar() {
    final monthName = _selectedMonth != null
        ? _getMonthName(_selectedMonth!)
        : 'الشهر';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الموظف أو رقمه...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        // يمكن إضافة بحث
                      },
                    ),
                  ),
                  onSubmitted: (value) {
                    // بحث
                  },
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<int>(
                icon: const Icon(Icons.calendar_month),
                onSelected: (month) {
                  setState(() {
                    _selectedMonth = month;
                    _loadSalaries();
                  });
                },
                itemBuilder: (context) => List.generate(12, (index) {
                  final month = index + 1;
                  return PopupMenuItem(
                    value: month,
                    child: Text(_getMonthName(month)),
                  );
                }),
              ),
              PopupMenuButton<int>(
                icon: const Icon(Icons.calendar_today),
                onSelected: (year) {
                  setState(() {
                    _selectedYear = year;
                    _loadSalaries();
                  });
                },
                itemBuilder: (context) {
                  final currentYear = DateTime.now().year;
                  return List.generate(5, (index) {
                    final year = currentYear - index;
                    return PopupMenuItem(value: year, child: Text('$year'));
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(
                label: Text('$monthName $_selectedYear'),
                backgroundColor: AppColors.hrCyan,
                labelStyle: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('غير المدفوعة فقط'),
                selected: _showUnpaidOnly,
                onSelected: (selected) {
                  setState(() {
                    _showUnpaidOnly = selected;
                    _loadSalaries();
                  });
                },
              ),
              const Spacer(),
              Text(
                'إجمالي الرواتب: ${_getTotalSalaries()} ر.س',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.hrDarkPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryStats() {
    final stats = _hrProvider.salarySummary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        border: const Border(bottom: BorderSide(color: AppColors.lightGray)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'إجمالي الرواتب',
            '${(stats?['totalAmount'] ?? 0).toStringAsFixed(0)} ر.س',
            AppColors.hrCyan,
            Icons.attach_money,
          ),
          _buildStatItem(
            'مسودة',
            (stats?['byStatus']?.firstWhere(
                      (s) => s['_id'] == 'مسودة',
                      orElse: () => {'count': 0},
                    )['count'] ??
                    0)
                .toString(),
            AppColors.salaryDraft,
            Icons.drafts,
          ),
          _buildStatItem(
            'معتمدة',
            (stats?['byStatus']?.firstWhere(
                      (s) => s['_id'] == 'معتمد',
                      orElse: () => {'count': 0},
                    )['count'] ??
                    0)
                .toString(),
            AppColors.salaryApproved,
            Icons.verified,
          ),
          _buildStatItem(
            'مدفوعة',
            (stats?['byStatus']?.firstWhere(
                      (s) => s['_id'] == 'مصرف',
                      orElse: () => {'count': 0},
                    )['count'] ??
                    0)
                .toString(),
            AppColors.salaryPaid,
            Icons.check_circle,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 20,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
        ),
      ],
    );
  }

  Widget _buildSalariesList(bool isLargeScreen) {
    if (_hrProvider.isLoadingSalaries) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hrProvider.salaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, size: 80, color: AppColors.lightGray),
            const SizedBox(height: 16),
            const Text(
              'لا توجد رواتب لهذه الفترة',
              style: TextStyle(fontSize: 18, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _generateSalaries,
              child: const Text('إنشاء كشوف رواتب'),
            ),
          ],
        ),
      );
    }

    List<Salary> filteredSalaries = List.from(_hrProvider.salaries);

    if (_showPaidOnly) {
      filteredSalaries =
          filteredSalaries.where((salary) => salary.isPaid).toList();
    }

    if (_showUnpaidOnly) {
      filteredSalaries =
          filteredSalaries.where((salary) => !salary.isPaid).toList();
    }

    if (_selectedPaymentMethod != null) {
      filteredSalaries = filteredSalaries
          .where((salary) => salary.paymentMethod == _selectedPaymentMethod)
          .toList();
    }

    return RefreshIndicator(
      onRefresh: _loadSalaries,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredSalaries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final salary = filteredSalaries[index];
          return SalaryCard(
            salary: salary,
            onTap: () => _openSalaryDetails(salary),
            onViewDetails: () => _openSalaryDetails(salary),
            onPay: salary.isApproved && !salary.isPaid
                ? () => _paySalary(salary)
                : null,
            onApprove: salary.isDraft ? () => _approveSalary(salary) : null,
            onExport: () => _printSalarySlip(salary),
          );
        },
      ),
    );
  }

  static const List<String> _monthNames = [
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

  String _getMonthName(int month) => _monthNames[month - 1];

  String _getMonthLabel(int? month) =>
      month != null ? _getMonthName(month) : 'جميع الأشهر';

  int? _monthNumberFromLabel(String label) {
    if (label == 'جميع الأشهر') return null;
    final index = _monthNames.indexOf(label);
    return index >= 0 ? index + 1 : null;
  }

  String _getYearLabel(int? year) =>
      year != null ? year.toString() : 'جميع السنوات';

  int? _yearFromLabel(String label) =>
      label == 'جميع السنوات' ? null : int.tryParse(label);

  String _getTotalSalaries() {
    final total = _hrProvider.salaries.fold<double>(
      0,
      (sum, salary) => sum + salary.netSalary,
    );
    return total.toStringAsFixed(0);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SalaryFilterDialog(
          selectedStatus: _selectedStatus,
          selectedDepartment: _selectedDepartment,
          selectedMonth: _getMonthLabel(_selectedMonth),
          selectedYear: _getYearLabel(_selectedYear),
          showPaidOnly: _showPaidOnly,
          showUnpaidOnly: _showUnpaidOnly,
          showByPaymentMethod: _showByPaymentMethod,
          selectedPaymentMethod: _selectedPaymentMethod ?? 'جميع الطرق',
          onStatusChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
          },
          onDepartmentChanged: (value) {
            setState(() {
              _selectedDepartment = value;
            });
          },
          onMonthChanged: (value) {
            setState(() {
              _selectedMonth = _monthNumberFromLabel(value);
            });
          },
          onYearChanged: (value) {
            setState(() {
              _selectedYear = _yearFromLabel(value);
            });
          },
          onPaidOnlyChanged: (value) {
            setState(() {
              _showPaidOnly = value;
              if (value) _showUnpaidOnly = false;
            });
          },
          onUnpaidOnlyChanged: (value) {
            setState(() {
              _showUnpaidOnly = value;
              if (value) _showPaidOnly = false;
            });
          },
          onShowByPaymentMethodChanged: (value) {
            setState(() {
              _showByPaymentMethod = value;
              if (!value) {
                _selectedPaymentMethod = null;
              } else {
                _selectedPaymentMethod ??= 'تحويل بنكي';
              }
            });
          },
          onPaymentMethodChanged: (value) {
            setState(() {
              if (value == 'جميع الطرق') {
                _selectedPaymentMethod = null;
              } else {
                _selectedPaymentMethod = value;
              }
            });
          },
          onApply: () {
            _loadSalaries();
          },
        onClear: () {
          setState(() {
            _selectedStatus = 'جميع الحالات';
            _selectedDepartment = 'جميع الأقسام';
            _showPaidOnly = false;
            _showUnpaidOnly = false;
            _showByPaymentMethod = false;
            _selectedPaymentMethod = null;
            final now = DateTime.now();
            _selectedMonth = now.month;
            _selectedYear = now.year;
            _searchController.clear();
          });
          _loadSalaries();
          Navigator.pop(context);
        },
        );
      },
    );
  }

  void _generateSalaries() {
    showDialog(
      context: context,
      builder: (context) {
        return GenerateSalaryDialog(
          onGenerate: () => _loadSalaries(),
        );
      },
    );
  }

  void _paySalary(Salary salary) {
    showDialog(
      context: context,
      builder: (context) {
        return PaySalaryDialog(
          salary: salary,
          onPay: (paymentMethod, paymentDate) async {
            try {
              await _hrProvider.paySalary(
                salary.id,
                paymentMethod,
                paymentDate,
              );
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم دفع الراتب بنجاح'),
                  backgroundColor: AppColors.successGreen,
                ),
              );

              _loadSalaries();
            } catch (error) {
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فشل الدفع: $error'),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _approveSalary(Salary salary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد الراتب'),
        content: const Text('هل أنت متأكد من اعتماد هذا الراتب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _hrProvider.approveSalary(salary.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اعتماد الراتب'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadSalaries();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الاعتماد: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _editSalary(Salary salary) {
    Navigator.pushNamed(context, '/hr/salaries/edit', arguments: salary.id);
  }

  Future<void> _printSalarySlip(Salary salary) async {
    try {
      // طباعة كشف الراتب
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري طباعة كشف الراتب...'),
          backgroundColor: AppColors.infoBlue,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الطباعة: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _openSalaryDetails(Salary salary) {
    Navigator.pushNamed(
      context,
      '/hr/salaries/details',
      arguments: salary.id,
    );
  }

  Future<void> _exportSalaries() async {
    try {
      await _hrProvider.exportSalaries(
        month: _selectedMonth,
        year: _selectedYear,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير كشوف الرواتب'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التصدير: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
