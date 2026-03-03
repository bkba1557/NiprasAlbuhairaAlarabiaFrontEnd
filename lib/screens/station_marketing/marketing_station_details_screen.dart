import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';

import 'marketing_handover_pdf.dart';
import 'marketing_handover_report_screen.dart';
import 'marketing_handover_report_form_screen.dart';
import 'marketing_models.dart';
import 'marketing_station_form_screen.dart';

class MarketingStationDetailsScreen extends StatefulWidget {
  final String stationId;
  final MarketingStation? initialStation;

  const MarketingStationDetailsScreen({
    super.key,
    required this.stationId,
    this.initialStation,
  });

  @override
  State<MarketingStationDetailsScreen> createState() =>
      _MarketingStationDetailsScreenState();
}

class _MarketingStationDetailsScreenState
    extends State<MarketingStationDetailsScreen> {
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketingStationProvider>().fetchStationById(widget.stationId);
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  MarketingStation? _getStation(MarketingStationProvider provider) {
    final selected = provider.selectedStation;
    if (selected != null && selected.id == widget.stationId) {
      return selected;
    }
    if (widget.initialStation != null &&
        widget.initialStation!.id == widget.stationId) {
      return widget.initialStation;
    }
    return null;
  }

  double _totalLiters(MarketingStation station) {
    return station.pumps.fold<double>(
      0,
      (total, pump) => total + pump.soldLiters,
    );
  }

  Future<void> _editStation(MarketingStation station) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingStationFormScreen(
          stationToEdit: station,
        ),
      ),
    );

    if (result == true && mounted) {
      await context
          .read<MarketingStationProvider>()
          .fetchStationById(station.id);
    }
  }

  void _openLeaseDialog({required MarketingStation station, bool isTransfer = false}) {
    showDialog<void>(
      context: context,
      builder: (_) => _LeaseDialog(
        initialLease: station.lease,
        accounting: station.accounting,
        onSave: (lease) async {
          await context
              .read<MarketingStationProvider>()
              .setLease(station.id, lease);
        },
        title: isTransfer ? 'تغيير المستأجر' : 'تأجير المحطة',
      ),
    );
  }

  Future<void> _terminateLease(MarketingStation station) async {
    await context.read<MarketingStationProvider>().terminateLease(station.id);
  }

  Future<void> _addClosingReadings(MarketingStation station) async {
    final updated = await showDialog<List<MarketingPump>>(
      context: context,
      builder: (_) => _ClosingReadingsDialog(pumps: station.pumps),
    );

    if (updated == null) return;
    await context.read<MarketingStationProvider>().updateStation(
          station.copyWith(pumps: updated),
        );
  }

  void _openHandoverReport(MarketingStation station) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingHandoverReportScreen(station: station),
      ),
    );
  }

  Future<void> _openHandoverReportForm(MarketingStation station) async {
    final result = await Navigator.push<MarketingStation>(
      context,
      MaterialPageRoute(
        builder: (_) => MarketingHandoverReportFormScreen(station: station),
      ),
    );

    if (result != null && mounted) {
      await context
          .read<MarketingStationProvider>()
          .fetchStationById(station.id);
    }
  }

  Future<void> _printHandoverReport(MarketingStation station) async {
    if (station.handoverReport == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد بيانات محضر للاستلام')),
        );
      }
      return;
    }

    final bytes = await buildMarketingHandoverPdf(station);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _downloadHandoverReport(MarketingStation station) async {
    if (station.handoverReport == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد بيانات محضر للاستلام')),
        );
      }
      return;
    }

    final bytes = await buildMarketingHandoverPdf(station);
    final safeName = station.name.replaceAll(' ', '_');
    await saveAndLaunchFile(bytes, 'محضر_استلام_$safeName.pdf');
  }

  String _mapLink(StationLocation location) {
    return 'https://www.google.com/maps?q=${location.lat},${location.lng}';
  }

  String _routeLink(StationLocation location) {
    return 'https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lng}';
  }

  Future<void> _openMapLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImages(MarketingStation station) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    setState(() => _uploading = true);
    final provider = context.read<MarketingStationProvider>();

    try {
      final urls = await provider.uploadAttachments(station.id, files);
      await provider.addAttachments(station.id, urls);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _captureAndUploadImage(MarketingStation station) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    setState(() => _uploading = true);
    final provider = context.read<MarketingStationProvider>();

    try {
      final urls = await provider.uploadAttachments(station.id, [file]);
      await provider.addAttachments(station.id, urls);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketingStationProvider>(
      builder: (context, provider, _) {
        final station = _getStation(provider);

        if (station == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isWide = MediaQuery.of(context).size.width >= 900;
        final hasReport = station.handoverReport != null;

        return Scaffold(
          appBar: AppBar(
            title:
                const Text('تفاصيل المحطة', style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.assignment_add),
                onPressed: () => _openHandoverReportForm(station),
                tooltip: 'إنشاء محضر تسليم',
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: hasReport ? () => _printHandoverReport(station) : null,
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed:
                    hasReport ? () => _downloadHandoverReport(station) : null,
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editStation(station),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _headerSection(station),
                  const SizedBox(height: 16),
                  _actionsSection(station),
                  const SizedBox(height: 16),
                  _detailsSection(isWide, station),
                  const SizedBox(height: 16),
                  _ownerSection(station),
                  const SizedBox(height: 16),
                  _handoverReportSection(station),
                  const SizedBox(height: 16),
                  _pumpsSection(station),
                  const SizedBox(height: 16),
                  _attachmentsSection(station),
                  const SizedBox(height: 16),
                  _accountingSection(station),
                ],
              ),
              if (_uploading || provider.isLoading)
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

  Widget _headerSection(MarketingStation station) {
    final tenantLabel = station.tenantName ??
        station.handoverReport?.companyName ??
        'غير محدد';
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
                  station.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${station.city} - ${station.address}',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _statusBadge(station.status),
                    _infoChip(
                      icon: Icons.assessment,
                      label:
                          'إجمالي اللترات: ${_totalLiters(station).toStringAsFixed(0)}',
                    ),
                    if (station.tenantName != null)
                      _infoChip(
                        icon: Icons.person,
                        label: 'المستأجر: ${station.tenantName}',
                      ),
                    if (station.handoverReport != null)
                      _infoChip(
                        icon: Icons.assignment_turned_in,
                        label:
                            'تم عمل محضر تسليم للمستأجر: $tenantLabel',
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

  Widget _actionsSection(MarketingStation station) {
    final isRented = station.status == StationMarketingStatus.rented ||
        station.status == StationMarketingStatus.rentedToNasserMotairi;
    final hasReport = station.handoverReport != null;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () => _openHandoverReportForm(station),
          icon: const Icon(Icons.assignment_add),
          label: Text(hasReport ? 'تعديل محضر التسليم' : 'إنشاء محضر التسليم'),
        ),
        OutlinedButton.icon(
          onPressed: hasReport ? () => _openHandoverReport(station) : null,
          icon: const Icon(Icons.assignment),
          label: const Text('عرض محضر التسليم'),
        ),
        ElevatedButton.icon(
          onPressed: isRented ? null : () => _openLeaseDialog(station: station),
          icon: const Icon(Icons.assignment_ind),
          label: const Text('تأجير المحطة'),
        ),
        OutlinedButton.icon(
          onPressed: isRented ? () => _terminateLease(station) : null,
          icon: const Icon(Icons.block),
          label: const Text('فسخ العقد'),
        ),
        OutlinedButton.icon(
          onPressed: isRented
              ? () => _openLeaseDialog(station: station, isTransfer: true)
              : null,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('تغيير المستأجر'),
        ),
        ElevatedButton.icon(
          onPressed: () => _addClosingReadings(station),
          icon: const Icon(Icons.speed),
          label: const Text('إضافة قراءات الإقفال'),
        ),
      ],
    );
  }

  Widget _detailsSection(bool isWide, MarketingStation station) {
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
                    Expanded(child: _detailRow('المدينة', station.city)),
                    const SizedBox(width: 12),
                    Expanded(child: _detailRow('العنوان', station.address)),
                  ],
                )
              : Column(
                  children: [
                    _detailRow('المدينة', station.city),
                    const SizedBox(height: 8),
                    _detailRow('العنوان', station.address),
                  ],
                ),
          const SizedBox(height: 8),
          _detailRow(
            'تاريخ الإضافة',
            station.createdAt.toString().split(' ').first,
          ),
          const SizedBox(height: 8),
          _detailRow('تمت الإضافة بواسطة', station.createdByName ?? '-'),
          const SizedBox(height: 8),
          if (station.location != null)
            _detailRow(
              'الموقع',
              '${station.location!.lat}, ${station.location!.lng}',
            ),
          if (station.location != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openMapLink(_mapLink(station.location!)),
                  icon: const Icon(Icons.map),
                  label: const Text('فتح الموقع'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openMapLink(_routeLink(station.location!)),
                  icon: const Icon(Icons.directions),
                  label: const Text('فتح المسار'),
                ),
              ],
            ),
          ],
          if (station.handoverReport != null) ...[
            const SizedBox(height: 8),
            _detailRow(
              'حالة محضر التسليم',
              'تم عمل محضر تسليم محروقات للمستأجر (${station.tenantName ?? station.handoverReport?.companyName ?? 'غير محدد'})',
            ),
          ],
          if (station.notes != null && station.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _detailRow('ملاحظات', station.notes!),
            ),
        ],
      ),
    );
  }

  Widget _ownerSection(MarketingStation station) {
    final owner = station.owner;
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
              'رقم الجوال',
              owner.phone.isEmpty ? '-' : owner.phone,
            ),
            const SizedBox(height: 8),
            _detailRow(
              'رقم الهوية',
              owner.idNumber.isEmpty ? '-' : owner.idNumber,
            ),
            const SizedBox(height: 8),
            _detailRow(
              'رقم عقد منصة إيجار',
              owner.ejarContractNumber.isEmpty ? '-' : owner.ejarContractNumber,
            ),
            const SizedBox(height: 8),
            _detailRow(
              'عنوان المالك',
              owner.address.isEmpty ? '-' : owner.address,
            ),
          ],
        ],
      ),
    );
  }

  Widget _handoverReportSection(MarketingStation station) {
    final report = station.handoverReport;
    if (report == null) {
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
            _sectionTitle('محضر استلام محطة محروقات'),
            const SizedBox(height: 8),
            Text(
              'لم يتم إدخال بيانات محضر الاستلام بعد.',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          ],
        ),
      );
    }

    final stationName =
        report.stationName.trim().isNotEmpty ? report.stationName : station.name;
    final city =
        report.city.trim().isNotEmpty ? report.city : station.city;
    final street =
        report.street.trim().isNotEmpty ? report.street : station.address;

    final contractText = report.contractReference.trim().isEmpty
        ? ''
        : ' حسب العقد المبرم ${_reportValue(report.contractReference)}';

    final paragraph = 'انه في يوم ${_reportValue(report.dayName)} بتاريخ '
        '${_reportValue(report.hijriDate)} هـ الموافق '
        '${_reportValue(report.gregorianDate)} تم الوقوف على محطة المحروقات '
        'المسماة بمحطة ${_reportValue(stationName)} مدينة ${_reportValue(city)} '
        'حي ${_reportValue(report.district)} على شارع ${_reportValue(street)} '
        'وتحمل ترخيص مدني تحت الرقم ${_reportValue(report.civilLicenseNumber)} '
        'بتاريخ ${_reportValue(report.civilLicenseDate)} هـ وترخيص البلدية '
        'تحت الرقم ${_reportValue(report.municipalityLicenseNumber)} بتاريخ '
        '${_reportValue(report.municipalityLicenseDate)} هـ، وذلك من قبل السيد '
        'صاحب المحطة/ ${_reportValue(report.ownerName)} أو من ينوب عنه '
        'بوكالة شرعية رقم ${_reportValue(report.authorizationNumber)}، '
        'ومندوب شركة ${_reportValue(report.companyName)} '
        '${_reportValue(report.companyRepresentativeName)}$contractText. '
        'وقد تم الاستلام والتسليم للمحطة المعنية على النحو التالي:';

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
          _sectionTitle('محضر استلام محطة محروقات'),
          const SizedBox(height: 8),
          Text(paragraph),
          const SizedBox(height: 12),
          Text(
            'يوجد بالمحطة عدد (${_reportValue(report.dispensersCount)}) طرمبة تموين سيارات '
            'منها (${_reportValue(report.doubleDispensersCount)}) مزدوج.',
            style: TextStyle(color: AppColors.mediumGray),
          ),
          const SizedBox(height: 12),
          Text('1) طرمبات الوقود', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildReportTable(
            headers: const [
              'نوع الطرمبة',
              'العدد',
              'قراءة العداد السري',
              'الحالة الفنية',
            ],
            rows: _ensureReportRows(
              report.fuelDispensers
                  .map(
                    (row) => [
                      row.pumpType,
                      row.count,
                      row.meterReading,
                      row.technicalStatus,
                    ],
                  )
                  .toList(),
              4,
              4,
            ),
          ),
          const SizedBox(height: 12),
          Text('2) الخزانات', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildReportTable(
            headers: const [
              'رقم الخزان',
              'نوع الوقود',
              'السعة التشغيلية',
              'الحالة الفنية',
            ],
            rows: _ensureReportRows(
              report.fuelTanks
                  .map(
                    (row) => [
                      row.tankNumber,
                      row.fuelType,
                      row.operatingCapacity,
                      row.technicalStatus,
                    ],
                  )
                  .toList(),
              4,
              4,
            ),
          ),
          const SizedBox(height: 12),
          Text('3) الطرمبات الغاطسة', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildReportTable(
            headers: const [
              'ماركة الغاطس',
              'عددها',
              'قوة الغاطس',
              'الحالة الفنية',
            ],
            rows: _ensureReportRows(
              report.submersiblePumps
                  .map(
                    (row) => [
                      row.brand,
                      row.count,
                      row.power,
                      row.technicalStatus,
                    ],
                  )
                  .toList(),
              1,
              4,
            ),
          ),
          const SizedBox(height: 12),
          Text('4) المعدات', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildReportTable(
            headers: const [
              'نوع الجهاز',
              'العدد',
              'المواصفات',
              'الحالة الفنية',
              'الملاحظات',
            ],
            rows: _ensureReportRows(
              report.equipment
                  .map(
                    (row) => [
                      row.equipmentType,
                      row.count,
                      row.specifications,
                      row.technicalStatus,
                      row.notes,
                    ],
                  )
                  .toList(),
              5,
              5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _printHandoverReport(station),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('طباعة المحضر'),
              ),
              OutlinedButton.icon(
                onPressed: () => _downloadHandoverReport(station),
                icon: const Icon(Icons.download),
                label: const Text('تحميل PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pumpsSection(MarketingStation station) {
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
          _sectionTitle('المضخات'),
          const SizedBox(height: 12),
          if (station.pumps.isEmpty)
            const Text('لا توجد مضخات مسجلة'),
          if (station.pumps.isNotEmpty)
            ...station.pumps.map((pump) {
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

  Widget _attachmentsSection(MarketingStation station) {
    final attachments = station.attachments;
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
          _sectionTitle('صور المحطة'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _captureAndUploadImage(station),
                icon: const Icon(Icons.photo_camera),
                label: const Text('تصوير وإرفاق'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickAndUploadImages(station),
                icon: const Icon(Icons.upload_file),
                label: const Text('رفع صور'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (attachments.isEmpty)
            Text(
              'لا توجد صور مرفوعة بعد',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          if (attachments.isNotEmpty)
            LayoutBuilder(
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
                  itemCount: attachments.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final url = attachments[index];
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
                                  child:
                                      const Center(child: CircularProgressIndicator()),
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
                          PositionedDirectional(
                            top: 6,
                            end: 6,
                            child: InkWell(
                              onTap: () => _downloadAttachment(url),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.lightGray,
                                  ),
                                ),
                                child: Icon(
                                  Icons.download,
                                  size: 16,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
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
      _showSnackBar('تعذر فتح الصورة');
    }
  }

  Future<void> _downloadAttachment(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _showSnackBar('تعذر تحميل الصورة');
        return;
      }
      final filename = Uri.parse(url).pathSegments.isNotEmpty
          ? Uri.parse(url).pathSegments.last
          : 'attachment.jpg';
      await saveAndLaunchFile(response.bodyBytes, filename);
    } catch (_) {
      _showSnackBar('تعذر تحميل الصورة');
    }
  }

  Widget _accountingSection(MarketingStation station) {
    final accounting = station.accounting;
    final baseCost = accounting.stationCost + accounting.expenses;
    const targetMargin = 0.15;
    final suggestedPrice = baseCost == 0 ? 0 : baseCost * (1 + targetMargin);
    final priceGap = accounting.leaseAmount - accounting.stationCost;
    final profitAfterExpenses =
        accounting.leaseAmount - accounting.stationCost - accounting.expenses;
    final planBase =
        accounting.leaseAmount > 0 ? accounting.leaseAmount : suggestedPrice;
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
          _sectionTitle('الحسابات'),
          const SizedBox(height: 12),
          _detailRow(
            'تكلفة استئجار المحطة',
            '${accounting.stationCost.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 8),
          _detailRow(
            'سعر التأجير للمستأجر',
            '${accounting.leaseAmount.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 8),
          _detailRow(
            'المصاريف',
            '${accounting.expenses.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 8),
          _detailRow(
            'الإيرادات',
            '${accounting.revenue.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 8),
          _detailRow(
            'فرق السعر (التأجير - الاستئجار)',
            '${priceGap.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 8),
          _detailRow(
            'الربح بعد المصاريف',
            '${profitAfterExpenses.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 8),
          _detailRow(
            'سعر تأجير مقترح (ربح 15%)',
            '${suggestedPrice.toStringAsFixed(2)} ر.س',
          ),
          const SizedBox(height: 12),
          _sectionTitle('خطط تأجير مقترحة'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                icon: Icons.calendar_month,
                label:
                    'شهري: ${(planBase / 12).toStringAsFixed(2)} ر.س',
              ),
              _infoChip(
                icon: Icons.calendar_view_month,
                label:
                    'ربع سنوي: ${(planBase / 4).toStringAsFixed(2)} ر.س',
              ),
              _infoChip(
                icon: Icons.calendar_today,
                label:
                    'نصف سنوي: ${(planBase / 2).toStringAsFixed(2)} ر.س',
              ),
              _infoChip(
                icon: Icons.event_available,
                label: 'سنوي: ${planBase.toStringAsFixed(2)} ر.س',
              ),
            ],
          ),
        ],
      ),
    );
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _reportValue(String? value) {
    if (value == null) return '........';
    final trimmed = value.trim();
    return trimmed.isEmpty ? '........' : trimmed;
  }

  List<List<String>> _ensureReportRows(
    List<List<String>> rows,
    int minRows,
    int columns,
  ) {
    final output = rows.map((row) {
      if (row.length >= columns) return row;
      return row + List.filled(columns - row.length, '');
    }).toList();
    while (output.length < minRows) {
      output.add(List.filled(columns, ''));
    }
    return output;
  }

  Widget _buildReportTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Table(
      border: TableBorder.all(color: AppColors.lightGray),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.backgroundGray),
          children: headers
              .map(
                (header) => Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    header,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => TableRow(
            children: row
                .map(
                  (cell) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      cell.trim().isEmpty ? '-' : cell,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _infoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppColors.primaryBlue)),
        ],
      ),
    );
  }

  Widget _statusBadge(StationMarketingStatus status) {
    String label;
    Color color;

    switch (status) {
      case StationMarketingStatus.pendingReview:
        label = 'تحت المراجعة';
        color = AppColors.warningOrange;
        break;
      case StationMarketingStatus.readyForLease:
        label = 'جاهزة للتأجير';
        color = AppColors.accentBlue;
        break;
      case StationMarketingStatus.rented:
        label = 'مؤجرة';
        color = Colors.teal;
        break;
      case StationMarketingStatus.rentedToNasserMotairi:
        label = 'مستأجرة لشركة ناصر المطيري';
        color = Colors.blueGrey;
        break;
      case StationMarketingStatus.cancelled:
        label = 'ملغية';
        color = AppColors.errorRed;
        break;
      case StationMarketingStatus.maintenance:
        label = 'تحت الصيانة';
        color = Colors.deepOrange;
        break;
      case StationMarketingStatus.study:
        label = 'تحت الدراسة';
        color = Colors.indigo;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  String _pumpFuelTypes(MarketingPump pump) {
    final types = pump.nozzles
        .map((nozzle) => _fuelTypeLabel(nozzle.fuelType))
        .toSet()
        .toList();
    if (types.isEmpty) return '-';
    return types.join('، ');
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

class _LeaseDialog extends StatefulWidget {
  final LeaseContract? initialLease;
  final void Function(LeaseContract contract) onSave;
  final String title;
  final MarketingAccounting accounting;

  const _LeaseDialog({
    required this.onSave,
    required this.title,
    required this.accounting,
    this.initialLease,
  });

  @override
  State<_LeaseDialog> createState() => _LeaseDialogState();
}

class _LeaseDialogState extends State<_LeaseDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _yearsController = TextEditingController(text: '1');
  final _paymentCountController = TextEditingController(text: '1');
  final _leaseAmountController = TextEditingController();
  double _leaseAmountValue = 0;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  String _paymentPlan = 'oneTime';
  int _paymentCount = 1;
  final List<TextEditingController> _paymentAmountControllers = [];
  late final AnimationController _glowController;

  static const Map<String, String> _paymentPlanLabels = {
    'oneTime': 'دفعة واحدة',
    'monthly': 'شهري',
    'quarterly': 'ربع سنوي',
    'semiAnnual': 'نصف سنوي',
    'annual': 'سنوي',
    'custom': 'مخصص',
  };

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _leaseAmountValue = widget.accounting.leaseAmount;
    _leaseAmountController.text = widget.accounting.leaseAmount == 0
        ? ''
        : widget.accounting.leaseAmount.toStringAsFixed(2);
    final lease = widget.initialLease;
    if (lease != null) {
      _nameController.text = lease.tenantName;
      _idController.text = lease.tenantId;
      _phoneController.text = lease.phone;
      _addressController.text = lease.address;
      _notesController.text = lease.notes;
      _yearsController.text = lease.years.toString();
      _startDate = lease.startDate;
      _endDate = lease.endDate;
      _paymentPlan = lease.paymentPlan;
      if (lease.leaseAmount != null && lease.leaseAmount! > 0) {
        _leaseAmountValue = lease.leaseAmount!;
        _leaseAmountController.text = lease.leaseAmount!.toStringAsFixed(2);
      }
      if (!_paymentPlanLabels.containsKey(_paymentPlan)) {
        _paymentPlan = 'custom';
      }
      _paymentCount = lease.paymentCount > 0 ? lease.paymentCount : 1;
      _paymentCountController.text = _paymentCount.toString();
      _setPaymentCount(_paymentCount);
      for (var i = 0; i < _paymentAmountControllers.length; i++) {
        if (i < lease.paymentAmounts.length) {
          _paymentAmountControllers[i].text =
              lease.paymentAmounts[i].toString();
        }
      }
    } else {
      _setPaymentCount(_paymentCount);
      _paymentCountController.text = _paymentCount.toString();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _yearsController.dispose();
    _paymentCountController.dispose();
    _leaseAmountController.dispose();
    for (final controller in _paymentAmountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setPaymentCount(int count) {
    final safeCount = count < 1 ? 1 : count;
    if (safeCount == _paymentAmountControllers.length) return;

    if (safeCount < _paymentAmountControllers.length) {
      final toRemove = _paymentAmountControllers.sublist(safeCount);
      for (final controller in toRemove) {
        controller.dispose();
      }
      _paymentAmountControllers.removeRange(
        safeCount,
        _paymentAmountControllers.length,
      );
    } else {
      for (int i = _paymentAmountControllers.length; i < safeCount; i++) {
        _paymentAmountControllers.add(TextEditingController());
      }
    }
    _paymentCount = safeCount;
    _paymentCountController.text = safeCount.toString();
  }

  void _syncPaymentCountWithYears() {
    if (_paymentPlan == 'custom') return;
    final years = int.tryParse(_yearsController.text.trim()) ?? 1;
    int count;
    switch (_paymentPlan) {
      case 'monthly':
        count = years * 12;
        break;
      case 'quarterly':
        count = years * 4;
        break;
      case 'semiAnnual':
        count = years * 2;
        break;
      case 'annual':
        count = years;
        break;
      case 'oneTime':
      default:
        count = 1;
        break;
    }
    setState(() => _setPaymentCount(count));
  }

  void _updateYearsFromDates() {
    final days = _endDate.difference(_startDate).inDays;
    var years = (days / 365).ceil();
    if (years < 1) years = 1;
    _yearsController.text = years.toString();
    _syncPaymentCountWithYears();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final leaseAmount =
        double.tryParse(_leaseAmountController.text.trim()) ?? 0;
    if (leaseAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ التأجير')),
      );
      return;
    }
    final years = int.tryParse(_yearsController.text.trim()) ?? 1;
    if (_paymentAmountControllers.isEmpty) {
      _setPaymentCount(_paymentCount);
    }
    final paymentAmounts = _paymentAmountControllers
        .map((controller) => double.tryParse(controller.text.trim()) ?? 0)
        .toList();
    if (paymentAmounts.any((amount) => amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبالغ الدفعات بشكل صحيح')),
      );
      return;
    }

    widget.onSave(
      LeaseContract(
        tenantName: _nameController.text.trim(),
        tenantId: _idController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        years: years,
        leaseAmount: leaseAmount,
        paymentPlan: _paymentPlan,
        paymentCount: _paymentCount,
        paymentAmounts: paymentAmounts,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        final years = int.tryParse(_yearsController.text.trim()) ?? 1;
        _endDate = _startDate.add(Duration(days: 365 * years));
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 365));
        }
      });
      _updateYearsFromDates();
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
      _updateYearsFromDates();
    }
  }

  Widget _leasePricingSummary(
    MarketingAccounting accounting, {
    double? leaseAmount,
  }) {
    const targetMargin = 0.15;
    final baseCost = accounting.stationCost + accounting.expenses;
    final suggested = baseCost == 0 ? 0 : baseCost * (1 + targetMargin);
    final effectiveLeaseAmount = leaseAmount ?? accounting.leaseAmount;
    final priceGap = effectiveLeaseAmount - accounting.stationCost;
    final expectedProfit = effectiveLeaseAmount - baseCost;
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = 0.4 + (_glowController.value * 0.6);
        final borderColor =
            AppColors.accentBlue.withOpacity(0.25 + (0.35 * glow));
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white,
                const Color(0xFFF6F7FB),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentBlue.withOpacity(0.12 + (0.2 * glow)),
                blurRadius: 18 + (10 * glow),
                spreadRadius: 1 + (1.5 * glow),
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.7),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_graph,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ملخص السعر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'تأجير المحطة',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _priceRow(
                'سعر استئجارك',
                '${accounting.stationCost.toStringAsFixed(2)} ر.س',
              ),
              const SizedBox(height: 8),
              _priceRow(
                'سعر تأجيرك للمستأجر',
                '${effectiveLeaseAmount.toStringAsFixed(2)} ر.س',
              ),
              const SizedBox(height: 8),
              _priceRow(
                'المصاريف',
                '${accounting.expenses.toStringAsFixed(2)} ر.س',
              ),
              const SizedBox(height: 8),
              _priceRow(
                'إجمالي التكلفة',
                '${baseCost.toStringAsFixed(2)} ر.س',
              ),
              const SizedBox(height: 8),
              _priceRow(
                'فرق السعر',
                '${priceGap.toStringAsFixed(2)} ر.س',
                valueColor:
                    priceGap >= 0 ? AppColors.successGreen : AppColors.errorRed,
              ),
              const SizedBox(height: 8),
              _priceRow(
                'الربح المتوقع',
                '${expectedProfit.toStringAsFixed(2)} ر.س',
                valueColor: expectedProfit >= 0
                    ? AppColors.successGreen
                    : AppColors.errorRed,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: AppColors.accentBlue,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'سعر مقترح (ربح 15%)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${suggested.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    Color valueColor = AppColors.darkGray,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1100
        ? 560.0
        : screenWidth > 900
            ? 520.0
            : screenWidth > 700
                ? 480.0
                : screenWidth > 520
                    ? 420.0
                    : 360.0;
    return AlertDialog(
      title: Text(widget.title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leasePricingSummary(
                  widget.accounting,
                  leaseAmount: _leaseAmountValue,
                ),
                const SizedBox(height: 12),
                _textField(
                  _leaseAmountController,
                  'سعر التأجير للمستأجر (ر.س)',
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _leaseAmountValue =
                          double.tryParse(value.trim()) ?? 0;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _textField(_nameController, 'اسم المستأجر'),
                const SizedBox(height: 8),
                _textField(_idController, 'رقم الهوية/الإقامة'),
                const SizedBox(height: 8),
                _textField(_phoneController, 'رقم الجوال'),
                const SizedBox(height: 8),
                _textField(_addressController, 'العنوان'),
                const SizedBox(height: 8),
                _textField(_notesController, 'ملاحظات', maxLines: 2),
                const SizedBox(height: 8),
                _textField(
                  _yearsController,
                  'مدة العقد (بالسنوات)',
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    final years =
                        int.tryParse(_yearsController.text.trim()) ?? 1;
                    setState(() {
                      _endDate = _startDate.add(Duration(days: 365 * years));
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 365));
                      }
                    });
                    _syncPaymentCountWithYears();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'بداية العقد: ${_startDate.toString().split(' ').first}',
                      ),
                    ),
                    TextButton(
                      onPressed: _pickStartDate,
                      child: const Text('تغيير'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'نهاية العقد: ${_endDate.toString().split(' ').first}',
                      ),
                    ),
                    TextButton(
                      onPressed: _pickEndDate,
                      child: const Text('تغيير'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'الدفعات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _paymentPlan,
                  items: _paymentPlanLabels.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentPlan = value);
                    if (_paymentPlan == 'custom') {
                      final count =
                          int.tryParse(_paymentCountController.text.trim()) ??
                              1;
                      setState(() => _setPaymentCount(count));
                    } else {
                      _syncPaymentCountWithYears();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'نوع الدفعات',
                  ),
                ),
                const SizedBox(height: 8),
                if (_paymentPlan == 'custom')
                  _textField(
                    _paymentCountController,
                    'عدد الدفعات',
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final count = int.tryParse(value.trim()) ?? 1;
                      setState(() => _setPaymentCount(count));
                    },
                  )
                else
                  Text(
                    'عدد الدفعات: $_paymentCount',
                    style: TextStyle(color: AppColors.mediumGray),
                  ),
                const SizedBox(height: 8),
                ...List.generate(_paymentCount, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _textField(
                      _paymentAmountControllers[index],
                      'مبلغ الدفعة ${index + 1} (ر.س)',
                      keyboardType: TextInputType.number,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('حفظ العقد'),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'مطلوب';
        }
        return null;
      },
    );
  }
}

class _ClosingReadingsDialog extends StatefulWidget {
  final List<MarketingPump> pumps;

  const _ClosingReadingsDialog({required this.pumps});

  @override
  State<_ClosingReadingsDialog> createState() => _ClosingReadingsDialogState();
}

class _ClosingReadingsDialogState extends State<_ClosingReadingsDialog> {
  late final List<List<TextEditingController>> _controllers;

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

  void _save() {
    final updated = <MarketingPump>[];
    for (var i = 0; i < widget.pumps.length; i++) {
      final pump = widget.pumps[i];
      if (pump.nozzles.isEmpty) {
        final value = double.tryParse(_controllers[i].first.text.trim());
        updated.add(
          pump.copyWith(
            closingReading: value,
            closingReadingDate: value == null ? null : DateTime.now(),
          ),
        );
        continue;
      }

      final updatedNozzles = <MarketingNozzle>[];
      for (var j = 0; j < pump.nozzles.length; j++) {
        final nozzle = pump.nozzles[j];
        final value = double.tryParse(_controllers[i][j].text.trim());
        updatedNozzles.add(
          nozzle.copyWith(closingReading: value),
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
                      TextField(
                        controller: _controllers[index].first,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'قراءة الإقفال',
                        ),
                      )
                    else
                      Column(
                        children: pump.nozzles.asMap().entries.map((nozzleEntry) {
                          final nozzleIndex = nozzleEntry.key;
                          final nozzle = nozzleEntry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'لي رقم ${nozzle.nozzleNumber} • ${_fuelTypeLabel(nozzle.fuelType)} • فتح: ${nozzle.openingReading.toStringAsFixed(2)}',
                                  style: TextStyle(color: AppColors.mediumGray),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _controllers[index][nozzleIndex],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'قراءة الإقفال',
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
