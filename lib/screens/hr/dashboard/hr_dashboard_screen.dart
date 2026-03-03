import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/dashboard/stats_card.dart';
import 'package:order_tracker/widgets/hr/dashboard/quick_actions_card.dart';
import 'package:order_tracker/widgets/hr/dashboard/upcoming_events_card.dart';
import 'package:order_tracker/widgets/hr/dashboard/attendance_summary_card.dart';
import 'package:order_tracker/widgets/hr/dashboard/salary_summary_card.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen> {
  late HRProvider _hrProvider;
  bool _isLoading = true;
  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed[0];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    await _hrProvider.fetchDashboardStats();
    await _hrProvider.fetchTodayAttendance();
    await _hrProvider.fetchUpcomingEvents();
    await _hrProvider.fetchSalarySummary();

    setState(() {
      _isLoading = false;
    });
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
          'لوحة تحكم شؤون الموظفين',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              _showDateRangePicker();
            },
            tooltip: 'اختر الفترة',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 1400 : double.infinity,
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen
                    ? 24
                    : isMediumScreen
                    ? 20
                    : 16,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التاريخ والفترة الحالية
                  _buildDateHeader(),

                  const SizedBox(height: 16),

                  // إحصائيات سريعة
                  if (_isLoading)
                    _buildLoadingStats()
                  else
                    _buildStatsGrid(isLargeScreen, isMediumScreen),

                  const SizedBox(height: 32),

                  // الإجراءات السريعة
                  _buildQuickActions(isLargeScreen),

                  const SizedBox(height: 32),

                  // الحضور اليومي
                  _buildTodayAttendance(),

                  const SizedBox(height: 32),

                  // الملخص المالي
                  _buildFinancialSummary(isLargeScreen),

                  const SizedBox(height: 32),

                  // الأحداث القادمة
                  _buildUpcomingEvents(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/hr/fingerprint/attendance');
        },
        icon: const Icon(Icons.fingerprint),
        label: const Text('تسجيل بالبصمة'),
        backgroundColor: AppColors.appBarWaterMid,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final hijriFormat = DateFormat('yyyy/MM/dd', 'ar');
    final gregorianFormat = DateFormat('yyyy/MM/dd', 'ar');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التاريخ الهجري: ${hijriFormat.format(now)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.appBarWaterDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'التاريخ الميلادي: ${gregorianFormat.format(now)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
            Chip(
              label: Text(
                DateFormat('EEEE', 'ar').format(now),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppColors.appBarWaterDeep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: List.generate(6, (index) {
        return const StatsCard(
          title: '...',
          value: '...',
          icon: Icons.hourglass_empty,
          color: Colors.grey,
          subtitle: 'جاري التحميل',
        );
      }),
    );
  }

  Widget _buildStatsGrid(bool isLargeScreen, bool isMediumScreen) {
    final stats = _hrProvider.dashboardStats;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isLargeScreen
          ? 4
          : isMediumScreen
          ? 2
          : 1,
      childAspectRatio: isLargeScreen
          ? 1.4
          : isMediumScreen
          ? 1.6
          : 1.8,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        StatsCard(
          title: 'إجمالي الموظفين',
          value: stats?.totalEmployees.toString() ?? '0',
          icon: Icons.people,
          color: AppColors.appBarWaterBright,
          subtitle: '${stats?.activeEmployees ?? 0} نشط',
          trend: '+${stats?.activeEmployees ?? 0}',
          onTap: () {
            Navigator.pushNamed(context, '/hr/employees');
          },
        ),
        StatsCard(
          title: 'الحاضرون اليوم',
          value: stats?.presentToday.toString() ?? '0',
          icon: Icons.check_circle,
          color: AppColors.appBarWaterGlow,
          subtitle: '${stats?.absentToday ?? 0} غائب',
          trend: '${stats?.lateToday ?? 0} متأخر',
          onTap: () {
            Navigator.pushNamed(context, '/hr/attendance');
          },
        ),
        StatsCard(
          title: 'رواتب هذا الشهر',
          value:
              '${(stats?.totalSalariesThisMonth ?? 0).toStringAsFixed(0)} ر.س',
          icon: Icons.attach_money,
          color: AppColors.appBarWaterMid,
          subtitle: 'إجمالي الرواتب',
          trend: 'شهري',
          onTap: () {
            Navigator.pushNamed(context, '/hr/salaries');
          },
        ),
        StatsCard(
          title: 'سلف مستحقة',
          value: '${(stats?.totalAdvancesDue ?? 0).toStringAsFixed(0)} ر.س',
          icon: Icons.credit_card,
          color: AppColors.accentBlue,
          subtitle: '${stats?.pendingAdvances ?? 0} معلقة',
          trend: '${stats?.pendingAdvances ?? 0}+',
          onTap: () {
            Navigator.pushNamed(context, '/hr/advances');
          },
        ),
        StatsCard(
          title: 'عقود منتهية',
          value: stats?.contractExpiringThisMonth.toString() ?? '0',
          icon: Icons.assignment_late,
          color: AppColors.appBarWaterDeep,
          subtitle: 'هذا الشهر',
          trend: 'تنتهي قريباً',
          onTap: () {
            _showExpiringContracts();
          },
        ),
        StatsCard(
          title: 'إقامات منتهية',
          value: stats?.residencyExpiringThisMonth.toString() ?? '0',
          icon: Icons.warning,
          color: AppColors.appBarWaterBright,
          subtitle: 'هذا الشهر',
          trend: 'تجديد مطلوب',
          onTap: () {
            _showExpiringResidencies();
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isLargeScreen) {
    return QuickActionsCard(
      isLargeScreen: isLargeScreen,
      onAddEmployee: () {
        Navigator.pushNamed(context, '/hr/employees/form');
      },
      onAddAttendance: () {
        Navigator.pushNamed(context, '/hr/attendance');
      },
      onAddSalary: () {
        Navigator.pushNamed(context, '/hr/salaries');
      },
      onAddAdvance: () {
        Navigator.pushNamed(context, '/hr/advances/form');
      },
      onAddPenalty: () {
        Navigator.pushNamed(context, '/hr/penalties/form');
      },
      onAddLocation: () {
        Navigator.pushNamed(context, '/hr/locations/form');
      },
      onDeviceRequests: () {
        Navigator.pushNamed(context, AppRoutes.deviceEnrollmentRequests);
      },
    );
  }

  Widget _buildTodayAttendance() {
    return AttendanceSummaryCard(
      attendanceRecords: _hrProvider.todayAttendance,
      isLoading: _isLoading,
      onRefresh: _loadDashboardData,
      onViewAll: () {
        Navigator.pushNamed(context, '/hr/attendance');
      },
    );
  }

  Widget _buildFinancialSummary(bool isLargeScreen) {
    return SalarySummaryCard(
      salarySummary: _hrProvider.salarySummary,
      isLargeScreen: isLargeScreen,
      isLoading: _isLoading,
      onViewAll: () {
        Navigator.pushNamed(context, '/hr/salaries');
      },
      onGenerateSalaries: () {
        _generateSalarySheets();
      },
    );
  }

  Widget _buildUpcomingEvents() {
    return UpcomingEventsCard(
      events: _hrProvider.upcomingEvents,
      isLoading: _isLoading,
      onViewAll: () {
        _showAllUpcomingEvents();
      },
          onAddEvent: () {
            _addNewEvent();
          },
        );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('اختر الفترة'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('اليوم'),
                  onTap: () {
                    Navigator.pop(context);
                    _loadDashboardData();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('هذا الأسبوع'),
                  onTap: () {
                    Navigator.pop(context);
                    // تحميل بيانات الأسبوع
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('هذا الشهر'),
                  onTap: () {
                    Navigator.pop(context);
                    // تحميل بيانات الشهر
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.filter_alt),
                  title: const Text('فترة مخصصة'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomDateRangePicker();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      // تحميل البيانات للفترة المحددة
      // _hrProvider.fetchDataForDateRange(picked.start, picked.end);
    }
  }

  void _showExpiringContracts() {
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
                'العقود المنتهية هذا الشهر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _hrProvider.expiringContracts.isEmpty
                    ? const Center(child: Text('لا توجد عقود منتهية هذا الشهر'))
                    : ListView.builder(
                        itemCount: _hrProvider.expiringContracts.length,
                        itemBuilder: (context, index) {
                          final employee = _hrProvider.expiringContracts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.appBarWaterDeep,
                              child: Text(
                                _initial(employee.name),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(employee.name),
                            subtitle: Text(
                              'ينتهي العقد: ${DateFormat('yyyy-MM-dd').format(employee.contractEndDate!)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.notifications_active),
                              onPressed: () {
                                _sendContractReminder(employee.id);
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExpiringResidencies() {
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
                'الإقامات المنتهية هذا الشهر',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _hrProvider.expiringResidencies.isEmpty
                    ? const Center(
                        child: Text('لا توجد إقامات منتهية هذا الشهر'),
                      )
                    : ListView.builder(
                        itemCount: _hrProvider.expiringResidencies.length,
                        itemBuilder: (context, index) {
                          final employee =
                              _hrProvider.expiringResidencies[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.appBarWaterBright,
                              child: const Icon(
                                Icons.card_membership,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(employee.name),
                            subtitle: Text(
                              'تنتهي الإقامة: ${DateFormat('yyyy-MM-dd').format(employee.residencyExpiryDate!)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.notifications_active),
                              onPressed: () {
                                _sendResidencyReminder(employee.id);
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _generateSalarySheets() async {
    final month = DateTime.now().month;
    final year = DateTime.now().year;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('جاري إنشاء كشوف الرواتب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('يرجى الانتظار...'),
          ],
        ),
      ),
    );

    try {
      await _hrProvider.generateSalarySheets(month, year);
      if (!mounted) return;

      Navigator.pop(context); // إغلاق دالة التحميل

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء كشوف رواتب $month/$year'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      _loadDashboardData();
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إنشاء كشوف الرواتب: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _showAllUpcomingEvents() {
    Navigator.pushNamed(context, '/hr/events');
  }

  void _addNewEvent() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة حدث جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'عنوان الحدث',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'وصف الحدث',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'التاريخ',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      // تحديث الحقل
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
              onPressed: () {
                // حفظ الحدث
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _sendContractReminder(String employeeId) async {
    try {
      await _hrProvider.sendContractReminder(employeeId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التنبيه'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال التنبيه: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _sendResidencyReminder(String employeeId) async {
    try {
      await _hrProvider.sendResidencyReminder(employeeId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التنبيه'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال التنبيه: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
