import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/models/station_maintenance_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_maintenance_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';

class StationMaintenanceDashboardScreen extends StatefulWidget {
  const StationMaintenanceDashboardScreen({super.key});

  @override
  State<StationMaintenanceDashboardScreen> createState() =>
      _StationMaintenanceDashboardScreenState();
}

class _StationMaintenanceDashboardScreenState
    extends State<StationMaintenanceDashboardScreen> {
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  bool _autoOpened = false;

  static const List<Map<String, String>> _statusOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'assigned', 'label': 'مسند'},
    {'key': 'in_progress', 'label': 'قيد التنفيذ'},
    {'key': 'under_review', 'label': 'تحت المراجعة'},
    {'key': 'approved', 'label': 'مقبول'},
    {'key': 'rejected', 'label': 'مرفوض'},
    {'key': 'closed', 'label': 'مغلق'},
  ];

  static const List<Map<String, String>> _typeOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'maintenance', 'label': 'صيانة محطة'},
    {'key': 'development', 'label': 'تطوير محطة'},
    {'key': 'other', 'label': 'أخرى'},
  ];

  bool _isTechnicianRole(String? role) {
    return role == 'maintenance_technician' ||
        role == 'Maintenance_Technician' ||
        role == 'maintenance_station' ||
        role == 'maintenance';
  }

  bool _isManagerRole(String? role) {
    return role == 'admin' ||
        role == 'owner' ||
        role == 'manager' ||
        role == 'supervisor' ||
        role == 'maintenance' ||
        role == 'maintenance_car_management';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _autoOpenTechnicianRequest();
    });
  }

  Future<void> _autoOpenTechnicianRequest() async {
    if (_autoOpened) return;
    final authProvider = context.read<AuthProvider>();
    if (!_isTechnicianRole(authProvider.user?.role)) return;

    final provider = context.read<StationMaintenanceProvider>();
    final active = await provider.fetchMyActiveRequest();
    if (active != null && active.status != 'under_review' && mounted) {
      _autoOpened = true;
      Navigator.pushNamed(
        context,
        AppRoutes.stationMaintenanceDetails,
        arguments: active.id,
      );
    }
  }

  Future<void> _loadData() async {
    final provider = context.read<StationMaintenanceProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    final technicianId = _isTechnicianRole(user?.role) ? user?.id : null;

    await provider.fetchRequests(
      status: _statusFilter == 'all' ? null : _statusFilter,
      type: _typeFilter == 'all' ? null : _typeFilter,
      technicianId: technicianId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StationMaintenanceProvider>();
    final authProvider = context.watch<AuthProvider>();
    final role = authProvider.user?.role;
    final isTechnician = _isTechnicianRole(role);
    final isManager = _isManagerRole(role);
    final requests = provider.requests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تطوير وصيانة المحطات'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;
          final maxWidth =
              constraints.maxWidth < 1100 ? constraints.maxWidth : 1100.0;
          final horizontalPadding = isCompact ? 16.0 : 24.0;

          final content = <Widget>[
            if (isManager) ...[
              _buildManagerActions(
                context,
                isCompact: isCompact,
                maxContentWidth: maxWidth,
              ),
              const SizedBox(height: 16),
            ],
            _buildFilters(),
            const SizedBox(height: 16),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (requests.isEmpty)
              _buildEmptyState(isTechnician)
            else
              ...requests.map((request) => _buildRequestCard(request)),
          ];

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: content,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.stationMaintenanceForm,
                  arguments: const {'type': 'maintenance'},
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('طلب جديد'),
            )
          : null,
    );
  }

  Widget _buildManagerActions(
    BuildContext context, {
    required bool isCompact,
    required double maxContentWidth,
  }) {
    /*
    final maintenanceCard = _buildActionCard(
      title: 'Ø¥Ù†Ø´Ø§Ø¡ ØµÙŠØ§Ù†Ø© Ù…Ø­Ø·Ø©',
      subtitle: 'ØªØ¹ÙŠÙŠÙ† ÙÙ†ÙŠ ÙˆÙØªØ­ Ø·Ù„Ø¨ ØµÙŠØ§Ù†Ø© Ø¬Ø¯ÙŠØ¯',
      icon: Icons.build_outlined,
      color: AppColors.primaryBlue,
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.stationMaintenanceForm,
          arguments: const {'type': 'maintenance'},
        );
      },
    );

    final developmentCard = _buildActionCard(
      title: 'Ø¥Ù†Ø´Ø§Ø¡ ØªØ·ÙˆÙŠØ± Ù…Ø­Ø·Ø©',
      subtitle: 'ØªØ¹ÙŠÙŠÙ† ÙÙ†ÙŠ Ù„Ø·Ù„Ø¨Ø§Øª Ø§Ù„ØªØ·ÙˆÙŠØ±',
      icon: Icons.home_repair_service_outlined,
      color: AppColors.successGreen,
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.stationMaintenanceForm,
          arguments: const {'type': 'development'},
        );
      },
    );

    */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإنشاء السريع',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isCompact ? maxContentWidth : (maxContentWidth - 12) / 2,
              child: _buildActionCard(
                title: 'إنشاء صيانة محطة',
                subtitle: 'تعيين فني وفتح طلب صيانة جديد',
                icon: Icons.build_outlined,
                color: AppColors.primaryBlue,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.stationMaintenanceForm,
                    arguments: const {'type': 'maintenance'},
                  );
                },
              ),
            ),
            SizedBox(
              width: isCompact ? maxContentWidth : (maxContentWidth - 12) / 2,
              child: _buildActionCard(
                title: 'إنشاء تطوير محطة',
                subtitle: 'تعيين فني لطلبات التطوير',
                icon: Icons.home_repair_service_outlined,
                color: AppColors.successGreen,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.stationMaintenanceForm,
                    arguments: const {'type': 'development'},
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التصفية',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _statusOptions.map((option) {
            final isSelected = _statusFilter == option['key'];
            return ChoiceChip(
              label: Text(option['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _statusFilter = option['key']!);
                _loadData();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _typeOptions.map((option) {
            final isSelected = _typeFilter == option['key'];
            return ChoiceChip(
              label: Text(option['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _typeFilter = option['key']!);
                _loadData();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isTechnician) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: AppColors.primaryBlue.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            isTechnician
                ? 'لا توجد طلبات مسندة حالياً'
                : 'لا توجد طلبات مسجلة حالياً',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            isTechnician
                ? 'سيتم فتح الطلب تلقائياً عند تعيينه لك'
                : 'يمكنك إنشاء طلب جديد من الأعلى',
            style: TextStyle(color: AppColors.mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(StationMaintenanceRequest request) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          request.title.isNotEmpty ? request.title : _typeLabel(request.type),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('المحطة: ${request.stationName.isNotEmpty ? request.stationName : 'غير محدد'}'),
            Text('الفني: ${request.assignedToName ?? 'غير محدد'}'),
            const SizedBox(height: 6),
            _buildStatusChip(request.status),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.stationMaintenanceDetails,
            arguments: request.id,
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'مسند';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'under_review':
        return 'تحت المراجعة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'closed':
        return 'مغلق';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blueGrey;
      case 'in_progress':
        return Colors.orange;
      case 'under_review':
        return Colors.amber;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'closed':
        return Colors.grey;
      default:
        return AppColors.mediumGray;
    }
  }

  String _typeLabel(String type) {
    if (type == 'development') {
      return 'تطوير محطة';
    }
    if (type == 'other') {
      return 'أخرى';
    }
    return 'صيانة محطة';
  }
}
