import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class InventoryDetailsScreen extends StatefulWidget {
  final String inventoryId;

  const InventoryDetailsScreen({super.key, required this.inventoryId});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadInventoryDetails(),
    );
  }

  Future<void> _loadInventoryDetails() async {
    await Provider.of<StationProvider>(
      context,
      listen: false,
    ).fetchInventoryById(widget.inventoryId);
  }

  Future<void> _editInventory(DailyInventory inventory) async {
    final receivedCtrl = TextEditingController(
      text: inventory.receivedQuantity.toStringAsFixed(2),
    );
    final tankerCountCtrl = TextEditingController(
      text: inventory.tankerCount.toString(),
    );
    final actualCtrl = TextEditingController(
      text: inventory.actualBalance?.toStringAsFixed(2) ?? '',
    );
    final diffReasonCtrl = TextEditingController(
      text: inventory.differenceReason ?? '',
    );
    final notesCtrl = TextEditingController(text: inventory.notes ?? '');

    double? parseDecimal(String value) {
      final normalized = value.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }

    void showMessage(
      String message, {
      Color backgroundColor = AppColors.errorRed,
    }) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    }

    try {
      final updates = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تعديل الجرد'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditSummaryRow(
                          label: 'الرصيد السابق',
                          value:
                              '${inventory.previousBalance.toStringAsFixed(2)} لتر',
                        ),
                        const SizedBox(height: 8),
                        _buildEditSummaryRow(
                          label: 'المبيعات',
                          value:
                              '${inventory.totalSales.toStringAsFixed(2)} لتر',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'هذه القيم تأتي من الباك إند وتُعرض هنا فقط.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mediumGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receivedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية المستلمة',
                      suffixText: 'لتر',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tankerCountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'عدد التنكرات',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: actualCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الفعلي',
                      suffixText: 'لتر',
                      helperText:
                          'اتركه فارغًا ليُعاد ضبطه تلقائيًا من النظام.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: diffReasonCtrl,
                    decoration: const InputDecoration(labelText: 'سبب الفرق'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final receivedText = receivedCtrl.text.trim();
                final tankerCountText = tankerCountCtrl.text.trim();
                final actualText = actualCtrl.text.trim();

                if (receivedText.isEmpty) {
                  showMessage('أدخل الكمية المستلمة.');
                  return;
                }

                final receivedQuantity = parseDecimal(receivedText);
                if (receivedQuantity == null || receivedQuantity < 0) {
                  showMessage('قيمة الكمية المستلمة غير صحيحة.');
                  return;
                }

                if (tankerCountText.isEmpty) {
                  showMessage('أدخل عدد التنكرات.');
                  return;
                }

                final tankerCount = int.tryParse(tankerCountText);
                if (tankerCount == null || tankerCount < 0) {
                  showMessage('عدد التنكرات غير صحيح.');
                  return;
                }

                final actualBalance = actualText.isEmpty
                    ? null
                    : parseDecimal(actualText);
                if (actualText.isNotEmpty &&
                    (actualBalance == null || actualBalance < 0)) {
                  showMessage('قيمة الرصيد الفعلي غير صحيحة.');
                  return;
                }

                Navigator.of(dialogContext).pop({
                  'receivedQuantity': receivedQuantity,
                  'tankerCount': tankerCount,
                  'actualBalance': actualText.isEmpty ? null : actualBalance,
                  'differenceReason': diffReasonCtrl.text.trim().isEmpty
                      ? null
                      : diffReasonCtrl.text.trim(),
                  'notes': notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  'updatedAt': DateTime.now().toIso8601String(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (updates == null) return;

      final provider = Provider.of<StationProvider>(context, listen: false);
      final success = await provider.updateInventory(inventory.id, updates);

      if (!mounted) return;

      if (success) {
        await _loadInventoryDetails();
        if (!mounted) return;
        showMessage(
          'تم تحديث الجرد بنجاح.',
          backgroundColor: AppColors.successGreen,
        );
      } else {
        showMessage(provider.error ?? 'فشل تحديث الجرد.');
      }
    } finally {
      receivedCtrl.dispose();
      tankerCountCtrl.dispose();
      actualCtrl.dispose();
      diffReasonCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> _exportReport(
    DailyInventory inventory,
    List<PumpSession> sessions,
  ) async {
    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();

      final fontRegular = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();
      final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

      final date = DateFormat('yyyy/MM/dd').format(inventory.inventoryDate);
      final pdfTitle = 'تقرير التوريد ${inventory.stationName}';
      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
      );

      pdf.addPage(
        pw.Page(
          theme: theme,
          build: (context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              pdfTitle,
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'شركة البحيرة العربية للنقليات',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColor.fromInt(
                                  AppColors.mediumGray.value,
                                ),
                              ),
                            ),
                            pw.Text(
                              'الرقم الوطني الموحد: 7011144750',
                              style: pw.TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        pw.Container(
                          width: 80,
                          height: 80,
                          child: pw.Image(logo, fit: pw.BoxFit.contain),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 12),
                    pw.Text('التاريخ: $date'),
                    pw.Text('نوع الوقود: ${inventory.fuelType}'),
                    pw.Text('الحالة: ${inventory.status}'),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'بيانات التوريد',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table.fromTextArray(
                      headers: ['الرصيد', 'البند'],
                      data: [
                        [
                          '${inventory.previousBalance.toStringAsFixed(2)} لتر',
                          'الرصيد السابق',
                        ],
                        [
                          '${inventory.receivedQuantity.toStringAsFixed(2)} لتر',
                          'كمية التوريد',
                        ],
                        [
                          '${inventory.totalSales.toStringAsFixed(2)} لتر',
                          'المبيعات',
                        ],
                        [
                          '${inventory.calculatedBalance?.toStringAsFixed(2) ?? '---'} لتر',
                          'الرصيد المتوقع',
                        ],
                        [
                          '${inventory.actualBalance?.toStringAsFixed(2) ?? '---'} لتر',
                          'الرصيد الفعلي',
                        ],
                        [
                          '${inventory.difference?.toStringAsFixed(2) ?? '---'} لتر (${inventory.differencePercentage?.toStringAsFixed(1) ?? '---'}%)',
                          'الفرق',
                        ],
                        [
                          '${inventory.totalRevenue.toStringAsFixed(2)} ريال',
                          'الإيرادات',
                        ],
                        [
                          '${inventory.totalExpenses.toStringAsFixed(2)} ريال',
                          'المصروفات',
                        ],
                        [
                          '${inventory.netRevenue?.toStringAsFixed(2) ?? '---'} ريال',
                          'صافي الربح',
                        ],
                      ],
                      cellAlignment: pw.Alignment.centerRight,
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFE0E0E0),
                      ),
                      cellPadding: const pw.EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                    ),
                    if (sessions.isNotEmpty) ...[
                      pw.Divider(height: 24),
                      pw.Text(
                        'جلسات اليوم',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Table.fromTextArray(
                        headers: [
                          'الجلسة',
                          'الوردية',
                          'الحالة',
                          'الكمية (لتر)',
                        ],
                        data: sessions.map((session) {
                          final sessionLiters =
                              session.totalLiters ?? session.totalSales ?? 0;
                          return [
                            session.sessionNumber,
                            session.shiftType,
                            session.status,
                            sessionLiters.toStringAsFixed(2),
                          ];
                        }).toList(),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                        ),
                        headerDecoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFE0E0E0),
                        ),
                        cellHeight: 28,
                        cellAlignment: pw.Alignment.centerRight,
                      ),
                    ],
                    if (inventory.notes != null &&
                        inventory.notes!.isNotEmpty) ...[
                      pw.Divider(height: 24),
                      pw.Text(
                        'ملاحظات:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(inventory.notes!, style: const pw.TextStyle()),
                    ],
                    pw.Spacer(),
                    pw.Divider(),
                    pw.Text(
                      'عنوان الشركة: مدينة الرياض، شارع الملك فهد، مبنى 12',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromInt(AppColors.mediumGray.value),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          'inventory-${inventory.stationName}-${DateFormat('yyyyMMdd').format(inventory.inventoryDate)}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'معتمد':
        return AppColors.successGreen;
      case 'مكتمل':
        return AppColors.infoBlue;
      case 'ملغى':
        return AppColors.errorRed;
      default:
        return AppColors.warningOrange;
    }
  }

  Widget _buildEditSummaryRow({required String label, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role == 'owner';
    final inventory = stationProvider.selectedInventory;
    final sessions = stationProvider.selectedInventorySessions;

    if (stationProvider.isLoading && inventory == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            AppSoftBackground(),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (inventory == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          ),
          title: const Text(
            'تفاصيل المخزون',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: const [
            AppSoftBackground(),
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppSurfaceCard(child: Text('لا يوجد بيانات لهذا الجرد')),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 241, 241),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: const Text(
          'تفاصيل المخزون',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'تعديل الجرد',
              icon: const Icon(Icons.edit),
              onPressed: stationProvider.isLoading
                  ? null
                  : () => _editInventory(inventory),
            ),
          if (isOwner)
            IconButton(
              tooltip: '\u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف الجرد'),
                    content: const Text(
                      'هل أنت متأكد من حذف هذا الجرد؟ لا يمكن التراجع عن هذا الإجراء.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('\u0625\u0644\u063a\u0627\u0621'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorRed,
                        ),
                        child: const Text('\u062d\u0630\u0641'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                final success = await stationProvider.deleteInventory(
                  inventory.id,
                );

                if (!mounted) return;

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الجرد بنجاح'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(stationProvider.error ?? 'فشل حذف الجرد'),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              },
            ),
          IconButton(
            onPressed: _isExporting
                ? null
                : () => _exportReport(inventory, sessions),
            icon: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير التقرير',
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          RefreshIndicator(
            onRefresh: _loadInventoryDetails,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(inventory),
                      const SizedBox(height: 16),
                      _buildFuelSummaryCard(inventory),
                      const SizedBox(height: 16),
                      _buildBalanceCard(inventory),
                      const SizedBox(height: 16),
                      if (sessions.isNotEmpty) ...[
                        _buildSessionsCard(sessions),
                      ],
                      if (inventory.notes != null &&
                          inventory.notes!.isNotEmpty)
                        _buildNotesCard(inventory.notes!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(DailyInventory inventory) {
    final date = DateFormat('yyyy/MM/dd').format(inventory.inventoryDate);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inventory.stationName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 6),
                Text('التاريخ: $date'),
                const SizedBox(height: 2),
                Text('نوع الوقود: ${inventory.fuelType}'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text('عدد التريلات: ${inventory.tankerCount}'),
                    Text('عدد المضخات: ${inventory.pumpCount}'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(inventory.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor(inventory.status)),
            ),
            child: Text(
              inventory.status,
              style: TextStyle(
                color: _statusColor(inventory.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelSummaryCard(DailyInventory inventory) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الوقود',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildKeyValue(
            label: 'الرصيد السابق',
            value: '${inventory.previousBalance.toStringAsFixed(2)} لتر',
          ),
          const SizedBox(height: 8),
          _buildKeyValue(
            label: 'الكمية المستلمة',
            value: '${inventory.receivedQuantity.toStringAsFixed(2)} لتر',
          ),
          const SizedBox(height: 8),
          _buildKeyValue(
            label: 'المبيعات (لتر)',
            value: '${inventory.totalSales.toStringAsFixed(2)} لتر',
          ),
          const SizedBox(height: 8),
          _buildKeyValue(
            label: 'الإيرادات',
            value: '${inventory.totalRevenue.toStringAsFixed(2)} ريال',
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(DailyInventory inventory) {
    final differenceColor = (inventory.difference ?? 0) >= 0
        ? AppColors.successGreen
        : AppColors.errorRed;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الرصيد والتفاوت',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'الرصيد المتوقع',
                  value:
                      '${inventory.calculatedBalance?.toStringAsFixed(2) ?? '---'} لتر',
                  color: AppColors.infoBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  label: 'الرصيد الفعلي',
                  value:
                      '${inventory.actualBalance?.toStringAsFixed(2) ?? '---'} لتر',
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatTile(
            label: 'الفرق',
            value: '${inventory.difference?.toStringAsFixed(2) ?? '---'} لتر',
            color: differenceColor,
            helper:
                '( ${inventory.differencePercentage?.toStringAsFixed(1) ?? '---'}% )',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsCard(List<PumpSession> sessions) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جلسات اليوم',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: sessions.map((session) {
              final liters = session.totalLiters ?? session.totalSales ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الجلسة ${session.sessionNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isLargeScreen ? 16 : 14,
                          ),
                        ),
                        Text(
                          '${liters.toStringAsFixed(2)} لتر',
                          style: const TextStyle(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('الوردية: ${session.shiftType}'),
                        Text('الحالة: ${session.status}'),
                        if (session.openingEmployeeName != null &&
                            session.openingEmployeeName!.isNotEmpty)
                          Text('الموظف: ${session.openingEmployeeName}'),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملاحظات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(notes),
        ],
      ),
    );
  }

  Widget _buildKeyValue({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mediumGray)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required Color color,
    String? helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.mediumGray, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if (helper != null)
            Text(helper, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
