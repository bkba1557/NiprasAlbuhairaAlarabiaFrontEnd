import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:order_tracker/providers/station_inspection_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';

import 'inspection_form_screen.dart';
import 'inspection_models.dart';
import 'inspection_pdf.dart';

class StationInspectionDetailsScreen extends StatefulWidget {
  final String inspectionId;
  final StationInspection? initialInspection;

  const StationInspectionDetailsScreen({
    super.key,
    required this.inspectionId,
    this.initialInspection,
  });

  @override
  State<StationInspectionDetailsScreen> createState() =>
      _StationInspectionDetailsScreenState();
}

class _StationInspectionDetailsScreenState
    extends State<StationInspectionDetailsScreen> {
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<StationInspectionProvider>()
          .fetchInspectionById(widget.inspectionId);
    });
  }

  StationInspection? _getInspection(StationInspectionProvider provider) {
    final selected = provider.selectedInspection;
    if (selected != null && selected.id == widget.inspectionId) {
      return selected;
    }
    if (widget.initialInspection != null &&
        widget.initialInspection!.id == widget.inspectionId) {
      return widget.initialInspection;
    }
    return null;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editInspection(StationInspection inspection) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StationInspectionFormScreen(
          inspectionToEdit: inspection,
        ),
      ),
    );

    if (result == true && mounted) {
      await context
          .read<StationInspectionProvider>()
          .fetchInspectionById(inspection.id);
    }
  }

  Future<void> _updateStatus(
    StationInspection inspection,
    InspectionStatus status,
  ) async {
    await context
        .read<StationInspectionProvider>()
        .updateStatus(inspection.id, status);
  }

  Future<void> _addClosingReadings(StationInspection inspection) async {
    final updated = await showDialog<List<InspectionPump>>(
      context: context,
      builder: (_) => _ClosingReadingsDialog(pumps: inspection.pumps),
    );

    if (updated == null) return;
    await context.read<StationInspectionProvider>().updateInspection(
          inspection.copyWith(pumps: updated),
        );
  }

  Future<void> _printInspection(StationInspection inspection) async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildInspectionPdf(inspection);
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _downloadInspection(StationInspection inspection) async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildInspectionPdf(inspection);
      final safeName = inspection.name.replaceAll(' ', '_');
      await saveAndLaunchFile(bytes, 'معاينة_$safeName.pdf');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StationInspectionProvider>(
      builder: (context, provider, _) {
        final inspection = _getInspection(provider);

        if (inspection == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isWide = MediaQuery.of(context).size.width >= 900;

        return Scaffold(
          appBar: AppBar(
            title: const Text('تفاصيل المعاينة',
                style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _exporting ? null : () => _printInspection(inspection),
                tooltip: 'تصدير PDF',
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed:
                    _exporting ? null : () => _downloadInspection(inspection),
                tooltip: 'تحميل',
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editInspection(inspection),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _headerSection(inspection),
                  const SizedBox(height: 16),
                  _actionsSection(inspection),
                  const SizedBox(height: 16),
                  _detailsSection(isWide, inspection),
                  const SizedBox(height: 16),
                  _ownerSection(inspection),
                  const SizedBox(height: 16),
                  _pumpsSection(inspection),
                  const SizedBox(height: 16),
                  _fuelSummarySection(inspection),
                  const SizedBox(height: 16),
                  _attachmentsSection(inspection),
                  const SizedBox(height: 16),
                  _notesSection(inspection),
                ],
              ),
              if (_exporting || provider.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.white70,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  Widget _headerSection(StationInspection inspection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
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
                  inspection.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${inspection.city} - ${inspection.region} - ${inspection.address}',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _statusBadge(inspection.status),
                    _infoChip(
                      icon: Icons.speed,
                      label: 'المضخات: ${inspection.pumps.length}',
                    ),
                    _infoChip(
                      icon: Icons.calendar_today,
                      label:
                          'تاريخ المعاينة: ${DateFormat('yyyy-MM-dd').format(inspection.createdAt)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsSection(StationInspection inspection) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () => _addClosingReadings(inspection),
          icon: const Icon(Icons.speed),
          label: const Text('إضافة قراءات الإقفال'),
        ),
      ],
    );
  }

  Widget _detailsSection(bool isWide, StationInspection inspection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('بيانات المحطة'),
          const SizedBox(height: 12),
          isWide
              ? Row(
                  children: [
                    Expanded(child: _detailRow('المدينة', inspection.city)),
                    const SizedBox(width: 12),
                    Expanded(child: _detailRow('المنطقة', inspection.region)),
                  ],
                )
              : Column(
                  children: [
                    _detailRow('المدينة', inspection.city),
                    const SizedBox(height: 8),
                    _detailRow('المنطقة', inspection.region),
                  ],
                ),
          const SizedBox(height: 8),
          _detailRow('العنوان', inspection.address),
          const SizedBox(height: 8),
          _detailRow('تاريخ الإضافة',
              DateFormat('yyyy-MM-dd HH:mm').format(inspection.createdAt)),
          const SizedBox(height: 8),
          _detailRow(
              'تمت الإضافة بواسطة', inspection.createdByName ?? '-'),
          if (inspection.location != null) ...[
            const SizedBox(height: 8),
            _detailRow(
              'الإحداثيات',
              '${inspection.location!.lat.toStringAsFixed(6)}, ${inspection.location!.lng.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openMapLink(_mapLink(inspection.location!)),
                  icon: const Icon(Icons.map),
                  label: const Text('فتح الموقع'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => _openMapLink(_routeLink(inspection.location!)),
                  icon: const Icon(Icons.directions),
                  label: const Text('فتح المسار'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ownerSection(StationInspection inspection) {
    final owner = inspection.owner;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('بيانات مالك المحطة'),
          const SizedBox(height: 12),
          if (owner == null)
            Text(
              'لا توجد بيانات للمالك بعد',
              style: TextStyle(color: AppColors.mediumGray),
            )
          else ...[
            _detailRow('اسم المالك', owner.name.isEmpty ? '-' : owner.name),
            const SizedBox(height: 8),
            _detailRow(
                'رقم الجوال', owner.phone.isEmpty ? '-' : owner.phone),
            const SizedBox(height: 8),
            _detailRow(
                'عنوان المالك', owner.address.isEmpty ? '-' : owner.address),
          ],
          const SizedBox(height: 12),
          _sectionTitle('حالة المعاينة'),
          const SizedBox(height: 8),
          DropdownButtonFormField<InspectionStatus>(
            value: inspection.status,
            items: InspectionStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(_statusLabel(status)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _updateStatus(inspection, value);
            },
            decoration: const InputDecoration(
              labelText: 'تحديث حالة المعاينة',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pumpsSection(StationInspection inspection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('المضخات والقراءات'),
          const SizedBox(height: 12),
          if (inspection.pumps.isEmpty)
            const Text('لا توجد مضخات مسجلة'),
          if (inspection.pumps.isNotEmpty)
            ...inspection.pumps.map((pump) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(pump.type),
                  subtitle: Text(
                    'عدد الليّات: ${pump.nozzleCount} • قراءة الفتح: ${pump.totalOpeningReading.toStringAsFixed(2)} • قراءة الإقفال: ${pump.nozzles.isEmpty ? (pump.closingReading != null ? pump.closingReading!.toStringAsFixed(2) : '-') : (pump.nozzles.any((n) => n.closingReading != null) ? pump.totalClosingReading.toStringAsFixed(2) : '-')} • الأنواع: ${_pumpFuelTypes(pump)}',
                  ),
                  trailing: Text(
                    'اللترات: ${pump.soldLiters.toStringAsFixed(0)}',
                    style: TextStyle(color: AppColors.successGreen),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _fuelSummarySection(StationInspection inspection) {
    final totals = _fuelTotals(inspection);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('ملخص اللترات المباعة'),
          const SizedBox(height: 12),
          if (totals.isEmpty)
            Text('لا توجد بيانات بيع بعد',
                style: TextStyle(color: AppColors.mediumGray))
          else
            ...totals.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(_fuelTypeLabel(entry.key))),
                    Text('${entry.value.toStringAsFixed(2)} لتر'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _attachmentsSection(StationInspection inspection) {
    final images =
        inspection.attachments.where((a) => a.type == 'image').toList();
    final audios =
        inspection.attachments.where((a) => a.type == 'audio').toList();
    final videos =
        inspection.attachments.where((a) => a.type == 'video').toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('مرفقات المعاينة'),
          const SizedBox(height: 12),
          if (images.isEmpty && audios.isEmpty && videos.isEmpty)
            Text('لا توجد مرفقات بعد',
                style: TextStyle(color: AppColors.mediumGray)),
          if (images.isNotEmpty) ...[
            const Text('الصور', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _imageGrid(images),
          ],
          if (videos.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('الفيديو', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _attachmentList(videos, icon: Icons.videocam),
          ],
          if (audios.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('التسجيلات الصوتية',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _attachmentList(audios, icon: Icons.audiotrack),
          ],
        ],
      ),
    );
  }

  Widget _notesSection(StationInspection inspection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('الملاحظات'),
          const SizedBox(height: 8),
          Text(
            inspection.notes?.isNotEmpty == true
                ? inspection.notes!
                : 'لا توجد ملاحظات',
            style: TextStyle(color: AppColors.mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _imageGrid(List<InspectionAttachment> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 3;
        if (width >= 1200) {
          columns = 6;
        } else if (width >= 900) {
          columns = 5;
        } else if (width >= 700) {
          columns = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final url = images[index].url;
            return InkWell(
              onTap: () => _openAttachment(url),
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.backgroundGray,
                          child: const Center(
                              child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.backgroundGray,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: AppColors.mediumGray,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'تعذر التحميل',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _attachmentList(List<InspectionAttachment> attachments,
      {required IconData icon}) {
    return Column(
      children: attachments.map((attachment) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.primaryBlue),
          title: Text(attachment.name.isEmpty ? 'ملف' : attachment.name),
          subtitle: Text(attachment.url),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openAttachment(attachment.url),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      _showSnackBar('تعذر فتح المرفق');
    }
  }

  String _mapLink(InspectionLocation location) {
    return 'https://www.google.com/maps?q=${location.lat},${location.lng}';
  }

  String _routeLink(InspectionLocation location) {
    return 'https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lng}';
  }

  Future<void> _openMapLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        _showSnackBar('تعذر فتح الرابط');
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.mediumGray),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _statusBadge(InspectionStatus status) {
    String label;
    Color color;

    switch (status) {
      case InspectionStatus.accepted:
        label = 'مقبولة';
        color = AppColors.successGreen;
        break;
      case InspectionStatus.rejected:
        label = 'مرفوضة';
        color = AppColors.errorRed;
        break;
      case InspectionStatus.pending:
      default:
        label = 'تحت المعاينة';
        color = AppColors.warningOrange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _pumpFuelTypes(InspectionPump pump) {
    final types = pump.nozzles
        .map((nozzle) => _fuelTypeLabel(nozzle.fuelType))
        .toSet()
        .toList();
    if (types.isEmpty) return '-';
    return types.join('، ');
  }

  Map<FuelType, double> _fuelTotals(StationInspection inspection) {
    final totals = <FuelType, double>{};
    for (final pump in inspection.pumps) {
      for (final nozzle in pump.nozzles) {
        totals[nozzle.fuelType] =
            (totals[nozzle.fuelType] ?? 0) + nozzle.soldLiters;
      }
    }
    return totals;
  }

  String _statusLabel(InspectionStatus status) {
    switch (status) {
      case InspectionStatus.accepted:
        return 'مقبولة';
      case InspectionStatus.rejected:
        return 'مرفوضة';
      case InspectionStatus.pending:
      default:
        return 'تحت المعاينة';
    }
  }

  String _fuelTypeLabel(FuelType type) {
    switch (type) {
      case FuelType.gas91:
        return 'بنزين 91';
      case FuelType.gas95:
        return 'بنزين 95';
      case FuelType.diesel:
        return 'ديزل';
      case FuelType.kerosene:
        return 'كيروسين';
    }
  }
}

class _ClosingReadingsDialog extends StatefulWidget {
  final List<InspectionPump> pumps;

  const _ClosingReadingsDialog({required this.pumps});

  @override
  State<_ClosingReadingsDialog> createState() => _ClosingReadingsDialogState();
}

class _ClosingReadingsDialogState extends State<_ClosingReadingsDialog> {
  late final List<List<TextEditingController>> _controllers;
  late final List<List<DateTime>> _dates;

  @override
  void initState() {
    super.initState();
    _controllers = widget.pumps.map((pump) {
      if (pump.nozzles.isNotEmpty) {
        return pump.nozzles
            .map(
              (nozzle) => TextEditingController(
                text: nozzle.closingReading?.toString() ?? '',
              ),
            )
            .toList();
      }
      return [
        TextEditingController(text: pump.closingReading?.toString() ?? ''),
      ];
    }).toList();

    _dates = widget.pumps.map((pump) {
      if (pump.nozzles.isNotEmpty) {
        return pump.nozzles
            .map((nozzle) => nozzle.closingReadingDate ?? DateTime.now())
            .toList();
      }
      return [pump.closingReadingDate ?? DateTime.now()];
    }).toList();
  }

  @override
  void dispose() {
    for (final controllers in _controllers) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickDateTime(int pumpIndex, int nozzleIndex) async {
    final initial = _dates[pumpIndex][nozzleIndex];
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final time = pickedTime ?? TimeOfDay.fromDateTime(initial);
    setState(() {
      _dates[pumpIndex][nozzleIndex] = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final updated = <InspectionPump>[];
    for (var i = 0; i < widget.pumps.length; i++) {
      final pump = widget.pumps[i];
      if (pump.nozzles.isEmpty) {
        final value = double.tryParse(_controllers[i].first.text.trim());
        updated.add(
          pump.copyWith(
            closingReading: value,
            closingReadingDate: value == null ? null : _dates[i].first,
          ),
        );
        continue;
      }

      final updatedNozzles = <InspectionNozzle>[];
      for (var j = 0; j < pump.nozzles.length; j++) {
        final nozzle = pump.nozzles[j];
        final value = double.tryParse(_controllers[i][j].text.trim());
        updatedNozzles.add(
          nozzle.copyWith(
            closingReading: value,
            closingReadingDate: value == null ? null : _dates[i][j],
          ),
        );
      }

      final hasClosing = updatedNozzles.any((n) => n.closingReading != null);
      final totalClosing = hasClosing
          ? updatedNozzles.fold<double>(
              0,
              (sum, n) => sum + (n.closingReading ?? 0),
            )
          : null;

      updated.add(
        pump.copyWith(
          nozzles: updatedNozzles,
          closingReading: totalClosing,
          closingReadingDate: hasClosing ? DateTime.now() : null,
        ),
      );
    }
    Navigator.pop(context, updated);
  }

  String _fuelTypeLabel(FuelType type) {
    switch (type) {
      case FuelType.gas91:
        return 'بنزين 91';
      case FuelType.gas95:
        return 'بنزين 95';
      case FuelType.diesel:
        return 'ديزل';
      case FuelType.kerosene:
        return 'كيروسين';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('قراءات الإقفال'),
      content: SingleChildScrollView(
        child: Column(
          children: widget.pumps.asMap().entries.map((entry) {
            final index = entry.key;
            final pump = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pump.type,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (pump.nozzles.isEmpty)
                      Column(
                        children: [
                          TextField(
                            controller: _controllers[index].first,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'قراءة الإقفال',
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () => _pickDateTime(index, 0),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              'تاريخ الإدخال: ${_dates[index].first.toString().split(".").first}',
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: pump.nozzles
                            .asMap()
                            .entries
                            .map((nozzleEntry) {
                          final nozzleIndex = nozzleEntry.key;
                          final nozzle = nozzleEntry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'لي رقم ${nozzle.nozzleNumber} • ${_fuelTypeLabel(nozzle.fuelType)} • فتح: ${nozzle.openingReading.toStringAsFixed(2)}',
                                  style:
                                      TextStyle(color: AppColors.mediumGray),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _controllers[index][nozzleIndex],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'قراءة الإقفال',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickDateTime(index, nozzleIndex),
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    'تاريخ الإدخال: ${_dates[index][nozzleIndex].toString().split(".").first}',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('حفظ القراءات'),
        ),
      ],
    );
  }
}
