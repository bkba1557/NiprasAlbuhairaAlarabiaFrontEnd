import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeDetailsScreen({
    super.key,
    required this.employeeId,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Employee? _employee;
  List<Attendance> _recentAttendance = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.hrGet('/employees/${widget.employeeId}');
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final employee = Employee.fromJson(data);
        final recent = (data['recentAttendance'] as List? ?? [])
            .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() {
          _employee = employee;
          _recentAttendance = recent;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'تعذر جلب بيانات الموظف';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر جلب بيانات الموظف: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الموظف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                )
              : _employee == null
                  ? const Center(child: Text('لا توجد بيانات للموظف'))
                  : _buildDetails(context),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final employee = _employee!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 1100;
        final maxWidth = isWide ? 1200.0 : width;
        final sectionWidth = isWide ? (maxWidth / 2) - 12 : maxWidth;

        final sections = [
          _buildSectionCard(
            title: 'البيانات الأساسية',
            children: [
              _infoRow('رقم الموظف', employee.employeeId),
              _infoRow('الاسم', employee.name),
              _infoRow('الهوية الوطنية', employee.nationalId),
              _infoRow('الجنس', employee.gender),
              _infoRow('الجنسية', employee.nationality),
              _infoRow('المدينة', employee.city),
              _infoRow('تاريخ الميلاد', _formatDate(employee.dateOfBirth)),
            ],
          ),
          _buildSectionCard(
            title: 'بيانات العمل',
            children: [
              _infoRow('القسم', employee.department),
              _infoRow('الوظيفة', employee.position),
              _infoRow('نوع التوظيف', employee.employmentType),
              _infoRow('تاريخ التعيين', _formatDate(employee.hireDate)),
              _infoRow('بداية العقد', _formatDate(employee.contractStartDate)),
              _infoRow(
                'نهاية العقد',
                employee.contractEndDate == null
                    ? 'غير محدد'
                    : _formatDate(employee.contractEndDate!),
              ),
              _infoRow('حالة الموظف', employee.status),
            ],
          ),
          _buildSectionCard(
            title: 'الاتصال',
            children: [
              _infoRow('الجوال', employee.phone),
              _infoRow('البريد الإلكتروني', employee.email),
              _infoRow('العنوان', employee.address ?? 'غير محدد'),
            ],
          ),
          _buildSectionCard(
            title: 'الرواتب والمستحقات',
            children: [
              _infoRow(
                'الراتب الأساسي',
                employee.basicSalary.toStringAsFixed(2),
              ),
              _infoRow(
                'بدل السكن',
                employee.housingAllowance.toStringAsFixed(2),
              ),
              _infoRow(
                'بدل النقل',
                employee.transportationAllowance.toStringAsFixed(2),
              ),
              _infoRow(
                'بدلات أخرى',
                employee.otherAllowances.toStringAsFixed(2),
              ),
            ],
          ),
          _buildSectionCard(
            title: 'البصمة والجهاز',
            children: [
              _infoRow(
                'بصمة الإصبع',
                employee.fingerprintEnrolled ? 'مسجلة' : 'غير مسجلة',
              ),
              _infoRow(
                'بصمة الوجه',
                employee.faceEnrolled ? 'مسجلة' : 'غير مسجلة',
              ),
              _infoRow(
                'الجهاز',
                employee.hasDevice
                    ? (employee.assignedDeviceId ?? 'غير محدد')
                    : 'غير مرتبط',
              ),
            ],
          ),
          _buildSectionCard(
            title: 'سجل الحضور الأخير',
            children: _recentAttendance.isEmpty
                ? [const Text('لا توجد سجلات حضور حديثة')]
                : _recentAttendance
                    .map(
                      (record) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(record.formattedDate),
                        subtitle: Text(
                          'حضور: ${record.formattedCheckIn} • انصراف: ${record.formattedCheckOut}',
                        ),
                        trailing: Text(record.status),
                      ),
                    )
                    .toList(),
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(employee),
                  const SizedBox(height: 12),
                  if (isWide)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: sections
                          .map(
                            (section) => SizedBox(
                              width: sectionWidth,
                              child: section,
                            ),
                          )
                          .toList(),
                    )
                  else
                    ...sections
                        .expand((section) => [section, const SizedBox(height: 12)])
                        .toList()
                      ..removeLast(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(Employee employee) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.hrPurple,
              child: Text(
                employee.name.isNotEmpty ? employee.name[0] : '',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.employeeId,
                    style: const TextStyle(color: AppColors.mediumGray),
                  ),
                ],
              ),
            ),
            _statusChip(employee.status),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.hrDarkPurple,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mediumGray),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'نشط':
        color = AppColors.successGreen;
        break;
      case 'إجازة':
        color = AppColors.warningOrange;
        break;
      default:
        color = AppColors.errorRed;
    }
    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}
