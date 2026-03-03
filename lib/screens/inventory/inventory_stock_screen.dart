import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/inventory_models.dart';
import 'package:order_tracker/providers/inventory_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:order_tracker/widgets/inventory/inventory_stock_data_grid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class InventoryStockScreen extends StatefulWidget {
  const InventoryStockScreen({super.key});

  @override
  State<InventoryStockScreen> createState() => _InventoryStockScreenState();
}

class _InventoryStockScreenState extends State<InventoryStockScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  String? _filterBranchId;
  String? _filterWarehouseId;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters();
      final provider = context.read<InventoryProvider>();
      if (provider.branches.isEmpty || provider.warehouses.isEmpty) {
        provider.fetchDashboardData();
      }
    });
  }

  void _applyFilters() {
    context.read<InventoryProvider>().fetchStock(
          branchId: _filterBranchId,
          warehouseId: _filterWarehouseId,
          from: _fromDate,
          to: _toDate,
        );
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _fromDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _applyFilters();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _toDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _applyFilters();
    }
  }

  void _resetFilters() {
    setState(() {
      _filterBranchId = null;
      _filterWarehouseId = null;
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
  }

  Future<void> _print(List<InventoryStockItem> items) async {
    final bytes = await _buildPdf(items);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _exportPdf(List<InventoryStockItem> items) async {
    final bytes = await _buildPdf(items);
    final fileStamp = DateFormat('yyyyMMdd').format(DateTime.now());
    await saveAndLaunchFile(bytes, 'مخزون_$fileStamp.pdf');
  }

  Future<void> _exportExcel(List<InventoryStockItem> items) async {
    final bytes = await _buildExcel(items);
    final fileStamp = DateFormat('yyyyMMdd').format(DateTime.now());
    await saveAndLaunchFile(bytes, 'مخزون_$fileStamp.xlsx');
  }

  Future<Uint8List> _buildPdf(List<InventoryStockItem> items) async {
    final arabicFontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final arabicFontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    final theme = pw.ThemeData.withFont(
      base: arabicFontRegular,
      bold: arabicFontBold,
      fontFallback: [arabicFontRegular],
    );

    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Text(
            'تقرير المخزون',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('التاريخ: ${_dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'التاريخ',
              'رقم الفاتورة',
              'الفرع',
              'المخزن',
              'المورد',
              'الرقم الضريبي',
              'العنوان',
              'التفاصيل',
              'الكمية',
              'السعر',
              'قبل الضريبة',
              'الضريبة',
              'الإجمالي',
            ],
            data: items
                .map(
                  (item) => [
                    _dateFormat.format(item.date),
                    item.invoiceNumber,
                    item.branchName,
                    item.warehouseName,
                    item.supplierName,
                    item.supplierTaxNumber,
                    item.supplierAddress,
                    item.description,
                    item.quantity.toStringAsFixed(2),
                    item.unitPrice.toStringAsFixed(2),
                    item.subtotal.toStringAsFixed(2),
                    item.taxAmount.toStringAsFixed(2),
                    item.total.toStringAsFixed(2),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _buildExcel(List<InventoryStockItem> items) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'المخزون';
    sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;

    final titleStyle = workbook.styles.add('titleStyle');
    titleStyle.bold = true;
    titleStyle.hAlign = xlsio.HAlignType.center;
    titleStyle.vAlign = xlsio.VAlignType.center;
    titleStyle.fontSize = 14;

    final headerStyle = workbook.styles.add('headerStyle');
    headerStyle.bold = true;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    final dataStyle = workbook.styles.add('dataStyle');
    dataStyle.hAlign = xlsio.HAlignType.center;
    dataStyle.vAlign = xlsio.VAlignType.center;
    dataStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    sheet.getRangeByName('A1:M1').merge();
    sheet.getRangeByName('A1').setText('تقرير المخزون');
    sheet.getRangeByName('A1').cellStyle = titleStyle;

    final headers = [
      'التاريخ',
      'رقم الفاتورة',
      'الفرع',
      'المخزن',
      'المورد',
      'الرقم الضريبي',
      'العنوان',
      'التفاصيل',
      'الكمية',
      'السعر',
      'قبل الضريبة',
      'الضريبة',
      'الإجمالي',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(2, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < items.length; i++) {
      final row = i + 3;
      final item = items[i];
      final values = [
        _dateFormat.format(item.date),
        item.invoiceNumber,
        item.branchName,
        item.warehouseName,
        item.supplierName,
        item.supplierTaxNumber,
        item.supplierAddress,
        item.description,
        item.quantity.toStringAsFixed(2),
        item.unitPrice.toStringAsFixed(2),
        item.subtotal.toStringAsFixed(2),
        item.taxAmount.toStringAsFixed(2),
        item.total.toStringAsFixed(2),
      ];
      for (int col = 0; col < values.length; col++) {
        final cell = sheet.getRangeByIndex(row, col + 1);
        cell.setText(values[col]);
        cell.cellStyle = dataStyle;
      }
    }

    for (int col = 1; col <= headers.length; col++) {
      sheet.autoFitColumn(col);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = provider.stockItems;
    final dataSource = InventoryStockDataSource(items);
    final warehouses = provider.warehousesByBranch(_filterBranchId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'إعادة تعيين التصفية',
            onPressed: _resetFilters,
          ),
        ],
        bottom: provider.isStockLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDropdown(
                  label: 'الفرع',
                  value: _filterBranchId,
                  items: provider.branches
                      .map(
                        (branch) => DropdownMenuItem<String?>(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterBranchId = value;
                      _filterWarehouseId = null;
                    });
                    _applyFilters();
                  },
                  allowAll: true,
                ),
                _buildDropdown(
                  label: 'المخزن',
                  value: _filterWarehouseId,
                  items: warehouses
                      .map(
                        (warehouse) => DropdownMenuItem<String?>(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _filterWarehouseId = value);
                    _applyFilters();
                  },
                  allowAll: true,
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _fromDate == null
                        ? 'من تاريخ'
                        : 'من: ${_dateFormat.format(_fromDate!)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _toDate == null
                        ? 'إلى تاريخ'
                        : 'إلى: ${_dateFormat.format(_toDate!)}',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: items.isEmpty ? null : () => _print(items),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة'),
                ),
                ElevatedButton.icon(
                  onPressed: items.isEmpty ? null : () => _exportPdf(items),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: items.isEmpty ? null : () => _exportExcel(items),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Excel'),
                ),
              ],
            ),
          ),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد مخزون مطابق للتصفية الحالية',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  )
                : InventoryStockDataGrid(dataSource: dataSource),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
    bool allowAll = false,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        value: value,
        items: [
          if (allowAll)
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('الكل'),
            ),
          ...items,
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
