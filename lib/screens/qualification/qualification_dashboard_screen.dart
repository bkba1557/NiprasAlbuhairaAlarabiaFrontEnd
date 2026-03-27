import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class QualificationDashboardScreen extends StatefulWidget {
  const QualificationDashboardScreen({super.key});

  @override
  State<QualificationDashboardScreen> createState() =>
      _QualificationDashboardScreenState();
}

class _QualificationDashboardScreenState
    extends State<QualificationDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  QualificationStatus? _statusFilter;
  bool _isExportingCityReport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInspections());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspections() async {
    await context.read<QualificationProvider>().fetchStations(limit: 0);
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

  List<QualificationStation> _applyFilters(
    List<QualificationStation> stations,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return stations.where((station) {
      final matchesQuery =
          query.isEmpty ||
          station.name.toLowerCase().contains(query) ||
          station.city.toLowerCase().contains(query) ||
          station.region.toLowerCase().contains(query) ||
          station.address.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == null
          ? true
          : station.status == _statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
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

  String _normalizeCityName(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    normalized = normalized
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    return normalized;
  }

  bool _preferCityLabel(String candidate, String current) {
    final candidateHasTaMarbuta = candidate.contains('ة');
    final currentHasTaMarbuta = current.contains('ة');
    if (candidateHasTaMarbuta != currentHasTaMarbuta) {
      return candidateHasTaMarbuta;
    }

    final candidateIsArabic = RegExp(
      r'^[\u0600-\u06FF\s]+$',
    ).hasMatch(candidate);
    final currentIsArabic = RegExp(r'^[\u0600-\u06FF\s]+$').hasMatch(current);
    if (candidateIsArabic != currentIsArabic) {
      return candidateIsArabic;
    }

    return candidate.length < current.length;
  }

  String _stationLocationUrl(QualificationStation station) {
    final lat = station.location.lat.toStringAsFixed(6);
    final lng = station.location.lng.toStringAsFixed(6);
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  List<String> _availableCities(List<QualificationStation> stations) {
    final grouped = <String, String>{};
    for (final station in stations) {
      final city = station.city.trim();
      if (city.isEmpty) continue;
      final key = _normalizeCityName(city);
      if (key.isEmpty) continue;
      final current = grouped[key];
      if (current == null || _preferCityLabel(city, current)) {
        grouped[key] = city;
      }
    }

    final cities = grouped.values.toList()..sort((a, b) => a.compareTo(b));
    return cities;
  }

  List<QualificationStation> _stationsForCity(
    List<QualificationStation> stations,
    String city,
  ) {
    final normalizedCity = _normalizeCityName(city);
    return stations
        .where((station) => _normalizeCityName(station.city) == normalizedCity)
        .toList();
  }

  List<QualificationStation> _stationsForCities(
    List<QualificationStation> stations,
    Set<String> cities,
  ) {
    if (cities.isEmpty) return const [];
    final normalizedCities = cities
        .map(_normalizeCityName)
        .where((city) => city.isNotEmpty)
        .toSet();
    return stations
        .where(
          (station) =>
              normalizedCities.contains(_normalizeCityName(station.city)),
        )
        .toList();
  }

  List<String> _regionsForStations(List<QualificationStation> stations) {
    final regions =
        stations
            .map((station) => station.region.trim())
            .where((region) => region.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));
    return regions;
  }

  String _sanitizeFileNamePart(String value) {
    final compressedSpaces = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return compressedSpaces.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  }

  Future<void> _showCityReportSheet(List<QualificationStation> stations) async {
    if (_isExportingCityReport) return;

    final cities = _availableCities(stations);
    if (cities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مدن متاحة لإنشاء التقرير')),
      );
      return;
    }

    final cityStationCounts = <String, int>{
      for (final city in cities) city: _stationsForCity(stations, city).length,
    };
    final selectedCities = <String>{cities.first};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedCityLabels = cities
                .where((city) => selectedCities.contains(city))
                .toList();
            final selectedStations = _stationsForCities(
              stations,
              selectedCities,
            );
            final selectedRegions = _regionsForStations(selectedStations);
            final selectedCitiesText = selectedCityLabels.isEmpty
                ? '-'
                : selectedCityLabels.join('، ');

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تقرير المحطات حسب المدن',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: selectedCities.length == cities.length
                              ? null
                              : () {
                                  setModalState(() {
                                    selectedCities
                                      ..clear()
                                      ..addAll(cities);
                                  });
                                },
                          icon: const Icon(Icons.select_all, size: 18),
                          label: const Text('تحديد الكل'),
                        ),
                        TextButton.icon(
                          onPressed: selectedCities.isEmpty
                              ? null
                              : () {
                                  setModalState(() => selectedCities.clear());
                                },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('إلغاء الكل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: cities.length,
                        itemBuilder: (context, index) {
                          final city = cities[index];
                          final isSelected = selectedCities.contains(city);
                          final stationCount = cityStationCounts[city] ?? 0;
                          return CheckboxListTile(
                            value: isSelected,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(city),
                            subtitle: Text('عدد المحطات: $stationCount'),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedCities.add(city);
                                } else {
                                  selectedCities.remove(city);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('المدن المحددة: $selectedCitiesText'),
                    const SizedBox(height: 8),
                    Text(
                      'عدد المحطات داخل المدن المحددة: ${selectedStations.length}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedRegions.isEmpty
                          ? 'المناطق: -'
                          : 'المناطق: ${selectedRegions.join('، ')}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                selectedCities.isEmpty ||
                                    selectedStations.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(sheetContext);
                                    await _exportCityReport(
                                      selectedCityLabels,
                                      selectedStations,
                                      selectedRegions,
                                    );
                                  },
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('تصدير التقرير'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportCityReport(
    List<String> selectedCities,
    List<QualificationStation> selectedStations,
    List<String> selectedRegions,
  ) async {
    if (_isExportingCityReport) return;
    if (selectedStations.isEmpty) return;

    final citiesLabel = selectedCities.isEmpty
        ? '-'
        : selectedCities.join('، ');

    setState(() => _isExportingCityReport = true);
    try {
      final regularFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
      );
      final boldFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
      );
      final logoData = await rootBundle.load(AppImages.logo);
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);
      final exportedAt = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
      final pdf = pw.Document();

      String stationStatusLabel(QualificationStatus status) {
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

      String textOrDash(String? value) {
        final text = value?.trim() ?? '';
        return text.isEmpty ? '-' : text;
      }

      final sortedStations = List<QualificationStation>.from(selectedStations)
        ..sort((a, b) {
          final byRegion = a.region.compareTo(b.region);
          if (byRegion != 0) return byRegion;
          return a.name.compareTo(b.name);
        });

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.fromLTRB(20, 24, 20, 24),
            theme: theme,
            textDirection: pw.TextDirection.rtl,
          ),
          header: (context) => context.pageNumber == 1
              ? _buildCityReportPdfHeader(
                  logoImage: logoImage,
                  city: citiesLabel,
                  exportedAt: exportedAt,
                  stationsCount: sortedStations.length,
                  regions: selectedRegions,
                )
              : pw.SizedBox(),
          footer: (context) => context.pageNumber == context.pagesCount
              ? _buildCityReportPdfFooter(context)
              : pw.SizedBox(),
          build: (context) => [
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(20),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.0),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(0.9),
                5: pw.FlexColumnWidth(1.0),
                6: pw.FlexColumnWidth(0.9),
                7: pw.FlexColumnWidth(0.9),
                8: pw.FlexColumnWidth(0.95),
                9: pw.FlexColumnWidth(1.8),
                10: pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(AppColors.primaryBlue.toARGB32()),
                  ),
                  children: [
                    _pdfHeaderCell('#'),
                    _pdfHeaderCell('المحطة'),
                    _pdfHeaderCell('الحالة'),
                    _pdfHeaderCell('المنطقة'),
                    _pdfHeaderCell('المالك'),
                    _pdfHeaderCell('جوال المالك'),
                    _pdfHeaderCell('المسؤول'),
                    _pdfHeaderCell('موقع المحطة'),
                    _pdfHeaderCell('تاريخ الإدخال'),
                    _pdfHeaderCell('العنوان'),
                    _pdfHeaderCell('ملاحظات'),
                  ],
                ),
                ...List.generate(sortedStations.length, (index) {
                  final station = sortedStations[index];
                  final rowColor = index.isOdd
                      ? PdfColor.fromInt(0xFFF8FAFC)
                      : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowColor),
                    children: [
                      _pdfBodyCell('${index + 1}', align: pw.Alignment.center),
                      _pdfBodyCell(station.name),
                      _pdfBodyCell(
                        stationStatusLabel(station.status),
                        align: pw.Alignment.center,
                      ),
                      _pdfBodyCell(
                        textOrDash(station.region),
                        align: pw.Alignment.center,
                      ),
                      _pdfBodyCell(textOrDash(station.ownerName)),
                      _pdfBodyCell(
                        textOrDash(station.ownerPhone),
                        align: pw.Alignment.center,
                      ),
                      _pdfBodyCell(textOrDash(station.assignedTo?.name)),
                      _pdfLinkCell(
                        label: 'موقع',
                        url: _stationLocationUrl(station),
                      ),
                      _pdfBodyCell(
                        DateFormat('yyyy/MM/dd').format(station.createdAt),
                        align: pw.Alignment.center,
                      ),
                      _pdfBodyCell(textOrDash(station.address)),
                      _pdfBodyCell(textOrDash(station.notes)),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final datePart = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final cityPart = selectedCities.length == 1
          ? _sanitizeFileNamePart(selectedCities.first)
          : 'multi_cities';
      final fileName = 'qualification_stations_${cityPart}_$datePart.pdf';

      try {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } catch (_) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      }

      if (!mounted) return;
      final successMessage = selectedCities.length == 1
          ? 'تم تصدير تقرير مدينة ${selectedCities.first}'
          : 'تم تصدير تقرير ${selectedCities.length} مدن';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تصدير التقرير: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingCityReport = false);
      }
    }
  }

  pw.Widget _buildCityReportPdfHeader({
    required pw.MemoryImage logoImage,
    required String city,
    required String exportedAt,
    required int stationsCount,
    required List<String> regions,
  }) {
    final regionsText = regions.isEmpty ? '-' : regions.join('، ');
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      'شركة البحيرة العربية للنقليات',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'الرقم الوطني الموحد: 7011144750',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.SizedBox(
                width: 68,
                height: 68,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF1F5F9),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor.fromInt(0xFFD1D9E6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تقرير محطات - المدن: $city',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(AppColors.primaryBlue.toARGB32()),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'عدد المحطات: $stationsCount    |    تاريخ التصدير: $exportedAt',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'المناطق: $regionsText',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCityReportPdfFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'نظام نبراس | شركة البحيرة العربية',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'المنطقة الصناعية - شركة البحيرة العربية للنقليات، '
          'المملكة العربية السعودية - منطقة حائل - حائل',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7.5),
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8.2,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _pdfBodyCell(
    String text, {
    pw.Alignment align = pw.Alignment.centerRight,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text.trim().isEmpty ? '-' : text,
        style: const pw.TextStyle(fontSize: 7.4),
        textAlign: align == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.right,
      ),
    );
  }

  pw.Widget _pdfLinkCell({required String label, required String url}) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.UrlLink(
        destination: url,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.4,
            color: PdfColors.blue700,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  InputDecoration _surfaceInputDecoration({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required bool compact,
    required int totalStations,
  }) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 18 : 24),
            decoration: const BoxDecoration(
              gradient: AppColors.appBarGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'لوحة التأهيل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة مواقع المحطات تحت الدراسة والتفاوض والاتفاق داخل لوحة موحدة ومتجاوبة.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHeaderActions(context, compact: true),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'لوحة التأهيل',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'إدارة مواقع المحطات تحت الدراسة والتفاوض والاتفاق داخل لوحة موحدة ومتجاوبة.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.84),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      _buildHeaderActions(context, compact: false),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildHeroChip(
                  icon: Icons.location_city_outlined,
                  label: '$totalStations محطة مسجلة',
                  color: AppColors.primaryBlue,
                ),
                _buildHeroChip(
                  icon: Icons.filter_alt_outlined,
                  label: _statusFilter == null
                      ? 'عرض كل الحالات'
                      : 'فلتر: ${_statusLabel(_statusFilter!)}',
                  color: AppColors.secondaryTeal,
                ),
                _buildHeroChip(
                  icon: Icons.search_rounded,
                  label: _searchController.text.trim().isEmpty
                      ? 'البحث غير مفعّل'
                      : 'البحث: ${_searchController.text.trim()}',
                  color: AppColors.warningOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
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

  Widget _buildStatCard(
    String label,
    int value,
    Color color, {
    required IconData icon,
    bool compact = false,
  }) {
    return AppSurfaceCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  value.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderActions(BuildContext context, {required bool compact}) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.qualificationForm);
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة محطة جديدة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.qualificationMap);
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('عرض المحطات على الخريطة'),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.qualificationMap);
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('عرض المحطات على الخريطة'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.qualificationForm);
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة محطة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFilterChips() {
    return [
      FilterChip(
        label: const Text('الكل'),
        selected: _statusFilter == null,
        onSelected: (_) => setState(() => _statusFilter = null),
      ),
      FilterChip(
        label: const Text('تحت الدراسة'),
        selected: _statusFilter == QualificationStatus.underReview,
        onSelected: (_) =>
            setState(() => _statusFilter = QualificationStatus.underReview),
      ),
      FilterChip(
        label: const Text('جاري التفاوض'),
        selected: _statusFilter == QualificationStatus.negotiating,
        onSelected: (_) =>
            setState(() => _statusFilter = QualificationStatus.negotiating),
      ),
      FilterChip(
        label: const Text('تم الاتفاق'),
        selected: _statusFilter == QualificationStatus.agreed,
        onSelected: (_) =>
            setState(() => _statusFilter = QualificationStatus.agreed),
      ),
      FilterChip(
        label: const Text('لم يتم الاتفاق'),
        selected: _statusFilter == QualificationStatus.notAgreed,
        onSelected: (_) =>
            setState(() => _statusFilter = QualificationStatus.notAgreed),
      ),
    ];
  }

  Widget _buildFilters({required bool compact}) {
    final chips = _buildFilterChips();
    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: chip,
                ),
              )
              .toList(),
        ),
      );
    }

    return Wrap(spacing: 8, children: chips);
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'ابحث عن محطة',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildStationCard(QualificationStation station) {
    final statusLabel = _statusLabel(station.status);
    final statusColor = _statusColor(station.status);
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<QualificationStatus>(
                  tooltip: 'تغيير الحالة',
                  onSelected: (value) => _showStatusUpdateSheet(station, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: QualificationStatus.underReview,
                      child: Text('تحت الدراسة'),
                    ),
                    PopupMenuItem(
                      value: QualificationStatus.negotiating,
                      child: Text('جاري التفاوض'),
                    ),
                    PopupMenuItem(
                      value: QualificationStatus.agreed,
                      child: Text('تم الاتفاق'),
                    ),
                    PopupMenuItem(
                      value: QualificationStatus.notAgreed,
                      child: Text('لم يتم الاتفاق'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          station.status == QualificationStatus.agreed
                              ? Icons.verified_outlined
                              : station.status == QualificationStatus.notAgreed
                              ? Icons.cancel_outlined
                              : Icons.info_outline,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${station.city} • ${station.region}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (station.address.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                station.address,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            if (station.status == QualificationStatus.negotiating &&
                (station.assignedTo?.name ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'المسؤول: ${station.assignedTo?.name}',
                style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
              ),
            ],
            ...[
              const SizedBox(height: 6),
              Text(
                'الموقع: ${station.location.lat.toStringAsFixed(5)}, '
                '${station.location.lng.toStringAsFixed(5)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.qualificationDetails,
                    arguments: station,
                  );
                },
                child: const Text('عرض التفاصيل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeroCard(
    BuildContext context, {
    required bool compact,
    required int totalStations,
    required bool reportDisabled,
    required VoidCallback onExportCityReport,
  }) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 18 : 24),
            decoration: const BoxDecoration(
              gradient: AppColors.appBarGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'لوحة التأهيل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة مواقع المحطات تحت الدراسة والتفاوض والاتفاق داخل لوحة موحدة وسريعة الوصول.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModernHeaderActions(
                        context,
                        compact: true,
                        reportDisabled: reportDisabled,
                        onExportCityReport: onExportCityReport,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'لوحة التأهيل',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'إدارة مواقع المحطات تحت الدراسة والتفاوض والاتفاق داخل لوحة موحدة وسريعة الوصول.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.84),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      _buildModernHeaderActions(
                        context,
                        compact: false,
                        reportDisabled: reportDisabled,
                        onExportCityReport: onExportCityReport,
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildHeroChip(
                  icon: Icons.location_city_outlined,
                  label: '$totalStations محطة مسجلة',
                  color: AppColors.primaryBlue,
                ),
                _buildHeroChip(
                  icon: Icons.filter_alt_outlined,
                  label: _statusFilter == null
                      ? 'عرض كل الحالات'
                      : 'فلتر: ${_statusLabel(_statusFilter!)}',
                  color: AppColors.secondaryTeal,
                ),
                _buildHeroChip(
                  icon: Icons.search_rounded,
                  label: _searchController.text.trim().isEmpty
                      ? 'البحث غير مفعّل'
                      : 'البحث: ${_searchController.text.trim()}',
                  color: AppColors.warningOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _buildStatusIcon(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return Icons.hourglass_top_rounded;
      case QualificationStatus.negotiating:
        return Icons.handshake_outlined;
      case QualificationStatus.agreed:
        return Icons.verified_rounded;
      case QualificationStatus.notAgreed:
        return Icons.block_rounded;
    }
  }

  Widget _buildModernHeaderActions(
    BuildContext context, {
    required bool compact,
    required bool reportDisabled,
    required VoidCallback onExportCityReport,
  }) {
    final reportButton = FilledButton.tonalIcon(
      onPressed: reportDisabled ? null : onExportCityReport,
      icon: _isExportingCityReport
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.assessment_outlined),
      label: const Text('تقرير المدن'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );

    final mapButton = OutlinedButton.icon(
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.qualificationMap);
      },
      icon: const Icon(Icons.map_outlined),
      label: const Text('عرض الخريطة'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.40)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );

    final addButton = FilledButton.icon(
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.qualificationForm);
      },
      icon: const Icon(Icons.add_rounded),
      label: const Text('إضافة محطة جديدة'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          addButton,
          const SizedBox(height: 8),
          mapButton,
          const SizedBox(height: 8),
          reportButton,
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [reportButton, mapButton, addButton],
    );
  }

  Widget _buildModernFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? color : AppColors.darkGray,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      selectedColor: color.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.34) : AppColors.silverLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onSelected: (_) => onTap(),
    );
  }

  List<Widget> _buildModernFilterChips() {
    return [
      _buildModernFilterChip(
        label: 'الكل',
        selected: _statusFilter == null,
        color: AppColors.primaryBlue,
        onTap: () => setState(() => _statusFilter = null),
      ),
      _buildModernFilterChip(
        label: 'تحت الدراسة',
        selected: _statusFilter == QualificationStatus.underReview,
        color: Colors.amber.shade700,
        onTap: () =>
            setState(() => _statusFilter = QualificationStatus.underReview),
      ),
      _buildModernFilterChip(
        label: 'جاري التفاوض',
        selected: _statusFilter == QualificationStatus.negotiating,
        color: Colors.blue.shade700,
        onTap: () =>
            setState(() => _statusFilter = QualificationStatus.negotiating),
      ),
      _buildModernFilterChip(
        label: 'تم الاتفاق',
        selected: _statusFilter == QualificationStatus.agreed,
        color: AppColors.successGreen,
        onTap: () => setState(() => _statusFilter = QualificationStatus.agreed),
      ),
      _buildModernFilterChip(
        label: 'لم يتم الاتفاق',
        selected: _statusFilter == QualificationStatus.notAgreed,
        color: AppColors.errorRed,
        onTap: () =>
            setState(() => _statusFilter = QualificationStatus.notAgreed),
      ),
    ];
  }

  Widget _buildModernFilters({required bool compact}) {
    final chips = _buildModernFilterChips();
    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map(
                (chip) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: chip,
                ),
              )
              .toList(),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildModernSearchField() {
    return TextField(
      controller: _searchController,
      decoration: _surfaceInputDecoration(
        hintText: 'ابحث عن اسم المحطة أو المدينة أو المنطقة',
        labelText: 'البحث',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildModernStationCard(
    QualificationStation station, {
    required bool compact,
  }) {
    final statusLabel = _statusLabel(station.status);
    final statusColor = _statusColor(station.status);
    final ownerName = station.ownerName?.trim() ?? '';
    final ownerPhone = station.ownerPhone?.trim() ?? '';
    final assigneeName = station.assignedTo?.name?.trim() ?? '';
    final notes = station.notes?.trim() ?? '';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${station.city} • ${station.region}',
                    style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<QualificationStatus>(
                tooltip: 'تغيير الحالة',
                onSelected: (value) => _showStatusUpdateSheet(station, value),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: QualificationStatus.underReview,
                    child: Text('تحت الدراسة'),
                  ),
                  PopupMenuItem(
                    value: QualificationStatus.negotiating,
                    child: Text('جاري التفاوض'),
                  ),
                  PopupMenuItem(
                    value: QualificationStatus.agreed,
                    child: Text('تم الاتفاق'),
                  ),
                  PopupMenuItem(
                    value: QualificationStatus.notAgreed,
                    child: Text('لم يتم الاتفاق'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _buildStatusIcon(station.status),
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_arrow_down_rounded, color: statusColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip(
                icon: Icons.pin_drop_outlined,
                label:
                    '${station.location.lat.toStringAsFixed(5)}, ${station.location.lng.toStringAsFixed(5)}',
                color: AppColors.primaryBlue,
              ),
              _buildHeroChip(
                icon: Icons.calendar_month_outlined,
                label: DateFormat('yyyy/MM/dd').format(station.createdAt),
                color: AppColors.secondaryTeal,
              ),
              if (station.attachments.isNotEmpty)
                _buildHeroChip(
                  icon: Icons.attach_file_rounded,
                  label: '${station.attachments.length} مرفق',
                  color: AppColors.warningOrange,
                ),
              if (assigneeName.isNotEmpty)
                _buildHeroChip(
                  icon: Icons.person_pin_circle_outlined,
                  label: 'المسؤول: $assigneeName',
                  color: Colors.blue.shade700,
                ),
            ],
          ),
          if (station.address.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.silverLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primaryBlue.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      station.address,
                      style: const TextStyle(
                        height: 1.6,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.warningOrange.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    color: AppColors.warningOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (ownerName.isNotEmpty || ownerPhone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                if (ownerName.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: AppColors.mediumGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGray,
                        ),
                      ),
                    ],
                  ),
                if (ownerPhone.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 18,
                        color: AppColors.mediumGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ownerPhone,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGray,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.qualificationDetails,
                      arguments: station,
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('عرض التفاصيل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(
                      color: AppColors.primaryBlue.withValues(alpha: 0.18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              if (!compact) const SizedBox(width: 12),
              if (compact) const SizedBox(height: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showStatusUpdateSheet(station, station.status),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('إدارة الحالة'),
                  style: FilledButton.styleFrom(
                    foregroundColor: statusColor,
                    backgroundColor: statusColor.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGray,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildModernEmptyState() {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              size: 38,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'لا توجد محطات مطابقة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'جرّب تعديل كلمات البحث أو تغيير الفلتر لعرض مواقع أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mediumGray, height: 1.6),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QualificationProvider>();
    final inspections = provider.stations;
    final filtered = _applyFilters(inspections);
    final underReviewCount = inspections
        .where((station) => station.status == QualificationStatus.underReview)
        .length;
    final negotiatingCount = inspections
        .where((station) => station.status == QualificationStatus.negotiating)
        .length;
    final agreedCount = inspections
        .where((station) => station.status == QualificationStatus.agreed)
        .length;
    final notAgreedCount = inspections
        .where((station) => station.status == QualificationStatus.notAgreed)
        .length;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 241, 241),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: const Text('مواقع تحت الدراسة في أنحاء المملكة'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.qualificationForm);
        },
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة محطة'),
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isCompact = width < 760;

          int statsColumns = 1;
          if (isCompact) {
            statsColumns = 3;
          } else if (width >= 1340) {
            statsColumns = 5;
          } else if (width >= 1080) {
            statsColumns = 3;
          } else if (width >= 680) {
            statsColumns = 2;
          }

          final statsAspectRatio = isCompact
              ? 1.0
              : statsColumns == 1
                  ? 2.5
                  : statsColumns == 2
                      ? 2.0
                      : 2.35;

          return RefreshIndicator(
            onRefresh: _loadInspections,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 14 : 20,
                isCompact ? 14 : 20,
                isCompact ? 14 : 20,
                110,
              ),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: _buildModernHeroCard(
                      context,
                      compact: isCompact,
                      totalStations: inspections.length,
                      reportDisabled:
                          provider.isLoading || _isExportingCityReport,
                      onExportCityReport: () =>
                          _showCityReportSheet(inspections),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: statsColumns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: statsAspectRatio,
                  children: [
                    _buildStatCard(
                      'إجمالي المحطات',
                      inspections.length,
                      AppColors.primaryBlue,
                      icon: Icons.local_gas_station_rounded,
                      compact: isCompact,
                    ),
                    _buildStatCard(
                      'تحت الدراسة',
                      underReviewCount,
                      Colors.amber.shade700,
                      icon: Icons.hourglass_top_rounded,
                      compact: isCompact,
                    ),
                    _buildStatCard(
                      'جاري التفاوض',
                      negotiatingCount,
                      Colors.blue.shade700,
                      icon: Icons.handshake_outlined,
                      compact: isCompact,
                    ),
                    _buildStatCard(
                      'تم الاتفاق',
                      agreedCount,
                      AppColors.successGreen,
                      icon: Icons.verified_rounded,
                      compact: isCompact,
                    ),
                    _buildStatCard(
                      'لم يتم الاتفاق',
                      notAgreedCount,
                      AppColors.errorRed,
                      icon: Icons.block_rounded,
                      compact: isCompact,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildModernSectionCard(
                  title: 'البحث والتصفية',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${filtered.length} نتيجة',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernSearchField(),
                      const SizedBox(height: 14),
                      _buildModernFilters(compact: isCompact),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (provider.error != null &&
                    provider.error!.trim().isNotEmpty) ...[
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
                  const SizedBox(height: 18),
                ],
                if (provider.isLoading)
                  const AppSurfaceCard(
                    padding: EdgeInsets.symmetric(vertical: 46),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  _buildModernEmptyState()
                else
                  Column(
                    children: [
                      ...filtered.map(
                        (station) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildModernStationCard(
                            station,
                            compact: isCompact,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
            },
          ),
        ],
      ),
    );
  }
}
