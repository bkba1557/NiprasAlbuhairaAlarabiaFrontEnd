import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class DeviceEnrollmentRequestsScreen extends StatefulWidget {
  const DeviceEnrollmentRequestsScreen({super.key});

  @override
  State<DeviceEnrollmentRequestsScreen> createState() =>
      _DeviceEnrollmentRequestsScreenState();
}

class _DeviceEnrollmentRequestsScreenState
    extends State<DeviceEnrollmentRequestsScreen> {
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    final provider = context.read<HRProvider>();
    await provider.fetchDeviceEnrollmentRequests(status: _statusFilter);
  }

  Future<void> _approve(DeviceEnrollmentRequest request) async {
    final provider = context.read<HRProvider>();
    try {
      await provider.approveDeviceEnrollmentRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اعتماد الطلب'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل اعتماد الطلب: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _reject(DeviceEnrollmentRequest request) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('رفض الطلب'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final provider = context.read<HRProvider>();
    try {
      await provider.rejectDeviceEnrollmentRequest(request.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الطلب'),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفض الطلب: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _updateStatus(
    DeviceEnrollmentRequest request,
    String status, {
    String? reason,
  }) async {
    final provider = context.read<HRProvider>();
    try {
      await provider.updateDeviceEnrollmentStatus(
        request.id,
        status,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الحالة'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث الحالة: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _showStatusActions(DeviceEnrollmentRequest request) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!request.isApproved)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('تحويل إلى معتمد'),
                  onTap: () => Navigator.pop(context, 'approved'),
                ),
              if (!request.isPending)
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: const Text('تحويل إلى قيد المراجعة'),
                  onTap: () => Navigator.pop(context, 'pending'),
                ),
              if (!request.isRejected)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('تحويل إلى مرفوض'),
                  onTap: () => Navigator.pop(context, 'rejected'),
                ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('إلغاء الربط'),
                onTap: () => Navigator.pop(context, 'cancelled'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    if (result == 'approved') {
      await _updateStatus(request, 'approved');
      return;
    }

    if (result == 'pending') {
      await _updateStatus(request, 'pending');
      return;
    }

    if (result == 'rejected') {
      final controller = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('سبب الرفض'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'السبب'),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, controller.text.trim()),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      );
      if (reason == null) return;
      await _updateStatus(request, 'rejected', reason: reason);
      return;
    }

    if (result == 'cancelled') {
      await _updateStatus(request, 'rejected',
          reason: 'تم الإلغاء من الإدارة');
    }
  }

  Future<void> _deleteDevice(DeviceEnrollmentRequest request) async {
    final targetId = (request.employeeRefId != null &&
            request.employeeRefId!.isNotEmpty)
        ? request.employeeRefId!
        : request.employeeId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف ربط الجهاز'),
          content: Text(
            'هل تريد إزالة ربط الجهاز (${request.deviceId}) من الموظف (${request.employeeId})؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
              ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final provider = context.read<HRProvider>();
    try {
      await provider.clearEmployeeDevice(targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف ربط الجهاز'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف ربط الجهاز: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HRProvider>();
    final requests = provider.deviceEnrollmentRequests;
    final isLoading = provider.isLoadingDeviceRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات ربط الأجهزة'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _statusFilter = value);
              _loadRequests();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('قيد المراجعة')),
              PopupMenuItem(value: 'approved', child: Text('معتمد')),
              PopupMenuItem(value: 'rejected', child: Text('مرفوض')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('لا توجد طلبات'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildRequestCard(request);
                  },
                ),
    );
  }

  Widget _buildRequestCard(DeviceEnrollmentRequest request) {
    final created =
        DateFormat('yyyy/MM/dd HH:mm').format(request.createdAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  request.employeeName ?? 'موظف بدون اسم',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('رقم الموظف: ${request.employeeId}'),
                const SizedBox(height: 4),
                Text('معرف الجهاز: ${request.deviceId}'),
                if (request.deviceLabel != null &&
                    request.deviceLabel!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('الجهاز: ${request.deviceLabel}'),
                ],
                const SizedBox(height: 4),
                Text('التاريخ: $created'),
                const SizedBox(height: 8),
                _buildStatusRow(request),
                if (request.isRejected &&
                    request.rejectedByName != null &&
                    request.rejectedByName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'تم الحذف بواسطة: ${request.rejectedByName!}',
                    style: const TextStyle(color: AppColors.mediumGray),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (request.isApproved) ...[
                  const SizedBox(height: 4),
                  if (request.approvedByName != null &&
                      request.approvedByName!.isNotEmpty)
                    Text(
                      'تم الاعتماد بواسطة: ${request.approvedByName!}',
                      style: const TextStyle(color: AppColors.mediumGray),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ],
            );

            final actions = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showStatusActions(request),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('تغيير الحالة'),
                  ),
                ),
                if (request.isPending) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _approve(request),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('اعتماد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _reject(request),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('رفض'),
                      ),
                    ],
                  ),
                ],
                if (request.isApproved) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => _deleteDevice(request),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف ربط الجهاز'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                    ),
                  ),
                ],
              ],
            );

            if (!isWide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  details,
                  const SizedBox(height: 8),
                  actions,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 24),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusRow(DeviceEnrollmentRequest request) {
    Color color;
    String label;
    switch (request.status) {
      case 'approved':
        color = AppColors.successGreen;
        label = 'معتمد';
        break;
      case 'rejected':
        color = AppColors.errorRed;
        label = (request.rejectionReason != null &&
                request.rejectionReason!.contains('إلغاء'))
            ? 'ملغي'
            : 'مرفوض';
        break;
      default:
        color = AppColors.warningOrange;
        label = 'قيد المراجعة';
    }

    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        if (request.isRejected && request.rejectionReason != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.rejectionReason!,
              style: const TextStyle(color: AppColors.mediumGray),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
