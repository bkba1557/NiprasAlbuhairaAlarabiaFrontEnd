import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import 'package:order_tracker/providers/marketing_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';

import 'marketing_handover_pdf.dart';
import 'marketing_models.dart';

class MarketingHandoverReportScreen extends StatefulWidget {
  final MarketingStation station;

  const MarketingHandoverReportScreen({super.key, required this.station});

  @override
  State<MarketingHandoverReportScreen> createState() =>
      _MarketingHandoverReportScreenState();
}

class _MarketingHandoverReportScreenState
    extends State<MarketingHandoverReportScreen> {
  late MarketingStation _station;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _station = widget.station;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAutoFields();
    });
  }

  Future<void> _ensureAutoFields() async {
    final report = _station.handoverReport ?? HandoverReport.empty();
    final autoReportNumber =
        report.reportNumber.trim().isEmpty ? _generateReportNumber() : null;
    final autoReference = report.contractReference.trim().isEmpty
        ? _generateContractReference()
        : null;

    if (autoReportNumber == null && autoReference == null) {
      return;
    }

    final updatedReport = report.copyWith(
      reportNumber: autoReportNumber ?? report.reportNumber,
      contractReference: autoReference ?? report.contractReference,
    );

    final updatedStation =
        _station.copyWith(handoverReport: updatedReport);

    setState(() {
      _saving = true;
      _station = updatedStation;
    });

    await context.read<MarketingStationProvider>().updateStation(updatedStation);
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  String _generateReportNumber() {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final suffix = _station.id.length >= 4
        ? _station.id.substring(_station.id.length - 4).toUpperCase()
        : _station.id.toUpperCase();
    return 'MR-$date-$suffix';
  }

  String _generateContractReference() {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final suffix = _station.id.length >= 6
        ? _station.id.substring(_station.id.length - 6).toUpperCase()
        : _station.id.toUpperCase();
    return 'REF-$date-$suffix';
  }

  Future<void> _printReport() async {
    final bytes = await buildMarketingHandoverPdf(_station);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _downloadReport() async {
    final bytes = await buildMarketingHandoverPdf(_station);
    final safeName = _station.name.replaceAll(' ', '_');
    await saveAndLaunchFile(bytes, 'محضر_استلام_$safeName.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final report = _station.handoverReport ?? HandoverReport.empty();
    final stationName = report.stationName.trim().isNotEmpty
        ? report.stationName
        : _station.name;
    final city = report.city.trim().isNotEmpty ? report.city : _station.city;
    final street =
        report.street.trim().isNotEmpty ? report.street : _station.address;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('محضر استلام محطة محروقات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _printReport,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadReport,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم المحضر: ${_reportValue(report.reportNumber)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'مرجع العقد: ${_reportValue(report.contractReference)}',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paragraph),
                    const SizedBox(height: 12),
                    Text(
                      'يوجد بالمحطة عدد (${_reportValue(report.dispensersCount)}) طرمبة تموين سيارات '
                      'منها (${_reportValue(report.doubleDispensersCount)}) مزدوج.',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1) طرمبات الوقود',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    Text(
                      '2) الخزانات',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    Text(
                      '3) الطرمبات الغاطسة',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    Text(
                      '4) المعدات',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                  ],
                ),
              ),
            ],
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.white70,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
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
}
