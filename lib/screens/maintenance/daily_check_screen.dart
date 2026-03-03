import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DailyCheckScreen extends StatefulWidget {
  final Map<String, dynamic> args;

  const DailyCheckScreen({super.key, required this.args});

  @override
  State<DailyCheckScreen> createState() => _DailyCheckScreenState();
}

class _DailyCheckScreenState extends State<DailyCheckScreen> {
  final _formKey = GlobalKey<FormState>();

  String _vehicleSafety = 'لم يتم';
  String _driverSafety = 'لم يتم';
  String _electricalMaintenance = 'لم يتم';
  String _mechanicalMaintenance = 'لم يتم';
  String _tankInspection = 'لم يتم';
  String _tiresInspection = 'لم يتم';
  String _brakesInspection = 'لم يتم';
  String _lightsInspection = 'لم يتم';
  String _fluidsCheck = 'لم يتم';
  String _emergencyEquipment = 'لم يتم';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _maintenanceTypeController =
      TextEditingController();
  final TextEditingController _maintenanceCostController =
      TextEditingController();

  String _inspectionResult = 'تم الفحص ولا يوجد ملاحظات';
  final List<Map<String, TextEditingController>> _invoiceControllers = [];
  bool _isSubmitting = false;
  late final bool isViewMode;
  bool _isExporting = false;
  bool _isExportDialogVisible = false;
  Timer? _exportTimer;
  Duration _exportElapsed = Duration.zero;

  final List<String> _options = ['تم', 'لم يتم', 'غير مطلوب'];
  final List<String> _inspectionOptions = [
    'تحتاج صيانة',
    'لا تحتاج صيانة',
    'تم الفحص ولا يوجد ملاحظات',
  ];
  final TextEditingController _odometerController = TextEditingController();
  bool _oilChangedToday = false;

  @override
  void initState() {
    super.initState();
    isViewMode = widget.args['mode'] == 'view';
    _loadExistingData();
    _normalizeDropdownValues();
  }

  @override
  void dispose() {
    _exportTimer?.cancel();
    _odometerController.dispose();

    _notesController.dispose();
    _maintenanceTypeController.dispose();
    _maintenanceCostController.dispose();
    for (final pair in _invoiceControllers) {
      pair['title']?.dispose();
      pair['url']?.dispose();
    }
    super.dispose();
  }

  void _addInvoiceRow() {
    if (!mounted) return;
    setState(() {
      _invoiceControllers.add({
        'title': TextEditingController(),
        'url': TextEditingController(),
      });
    });
  }

  

  void _loadExistingData() {
    final String mode = widget.args['mode'] ?? 'edit';

    // ✅ تحويل آمن للـ dailyCheck
    final Map<String, dynamic> dailyCheck = Map<String, dynamic>.from(
      widget.args['dailyCheck'] ?? {},
    );

    // =============================
    // 👀 VIEW MODE (عرض فقط)
    // =============================
    if (mode == 'view' && dailyCheck.isNotEmpty) {
      _odometerController.text =
          dailyCheck['odometerReading']?.toString() ?? '';

      _oilChangedToday = dailyCheck['oilChanged'] ?? false;

      _vehicleSafety = dailyCheck['vehicleSafety'] ?? 'لم يتم';
      _driverSafety = dailyCheck['driverSafety'] ?? 'لم يتم';
      _electricalMaintenance = dailyCheck['electricalMaintenance'] ?? 'لم يتم';
      _mechanicalMaintenance = dailyCheck['mechanicalMaintenance'] ?? 'لم يتم';
      _tankInspection = dailyCheck['tankInspection'] ?? 'لم يتم';
      _tiresInspection = dailyCheck['tiresInspection'] ?? 'لم يتم';
      _brakesInspection = dailyCheck['brakesInspection'] ?? 'لم يتم';
      _lightsInspection = dailyCheck['lightsInspection'] ?? 'لم يتم';
      _fluidsCheck = dailyCheck['fluidsCheck'] ?? 'لم يتم';
      _emergencyEquipment = dailyCheck['emergencyEquipment'] ?? 'لم يتم';

      _inspectionResult = dailyCheck['inspectionResult'] ?? _inspectionResult;

      _notesController.text = dailyCheck['notes'] ?? '';
      _maintenanceTypeController.text = dailyCheck['maintenanceType'] ?? '';
      _maintenanceCostController.text =
          dailyCheck['maintenanceCost']?.toString() ?? '';

      final List<dynamic> invoices =
          dailyCheck['maintenanceInvoices'] as List<dynamic>? ?? [];

      for (final invoice in invoices) {
        _invoiceControllers.add({
          'title': TextEditingController(
            text: invoice['title']?.toString() ?? '',
          ),
          'url': TextEditingController(text: invoice['url']?.toString() ?? ''),
        });
      }
    }

    // =============================
    // ✨ ضمان سلامة القيم للـ Dropdown
    // =============================
    _normalizeDropdownValues();

    if (mounted) {
      setState(() {});
    }
  }

  void _normalizeDropdownValues() {
    const defaultCheck = 'لم يتم';

    if (!_options.contains(_vehicleSafety)) {
      _vehicleSafety = defaultCheck;
    }
    if (!_options.contains(_driverSafety)) {
      _driverSafety = defaultCheck;
    }
    if (!_options.contains(_electricalMaintenance)) {
      _electricalMaintenance = defaultCheck;
    }
    if (!_options.contains(_mechanicalMaintenance)) {
      _mechanicalMaintenance = defaultCheck;
    }
    if (!_options.contains(_tankInspection)) {
      _tankInspection = defaultCheck;
    }
    if (!_options.contains(_tiresInspection)) {
      _tiresInspection = defaultCheck;
    }
    if (!_options.contains(_brakesInspection)) {
      _brakesInspection = defaultCheck;
    }
    if (!_options.contains(_lightsInspection)) {
      _lightsInspection = defaultCheck;
    }
    if (!_options.contains(_fluidsCheck)) {
      _fluidsCheck = defaultCheck;
    }
    if (!_options.contains(_emergencyEquipment)) {
      _emergencyEquipment = defaultCheck;
    }

    if (!_inspectionOptions.contains(_inspectionResult)) {
      _inspectionResult = _inspectionOptions.last;
    }
  }

  void _removeInvoiceRow(int index) {
    if (!mounted) return;
    if (index < 0 || index >= _invoiceControllers.length) return;
    setState(() {
      _invoiceControllers[index]['title']?.dispose();
      _invoiceControllers[index]['url']?.dispose();
      _invoiceControllers.removeAt(index);
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startExportDialog() {
    if (!mounted || _isExportDialogVisible) return;
    _isExportDialogVisible = true;
    _exportElapsed = Duration.zero;
    _exportTimer?.cancel();
    _exportTimer = null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (_exportTimer == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _exportTimer = Timer.periodic(
                  const Duration(milliseconds: 200),
                  (_) {
                    if (!mounted) return;
                    setStateDialog(() {
                      _exportElapsed += const Duration(milliseconds: 200);
                    });
                  },
                );
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'جارٍ تجهيز ملف PDF...',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الوقت المنقضي: ${_formatDuration(_exportElapsed)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _isExportDialogVisible = false;
    });
  }

  void _stopExportDialog() {
    _exportTimer?.cancel();
    _exportTimer = null;
    if (_isExportDialogVisible && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  String _resolveMaintenanceStatusText() {
    final dailyCheck = widget.args['dailyCheck'] as Map<String, dynamic>?;
    final raw = (dailyCheck?['status'] ??
            widget.args['status'] ??
            widget.args['maintenanceStatus'] ??
            widget.args['approvalStatus'] ??
            '')
        .toString()
        .trim();

    if (raw.isEmpty) return '';
    if (raw.contains('قيد')) return 'قيد المراجعة';
    if (raw.contains('مقبول')) return 'مقبولة';
    if (raw.contains('مرفوض')) return 'مرفوضة';

    final lower = raw.toLowerCase();
    if (lower.contains('pending')) return 'قيد المراجعة';
    if (lower.contains('approved') || lower.contains('accepted')) {
      return 'مقبولة';
    }
    if (lower.contains('rejected') || lower.contains('declined')) {
      return 'مرفوضة';
    }

    return raw;
  }

  PdfColor _statusWatermarkColor(String statusText) {
    if (statusText == 'مقبولة') return PdfColors.green;
    if (statusText == 'مرفوضة') return PdfColors.red;
    if (statusText == 'قيد المراجعة') return PdfColors.orange;
    return PdfColors.grey600;
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    _startExportDialog();

    try {
    // ===============================
    // 🔹 تحميل الخط العربي (مرة واحدة)
    // ===============================
    final arabicFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );

    // ===============================
    // 🔹 تحميل الشعار
    // ===============================
    final logoData = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final dailyCheck = widget.args['dailyCheck'] as Map<String, dynamic>?;
    final checkDate = widget.args['date'] as DateTime? ?? DateTime.now();
    final headerInfo = <String, dynamic>{};
    if (dailyCheck != null) {
      headerInfo.addAll(dailyCheck);
    }
    headerInfo['plateNumber'] ??= widget.args['plateNumber'];
    headerInfo['driverName'] ??= widget.args['driverName'];

    final statusText = _resolveMaintenanceStatusText();
    final watermarkColor = _statusWatermarkColor(statusText);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
          textDirection: pw.TextDirection.rtl,
          buildBackground: (context) {
            if (statusText.isEmpty) return pw.SizedBox();
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.18,
                      child: pw.Transform.rotate(
                        angle: -0.35,
                        child: pw.Text(
                          statusText,
                          style: pw.TextStyle(
                            fontSize: 64,
                            fontWeight: pw.FontWeight.bold,
                            color: watermarkColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        header: (context) {
          return _buildPdfHeader(logoImage, headerInfo, checkDate);
        },
        footer: (context) {
          return pw.Column(
            children: [
              _buildPdfFooter(
                maintenanceOfficerName:
                    widget.args['maintenanceOfficerName'] ?? 'مسؤول الصيانة',
              ),
              pw.SizedBox(height: 5),
              _buildPdfBottomDividerWithAddress(),
            ],
          );
        },
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildPdfTable(),
        ],
      ),
    );

    // ===============================
    // 🔹 تصدير / تحميل
    // ===============================
    final bytes = await pdf.save();
    final formattedDate = DateFormat('yyyyMMdd').format(checkDate);
    final plate = (headerInfo['plateNumber'] ?? '').toString().trim();
    final safePlate = plate.isEmpty ? 'vehicle' : plate;
    final fileName = 'daily_check_${safePlate}_$formattedDate.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التصدير: $e')),
      );
    }
    } finally {
      _stopExportDialog();
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _submitCheck() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final provider = Provider.of<MaintenanceProvider>(context, listen: false);

    final checkData = {
      'date': widget.args['date'].toIso8601String(),
      'vehicleSafety': _vehicleSafety,
      'driverSafety': _driverSafety,
      'odometerReading': int.tryParse(_odometerController.text),
      'oilChanged': _oilChangedToday,
      'electricalMaintenance': _electricalMaintenance,
      'mechanicalMaintenance': _mechanicalMaintenance,
      'tankInspection': _tankInspection,
      'tiresInspection': _tiresInspection,
      'brakesInspection': _brakesInspection,
      'lightsInspection': _lightsInspection,
      'fluidsCheck': _fluidsCheck,
      'emergencyEquipment': _emergencyEquipment,
      'notes': _notesController.text.trim(),
      'inspectionResult': _inspectionResult,
      'maintenanceType': _maintenanceTypeController.text.trim(),
      'maintenanceCost': double.tryParse(
        _maintenanceCostController.text.trim(),
      ),
      'maintenanceInvoices': _invoiceControllers
          .map(
            (pair) => {
              'title': pair['title']?.text.trim() ?? '',
              'url': pair['url']?.text.trim() ?? '',
            },
          )
          .where(
            (invoice) =>
                invoice['title']!.isNotEmpty || invoice['url']!.isNotEmpty,
          )
          .toList(),
    };

    try {
      await provider.addDailyCheck(widget.args['maintenanceId'], checkData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الفحص للمراجعة'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

pw.Widget buildArabicInfoTable({required List<Map<String, String>> rows}) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.2),
      },
      children: rows.map((row) {
        return pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 6,
              ),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                row['value'] ?? '-',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 6,
              ),
              alignment: pw.Alignment.centerRight,
              color: PdfColors.grey200,
              child: pw.Text(
                row['label'] ?? '',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }




pw.Widget _buildPdfHeader(
    pw.MemoryImage logoImage,
    Map<String, dynamic> record,
    DateTime checkDate,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(checkDate);

    final plateNumber = record['plateNumber']?.toString() ?? '-';
    final driverName = record['driverName']?.toString() ?? '-';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // =========================
            // 📄 Text Section
            // =========================
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'شركة البحيرة العربية للنقليات',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'الرقم الوطني الموحد: 7011144750',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Divider(color: PdfColors.grey400, height: 1),
                  pw.SizedBox(height: 5),

                  // ===== Title =====
                  pw.Text(
                    'إذن صيانة للمركبة',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),

                  // ===== Vehicle & Driver =====
                  pw.Text(
                    'رقم المركبة (اللوحة): $plateNumber',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    'اسم السائق: $driverName',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.SizedBox(height: 2),

                  // ===== Date =====
                  pw.Text(
                    'التاريخ: $date',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 8),

            // =========================
            // 🖼️ Logo
            // =========================
            pw.Container(
              width: 90,
              height: 90,
              alignment: pw.Alignment.center,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }


// pw.Widget _buildPdfTable() {
//   return pw.SizedBox.shrink();
// }

pw.Widget _buildPdfTable() {
    List<Map<String, String>> rows = [
      {'label': 'قراءة العداد', 'value': _odometerController.text},
      {'label': 'تغيير الزيت', 'value': _oilChangedToday ? 'نعم' : 'لا'},
      {'label': 'نتيجة الفحص', 'value': _inspectionResult},
      {'label': 'سلامة المركبة', 'value': _vehicleSafety},
      {'label': 'سلامة السائق', 'value': _driverSafety},
      {'label': 'صيانة كهرباء', 'value': _electricalMaintenance},
      {'label': 'صيانة ميكانيكا', 'value': _mechanicalMaintenance},
      {'label': 'فحص التانكي', 'value': _tankInspection},
      {'label': 'فحص الإطارات', 'value': _tiresInspection},
      {'label': 'فحص الفرامل', 'value': _brakesInspection},
      {'label': 'فحص الأضواء', 'value': _lightsInspection},
      {'label': 'فحص السوائل', 'value': _fluidsCheck},
      {'label': 'معدات الطوارئ', 'value': _emergencyEquipment},
    ];

    if (_inspectionResult == 'تحتاج صيانة') {
      rows.addAll([
        {'label': 'نوع الصيانة', 'value': _maintenanceTypeController.text},
        {'label': 'تكلفة الصيانة', 'value': _maintenanceCostController.text},
      ]);
    }

    if (_notesController.text.trim().isNotEmpty) {
      rows.add({'label': 'ملاحظات', 'value': _notesController.text.trim()});
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey400),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1.3),
        },
        children: rows.map((row) {
          return pw.TableRow(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  row['value']!.isNotEmpty ? row['value']! : '-',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
                alignment: pw.Alignment.centerRight,
                color: PdfColors.grey200,
                child: pw.Text(
                  row['label']!,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  



pw.Widget _buildPdfFooter({required String maintenanceOfficerName}) {
    pw.Widget signatureLine() => pw.Column(
      children: [
        pw.SizedBox(height: 10),
        pw.Container(width: 80, height: 0.8, color: PdfColors.grey700),
        pw.SizedBox(height: 2),
        pw.Text('التوقيع', style: const pw.TextStyle(fontSize: 7)),
      ],
    );

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        child: pw.Column(
          children: [
            pw.Divider(thickness: 0.8),
            pw.SizedBox(height: 5),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _footerPerson(
                    'المدير العام',
                    'Hamada Rashidy - حمادة الرشيدى',
                    signatureLine(),
                  ),
                ),

                pw.SizedBox(width: 12),

                pw.Expanded(child: _footerMaintenance(maintenanceOfficerName)),

                pw.SizedBox(width: 12),

                pw.Expanded(
                  child: _footerPerson(
                    'رئيس مجلس الإدارة',
                    'ناصر المطيرى - Nasser Khaled',
                    signatureLine(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

 
 
pw.Widget _footerPerson(String title, String name, pw.Widget signature) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 3),

      pw.Text(
        name,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
        softWrap: true,
        maxLines: 2,
      ),

      signature,
    ],
  );
}


pw.Widget _footerMaintenance(String maintenanceOfficerName) {
    return pw.SizedBox(
      width: 140,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'مسؤول الصيانة',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            maintenanceOfficerName,
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'معتمد منه',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }



pw.Widget _buildPdfBottomDividerWithAddress() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 20),
        child: pw.Column(
          children: [
            // =====================
            // 🔹 الخط الفاصل
            // =====================
            pw.Divider(thickness: 0.8, color: PdfColors.grey700),

            pw.SizedBox(height: 8),

            // =====================
            // 📍 العنوان
            // =====================
            pw.Text(
                 'المنطقة الصناعية – شركة البحيرة العربية للنقليات, المملكة العربية السعودية – منطقة حائل  – حائل',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              "“Industrial Area – Al Buhaira Al Arabia Transport Company, Kingdom of Saudi Arabia – Hail Region – Hail.”",
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'جوال: 0535550130   |   البريد الإلكتروني: n.n.66@hotmail.com',
              style: const pw.TextStyle(fontSize: 7.5),
              textAlign: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 15),

            pw.Text(
              'نظام نبراس | شركة البحيرة العربية ',
              style: const pw.TextStyle(fontSize: 7.5),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MaintenanceProvider>(context);
    final checkDate = widget.args['date'] as DateTime;

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 768;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
    appBar: AppBar(
  title: Text(
    'فحص يوم ${DateFormat('yyyy-MM-dd').format(checkDate)}',
    style: TextStyle(
      color: Colors.white,
      fontSize: isLargeScreen ? 22 : isMediumScreen ? 18 : 16,
    ),
  ),
  actions: [
    if (isViewMode || widget.args['mode'] == 'edit')
      IconButton(
        tooltip: 'طباعة / تصدير PDF',
        icon: const Icon(Icons.picture_as_pdf),
        onPressed: _isExporting ? null : _exportPdf,
      ),
  ],
),

      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              isLargeScreen
                  ? 32
                  : isMediumScreen
                  ? 24
                  : 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
                maxWidth: isLargeScreen ? 900 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // 📋 Inspection Result
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                color: Colors.blue,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'نتيجة الفحص والصيانة',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          Container(
                            padding: EdgeInsets.all(
                              isLargeScreen
                                  ? 16
                                  : isMediumScreen
                                  ? 12
                                  : 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _inspectionResult,
                              isExpanded: true,
                              decoration: const InputDecoration.collapsed(
                                hintText: '',
                              ),
                              style: TextStyle(
                                fontSize: isLargeScreen
                                    ? 18
                                    : isMediumScreen
                                    ? 16
                                    : 14,
                                color: Colors.black87,
                                fontFamily: "Cairo",
                              ),
                              items: _inspectionOptions.map((option) {
                                Color optionColor;
                                IconData optionIcon;

                                switch (option) {
                                  case 'تحتاج صيانة':
                                    optionColor = Colors.orange;
                                    optionIcon = Icons.build;
                                    break;
                                  case 'لا تحتاج صيانة':
                                    optionColor = Colors.green;
                                    optionIcon = Icons.check_circle;
                                    break;
                                  case 'تم الفحص ولا يوجد ملاحظات':
                                    optionColor = Colors.blue;
                                    optionIcon = Icons.assignment_turned_in;
                                    break;
                                  default:
                                    optionColor = Colors.grey;
                                    optionIcon = Icons.help_outline;
                                }

                                return DropdownMenuItem<String>(
                                  value: option,
                                  child: Row(
                                    children: [
                                      Icon(
                                        optionIcon,
                                        color: optionColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            color: optionColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),

                              // 🔒 هنا القفل الحقيقي
                              onChanged: isViewMode
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _inspectionResult = value!;

                                        if (_inspectionResult !=
                                            'تحتاج صيانة') {
                                          _maintenanceTypeController.clear();
                                          _maintenanceCostController.clear();

                                          for (final pair
                                              in _invoiceControllers) {
                                            pair['title']?.dispose();
                                            pair['url']?.dispose();
                                          }
                                          _invoiceControllers.clear();
                                        }
                                      });

                                      if (_inspectionResult == 'تحتاج صيانة' &&
                                          _invoiceControllers.isEmpty) {
                                        _addInvoiceRow();
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

// =========================
                  // 🚗 Odometer Reading
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Icon(Icons.speed, color: Colors.indigo),
                              const SizedBox(width: 12),
                              Text(
                                'قراءة العداد (كم)',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 🔢 عداد
                          TextFormField(
                            controller: _odometerController,
                            keyboardType: TextInputType.number,
                            enabled: !isViewMode,
                            decoration: InputDecoration(
                              hintText: 'أدخل قراءة العداد الحالية',
                              prefixIcon: const Icon(Icons.directions_car),
                              filled: isViewMode,
                              fillColor: isViewMode
                                  ? Colors.grey.shade100
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 🛢️ تغيير زيت اليوم
                          CheckboxListTile(
                            value: _oilChangedToday,
                            onChanged: isViewMode
                                ? null
                                : (v) => setState(
                                    () => _oilChangedToday = v ?? false,
                                  ),
                            title: const Text(
                              'تم تغيير الزيت اليوم',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            secondary: const Icon(Icons.oil_barrel),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                  ),


                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // 🔧 Maintenance Details (Conditional)
                  // =========================
                  if (_inspectionResult == 'تحتاج صيانة')
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            Row(
                              children: [
                                Icon(
                                  Icons.build_outlined,
                                  color: Colors.orange,
                                  size: isLargeScreen
                                      ? 28
                                      : isMediumScreen
                                      ? 24
                                      : 20,
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 16
                                      : isMediumScreen
                                      ? 12
                                      : 8,
                                ),
                                Text(
                                  'تفاصيل الصيانة',
                                  style: TextStyle(
                                    fontSize: isLargeScreen
                                        ? 22
                                        : isMediumScreen
                                        ? 18
                                        : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: isLargeScreen
                                  ? 20
                                  : isMediumScreen
                                  ? 16
                                  : 12,
                            ),

                            // Maintenance Type and Cost
                            if (isLargeScreen || isMediumScreen)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _maintenanceTypeController,
                                      label: 'نوع الصيانة',
                                      hintText: 'أدخل نوع الصيانة المطلوبة',
                                      icon: Icons.category_outlined,
                                      isLargeScreen: isLargeScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                  ),
                                  SizedBox(
                                    width: isLargeScreen
                                        ? 24
                                        : isMediumScreen
                                        ? 16
                                        : 12,
                                  ),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _maintenanceCostController,
                                      label: 'تكلفة الصيانة',
                                      hintText: 'أدخل التكلفة',
                                      icon: Icons.attach_money_outlined,
                                      keyboardType: TextInputType.number,
                                      isLargeScreen: isLargeScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  _buildTextField(
                                    controller: _maintenanceTypeController,
                                    label: 'نوع الصيانة',
                                    hintText: 'أدخل نوع الصيانة المطلوبة',
                                    icon: Icons.category_outlined,
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  SizedBox(
                                    height: isLargeScreen
                                        ? 20
                                        : isMediumScreen
                                        ? 16
                                        : 12,
                                  ),
                                  _buildTextField(
                                    controller: _maintenanceCostController,
                                    label: 'تكلفة الصيانة',
                                    hintText: 'أدخل التكلفة',
                                    icon: Icons.attach_money_outlined,
                                    keyboardType: TextInputType.number,
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ],
                              ),

                            SizedBox(
                              height: isLargeScreen
                                  ? 24
                                  : isMediumScreen
                                  ? 20
                                  : 16,
                            ),

                            // Invoices Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_outlined,
                                      color: Colors.purple,
                                      size: isLargeScreen
                                          ? 24
                                          : isMediumScreen
                                          ? 20
                                          : 18,
                                    ),
                                    SizedBox(
                                      width: isLargeScreen
                                          ? 12
                                          : isMediumScreen
                                          ? 8
                                          : 6,
                                    ),
                                    Text(
                                      'فواتير الصيانة',
                                      style: TextStyle(
                                        fontSize: isLargeScreen
                                            ? 20
                                            : isMediumScreen
                                            ? 18
                                            : 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _addInvoiceRow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isLargeScreen
                                          ? 20
                                          : isMediumScreen
                                          ? 16
                                          : 12,
                                      vertical: isLargeScreen
                                          ? 12
                                          : isMediumScreen
                                          ? 10
                                          : 8,
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.add,
                                    size: isLargeScreen
                                        ? 22
                                        : isMediumScreen
                                        ? 18
                                        : 16,
                                  ),
                                  label: Text(
                                    'إضافة فاتورة',
                                    style: TextStyle(
                                      fontSize: isLargeScreen
                                          ? 16
                                          : isMediumScreen
                                          ? 14
                                          : 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(
                              height: isLargeScreen
                                  ? 16
                                  : isMediumScreen
                                  ? 12
                                  : 8,
                            ),

                            if (_invoiceControllers.isEmpty)
                              Container(
                                padding: EdgeInsets.all(
                                  isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 20
                                      : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: isLargeScreen
                                          ? 64
                                          : isMediumScreen
                                          ? 48
                                          : 40,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'لا توجد فواتير مضافة',
                                      style: TextStyle(
                                        fontSize: isLargeScreen
                                            ? 18
                                            : isMediumScreen
                                            ? 16
                                            : 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'انقر على زر "إضافة فاتورة" لبدء إضافة الفواتير',
                                      style: TextStyle(
                                        fontSize: isLargeScreen
                                            ? 14
                                            : isMediumScreen
                                            ? 12
                                            : 11,
                                        color: Colors.grey.shade500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                            ..._invoiceControllers.asMap().entries.map((entry) {
                              final index = entry.key;
                              final controllers = entry.value;
                              return Container(
                                margin: EdgeInsets.only(
                                  top: isLargeScreen
                                      ? 16
                                      : isMediumScreen
                                      ? 12
                                      : 8,
                                ),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      isLargeScreen
                                          ? 20
                                          : isMediumScreen
                                          ? 16
                                          : 12,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'فاتورة ${index + 1}',
                                              style: TextStyle(
                                                fontSize: isLargeScreen
                                                    ? 18
                                                    : isMediumScreen
                                                    ? 16
                                                    : 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade700,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeInvoiceRow(index),
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: isLargeScreen
                                                    ? 24
                                                    : isMediumScreen
                                                    ? 20
                                                    : 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: isLargeScreen
                                              ? 16
                                              : isMediumScreen
                                              ? 12
                                              : 8,
                                        ),
                                        _buildTextField(
                                          controller: controllers['title']!,
                                          label: 'عنوان الفاتورة',
                                          hintText: 'أدخل عنوان الفاتورة',
                                          icon: Icons.title_outlined,
                                          isLargeScreen: isLargeScreen,
                                          isMediumScreen: isMediumScreen,
                                        ),
                                        SizedBox(
                                          height: isLargeScreen
                                              ? 16
                                              : isMediumScreen
                                              ? 12
                                              : 8,
                                        ),
                                        _buildTextField(
                                          controller: controllers['url']!,
                                          label: 'رابط الفاتورة',
                                          hintText: 'أدخل رابط الفاتورة',
                                          icon: Icons.link_outlined,
                                          isLargeScreen: isLargeScreen,
                                          isMediumScreen: isMediumScreen,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                  if (_inspectionResult == 'تحتاج صيانة')
                    SizedBox(
                      height: isLargeScreen
                          ? 32
                          : isMediumScreen
                          ? 24
                          : 16,
                    ),

                  // =========================
                  // 🛡️ Safety Checks
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: Colors.red,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'فحص السلامة',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isLargeScreen ? 2 : 1,
                            childAspectRatio: isLargeScreen
                                ? 3.2
                                : (isMediumScreen ? 3.0 : 2.8),
                            mainAxisSpacing: isLargeScreen
                                ? 16
                                : isMediumScreen
                                ? 12
                                : 8,
                            crossAxisSpacing: isLargeScreen
                                ? 16
                                : isMediumScreen
                                ? 12
                                : 8,
                            children: [
                              _buildCheckField(
                                title: 'سلامة المركبة',
                                value: _vehicleSafety,
                                onChanged: (value) =>
                                    setState(() => _vehicleSafety = value!),
                                icon: Icons.directions_car_outlined,
                                color: Colors.red,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'سلامة السائق',
                                value: _driverSafety,
                                onChanged: (value) =>
                                    setState(() => _driverSafety = value!),
                                icon: Icons.person_outline,
                                color: Colors.blue,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // 🔧 Maintenance Checks
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Icon(
                                Icons.build_outlined,
                                color: Colors.orange,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'فحص الصيانة',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isLargeScreen ? 2 : 1,
                            childAspectRatio: isLargeScreen
                                ? 3.2
                                : (isMediumScreen ? 3.0 : 2.8),
                            mainAxisSpacing: isLargeScreen
                                ? 16
                                : isMediumScreen
                                ? 12
                                : 8,
                            crossAxisSpacing: isLargeScreen
                                ? 16
                                : isMediumScreen
                                ? 12
                                : 8,
                            children: [
                              _buildCheckField(
                                title: 'صيانة الكهرباء',
                                value: _electricalMaintenance,
                                onChanged: (value) => setState(
                                  () => _electricalMaintenance = value!,
                                ),
                                icon: Icons.electrical_services_outlined,
                                color: Colors.orange,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'صيانة الميكانيكا',
                                value: _mechanicalMaintenance,
                                onChanged: (value) => setState(
                                  () => _mechanicalMaintenance = value!,
                                ),
                                icon: Icons.engineering_outlined,
                                color: Colors.purple,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // 🚗 Equipment Checks
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Icon(
                                Icons.construction_outlined,
                                color: Colors.teal,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'فحص المعدات',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isLargeScreen
                                ? 2
                                : (isMediumScreen ? 2 : 1),
                            childAspectRatio: isLargeScreen
                                ? 2.6
                                : (isMediumScreen ? 2.8 : 3.0),
                            mainAxisSpacing: isLargeScreen
                                ? 16
                                : isMediumScreen
                                ? 12
                                : 8,
                            crossAxisSpacing: isLargeScreen
                                ? 16
                                : isMediumScreen
                                ? 12
                                : 8,
                            children: [
                              _buildCheckField(
                                title: 'فحص التانكي',
                                value: _tankInspection,
                                onChanged: (value) =>
                                    setState(() => _tankInspection = value!),
                                icon: Icons.local_gas_station_outlined,
                                color: Colors.teal,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'فحص الإطارات',
                                value: _tiresInspection,
                                onChanged: (value) =>
                                    setState(() => _tiresInspection = value!),
                                icon: Icons.tire_repair_outlined,
                                color: Colors.brown,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'فحص الفرامل',
                                value: _brakesInspection,
                                onChanged: (value) =>
                                    setState(() => _brakesInspection = value!),
                                icon: Icons.stop_circle_outlined,
                                color: Colors.red,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'فحص الأضواء',
                                value: _lightsInspection,
                                onChanged: (value) =>
                                    setState(() => _lightsInspection = value!),
                                icon: Icons.lightbulb_outlined,
                                color: Colors.yellow.shade800,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'فحص السوائل',
                                value: _fluidsCheck,
                                onChanged: (value) =>
                                    setState(() => _fluidsCheck = value!),
                                icon: Icons.opacity_outlined,
                                color: Colors.blue,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                              _buildCheckField(
                                title: 'معدات الطوارئ',
                                value: _emergencyEquipment,
                                onChanged: (value) => setState(
                                  () => _emergencyEquipment = value!,
                                ),
                                icon: Icons.emergency_outlined,
                                color: Colors.red,
                                isLargeScreen: isLargeScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // 📝 Notes
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Icon(
                                Icons.note_outlined,
                                color: Colors.blueGrey,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'ملاحظات إضافية',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          Container(
                            padding: EdgeInsets.all(
                              isLargeScreen
                                  ? 16
                                  : isMediumScreen
                                  ? 12
                                  : 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                hintText: 'أدخل أي ملاحظات إضافية هنا...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                fontSize: isLargeScreen
                                    ? 18
                                    : isMediumScreen
                                    ? 16
                                    : 14,
                              ),
                              maxLines: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 40
                        : isMediumScreen
                        ? 32
                        : 24,
                  ),

                  // =========================
                  // ✅ Submit Button
                  // =========================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _submitCheck,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isLargeScreen
                              ? 22
                              : isMediumScreen
                              ? 18
                              : 16,
                          horizontal: isLargeScreen
                              ? 40
                              : isMediumScreen
                              ? 32
                              : 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Colors.blue.shade300,
                      ),
                      child: provider.isLoading
                          ? SizedBox(
                              height: isLargeScreen
                                  ? 28
                                  : isMediumScreen
                                  ? 24
                                  : 20,
                              width: isLargeScreen
                                  ? 28
                                  : isMediumScreen
                                  ? 24
                                  : 20,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_outlined,
                                  size: isLargeScreen
                                      ? 28
                                      : isMediumScreen
                                      ? 24
                                      : 20,
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 16
                                      : isMediumScreen
                                      ? 12
                                      : 8,
                                ),
                                Text(
                                  'إرسال للمراجعة',
                                  style: TextStyle(
                                    fontSize: isLargeScreen
                                        ? 20
                                        : isMediumScreen
                                        ? 18
                                        : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 120
                        : 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildCheckField({
    required String title,
    required String value,
    required Function(String?) onChanged,
    required IconData icon,
    required Color color,
    required bool isLargeScreen,
    required bool isMediumScreen,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 128),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 16 : 11,
              vertical: isLargeScreen ? 10 : 8,
            ),

            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ⭐ مهم
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: value,
                  isExpanded: true,
                  isDense: true, // ⭐ يقلل الارتفاع
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),

                    // 🔒 شكل مقفول في وضع العرض
                    filled: isViewMode,
                    fillColor: isViewMode ? Colors.grey.shade100 : null,
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isViewMode ? Colors.grey : color,
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isViewMode ? Colors.grey.shade700 : Colors.black87,
                  ),
                  items: _options.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    );
                  }).toList(),

                  // 🔐 القفل الحقيقي
                  onChanged: isViewMode ? null : onChanged,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool isLargeScreen = false,
    bool isMediumScreen = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.blueGrey,
              size: isLargeScreen
                  ? 22
                  : isMediumScreen
                  ? 18
                  : 16,
            ),
            SizedBox(
              width: isLargeScreen
                  ? 10
                  : isMediumScreen
                  ? 8
                  : 6,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isLargeScreen
                    ? 18
                    : isMediumScreen
                    ? 16
                    : 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(
            isLargeScreen
                ? 4
                : isMediumScreen
                ? 2
                : 0,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(
                isLargeScreen
                    ? 16
                    : isMediumScreen
                    ? 12
                    : 10,
              ),
            ),
            style: TextStyle(
              fontSize: isLargeScreen
                  ? 16
                  : isMediumScreen
                  ? 14
                  : 12,
            ),
          ),
        ),
      ],
    );
  }
}
