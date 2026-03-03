import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
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
                                color: PdfColor.fromInt(AppColors.mediumGray.value),
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
                        ['${inventory.previousBalance.toStringAsFixed(2)} لتر', 'الرصيد السابق'],
                        ['${inventory.receivedQuantity.toStringAsFixed(2)} لتر', 'كمية التوريد'],
                        ['${inventory.totalSales.toStringAsFixed(2)} لتر', 'المبيعات'],
                        [
                          '${inventory.calculatedBalance?.toStringAsFixed(2) ?? '---'} لتر',
                          'الرصيد المتوقع'
                        ],
                        [
                          '${inventory.actualBalance?.toStringAsFixed(2) ?? '---'} لتر',
                          'الرصيد الفعلي'
                        ],
                        [
                          '${inventory.difference?.toStringAsFixed(2) ?? '---'} لتر (${inventory.differencePercentage?.toStringAsFixed(1) ?? '---'}%)',
                          'الفرق'
                        ],
                        ['${inventory.totalRevenue.toStringAsFixed(2)} ريال', 'الإيرادات'],
                        ['${inventory.totalExpenses.toStringAsFixed(2)} ريال', 'المصروفات'],
                        [
                          '${inventory.netRevenue?.toStringAsFixed(2) ?? '---'} ريال',
                          'صافي الربح'
                        ],
                      ],
                      cellAlignment: pw.Alignment.centerRight,
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
                      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    ),
                    if (sessions.isNotEmpty) ...[
                      pw.Divider(height: 24),
                      pw.Text(
                        'جلسات اليوم',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Table.fromTextArray(
                        headers: ['الجلسة', 'الوردية', 'الحالة', 'الكمية (لتر)'],
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
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
                        cellHeight: 28,
                        cellAlignment: pw.Alignment.centerRight,
                      ),
                    ],
                    if (inventory.notes != null && inventory.notes!.isNotEmpty) ...[
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
                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(AppColors.mediumGray.value)),
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

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = authProvider.role == 'owner';
    final inventory = stationProvider.selectedInventory;
    final sessions = stationProvider.selectedInventorySessions;

    if (stationProvider.isLoading && inventory == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (inventory == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المخزون', style: TextStyle(color: Colors.white),)),
        body: const Center(child: Text('لا يوجد بيانات لهذا الجرد')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المخزون'),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: '\u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('??\u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f'),
                    content: const Text(
                      '?? \u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f ?? \u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f? ?? ?\u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f?? ?? \u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f??.',
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
                      content: Text('?? \u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f \u0625\u0644\u063a\u0627\u0621'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        stationProvider.error ?? '??? \u062d\u0630\u0641 \u0627\u0644\u062c\u0631\u062f',
                      ),
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
      body: RefreshIndicator(
        onRefresh: _loadInventoryDetails,
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
              if (sessions.isNotEmpty) ...[_buildSessionsCard(sessions)],
              if (inventory.notes != null && inventory.notes!.isNotEmpty)
                _buildNotesCard(inventory.notes!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(DailyInventory inventory) {
    final date = DateFormat('yyyy/MM/dd').format(inventory.inventoryDate);

    return Card(
      child: Padding(
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
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('التاريخ: $date'),
                  const SizedBox(height: 2),
                  Text('نوع الوقود: ${inventory.fuelType}'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('عدد التريلات: ${inventory.tankerCount}'),
                      const SizedBox(width: 16),
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
      ),
    );
  }

  Widget _buildFuelSummaryCard(DailyInventory inventory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الوقود',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildBalanceCard(DailyInventory inventory) {
    final differenceColor = (inventory.difference ?? 0) >= 0
        ? AppColors.successGreen
        : AppColors.errorRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الرصيد والتفاوت',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildSessionsCard(List<PumpSession> sessions) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جلسات اليوم',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                            style: TextStyle(
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
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملاحظات',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(notes),
          ],
        ),
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
