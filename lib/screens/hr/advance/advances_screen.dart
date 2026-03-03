import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/advance/advance_card.dart';
import 'package:order_tracker/widgets/hr/advance/advance_filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  late HRProvider _hrProvider;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'جميع الحالات';
  String _selectedDepartment = 'جميع الأقسام';
  String _selectedSort = 'الأحدث';
  bool _showOverdueOnly = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdvances();
    });
  }

  Future<void> _loadAdvances() async {
    await _hrProvider.fetchAdvances(
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة السلف',
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
            onPressed: _exportAdvances,
            tooltip: 'تصدير',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/hr/advances/form');
            },
            tooltip: 'طلب سلفة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdvances,
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلترة
          _buildSearchBar(),

          // إحصائيات السلف
          _buildAdvancesStats(),

          // قائمة السلف
          Expanded(child: _buildAdvancesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/hr/advances/form');
        },
        backgroundColor: AppColors.advanceInstallment,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
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
                        // بحث
                      },
                    ),
                  ),
                  onSubmitted: (value) {
                    // بحث
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: _selectDateRange,
                tooltip: 'اختر فترة',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilterChip(
                label: const Text('المتأخرة فقط'),
                selected: _showOverdueOnly,
                onSelected: (selected) {
                  setState(() {
                    _showOverdueOnly = selected;
                  });
                },
                backgroundColor: _showOverdueOnly
                    ? AppColors.advanceOverdue.withOpacity(0.1)
                    : null,
              ),
              const SizedBox(width: 8),
              if (_startDate != null && _endDate != null)
                Chip(
                  label: Text(
                    '${DateFormat('yyyy/MM/dd').format(_startDate!)} - ${DateFormat('yyyy/MM/dd').format(_endDate!)}',
                  ),
                  onDeleted: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _loadAdvances();
                    });
                  },
                ),
              const Spacer(),
              Text(
                'إجمالي السلف المستحقة: ${_getTotalDueAdvances()} ر.س',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.advanceOverdue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancesStats() {
    final totalAdvances = _hrProvider.advances.length;
    final totalAmount = _hrProvider.advances.fold<double>(
      0,
      (sum, advance) => sum + advance.amount,
    );
    final totalDue = _hrProvider.advances.fold<double>(
      0,
      (sum, advance) => sum + advance.remainingAmount,
    );
    final pendingCount = _hrProvider.advances.where((a) => a.isPending).length;
    const overdueCount = 0; // سيتم حسابها من API

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
            'إجمالي السلف',
            totalAdvances.toString(),
            AppColors.advanceInstallment,
            Icons.credit_card,
          ),
          _buildStatItem(
            'المبلغ الإجمالي',
            '${totalAmount.toStringAsFixed(0)} ر.س',
            AppColors.hrCyan,
            Icons.attach_money,
          ),
          _buildStatItem(
            'مستحقة',
            '${totalDue.toStringAsFixed(0)} ر.س',
            AppColors.warningOrange,
            Icons.warning,
          ),
          _buildStatItem(
            'معلقة',
            pendingCount.toString(),
            AppColors.advancePending,
            Icons.pending,
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

  Widget _buildAdvancesList() {
    if (_hrProvider.isLoadingAdvances) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hrProvider.advances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off, size: 80, color: AppColors.lightGray),
            const SizedBox(height: 16),
            const Text(
              'لا توجد سلف',
              style: TextStyle(fontSize: 18, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/hr/advances/form');
              },
              child: const Text('طلب سلفة جديدة'),
            ),
          ],
        ),
      );
    }

    List<Advance> filteredAdvances = _hrProvider.advances;

    if (_showOverdueOnly) {
      filteredAdvances = filteredAdvances.where((a) => a.isOverdue).toList();
    }

    if (_startDate != null && _endDate != null) {
      filteredAdvances = filteredAdvances.where((a) {
        return a.requestDate.isAfter(_startDate!) &&
            a.requestDate.isBefore(_endDate!);
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadAdvances,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAdvances.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final advance = filteredAdvances[index];
          return AdvanceCard(
            advance: advance,
            onTap: () {
              _viewAdvanceDetails(advance);
            },
            onApprove: advance.isPending
                ? () => _approveAdvance(advance)
                : null,
            onReject: advance.isPending ? () => _rejectAdvance(advance) : null,
            onPay: advance.isApproved && !advance.isPaid
                ? () => _payAdvance(advance)
                : null,
            onRepayment: advance.isInstallment
                ? () => _recordRepayment(advance)
                : null,
          );
        },
      ),
    );
  }

  String _getTotalDueAdvances() {
    final total = _hrProvider.advances.fold<double>(
      0,
      (sum, advance) => sum + advance.remainingAmount,
    );
    return total.toStringAsFixed(0);
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _loadAdvances();
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AdvanceFilterDialog(
          selectedStatus: _selectedStatus,
          selectedDepartment: _selectedDepartment,
          selectedSort: _selectedSort,
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
          onSortChanged: (value) {
            setState(() {
              _selectedSort = value;
            });
          },
          onApply: () {
            Navigator.pop(context);
            _loadAdvances();
          },
          onClear: () {
            setState(() {
              _selectedStatus = 'جميع الحالات';
              _selectedDepartment = 'جميع الأقسام';
              _selectedSort = 'الأحدث';
              _showOverdueOnly = false;
              _startDate = null;
              _endDate = null;
              _searchController.clear();
            });
            Navigator.pop(context);
            _loadAdvances();
          },
        );
      },
    );
  }

  void _viewAdvanceDetails(Advance advance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تفاصيل السلفة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.hrPurple),
                title: Text('الموظف: ${advance.employeeName}'),
                subtitle: Text('الرقم الوظيفي: ${advance.employeeNumber}'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: AppColors.hrCyan,
                ),
                title: Text('تاريخ الطلب: ${advance.formattedRequestDate}'),
                subtitle: Text('الحالة: ${advance.status}'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.attach_money,
                  color: AppColors.hrCyan,
                ),
                title: Text('المبلغ: ${advance.formattedAmount}'),
                subtitle: Text('المتبقي: ${advance.formattedRemainingAmount}'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.description,
                  color: AppColors.mediumGray,
                ),
                title: const Text('السبب:'),
                subtitle: Text(advance.reason),
              ),
              if (advance.repayments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'جدول التسديد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...advance.repayments.map((repayment) {
                  return ListTile(
                    leading: Icon(
                      repayment.isPaid ? Icons.check_circle : Icons.pending,
                      color: repayment.isPaid
                          ? AppColors.successGreen
                          : AppColors.warningOrange,
                    ),
                    title: Text(
                      '${repayment.formattedAmount} - ${repayment.formattedMonthYear}',
                    ),
                    subtitle: Text('الحالة: ${repayment.status}'),
                    trailing: repayment.isPaid
                        ? Text(
                            DateFormat('yyyy/MM/dd').format(repayment.paidAt!),
                          )
                        : null,
                  );
                }).toList(),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (advance.isPending)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _approveAdvance(advance);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                      ),
                      child: const Text('موافقة'),
                    ),
                  if (advance.isPending)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _rejectAdvance(advance);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                      ),
                      child: const Text('رفض'),
                    ),
                  if (advance.isApproved && !advance.isPaid)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _payAdvance(advance);
                      },
                      child: const Text('دفع'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightGray,
                  foregroundColor: AppColors.darkGray,
                ),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _approveAdvance(Advance advance) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController notesController = TextEditingController();

        return AlertDialog(
          title: Text('موافقة على سلفة ${advance.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ: ${advance.formattedAmount}'),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الموافقة',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, notesController.text),
              child: const Text('موافقة'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await _hrProvider.approveAdvance(advance.id, result);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الموافقة على السلفة'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadAdvances();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الموافقة: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _rejectAdvance(Advance advance) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController reasonController = TextEditingController();

        return AlertDialog(
          title: Text('رفض سلفة ${advance.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ: ${advance.formattedAmount}'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الرفض',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reasonController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
              ),
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      try {
        await _hrProvider.rejectAdvance(advance.id, reason);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض السلفة'),
            backgroundColor: AppColors.errorRed,
          ),
        );

        _loadAdvances();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الرفض: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _payAdvance(Advance advance) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String paymentMethod = 'نقدي';
        DateTime paymentDate = DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('دفع سلفة ${advance.employeeName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('المبلغ: ${advance.formattedAmount}'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      items: const [
                        DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                        DropdownMenuItem(
                          value: 'تحويل بنكي',
                          child: Text('تحويل بنكي'),
                        ),
                        DropdownMenuItem(value: 'شيك', child: Text('شيك')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          paymentMethod = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الدفع',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: DateFormat('yyyy/MM/dd').format(paymentDate),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: paymentDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            paymentDate = date;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'paymentMethod': paymentMethod,
                    'paymentDate': paymentDate,
                  }),
                  child: const Text('دفع'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        await _hrProvider.payAdvance(
          advance.id,
          result['paymentMethod'],
          result['paymentDate'],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم دفع السلفة'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadAdvances();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الدفع: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _recordRepayment(Advance advance) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        double amount = advance.monthlyInstallment;
        int month = DateTime.now().month;
        int year = DateTime.now().year;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('تسديد قسط لسلفة ${advance.employeeName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('المبلغ المتبقي: ${advance.formattedRemainingAmount}'),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: amount.toString(),
                      ),
                      onChanged: (value) {
                        amount = double.tryParse(value) ?? 0;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'الشهر',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(
                              text: month.toString(),
                            ),
                            onChanged: (value) {
                              month =
                                  int.tryParse(value) ?? DateTime.now().month;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'السنة',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(
                              text: year.toString(),
                            ),
                            onChanged: (value) {
                              year = int.tryParse(value) ?? DateTime.now().year;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'amount': amount,
                    'month': month,
                    'year': year,
                  }),
                  child: const Text('تسجيل التسديد'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        await _hrProvider.recordRepayment(
          advance.id,
          result['amount'],
          result['month'],
          result['year'],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل التسديد'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadAdvances();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التسجيل: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _exportAdvances() async {
    try {
      await _hrProvider.exportAdvances();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير بيانات السلف'),
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
