import 'package:flutter/material.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/screens/maintenance/daily_check_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/widgets/maintenance/daily_check_card.dart';
import 'package:order_tracker/widgets/maintenance/supervisor_action_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  final String maintenanceId;

  const MaintenanceDetailScreen({super.key, required this.maintenanceId});

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  int _selectedTab = 0;
  DateTime? _selectedDate;

  bool _isNewDailyCheck(Map<String, dynamic> check) {
    final fields = [
      'vehicleSafety',
      'driverSafety',
      'electricalMaintenance',
      'mechanicalMaintenance',
      'tankInspection',
      'tiresInspection',
      'brakesInspection',
      'lightsInspection',
      'fluidsCheck',
      'emergencyEquipment',
    ];

    for (final f in fields) {
      if (check[f] == 'تم') return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<MaintenanceProvider>(context, listen: false);
    await provider.fetchMaintenanceRecordById(widget.maintenanceId);
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('تصدير كـ PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('تصدير كـ Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('مشاركة'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement sharing
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPDF() async {
    final provider = Provider.of<MaintenanceProvider>(context, listen: false);
    try {
      await provider.exportToPDF(widget.maintenanceId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير الملف بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    final provider = Provider.of<MaintenanceProvider>(context, listen: false);
    try {
      await provider.exportToExcel(widget.maintenanceId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير الملف بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddCheckDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فحص يومي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('فحص اليوم'),
                subtitle: Text(
                  _selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                      : DateFormat('yyyy-MM-dd').format(DateTime.now()),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/maintenance/daily-check',
                    arguments: {
                      'maintenanceId': widget.maintenanceId,
                      'date': _selectedDate ?? DateTime.now(),
                    },
                  );
                },
                child: const Text('متابعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupervisorActions() {
    showDialog(
      context: context,
      builder: (context) => SupervisorActionDialog(
        maintenanceId: widget.maintenanceId,
        onSendWarning: () {
          _showSendWarningDialog();
        },
        onSendNote: () {
          _showSendNoteDialog();
        },
      ),
    );
  }

  void _showSendWarningDialog() {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال تحذير'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'رسالة التحذير',
            hintText: 'أدخل رسالة التحذير...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isNotEmpty) {
                final provider = Provider.of<MaintenanceProvider>(
                  context,
                  listen: false,
                );
                await provider.sendWarning(
                  widget.maintenanceId,
                  messageController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال التحذير بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _showSendNoteDialog() {
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال ملاحظة'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'الملاحظة',
            hintText: 'أدخل الملاحظة...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                final provider = Provider.of<MaintenanceProvider>(
                  context,
                  listen: false,
                );
                await provider.sendNote(
                  widget.maintenanceId,
                  noteController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال الملاحظة بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveCheck(String checkId, String notes) async {
    final provider = Provider.of<MaintenanceProvider>(context, listen: false);
    await provider.approveDailyCheck(
      widget.maintenanceId,
      checkId,
      notes: notes,
    );
  }

  Future<void> _rejectCheck(String checkId, String notes) async {
    final provider = Provider.of<MaintenanceProvider>(context, listen: false);
    await provider.rejectDailyCheck(
      widget.maintenanceId,
      checkId,
      notes: notes,
    );
  }

  void _showReviewDialog({required String checkId, required bool approve}) {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'اعتماد الفحص' : 'رفض الفحص'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'ملاحظات المشرف',
            hintText: 'اكتب ملاحظاتك هنا...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (approve) {
                  await _approveCheck(checkId, notesController.text.trim());
                } else {
                  await _rejectCheck(checkId, notesController.text.trim());
                }

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(approve ? 'تم اعتماد الفحص' : 'تم رفض الفحص'),
                    backgroundColor: approve ? Colors.green : Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(approve ? 'اعتماد' : 'رفض'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MaintenanceProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final record = provider.currentRecord;
    final role = authProvider.user?.role ?? '';
    final isSupervisor = role == 'maintenance_car_management';

    if (provider.isLoading && record == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الصيانة')),
        body: const Center(child: Text('سجل الصيانة غير موجود')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'صيانة ${record['plateNumber']}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          selectionColor: Colors.white,
        ),
        actions: [
          IconButton(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.download),
          ),
          PopupMenuButton(
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
              ];
              if (isSupervisor) {
                items.add(
                  const PopupMenuItem(
                    value: 'supervisor',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings),
                        SizedBox(width: 8),
                        Text('إجراءات المشرف'),
                      ],
                    ),
                  ),
                );
              }
              return items;
            },
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.maintenanceEdit,
                  arguments: record,
                );
              } else if (value == 'supervisor' && isSupervisor) {
                _showSupervisorActions();
              }
            },
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton(
              onPressed: _showAddCheckDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: _buildResponsiveBody(record, isSupervisor),
    );
  }

  Widget _buildResponsiveBody(dynamic record, bool isSupervisor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 600;
    final isSmallScreen = screenWidth < 400;

    return Column(
      children: [
        // =========================
        // 📱 Responsive Tab Bar
        // =========================
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              _buildTabButton('المعلومات', 0, Icons.info_outline),
              _buildTabButton('الفحوصات اليومية', 1, Icons.checklist),
              _buildTabButton('الإجراءات', 2, Icons.history),
            ],
          ),
        ),

        // =========================
        // 📊 Responsive Content
        // =========================
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildInformationTab(record, isLargeScreen, isMediumScreen),
              _buildDailyChecksTab(
                record,
                isSupervisor,
                isLargeScreen,
                isMediumScreen,
              ),
              _buildActionsTab(
                record,
                isSupervisor,
                isLargeScreen,
                isMediumScreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationTab(
    dynamic record,
    bool isLargeScreen,
    bool isMediumScreen,
  ) {
    final completedDays = (record['completedDays'] ?? 0) as num;
    final totalDays = (record['totalDays'] ?? 0) as num;
    final completionRate = totalDays > 0
        ? ((completedDays / totalDays) * 100).toStringAsFixed(2)
        : '0.00';
    final driverLicenseExpiry = DateTime.tryParse(
      record['driverLicenseExpiry']?.toString() ?? '',
    );
    final vehicleLicenseExpiry = DateTime.tryParse(
      record['vehicleLicenseExpiry']?.toString() ?? '',
    );
    final vehicleOperatingCardIssueDate = DateTime.tryParse(
      record['vehicleOperatingCardIssueDate']?.toString() ?? '',
    );
    final vehicleOperatingCardExpiryDate = DateTime.tryParse(
      record['vehicleOperatingCardExpiryDate']?.toString() ?? '',
    );
    final driverOperatingCardIssueDate = DateTime.tryParse(
      record['driverOperatingCardIssueDate']?.toString() ?? '',
    );
    final driverOperatingCardExpiryDate = DateTime.tryParse(
      record['driverOperatingCardExpiryDate']?.toString() ?? '',
    );
    final vehicleRegistrationIssueDate = DateTime.tryParse(
      record['vehicleRegistrationIssueDate']?.toString() ?? '',
    );
    final vehicleRegistrationExpiryDate = DateTime.tryParse(
      record['vehicleRegistrationExpiryDate']?.toString() ?? '',
    );
    final vehiclePeriodicInspectionIssueDate = DateTime.tryParse(
      record['vehiclePeriodicInspectionIssueDate']?.toString() ?? '',
    );
    final vehiclePeriodicInspectionExpiryDate = DateTime.tryParse(
      record['vehiclePeriodicInspectionExpiryDate']?.toString() ?? '',
    );
    final driverInsuranceIssueDate = DateTime.tryParse(
      record['driverInsuranceIssueDate']?.toString() ?? '',
    );
    final driverInsuranceExpiryDate = DateTime.tryParse(
      record['driverInsuranceExpiryDate']?.toString() ?? '',
    );
    final vehicleInsuranceIssueDate = DateTime.tryParse(
      record['vehicleInsuranceIssueDate']?.toString() ?? '',
    );
    final vehicleInsuranceExpiryDate = DateTime.tryParse(
      record['vehicleInsuranceExpiryDate']?.toString() ?? '',
    );
    final double infoCardMaxWidth = isLargeScreen
        ? 1100
        : isMediumScreen
        ? 900
        : double.infinity;
    final double infoGridAspectRatio = isLargeScreen
        ? 2.2
        : isMediumScreen
        ? 1.4
        : 1.1;

    Widget wrapSectionCard(Widget child) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: infoCardMaxWidth),
          child: child,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          isLargeScreen
              ? 24
              : isMediumScreen
              ? 20
              : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // 🚗 Vehicle Information
            // =========================
            Center(
              child: Text(
                'معلومات المركبة',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            wrapSectionCard(
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 50
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isLargeScreen
                              ? 5
                              : isMediumScreen
                              ? 2
                              : 1,
                          crossAxisSpacing: 30,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          final items = [
                            {
                              'title': 'رقم اللوحة',
                              'value': record['plateNumber'] ?? '-',
                              'icon': Icons.confirmation_number,
                              'color': Colors.blue,
                            },
                            {
                              'title': 'رقم التانكي',
                              'value': record['tankNumber'] ?? '-',
                              'icon': Icons.local_gas_station,
                              'color': Colors.green,
                            },
                            {
                              'title': 'نوع المركبة',
                              'value': record['vehicleType'] ?? '-',
                              'icon': Icons.directions_car,
                              'color': Colors.orange,
                            },
                            {
                              'title': 'نوع الوقود',
                              'value': record['fuelType'] ?? '-',
                              'icon': Icons.local_gas_station,
                              'color': Colors.red,
                            },
                            {
                              'title': 'شهر التفتيش',
                              'value': record['inspectionMonth'] ?? '-',
                              'icon': Icons.calendar_today,
                              'color': Colors.purple,
                            },
                          ];

                          final item = items[index];

                          return _buildInfoCard(
                            item['title'] as String,
                            item['value'] as String,
                            item['icon'] as IconData,
                            item['color'] as Color,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // =========================
            // 👤 Driver Information
            // =========================
            Center(
              child: Text(
                'معلومات السائق',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            wrapSectionCard(
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 24
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 5 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'رقم الهوية',
                            record['driverId'] ?? '-',
                            Icons.badge,
                            Colors.blue,
                          ),
                          _buildInfoCard(
                            'اسم السائق',
                            record['driverName'] ?? '-',
                            Icons.person,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'رقم رخصة السائق',
                            record['driverLicenseNumber'] ?? '-',
                            Icons.card_membership,
                            Colors.orange,
                          ),
                          _buildInfoCard(
                            'انتهاء رخصة السائق',
                            driverLicenseExpiry != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(driverLicenseExpiry)
                                : '-',
                            Icons.calendar_today,
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // =========================
            // 📝 License Information
            // =========================
            Center(
              child: Text(
                'معلومات الرخصة',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            wrapSectionCard(
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 24
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 5 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'رقم رخصة المركبة',
                            record['vehicleLicenseNumber'] ?? '-',
                            Icons.directions_car_filled,
                            Colors.blue,
                          ),
                          _buildInfoCard(
                            'انتهاء رخصة المركبة',
                            vehicleLicenseExpiry != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleLicenseExpiry)
                                : '-',
                            Icons.event_busy,
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // =========================
            // =========================
            // Operating Cards
            // =========================
            Center(
              child: Text(
                'بطاقات التشغيل',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            wrapSectionCard(
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 24
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بطاقة تشغيل السيارة',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 18
                              : isMediumScreen
                              ? 16
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 3 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'رقم البطاقة',
                            record['vehicleOperatingCardNumber'] ?? '-',
                            Icons.confirmation_number,
                            Colors.teal,
                          ),
                          _buildInfoCard(
                            'تاريخ الإصدار',
                            vehicleOperatingCardIssueDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleOperatingCardIssueDate)
                                : '-',
                            Icons.event_available,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'تاريخ الانتهاء',
                            vehicleOperatingCardExpiryDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleOperatingCardExpiryDate)
                                : '-',
                            Icons.event_busy,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'بطاقة تشغيل السائق',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 18
                              : isMediumScreen
                              ? 16
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 4 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'اسم السائق',
                            record['driverOperatingCardName'] ?? '-',
                            Icons.person,
                            Colors.blue,
                          ),
                          _buildInfoCard(
                            'رقم البطاقة',
                            record['driverOperatingCardNumber'] ?? '-',
                            Icons.credit_card,
                            Colors.orange,
                          ),
                          _buildInfoCard(
                            'تاريخ الإصدار',
                            driverOperatingCardIssueDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(driverOperatingCardIssueDate)
                                : '-',
                            Icons.event_available,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'تاريخ الانتهاء',
                            driverOperatingCardExpiryDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(driverOperatingCardExpiryDate)
                                : '-',
                            Icons.event_busy,
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // =========================
            // Vehicle Registration
            // =========================
            Center(
              child: Text(
                'استمارة السيارة',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            wrapSectionCard(
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 24
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 3 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'الرقم التسلسلي',
                            record['vehicleRegistrationSerialNumber'] ?? '-',
                            Icons.tag,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'رقم السيارة',
                            record['vehicleRegistrationNumber'] ?? '-',
                            Icons.directions_car,
                            Colors.blue,
                          ),
                          _buildInfoCard(
                            'رقم اللوحة',
                            record['plateNumber'] ?? '-',
                            Icons.confirmation_number,
                            Colors.orange,
                          ),
                          _buildInfoCard(
                            'تاريخ الإصدار',
                            vehicleRegistrationIssueDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleRegistrationIssueDate)
                                : '-',
                            Icons.event_available,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'تاريخ الانتهاء',
                            vehicleRegistrationExpiryDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleRegistrationExpiryDate)
                                : '-',
                            Icons.event_busy,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSaudiVehicleLicenseCard(
                        record: record,
                        issueDate: vehicleRegistrationIssueDate,
                        expiryDate: vehicleRegistrationExpiryDate,
                        isLargeScreen: isLargeScreen,
                        isMediumScreen: isMediumScreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // =========================
            // Periodic Vehicle Inspection (Vehicle Safety Center)
            // =========================
            Center(
              child: Text(
                'الفحص الدوري (مركز سلامة المركبات)',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            wrapSectionCard(
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 24
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isLargeScreen ? 2 : 1,
                    childAspectRatio: infoGridAspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 12,
                    children: [
                      _buildInfoCard(
                        'تاريخ الإصدار',
                        vehiclePeriodicInspectionIssueDate != null
                            ? DateFormat('yyyy-MM-dd')
                                .format(vehiclePeriodicInspectionIssueDate)
                            : '-',
                        Icons.event_available,
                        Colors.green,
                      ),
                      _buildInfoCard(
                        'تاريخ الانتهاء',
                        vehiclePeriodicInspectionExpiryDate != null
                            ? DateFormat('yyyy-MM-dd')
                                .format(vehiclePeriodicInspectionExpiryDate)
                            : '-',
                        Icons.event_busy,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // =========================
            // Insurance
            // =========================
            Center(
              child: Text(
                'التأمين',
                style: TextStyle(
                  fontSize: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            wrapSectionCard(
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isLargeScreen
                        ? 24
                        : isMediumScreen
                        ? 20
                        : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تأمين السائق',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 18
                              : isMediumScreen
                              ? 16
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 3 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'رقم البوليصة',
                            record['driverInsurancePolicyNumber'] ?? '-',
                            Icons.numbers,
                            Colors.indigo,
                          ),
                          _buildInfoCard(
                            'تاريخ الإصدار',
                            driverInsuranceIssueDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(driverInsuranceIssueDate)
                                : '-',
                            Icons.event_available,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'تاريخ الانتهاء',
                            driverInsuranceExpiryDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(driverInsuranceExpiryDate)
                                : '-',
                            Icons.event_busy,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تأمين السيارة',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 18
                              : isMediumScreen
                              ? 16
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isLargeScreen ? 3 : 1,
                        childAspectRatio: infoGridAspectRatio,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        children: [
                          _buildInfoCard(
                            'رقم البوليصة',
                            record['vehicleInsurancePolicyNumber'] ?? '-',
                            Icons.numbers,
                            Colors.indigo,
                          ),
                          _buildInfoCard(
                            'تاريخ الإصدار',
                            vehicleInsuranceIssueDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleInsuranceIssueDate)
                                : '-',
                            Icons.event_available,
                            Colors.green,
                          ),
                          _buildInfoCard(
                            'تاريخ الانتهاء',
                            vehicleInsuranceExpiryDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(vehicleInsuranceExpiryDate)
                                : '-',
                            Icons.event_busy,
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 📊 Monthly Summary
            // =========================
            Text(
              'ملخص الشهر',
              style: TextStyle(
                fontSize: isLargeScreen
                    ? 24
                    : isMediumScreen
                    ? 20
                    : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isLargeScreen
                          ? 4
                          : isMediumScreen
                          ? 2
                          : 1,
                      childAspectRatio: isLargeScreen ? 3 : 1.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildStatCard(
                          'الأيام المكتملة',
                          completedDays.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'الأيام المعلقة',
                          record['pendingDays']?.toString() ?? '0',
                          Icons.pending,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'إجمالي الأيام',
                          totalDays.toString(),
                          Icons.calendar_view_month,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'نسبة الإنجاز',
                          '$completionRate%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          record['monthlyStatus'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(
                            record['monthlyStatus'],
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الحالة النهائية:',
                            style: TextStyle(
                              fontSize: isLargeScreen ? 18 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(
                            label: Text(
                              record['monthlyStatus'] ?? 'غير محدد',
                              style: TextStyle(
                                color: _getStatusColor(record['monthlyStatus']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: _getStatusColor(
                              record['monthlyStatus'],
                            ).withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChecksTab(
    dynamic record,
    bool isSupervisor,
    bool isLargeScreen,
    bool isMediumScreen,
  ) {
    final dailyChecks = record['dailyChecks'] ?? [];
    final double maxCardWidth = isLargeScreen
        ? 900
        : isMediumScreen
        ? 720
        : double.infinity;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // =========================
          // 📈 Stats Header
          // =========================
          Container(
            padding: EdgeInsets.all(
              isLargeScreen
                  ? 24
                  : isMediumScreen
                  ? 20
                  : 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الفحوصات اليومية',
                        style: TextStyle(
                          fontSize: isLargeScreen
                              ? 22
                              : isMediumScreen
                              ? 18
                              : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'إجمالي الفحوصات: ${dailyChecks.length}',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 16 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Chip(
                      label: Text('مكتمل: ${record['completedDays'] ?? 0}'),
                      backgroundColor: Colors.green.shade100,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 16 : 12,
                        vertical: isLargeScreen ? 8 : 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('معلق: ${record['pendingDays'] ?? 0}'),
                      backgroundColor: Colors.orange.shade100,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 16 : 12,
                        vertical: isLargeScreen ? 8 : 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // =========================
          // 📋 Daily Checks List
          // =========================
          Expanded(
            child: dailyChecks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist,
                          size: isLargeScreen ? 100 : 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد فحوصات يومية',
                          style: TextStyle(
                            fontSize: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 18
                                : 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'انقر على زر + لإضافة فحص جديد',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 16 : 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(
                      isLargeScreen
                          ? 24
                          : isMediumScreen
                          ? 20
                          : 16,
                    ),
                    itemCount: dailyChecks.length,
                    itemBuilder: (context, index) {
                      final check = dailyChecks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxCardWidth),
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    DailyCheckCard(
                                      check: check,
                                      isLargeScreen: isLargeScreen,
                                      isMediumScreen: isMediumScreen,
                                      onTap: () {
                                        final parsedDate =
                                            DateTime.tryParse(
                                              check['date']?.toString() ?? '',
                                            ) ??
                                            DateTime.now();

                                        final isNew = _isNewDailyCheck(check);

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DailyCheckScreen(
                                              args: {
                                                'maintenanceId':
                                                    widget.maintenanceId,
                                                'date': parsedDate,
                                                'dailyCheck': check,
                                                'mode': isNew
                                                    ? 'edit'
                                                    : 'view', // 👈 هنا القرار
                                                'plateNumber':
                                                    record['plateNumber'],
                                                'driverName':
                                                    record['driverName'],
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // =========================
                                    // 🛢️ Oil Change Approval (Manager Only)
                                    // =========================
                                    if (isSupervisor &&
                                        check['oilChanged'] == true &&
                                        check['status'] == 'under_review')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.oil_barrel,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 8),
                                              const Expanded(
                                                child: Text(
                                                  'الفني أكد تغيير الزيت – بانتظار اعتمادك',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final provider =
                                                      Provider.of<
                                                        MaintenanceProvider
                                                      >(context, listen: false);

                                                  await provider
                                                      .approveOilChange(
                                                        maintenanceId: widget
                                                            .maintenanceId,
                                                        dailyCheckId:
                                                            check['_id'],
                                                      );

                                                  if (!mounted) return;

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'تم اعتماد تغيير الزيت بنجاح',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                ),
                                                child: const Text('اعتماد'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    if (isSupervisor &&
                                        check['status'] == 'under_review')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  _showReviewDialog(
                                                    checkId: check['_id'],
                                                    approve: false,
                                                  );
                                                },
                                                icon: const Icon(Icons.close),
                                                label: const Text('رفض'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: isLargeScreen
                                                        ? 16
                                                        : 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  _showReviewDialog(
                                                    checkId: check['_id'],
                                                    approve: true,
                                                  );
                                                },
                                                icon: const Icon(Icons.check),
                                                label: const Text('اعتماد'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: isLargeScreen
                                                        ? 16
                                                        : 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab(
    dynamic record,
    bool isSupervisor,
    bool isLargeScreen,
    bool isMediumScreen,
  ) {
    final supervisorActions = record['supervisorActions'] ?? [];
    final notifications = record['notifications'] ?? [];

    if (!isSupervisor) {
      return _buildActionsList(
        notifications,
        Icons.notifications,
        'لا توجد إشعارات',
        _buildNotificationItem,
        isLargeScreen,
        isMediumScreen,
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // =========================
          // 📑 Tabs for Actions
          // =========================
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: TabBar(
              labelStyle: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isLargeScreen ? 14 : 13,
              ),
              tabs: const [
                Tab(text: 'إجراءات المشرف'),
                Tab(text: 'الإشعارات'),
              ],
            ),
          ),

          // =========================
          // 📝 Content Area
          // =========================
          Expanded(
            child: TabBarView(
              children: [
                // Supervisor Actions
                _buildActionsList(
                  supervisorActions,
                  Icons.admin_panel_settings,
                  'لا توجد إجراءات للمشرف',
                  _buildActionItem,
                  isLargeScreen,
                  isMediumScreen,
                ),

                // Notifications
                _buildActionsList(
                  notifications,
                  Icons.notifications,
                  'لا توجد إشعارات',
                  _buildNotificationItem,
                  isLargeScreen,
                  isMediumScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsList(
    List<dynamic> items,
    IconData emptyIcon,
    String emptyText,
    Widget Function(dynamic item, BuildContext context) builder,
    bool isLargeScreen,
    bool isMediumScreen,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: isLargeScreen ? 100 : 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: TextStyle(
                fontSize: isLargeScreen
                    ? 20
                    : isMediumScreen
                    ? 18
                    : 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(
        isLargeScreen
            ? 24
            : isMediumScreen
            ? 20
            : 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: builder(items[index], context),
        );
      },
    );
  }

  Widget _buildActionItem(dynamic action, BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getActionColor(action['actionType']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getActionIcon(action['actionType']),
            color: _getActionColor(action['actionType']),
            size: 24,
          ),
        ),
        title: Text(
          _getActionTitle(action['actionType']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              action['message'] ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(DateTime.parse(action['date'])),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(dynamic notification, BuildContext context) {
    final isRead = notification['read'] == true;

    return Card(
      elevation: isRead ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isRead ? Colors.grey.shade50 : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isRead ? Colors.grey.shade300 : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isRead ? Icons.notifications_none : Icons.notifications,
            color: isRead ? Colors.grey : Colors.blue,
            size: 24,
          ),
        ),
        title: Text(
          notification['title'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isRead ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'] ?? '',
              style: TextStyle(
                color: isRead ? Colors.grey.shade500 : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(DateTime.parse(notification['sentAt'])),
              style: TextStyle(
                fontSize: 12,
                color: isRead ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompactHeight = constraints.maxHeight <= 90;
        final double titleSize = isCompactHeight ? 12 : 14;
        final double valueSize = isCompactHeight ? 13 : 16;
        final double spacing = isCompactHeight ? 4 : 8;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaudiVehicleLicenseCard({
    required Map<String, dynamic> record,
    required DateTime? issueDate,
    required DateTime? expiryDate,
    required bool isLargeScreen,
    required bool isMediumScreen,
  }) {
    final titleSize = isLargeScreen
        ? 18.0
        : isMediumScreen
        ? 16.0
        : 14.0;
    final labelSize = isLargeScreen
        ? 14.0
        : isMediumScreen
        ? 12.0
        : 11.0;
    final valueSize = isLargeScreen
        ? 16.0
        : isMediumScreen
        ? 14.0
        : 12.0;

    Widget buildField(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: labelSize,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '-',
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    final serialNumber = (record['vehicleRegistrationSerialNumber'] ?? '-')
        .toString();
    final vehicleNumber = (record['vehicleRegistrationNumber'] ?? '-')
        .toString();
    final plateNumber = (record['plateNumber'] ?? '-').toString();
    final issueText = issueDate != null
        ? DateFormat('yyyy/MM/dd').format(issueDate)
        : '-';
    final expiryText = expiryDate != null
        ? DateFormat('yyyy/MM/dd').format(expiryDate)
        : '-';

    return Container(
      padding: EdgeInsets.all(
        isLargeScreen
            ? 20
            : isMediumScreen
            ? 16
            : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0E8B3A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isLargeScreen
                  ? 10
                  : isMediumScreen
                  ? 8
                  : 6,
              horizontal: isLargeScreen
                  ? 14
                  : isMediumScreen
                  ? 12
                  : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0E8B3A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'رخصة سير مركبة',
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: isLargeScreen ? 16 : 12),
          Row(
            children: [
              Expanded(child: buildField('الرقم التسلسلي', serialNumber)),
              const SizedBox(width: 16),
              Expanded(child: buildField('رقم السيارة', vehicleNumber)),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 10),
          Row(
            children: [
              Expanded(child: buildField('رقم اللوحة', plateNumber)),
              const SizedBox(width: 16),
              Expanded(child: buildField('تاريخ الإصدار', issueText)),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 10),
          buildField('تاريخ الانتهاء', expiryText),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'مكتمل':
        return Colors.green;
      case 'غير مكتمل':
        return Colors.red;
      case 'تحت المراجعة':
        return Colors.orange;
      case 'مرفوض':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType) {
      case 'warning':
        return Icons.warning;
      case 'note':
        return Icons.note;
      case 'approval':
        return Icons.check_circle;
      case 'rejection':
        return Icons.cancel;
      case 'maintenance_scheduled':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'warning':
        return Colors.orange;
      case 'note':
        return Colors.blue;
      case 'approval':
        return Colors.green;
      case 'rejection':
        return Colors.red;
      case 'maintenance_scheduled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getActionTitle(String actionType) {
    switch (actionType) {
      case 'warning':
        return 'تحذير';
      case 'note':
        return 'ملاحظة';
      case 'approval':
        return 'موافقة';
      case 'rejection':
        return 'رفض';
      case 'maintenance_scheduled':
        return 'جدولة صيانة';
      default:
        return 'إجراء';
    }
  }
}
