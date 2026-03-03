import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/models/station_maintenance_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/notification_provider.dart';
import 'package:order_tracker/providers/station_maintenance_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';

class StationMaintenanceTechnicianScreen extends StatefulWidget {
  const StationMaintenanceTechnicianScreen({super.key});

  @override
  State<StationMaintenanceTechnicianScreen> createState() =>
      _StationMaintenanceTechnicianScreenState();
}

class _StationMaintenanceTechnicianScreenState
    extends State<StationMaintenanceTechnicianScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final provider = context.read<StationMaintenanceProvider>();
    final authProvider = context.read<AuthProvider>();
    final technicianId = authProvider.user?.id;
    await provider.fetchRequests(technicianId: technicianId);
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final provider = context.watch<StationMaintenanceProvider>();
    final requests = provider.requests;

    final activeRequests = requests
        .where(
          (request) =>
              request.status == 'assigned' || request.status == 'in_progress',
        )
        .toList();

    final historyRequests = requests
        .where(
          (request) =>
              request.status == 'under_review' ||
              request.status == 'approved' ||
              request.status == 'rejected' ||
              request.status == 'closed',
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الفني'),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (notificationProvider.unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notificationProvider.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'المهام',
            icon: const Icon(Icons.task_alt),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.tasks);
            },
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              await authProvider.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('الطلبات الجديدة'),
            const SizedBox(height: 12),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (activeRequests.isEmpty)
              _buildEmptyState('لا توجد طلبات مسندة حاليا')
            else
              ...activeRequests.map(_buildRequestCard),
            const SizedBox(height: 24),
            _buildSectionTitle('سجل الطلبات'),
            const SizedBox(height: 12),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (historyRequests.isEmpty)
              _buildEmptyState('لا يوجد سجل طلبات بعد')
            else
              ...historyRequests.map(_buildRequestCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.mediumGray),
      ),
    );
  }

  Widget _buildRequestCard(StationMaintenanceRequest request) {
    final isAssigned = request.status == 'assigned';
    final title = request.title.isNotEmpty
        ? request.title
        : _typeLabel(request.type);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('المحطة: ${request.stationName.isNotEmpty ? request.stationName : 'غير محدد'}'),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _openDetails(request),
                  child: const Text('التفاصيل'),
                ),
                const SizedBox(width: 8),
                if (isAssigned)
                  ElevatedButton(
                    onPressed: () => _acceptRequest(request),
                    child: const Text('قبول الطلب'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(StationMaintenanceRequest request) async {
    final provider = context.read<StationMaintenanceProvider>();
    final started = await provider.startRequest(request.id);
    if (!mounted) return;

    if (started == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'تعذر قبول الطلب'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    _openDetails(started);
  }

  void _openDetails(StationMaintenanceRequest request) {
    Navigator.pushNamed(
      context,
      AppRoutes.stationMaintenanceDetails,
      arguments: request.id,
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
