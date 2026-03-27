import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/screens/qualification/qualification_form_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class QualificationStationDetailsScreen extends StatefulWidget {
  final QualificationStation? initialStation;

  const QualificationStationDetailsScreen({super.key, this.initialStation});

  @override
  State<QualificationStationDetailsScreen> createState() =>
      _QualificationStationDetailsScreenState();
}

class _QualificationStationDetailsScreenState
    extends State<QualificationStationDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stationId = widget.initialStation?.id;
      if (stationId != null && stationId.isNotEmpty) {
        context.read<QualificationProvider>().fetchStationById(stationId);
      }
    });
  }

  QualificationStation? _resolveStation(QualificationProvider provider) {
    final selected = provider.selectedStation;
    final stationId = widget.initialStation?.id;
    if (selected != null && stationId != null && selected.id == stationId) {
      return selected;
    }
    return widget.initialStation;
  }

  String _statusLabel(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return 'تحت الدراسة';
      case QualificationStatus.negotiating:
        return 'جاري التفاوض';
      case QualificationStatus.agreed:
        return 'تم الاتفاق';
      case QualificationStatus.notAgreed:
        return 'لم يتم الاتفاق';
    }
  }

  Color _statusColor(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return Colors.amber.shade700;
      case QualificationStatus.negotiating:
        return Colors.blue.shade700;
      case QualificationStatus.agreed:
        return Colors.green;
      case QualificationStatus.notAgreed:
        return Colors.red;
    }
  }

  String _formatDate(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  IconData _attachmentIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.audiotrack_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _openAttachment(QualificationAttachment attachment) async {
    final uri = Uri.parse(attachment.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح المرفق')));
    }
  }

  Widget _statusBadge(QualificationStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.mediumGray),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(color: AppColors.mediumGray),
          ),
        ),
      ],
    );
  }

  Widget _surfaceSection({
    required String title,
    required Widget child,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return AppSurfaceCard(
      padding: padding,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                    fontSize: 20,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerSection(QualificationStation station) {
    final status = station.status;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.silverLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                foregroundColor: AppColors.primaryBlue,
                child: const Icon(Icons.local_gas_station),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${station.city} • ${station.region}',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                    if (station.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        station.address,
                        style: TextStyle(color: AppColors.lightGray),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusBadge(status),
              _infoChip(
                icon: Icons.calendar_today,
                label: 'تاريخ الإنشاء: ${_formatDate(station.createdAt)}',
              ),
              if ((station.createdByName ?? '').isNotEmpty)
                _infoChip(
                  icon: Icons.person_outline,
                  label: 'تم بواسطة: ${station.createdByName}',
                ),
            ],
          ),
          if (status == QualificationStatus.negotiating &&
              (station.assignedTo?.name ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(
              label: 'المسؤول',
              value: station.assignedTo!.name!,
              icon: Icons.person,
            ),
          ],
          const SizedBox(height: 12),
          _infoRow(
            label: 'الموقع',
            value:
                '${station.location.lat.toStringAsFixed(5)}, ${station.location.lng.toStringAsFixed(5)}',
            icon: Icons.place_outlined,
          ),
          if ((station.ownerName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(
              label: 'اسم المالك',
              value: station.ownerName!.trim(),
              icon: Icons.person_outline,
            ),
          ],
          if ((station.ownerPhone ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(
              label: 'رقم الجوال',
              value: station.ownerPhone!.trim(),
              icon: Icons.phone_android,
            ),
          ],
          if ((station.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(
              label: 'ملاحظات',
              value: station.notes!.trim(),
              icon: Icons.sticky_note_2_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection(QualificationStation station) {
    final history = List<QualificationStatusChange>.from(station.statusHistory)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل الإجراءات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'لا توجد إجراءات مسجلة بعد',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          )
        else
          ...history.map(_historyCard),
      ],
    );
  }

  Widget _stationAttachmentsSection(QualificationStation station) {
    if (station.attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مرفقات المحطة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: station.attachments.map((attachment) {
            return ActionChip(
              avatar: Icon(_attachmentIcon(attachment.type), size: 18),
              label: Text(attachment.name),
              onPressed: () => _openAttachment(attachment),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _updateStatus(
    QualificationStation station,
    QualificationStatus status, {
    required String reason,
    QualificationAssignee? assignedTo,
    List<QualificationAttachment> attachments = const [],
  }) async {
    if (station.status == status) return;
    await context.read<QualificationProvider>().updateStatus(
      station.id,
      status,
      reason: reason,
      assignedTo: assignedTo,
      attachments: attachments,
    );
  }

  Future<void> _showStatusUpdateSheet(
    QualificationStation station,
    QualificationStatus status,
  ) async {
    final reasonController = TextEditingController();
    final assignedController = TextEditingController(
      text: station.assignedTo?.name ?? '',
    );
    final attachments = <PlatformFile>[];
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تغيير الحالة إلى: ${_statusLabel(status)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'سبب الإجراء',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (status == QualificationStatus.negotiating) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: assignedController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم المسؤول',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        withData: kIsWeb,
                      );
                      if (result == null) return;
                      setModalState(() {
                        attachments.addAll(result.files);
                      });
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      attachments.isEmpty
                          ? 'إرفاق ملفات (اختياري)'
                          : 'تم اختيار ${attachments.length} ملف',
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: attachments
                          .map((file) => Chip(label: Text(file.name)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final reason = reasonController.text.trim();
                                  if (reason.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('يرجى إدخال السبب'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (status ==
                                          QualificationStatus.negotiating &&
                                      assignedController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'يرجى تحديد المستخدم المسؤول',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => saving = true);
                                  final provider = context
                                      .read<QualificationProvider>();
                                  final uploaded = await provider
                                      .uploadAttachments(attachments);
                                  final assignedTo =
                                      assignedController.text.trim().isEmpty
                                      ? null
                                      : QualificationAssignee(
                                          name: assignedController.text.trim(),
                                        );

                                  await _updateStatus(
                                    station,
                                    status,
                                    reason: reason,
                                    assignedTo: assignedTo,
                                    attachments: uploaded,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('تأكيد'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openStatusSelector(QualificationStation station) async {
    final nextStatus = await showModalBottomSheet<QualificationStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: QualificationStatus.values.map((status) {
              return ListTile(
                leading: Icon(
                  Icons.circle,
                  color: _statusColor(status),
                  size: 14,
                ),
                title: Text(_statusLabel(status)),
                onTap: () => Navigator.pop(context, status),
              );
            }).toList(),
          ),
        );
      },
    );

    if (nextStatus == null) return;
    if (!mounted) return;
    await _showStatusUpdateSheet(station, nextStatus);
  }

  Future<void> _addAttachments(QualificationStation station) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    final provider = context.read<QualificationProvider>();
    final uploaded = await provider.uploadAttachments(result.files);
    if (uploaded.isEmpty) return;

    final updatedStation = QualificationStation(
      id: station.id,
      name: station.name,
      ownerName: station.ownerName,
      ownerPhone: station.ownerPhone,
      city: station.city,
      region: station.region,
      address: station.address,
      status: station.status,
      location: station.location,
      createdAt: station.createdAt,
      createdByName: station.createdByName,
      notes: station.notes,
      assignedTo: station.assignedTo,
      attachments: [...station.attachments, ...uploaded],
      statusHistory: station.statusHistory,
    );

    await provider.updateStation(updatedStation);
  }

  Future<void> _openEditStation(QualificationStation station) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QualificationStationFormScreen(inspectionToEdit: station),
      ),
    );
    if (mounted) {
      await context.read<QualificationProvider>().fetchStationById(station.id);
    }
  }

  Future<void> _openGoogleMaps(QualificationStation station) async {
    final lat = station.location.lat;
    final lng = station.location.lng;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح خرائط جوجل')));
    }
  }

  void _openOnMap(QualificationStation station) {
    Navigator.pushNamed(
      context,
      AppRoutes.qualificationMap,
      arguments: station,
    );
  }

  Widget _actionsSection(QualificationStation station) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإجراءات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openStatusSelector(station),
              icon: const Icon(Icons.sync_alt),
              label: const Text('تغيير الحالة'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openEditStation(station),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل البيانات'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addAttachments(station),
              icon: const Icon(Icons.attach_file),
              label: const Text('إضافة مرفقات'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openOnMap(station),
              icon: const Icon(Icons.map_outlined),
              label: const Text('عرض على الخريطة'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openGoogleMaps(station),
              icon: const Icon(Icons.directions),
              label: const Text('الذهاب للمحطة'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _historyCard(QualificationStatusChange change) {
    final color = _statusColor(change.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(change.status),
              const Spacer(),
              Text(
                _formatDate(change.createdAt),
                style: TextStyle(color: AppColors.lightGray, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'سبب الإجراء: ${change.reason}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if ((change.assignedTo?.name ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(
              label: 'المسؤول',
              value: change.assignedTo!.name!,
              icon: Icons.person_outline,
            ),
          ],
          if ((change.changedByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(
              label: 'تم بواسطة',
              value: change.changedByName!,
              icon: Icons.verified_user_outlined,
            ),
          ],
          if (change.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'المرفقات',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: change.attachments.map((attachment) {
                return ActionChip(
                  avatar: Icon(_attachmentIcon(attachment.type), size: 18),
                  label: Text(attachment.name),
                  onPressed: () => _openAttachment(attachment),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modernHeaderSection(QualificationStation station) {
    final statusColor = _statusColor(station.status);
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              gradient: AppColors.appBarGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${station.city} • ${station.region}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (station.address.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          station.address,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined, size: 16, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            _statusLabel(station.status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _metaChip(
                      icon: Icons.calendar_today_outlined,
                      label: 'تاريخ الإنشاء: ${_formatDate(station.createdAt)}',
                      color: AppColors.primaryBlue,
                    ),
                    if ((station.createdByName ?? '').isNotEmpty)
                      _metaChip(
                        icon: Icons.person_outline_rounded,
                        label: 'تم بواسطة: ${station.createdByName}',
                        color: AppColors.primaryBlue,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      icon: Icons.place_outlined,
                      label:
                          '${station.location.lat.toStringAsFixed(5)}, ${station.location.lng.toStringAsFixed(5)}',
                    ),
                    if ((station.ownerPhone ?? '').trim().isNotEmpty)
                      _infoChip(
                        icon: Icons.phone_android,
                        label: station.ownerPhone!.trim(),
                      ),
                    if ((station.ownerName ?? '').trim().isNotEmpty)
                      _infoChip(
                        icon: Icons.person_outline,
                        label: station.ownerName!.trim(),
                      ),
                    if ((station.assignedTo?.name ?? '').trim().isNotEmpty)
                      _infoChip(
                        icon: Icons.badge_outlined,
                        label: 'المسؤول: ${station.assignedTo!.name!}',
                      ),
                  ],
                ),
                if ((station.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.warningOrange.withValues(alpha: 0.18),
                      ),
                    ),
                    child: _infoRow(
                      label: 'ملاحظات',
                      value: station.notes!.trim(),
                      icon: Icons.sticky_note_2_outlined,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernActionsSection(QualificationStation station) {
    return _surfaceSection(
      title: 'الإجراءات',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () => _openStatusSelector(station),
            icon: const Icon(Icons.sync_alt_rounded),
            label: const Text('تغيير الحالة'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openEditStation(station),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل البيانات'),
          ),
          OutlinedButton.icon(
            onPressed: () => _addAttachments(station),
            icon: const Icon(Icons.attach_file),
            label: const Text('إضافة مرفقات'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openOnMap(station),
            icon: const Icon(Icons.map_outlined),
            label: const Text('عرض على الخريطة'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openGoogleMaps(station),
            icon: const Icon(Icons.directions),
            label: const Text('الذهاب للمحطة'),
          ),
        ],
      ),
    );
  }

  Widget _modernAttachmentsSection(QualificationStation station) {
    if (station.attachments.isEmpty) {
      return const SizedBox.shrink();
    }
    return _surfaceSection(
      title: 'مرفقات المحطة',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: station.attachments.map((attachment) {
          return ActionChip(
            avatar: Icon(_attachmentIcon(attachment.type), size: 18),
            label: Text(attachment.name),
            onPressed: () => _openAttachment(attachment),
          );
        }).toList(),
      ),
    );
  }

  Widget _modernHistoryCard(QualificationStatusChange change) {
    final color = _statusColor(change.status);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      color: Colors.white.withValues(alpha: 0.92),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(change.status),
              const Spacer(),
              Text(
                _formatDate(change.createdAt),
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'سبب الإجراء: ${change.reason}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGray,
            ),
          ),
          if ((change.assignedTo?.name ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(
              label: 'المسؤول',
              value: change.assignedTo!.name!,
              icon: Icons.person_outline,
            ),
          ],
          if ((change.changedByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(
              label: 'تم بواسطة',
              value: change.changedByName!,
              icon: Icons.verified_user_outlined,
            ),
          ],
          if (change.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: change.attachments.map((attachment) {
                return ActionChip(
                  avatar: Icon(_attachmentIcon(attachment.type), size: 18),
                  label: Text(attachment.name),
                  onPressed: () => _openAttachment(attachment),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modernHistorySection(QualificationStation station) {
    final history = List<QualificationStatusChange>.from(station.statusHistory)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _surfaceSection(
      title: 'سجل الإجراءات',
      child: history.isEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'لا توجد إجراءات مسجلة بعد',
                style: TextStyle(color: AppColors.mediumGray),
              ),
            )
          : Column(
              children: history
                  .map(
                    (change) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _modernHistoryCard(change),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QualificationProvider>(
      builder: (context, provider, _) {
        final station = _resolveStation(provider);

        return Scaffold(
          backgroundColor: const Color.fromARGB(26, 245, 242, 242),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.appBarGradient,
              ),
            ),
            title: const Text('تفاصيل التأهيل'),
            centerTitle: true,
          ),
          body: station == null
              ? const Stack(
                  children: [
                    AppSoftBackground(),
                    Center(child: CircularProgressIndicator()),
                  ],
                )

//qualification_map_screen.dart احتاج هنا اقدر اعمل زوم ان وزووم اوت واقدر احرك يمين ويسار وفوق وتحت داخل الخريطة 
              : Stack(
                  children: [
                    const AppSoftBackground(),
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _modernHeaderSection(station),
                            const SizedBox(height: 16),
                            _modernActionsSection(station),
                            if (station.attachments.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _modernAttachmentsSection(station),
                            ],
                            const SizedBox(height: 16),
                            _modernHistorySection(station),
                            if (provider.error != null &&
                                provider.error!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              AppSurfaceCard(
                                color: AppColors.errorRed.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: AppColors.errorRed.withValues(alpha: 0.18),
                                ),
                                child: Text(
                                  provider.error!,
                                  style: const TextStyle(
                                    color: AppColors.errorRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    if (provider.isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white70,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
