import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/hr/attendance/attendance_filter_dialog.dart';
import 'package:order_tracker/widgets/hr/attendance/attendance_record_card.dart';
import 'package:order_tracker/widgets/hr/attendance/manual_attendance_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late HRProvider _hrProvider;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedStatus = 'جميع الحالات';
  String _selectedDepartment = 'جميع الأقسام';
  String _selectedSort = 'الأحدث';
  bool _showManualRecords = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendance();
    });
    _selectedDate = DateTime.now();
  }

  Future<void> _loadAttendance() async {
    await _hrProvider.fetchAttendanceRecords(
      date: _selectedDate,
      startDate: _startDate,
      endDate: _endDate,
      status: _selectedStatus == 'جميع الحالات' ? null : _selectedStatus,
      department: _selectedDepartment == 'جميع الأقسام'
          ? null
          : _selectedDepartment,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
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
          'الحضور والانصراف',
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
            onPressed: _exportAttendance,
            tooltip: 'تصدير',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addManualAttendance,
            tooltip: 'إضافة يدوي',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendance,
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // شريط التاريخ والبحث
          _buildDateBar(),

          // إحصائيات الحضور
          _buildAttendanceStats(),

          // قائمة سجلات الحضور
          Expanded(child: _buildAttendanceList(isLargeScreen)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/hr/fingerprint/attendance');
        },
        backgroundColor: AppColors.hrCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.fingerprint),
      ),
    );
  }

  Widget _buildDateBar() {
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
                        _loadAttendance();
                      },
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      _loadAttendance();
                    }
                  },
                  onSubmitted: (value) {
                    _loadAttendance();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _selectDate,
                tooltip: 'اختر تاريخ',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateChip('اليوم', () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _startDate = null;
                  _endDate = null;
                  _loadAttendance();
                });
              }),
              _buildDateChip('أمس', () {
                setState(() {
                  _selectedDate = DateTime.now().subtract(
                    const Duration(days: 1),
                  );
                  _startDate = null;
                  _endDate = null;
                  _loadAttendance();
                });
              }),
              _buildDateChip('هذا الأسبوع', () {
                final now = DateTime.now();
                final startOfWeek = now.subtract(
                  Duration(days: now.weekday - 1),
                );
                setState(() {
                  _selectedDate = null;
                  _startDate = startOfWeek;
                  _endDate = now;
                  _loadAttendance();
                });
              }),
              _buildDateChip('هذا الشهر', () {
                final now = DateTime.now();
                final startOfMonth = DateTime(now.year, now.month, 1);
                final endOfMonth = DateTime(now.year, now.month + 1, 0);
                setState(() {
                  _selectedDate = null;
                  _startDate = startOfMonth;
                  _endDate = endOfMonth;
                  _loadAttendance();
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, VoidCallback onTap) {
    final isSelected =
        (label == 'اليوم' && _selectedDate != null) ||
        (label == 'أمس' &&
            _selectedDate != null &&
            DateFormat('yyyy-MM-dd').format(_selectedDate!) ==
                DateFormat(
                  'yyyy-MM-dd',
                ).format(DateTime.now().subtract(const Duration(days: 1)))) ||
        (label == 'هذا الأسبوع' && _startDate != null && _endDate != null) ||
        (label == 'هذا الشهر' && _startDate != null && _endDate != null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.hrCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.hrCyan : AppColors.lightGray,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.darkGray,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceStats() {
    final stats = _hrProvider.attendanceStats;

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
            'إجمالي السجلات',
            stats?['totalRecords']?.toString() ?? '0',
            AppColors.hrCyan,
            Icons.list,
          ),
          _buildStatItem(
            'حاضر',
            stats?['present']?.toString() ?? '0',
            AppColors.attendancePresent,
            Icons.check_circle,
          ),
          _buildStatItem(
            'متأخر',
            stats?['late']?.toString() ?? '0',
            AppColors.attendanceLate,
            Icons.schedule,
          ),
          _buildStatItem(
            'غياب',
            stats?['absent']?.toString() ?? '0',
            AppColors.attendanceAbsent,
            Icons.cancel,
          ),
          _buildStatItem(
            'إجازة',
            stats?['leave']?.toString() ?? '0',
            AppColors.attendanceLeave,
            Icons.beach_access,
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

  Widget _buildAttendanceList(bool isLargeScreen) {
    if (_hrProvider.isLoadingAttendance) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hrProvider.attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: AppColors.lightGray),
            const SizedBox(height: 16),
            const Text(
              'لا توجد سجلات حضور',
              style: TextStyle(fontSize: 18, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadAttendance,
              child: const Text('تحديث'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _hrProvider.attendanceRecords.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final record = _hrProvider.attendanceRecords[index];
          return AttendanceRecordCard(
            attendance: record,
            onTap: () {
              _viewAttendanceDetails(record);
            },
            onEdit: () {
              _editAttendance(record);
            },
          );
        },
      ),
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
        _startDate = null;
        _endDate = null;
        _loadAttendance();
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AttendanceFilterDialog(
          selectedStatus: _selectedStatus,
          selectedDepartment: _selectedDepartment,
          selectedSort: _selectedSort,
          showManualRecords: _showManualRecords,
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
          onManualRecordsChanged: (value) {
            setState(() {
              _showManualRecords = value;
            });
          },
          onApply: () {
            Navigator.pop(context);
            _loadAttendance();
          },
          onClear: () {
            setState(() {
              _selectedStatus = 'جميع الحالات';
              _selectedDepartment = 'جميع الأقسام';
              _selectedSort = 'الأحدث';
              _showManualRecords = false;
              _selectedDate = DateTime.now();
              _startDate = null;
              _endDate = null;
              _searchController.clear();
            });
            Navigator.pop(context);
            _loadAttendance();
          },
        );
      },
    );
  }

  void _addManualAttendance() {
    showDialog(
      context: context,
      builder: (context) {
        return ManualAttendanceDialog(
          onSave: (attendanceData) async {
            try {
              await _hrProvider.addManualAttendance(attendanceData);
              if (!mounted) return;
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تسجيل الحضور يدوياً'),
                  backgroundColor: AppColors.successGreen,
                ),
              );

              _loadAttendance();
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فشل التسجيل: $error'),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _viewAttendanceDetails(Attendance attendance) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تفاصيل الحضور - ${attendance.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('التاريخ', attendance.formattedDate),
                _buildDetailRow('رقم الموظف', attendance.employeeNumber),
                _buildDetailRow(
                  'القسم',
                  _getEmployeeDepartment(attendance.employeeId),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الحضور:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildCheckDetail('الوقت', attendance.formattedCheckIn),
                _buildCheckDetail(
                  'المكان',
                  attendance.checkIn?.location?.address ?? 'غير محدد',
                ),
                _buildCheckDetail(
                  'حالة الموقع',
                  attendance.checkIn?.locationStatus ?? 'غير مسجل',
                ),
                _buildCheckDetail(
                  'تأخير',
                  attendance.checkIn?.isLate == true
                      ? '${attendance.checkIn?.lateMinutes} دقيقة'
                      : 'لا يوجد',
                ),
                const SizedBox(height: 16),
                const Text(
                  'الانصراف:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildCheckDetail('الوقت', attendance.formattedCheckOut),
                _buildCheckDetail(
                  'المكان',
                  attendance.checkOut?.location?.address ?? 'غير محدد',
                ),
                _buildCheckDetail(
                  'انصراف مبكر',
                  attendance.checkOut?.isEarly == true
                      ? '${attendance.checkOut?.earlyMinutes} دقيقة'
                      : 'لا يوجد',
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  'إجمالي الساعات',
                  attendance.formattedTotalHours,
                ),
                _buildDetailRow(
                  'ساعات إضافية',
                  attendance.overtimeHours?.toStringAsFixed(2) ?? '0.00',
                ),
                _buildDetailRow('الحالة', attendance.status),
                if (attendance.notes != null)
                  _buildDetailRow('ملاحظات', attendance.notes!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            if (_canEditAttendance(attendance))
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _editAttendance(attendance);
                },
                child: const Text('تعديل'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildCheckDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.mediumGray),
          ),
        ],
      ),
    );
  }

  bool _canEditAttendance(Attendance attendance) {
    // يمكن للمديرين والمشرفين تعديل السجلات
    return true;
  }

  void _editAttendance(Attendance attendance) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل حضور ${attendance.employeeName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'وقت الحضور',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  controller: TextEditingController(
                    text: attendance.formattedCheckIn,
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        attendance.checkIn?.time ?? DateTime.now(),
                      ),
                    );
                    if (time != null) {
                      // تحديث الوقت
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'وقت الانصراف',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  controller: TextEditingController(
                    text: attendance.formattedCheckOut,
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        attendance.checkOut?.time ?? DateTime.now(),
                      ),
                    );
                    if (time != null) {
                      // تحديث الوقت
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: attendance.status),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(
                    text: attendance.notes ?? '',
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
              onPressed: () async {
                try {
                  await _hrProvider.updateAttendance(attendance.id, {
                    'status': attendance.status,
                    'notes': attendance.notes,
                  });

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث سجل الحضور'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );

                  _loadAttendance();
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل التحديث: $error'),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportAttendance() async {
    try {
      await _hrProvider.exportAttendance(
        startDate: _startDate,
        endDate: _endDate,
        date: _selectedDate,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير سجلات الحضور'),
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

  String _getEmployeeDepartment(String employeeId) {
    for (final employee in _hrProvider.employees) {
      if (employee.id == employeeId) {
        return employee.department;
      }
    }
    return 'غير محدد';
  }
}
