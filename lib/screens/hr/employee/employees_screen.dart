import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/employee/employee_card.dart';
import 'package:order_tracker/widgets/hr/employee/filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  late HRProvider _hrProvider;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _departments = [
    'جميع الأقسام',
    'المبيعات',
    'التسويق',
    'المحاسبة',
    'التقنية',
    'الخدمات',
  ];
  final List<String> _statuses = [
    'جميع الحالات',
    'نشط',
    'موقف',
    'استقال',
    'مفصول',
    'إجازة',
  ];
  String _selectedDepartment = 'جميع الأقسام';
  String _selectedStatus = 'جميع الحالات';
  String _selectedSort = 'الأحدث';
  bool _showFingerprintOnly = false;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployees();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    await _hrProvider.fetchEmployees(
      search: _searchController.text,
      department: _selectedDepartment == 'جميع الأقسام'
          ? null
          : _selectedDepartment,
      status: _selectedStatus == 'جميع الحالات' ? null : _selectedStatus,
      fingerprintOnly: _showFingerprintOnly,
      activeOnly: _showActiveOnly,
    );
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 3 || _searchController.text.isEmpty) {
      _loadEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    _hrProvider = Provider.of<HRProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة الموظفين',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 4,
        actions: [
          // زر الفلترة
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'فلترة',
          ),

          // فرز
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _selectedSort = value;
                _applySorting();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'الأحدث', child: Text('الأحدث')),
              const PopupMenuItem(value: 'الأقدم', child: Text('الأقدم')),
              const PopupMenuItem(value: 'الاسم', child: Text('الاسم')),
              const PopupMenuItem(
                value: 'الرقم الوظيفي',
                child: Text('الرقم الوظيفي'),
              ),
              const PopupMenuItem(value: 'الراتب', child: Text('الراتب')),
            ],
          ),

          // تصدير
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportEmployees,
            tooltip: 'تصدير',
          ),

          // إنشاء جديد
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/hr/employees/form');
            },
            tooltip: 'إضافة موظف',
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والتصفية
          _buildSearchBar(),

          // إحصائيات سريعة
          _buildQuickStats(),

          // قائمة الموظفين
          Expanded(child: _buildEmployeesList(isLargeScreen, isMediumScreen)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/hr/employees/form');
        },
        backgroundColor: AppColors.hrPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، الرقم الوظيفي، الهوية...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: Text('البصمة فقط'),
            selected: _showFingerprintOnly,
            onSelected: (selected) {
              setState(() {
                _showFingerprintOnly = selected;
                _loadEmployees();
              });
            },
            backgroundColor: _showFingerprintOnly
                ? AppColors.hrLightPurple
                : null,
            selectedColor: AppColors.hrPurple,
            labelStyle: TextStyle(
              color: _showFingerprintOnly ? Colors.white : null,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text('النشطين فقط'),
            selected: _showActiveOnly,
            onSelected: (selected) {
              setState(() {
                _showActiveOnly = selected;
                _loadEmployees();
              });
            },
            backgroundColor: _showActiveOnly ? AppColors.hrLightTeal : null,
            selectedColor: AppColors.hrTeal,
            labelStyle: TextStyle(color: _showActiveOnly ? Colors.white : null),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final stats = _hrProvider.employeesStats;

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
            'إجمالي الموظفين',
            stats?['total']?.toString() ?? '0',
            AppColors.hrPurple,
            Icons.people,
          ),
          _buildStatItem(
            'مسجلين بالبصمة',
            stats?['fingerprintEnrolled']?.toString() ?? '0',
            AppColors.hrCyan,
            Icons.fingerprint,
          ),
          _buildStatItem(
            'النشطين',
            stats?['active']?.toString() ?? '0',
            AppColors.successGreen,
            Icons.check_circle,
          ),
          _buildStatItem(
            'العقود المنتهية',
            stats?['contractExpiring']?.toString() ?? '0',
            AppColors.warningOrange,
            Icons.warning,
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

  Widget _buildEmployeesList(bool isLargeScreen, bool isMediumScreen) {
    if (_hrProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hrProvider.employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: AppColors.lightGray),
            const SizedBox(height: 16),
            const Text(
              'لا توجد موظفين',
              style: TextStyle(fontSize: 18, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/hr/employees/form');
              },
              child: const Text('إضافة موظف جديد'),
            ),
          ],
        ),
      );
    }

    final crossAxisCount = isLargeScreen
        ? 3
        : isMediumScreen
        ? 2
        : 1;
    final childAspectRatio = isLargeScreen
        ? 2.8
        : isMediumScreen
        ? 1.6
        : 1.8;

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _hrProvider.employees.length,
        itemBuilder: (context, index) {
          final employee = _hrProvider.employees[index];
          return EmployeeCard(
            employee: employee,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/hr/employees/details',
                arguments: employee.id,
              );
            },
            onEdit: () {
              _editEmployee(employee);
            },
            onFingerprint: () {
              _enrollFingerprint(employee);
            },
            onFace: () async {
              final result = await Navigator.pushNamed(
                context,
                '/hr/face/enrollment',
                arguments: employee.id,
              );
              if (result == true) {
                _loadEmployees();
              }
            },
            onDevice: () async {
              final result = await Navigator.pushNamed(
                context,
                '/hr/device/assignment',
                arguments: employee,
              );
              if (result == true) {
                _loadEmployees();
              }
            },
            onStatusChange: () {
              _changeEmployeeStatus(employee);
            },
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return FilterDialog(
          departments: _departments,
          statuses: _statuses,
          selectedDepartment: _selectedDepartment,
          selectedStatus: _selectedStatus,
          onDepartmentChanged: (value) {
            setState(() {
              _selectedDepartment = value;
            });
          },
          onStatusChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
          },
          onApply: () {
            Navigator.pop(context);
            _loadEmployees();
          },
          onClear: () {
            setState(() {
              _selectedDepartment = 'جميع الأقسام';
              _selectedStatus = 'جميع الحالات';
              _showFingerprintOnly = false;
              _showActiveOnly = true;
            });
            Navigator.pop(context);
            _loadEmployees();
          },
        );
      },
    );
  }

  void _applySorting() {
    List<Employee> sortedList = List.from(_hrProvider.employees);

    switch (_selectedSort) {
      case 'الأحدث':
        sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'الأقدم':
        sortedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'الاسم':
        sortedList.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'الرقم الوظيفي':
        sortedList.sort((a, b) => a.employeeId.compareTo(b.employeeId));
        break;
      case 'الراتب':
        sortedList.sort((a, b) => b.totalSalary.compareTo(a.totalSalary));
        break;
    }

    _hrProvider.setSortedEmployees(sortedList);
  }

  void _editEmployee(Employee employee) {
    Navigator.pushNamed(context, '/hr/employees/form', arguments: employee);
  }

  void _enrollFingerprint(Employee employee) {
    Navigator.pushNamed(
      context,
      '/hr/fingerprint/enrollment',
      arguments: employee.id,
    );
  }

  void _changeEmployeeStatus(Employee employee) {
    showDialog(
      context: context,
      builder: (context) {
        String newStatus = employee.status;
        String? terminationReason;
        DateTime? terminationDate;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('تغيير حالة ${employee.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: newStatus,
                      items: const [
                        DropdownMenuItem(value: 'نشط', child: Text('نشط')),
                        DropdownMenuItem(value: 'موقف', child: Text('موقف')),
                        DropdownMenuItem(
                          value: 'استقال',
                          child: Text('استقال'),
                        ),
                        DropdownMenuItem(value: 'مفصول', child: Text('مفصول')),
                        DropdownMenuItem(value: 'إجازة', child: Text('إجازة')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          newStatus = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'الحالة الجديدة',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    if (newStatus == 'مفصول')
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'سبب الفصل',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            onChanged: (value) {
                              terminationReason = value;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ الفصل',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  terminationDate = date;
                                });
                              }
                            },
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
                  onPressed: () async {
                    try {
                      await _hrProvider.changeEmployeeStatus(
                        employee.id,
                        newStatus,
                        terminationDate: terminationDate,
                        terminationReason: terminationReason,
                      );

                      if (!mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم تغيير حالة الموظف إلى $newStatus'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );

                      _loadEmployees();
                    } catch (error) {
                      if (!mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل تغيير الحالة: $error'),
                          backgroundColor: AppColors.errorRed,
                        ),
                      );
                    }
                  },
                  child: const Text('تأكيد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportEmployees() async {
    try {
      await _hrProvider.exportEmployees();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير بيانات الموظفين'),
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
