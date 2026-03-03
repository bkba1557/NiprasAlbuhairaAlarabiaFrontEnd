import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/penalty/penalty_card.dart';
import 'package:order_tracker/widgets/hr/penalty/penalty_filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class PenaltiesScreen extends StatefulWidget {
  const PenaltiesScreen({super.key});

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  late HRProvider _hrProvider;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'جميع الحالات';
  String _selectedType = 'جميع الأنواع';
  String _selectedDepartment = 'جميع الأقسام';
  String _selectedSort = 'الأحدث';
  bool _showNotDeductedOnly = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPenalties();
    });
  }

  Future<void> _loadPenalties() async {
    await _hrProvider.fetchPenalties(
      status: _selectedStatus == 'جميع الحالات' ? null : _selectedStatus,
      type: _selectedType == 'جميع الأنواع' ? null : _selectedType,
      department: _selectedDepartment == 'جميع الأقسام'
          ? null
          : _selectedDepartment,
    );
  }

  @override
  Widget build(BuildContext context) {
    _hrProvider = Provider.of<HRProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة الجزاءات',
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
            onPressed: _exportPenalties,
            tooltip: 'تصدير',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/hr/penalties/form');
            },
            tooltip: 'إضافة جزاء',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPenalties,
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلترة
          _buildSearchBar(),

          // إحصائيات الجزاءات
          _buildPenaltiesStats(),

          // قائمة الجزاءات
          Expanded(child: _buildPenaltiesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/hr/penalties/form');
        },
        backgroundColor: AppColors.penaltyApplied,
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
                    hintText: 'بحث باسم الموظف أو وصف الجزاء...',
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
                label: const Text('غير المخصومة فقط'),
                selected: _showNotDeductedOnly,
                onSelected: (selected) {
                  setState(() {
                    _showNotDeductedOnly = selected;
                  });
                },
                backgroundColor: _showNotDeductedOnly
                    ? AppColors.penaltyPending.withOpacity(0.1)
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
                      _loadPenalties();
                    });
                  },
                ),
              const Spacer(),
              Text(
                'إجمالي الجزاءات: ${_getTotalPenaltiesAmount()} ر.س',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.penaltyApplied,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltiesStats() {
    final totalPenalties = _hrProvider.penalties.length;
    final totalAmount = _hrProvider.penalties.fold<double>(
      0,
      (sum, penalty) => sum + penalty.amount,
    );
    final pendingCount = _hrProvider.penalties.where((p) => p.isPending).length;
    final appliedCount = _hrProvider.penalties.where((p) => p.isApplied).length;

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
            'إجمالي الجزاءات',
            totalPenalties.toString(),
            AppColors.penaltyApplied,
            Icons.gavel,
          ),
          _buildStatItem(
            'المبلغ الإجمالي',
            '${totalAmount.toStringAsFixed(0)} ر.س',
            AppColors.hrCyan,
            Icons.attach_money,
          ),
          _buildStatItem(
            'معلقة',
            pendingCount.toString(),
            AppColors.penaltyPending,
            Icons.pending,
          ),
          _buildStatItem(
            'مطبقة',
            appliedCount.toString(),
            AppColors.successGreen,
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

  Widget _buildPenaltiesList() {
    if (_hrProvider.isLoadingPenalties) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hrProvider.penalties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel, size: 80, color: AppColors.lightGray),
            const SizedBox(height: 16),
            const Text(
              'لا توجد جزاءات',
              style: TextStyle(fontSize: 18, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/hr/penalties/form');
              },
              child: const Text('إضافة جزاء جديد'),
            ),
          ],
        ),
      );
    }

    List<Penalty> filteredPenalties = _hrProvider.penalties;

    if (_showNotDeductedOnly) {
      filteredPenalties = filteredPenalties.where((p) => !p.deducted).toList();
    }

    if (_startDate != null && _endDate != null) {
      filteredPenalties = filteredPenalties.where((p) {
        return p.date.isAfter(_startDate!) && p.date.isBefore(_endDate!);
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadPenalties,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredPenalties.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final penalty = filteredPenalties[index];
          return PenaltyCard(
            penalty: penalty,
            onTap: () {
              _viewPenaltyDetails(penalty);
            },
            onApprove: penalty.isPending
                ? () => _approvePenalty(penalty)
                : null,
            onCancel: penalty.isApplied ? () => _cancelPenalty(penalty) : null,
            onAppeal: penalty.isApplied ? () => _appealPenalty(penalty) : null,
          );
        },
      ),
    );
  }

  String _getTotalPenaltiesAmount() {
    final total = _hrProvider.penalties.fold<double>(
      0,
      (sum, penalty) => sum + penalty.amount,
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
        _loadPenalties();
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return PenaltyFilterDialog(
          selectedStatus: _selectedStatus,
          selectedType: _selectedType,
          selectedDepartment: _selectedDepartment,
          selectedSort: _selectedSort,
          onStatusChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
          },
          onTypeChanged: (value) {
            setState(() {
              _selectedType = value;
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
            _loadPenalties();
          },
          onClear: () {
            setState(() {
              _selectedStatus = 'جميع الحالات';
              _selectedType = 'جميع الأنواع';
              _selectedDepartment = 'جميع الأقسام';
              _selectedSort = 'الأحدث';
              _showNotDeductedOnly = false;
              _startDate = null;
              _endDate = null;
              _searchController.clear();
            });
            Navigator.pop(context);
            _loadPenalties();
          },
        );
      },
    );
  }

  void _viewPenaltyDetails(Penalty penalty) {
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
                'تفاصيل الجزاء',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.hrPurple),
                title: Text('الموظف: ${penalty.employeeName}'),
                subtitle: Text('الرقم الوظيفي: ${penalty.employeeNumber}'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: AppColors.hrCyan,
                ),
                title: Text('التاريخ: ${penalty.formattedDate}'),
                subtitle: Text('النوع: ${penalty.type}'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.gavel,
                  color: AppColors.penaltyApplied,
                ),
                title: Text('المبلغ: ${penalty.formattedAmount}'),
                subtitle: Text(penalty.deducted ? 'مخصوم' : 'غير مخصوم'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.description,
                  color: AppColors.mediumGray,
                ),
                title: const Text('الوصف:'),
                subtitle: Text(penalty.description),
              ),
              if (penalty.approvalNotes != null)
                ListTile(
                  leading: const Icon(
                    Icons.note,
                    color: AppColors.warningOrange,
                  ),
                  title: const Text('ملاحظات الموافقة:'),
                  subtitle: Text(penalty.approvalNotes!),
                ),
              if (penalty.approvedAt != null)
                ListTile(
                  leading: const Icon(
                    Icons.verified,
                    color: AppColors.successGreen,
                  ),
                  title: Text(
                    'تمت الموافقة بواسطة: ${penalty.approvedByName ?? ''}',
                  ),
                  subtitle: Text(
                    DateFormat('yyyy/MM/dd').format(penalty.approvedAt!),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (penalty.isPending)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _approvePenalty(penalty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                      ),
                      child: const Text('موافقة'),
                    ),
                  if (penalty.isApplied)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _cancelPenalty(penalty);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  if (penalty.isApplied && !penalty.deducted)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deductFromSalary(penalty);
                      },
                      child: const Text('خصم من الراتب'),
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

  void _approvePenalty(Penalty penalty) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController notesController = TextEditingController();

        return AlertDialog(
          title: Text('موافقة على جزاء ${penalty.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ: ${penalty.formattedAmount}'),
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
        await _hrProvider.approvePenalty(penalty.id, result);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الموافقة على الجزاء'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadPenalties();
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

  void _cancelPenalty(Penalty penalty) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController reasonController = TextEditingController();

        return AlertDialog(
          title: Text('إلغاء جزاء ${penalty.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ: ${penalty.formattedAmount}'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الإلغاء',
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
              child: const Text('إلغاء الجزاء'),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      try {
        await _hrProvider.cancelPenalty(penalty.id, reason);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الجزاء'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadPenalties();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإلغاء: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _appealPenalty(Penalty penalty) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController reasonController = TextEditingController();

        return AlertDialog(
          title: Text('استئناف جزاء ${penalty.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ: ${penalty.formattedAmount}'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الاستئناف',
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
              child: const Text('تقديم الاستئناف'),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      try {
        await _hrProvider.appealPenalty(penalty.id, reason);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تقديم الاستئناف'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadPenalties();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تقديم الاستئناف: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _deductFromSalary(Penalty penalty) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خصم من الراتب'),
        content: Text('هل تريد خصم ${penalty.formattedAmount} من راتب الموظف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خصم'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _hrProvider.deductPenaltyFromSalary(penalty.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم خصم الجزاء من الراتب'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        _loadPenalties();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الخصم: $error'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _exportPenalties() async {
    try {
      await _hrProvider.exportPenalties();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير بيانات الجزاءات'),
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
