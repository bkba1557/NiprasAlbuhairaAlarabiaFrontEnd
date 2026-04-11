import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/screens/order_details_screen.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class MovementArchiveOrdersScreen extends StatefulWidget {
  const MovementArchiveOrdersScreen({super.key});

  @override
  State<MovementArchiveOrdersScreen> createState() =>
      _MovementArchiveOrdersScreenState();
}

class _RiyalSuffixIcon extends StatelessWidget {
  const _RiyalSuffixIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: SvgPicture.asset(
        _MovementArchiveOrdersScreenState._saudiRiyalSymbolAsset,
        width: 16,
        height: 16,
        colorFilter: const ColorFilter.mode(
          AppColors.primaryDarkBlue,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _MovementArchiveOrdersScreenState
    extends State<MovementArchiveOrdersScreen> {
  static const String _saudiRiyalSymbolAsset =
      'assets/images/saudi_riyal_symbol.svg';
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  List<Order> _orders = <Order>[];
  bool _loading = true;
  String? _busyOrderId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final orders = await context
        .read<OrderProvider>()
        .fetchMovementArchiveOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return _dateFormat.format(value);
  }

  String _formatSchedule(DateTime? date, String? time) {
    final timeText = (time ?? '').trim();
    if (date == null && timeText.isEmpty) return '-';
    final dateText = date == null ? '-' : _dateFormat.format(date);
    return timeText.isEmpty ? dateText : '$timeText - $dateText';
  }

  double? _parseAmount(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  double _vatRateForOrder(Order order) {
    final rawRate = order.effectiveVatRate;
    if (rawRate <= 0) return 0.15;
    return rawRate > 1 ? rawRate / 100 : rawRate;
  }

  double _orderQuantity(Order order) => order.quantity ?? 0;

  String _moneyText(double value) => value.toStringAsFixed(2);

  String _quantityText(Order order) {
    return _quantityTextFor(order, _orderQuantity(order));
  }

  String _quantityTextFor(Order order, double quantity) {
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return '$quantityText ${order.unit ?? 'لتر'}'.trim();
  }

  String _safeText(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _customerDisplayName(Order order) {
    final direct = _safeText(order.movementCustomerName);
    if (direct != '-') return direct;
    final customerName = order.customer?.name;
    return _safeText(customerName);
  }

  double _subtotalFromQuantity(double quantity, double literPrice) {
    return quantity * literPrice;
  }

  Future<PlatformFile> _buildGeneratedTaxInvoiceFileV2({
    required Order order,
    required double invoiceQuantity,
    required double literPrice,
    required double subtotal,
    required double vatAmount,
    required double total,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    final logo = pw.MemoryImage(
      (await rootBundle.load(AppImages.logo)).buffer.asUint8List(),
    );
    final orderRows = <MapEntry<String, String>>[
      MapEntry('نوع الوقود', _safeText(order.fuelType)),
      MapEntry('الكمية', _quantityTextFor(order, invoiceQuantity)),
      MapEntry('نوع الطلب', _safeText(order.effectiveRequestType)),
      MapEntry('اسم المورد', _safeText(order.supplierName)),
      MapEntry('اسم العميل', _customerDisplayName(order)),
    ];
    final amountRows = <MapEntry<String, String>>[
      MapEntry('سعر اللتر', '${_moneyText(literPrice)} ر.س'),
      MapEntry(
        'السعر قبل الضريبة',
        '${_moneyText(subtotal)} ر.س',
      ),
      MapEntry('قيمة الضريبة', '${_moneyText(vatAmount)} ر.س'),
      MapEntry(
        'الإجمالي بعد الضريبة',
        '${_moneyText(total)} ر.س',
      ),
    ];
    final barcodeData = orderRows
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Table buildTable(List<MapEntry<String, String>> rows) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1),
        },
        children: rows.map((entry) {
          return pw.TableRow(
            children: <pw.Widget>[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  entry.value,
                  style: pw.TextStyle(
                    color: PdfColors.blue900,
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.grey100,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  entry.key,
                  style: pw.TextStyle(
                    color: PdfColors.grey800,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  children: <pw.Widget>[
                    pw.Container(
                      width: 64,
                      height: 64,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.Text(
                            'شركة البحيرة العربية',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'فاتورة ضريبية صادرة من نظام نبراس',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: <pw.Widget>[
                        pw.Text(
                          'فاتورة ضريبية',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          order.orderNumber,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              sectionTitle('بيانات الطلب'),
              pw.SizedBox(height: 8),
              buildTable(orderRows),
              pw.SizedBox(height: 18),
              sectionTitle('الملخص المالي'),
              pw.SizedBox(height: 8),
              buildTable(amountRows),
              pw.Spacer(),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: barcodeData,
                      width: 120,
                      height: 120,
                      drawText: false,
                    ),
                  ),
                  pw.SizedBox(width: 18),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        'تم إصدار هذه الفاتورة آلياً من نظام نبراس. الباركود يحتوي بيانات الطلب الأساسية للتحقق السريع.',
                        style: const pw.TextStyle(
                          color: PdfColors.grey700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300),
              pw.Text(
                'شركة البحيرة العربية - نظام نبراس لإدارة الطلبات',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 9,
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final safeOrderNumber = order.orderNumber.replaceAll(
      RegExp(r'[^A-Za-z0-9_\-]+'),
      '_',
    );
    return PlatformFile(
      name: 'tax_invoice_$safeOrderNumber.pdf',
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    );
  }

  List<Order> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _orders;
    return _orders.where((order) {
      final haystack = <String>[
        order.orderNumber,
        order.supplierOrderNumber ?? '',
        order.supplierName,
        order.movementCustomerName ?? '',
        order.driverName ?? '',
        order.vehicleNumber ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _pickFiles({
    required ValueSetter<List<PlatformFile>> onPicked,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    onPicked(result.files);
  }

  Future<void> _showCompletionDialog(Order order) async {
    final notesController = TextEditingController();
    final actualSupplyQuantityController = TextEditingController();
    final literPriceController = TextEditingController();
    final saleValueController = TextEditingController();
    final transportValueController = TextEditingController();
    final vatRate = _vatRateForOrder(order);
    var taxInvoiceFiles = <PlatformFile>[];
    var systemInvoiceFiles = <PlatformFile>[];
    var fuelReceiptFiles = <PlatformFile>[];
    var actualQuantityStatementFiles = <PlatformFile>[];
    var addAllIncludedVat = true;
    var calculateUsingActualQuantity = false;
    var saving = false;
    double? actualSupplyQuantity;
    double calculationQuantity = _orderQuantity(order);
    double? literPrice;
    double subtotal = 0;
    double vatAmount = 0;
    double totalAfterVat = 0;

    void recalculateSaleValue() {
      final parsedLiterPrice = _parseAmount(literPriceController.text);
      actualSupplyQuantity = _parseAmount(actualSupplyQuantityController.text);
      calculationQuantity = calculateUsingActualQuantity
          ? (actualSupplyQuantity ?? 0)
          : _orderQuantity(order);
      literPrice = parsedLiterPrice;
      if (parsedLiterPrice == null || calculationQuantity <= 0) {
        subtotal = 0;
        vatAmount = 0;
        totalAfterVat = 0;
        saleValueController.clear();
        return;
      }
      subtotal = _subtotalFromQuantity(calculationQuantity, parsedLiterPrice);
      vatAmount = subtotal * vatRate;
      totalAfterVat = subtotal + vatAmount;
      saleValueController.text = _moneyText(totalAfterVat);
    }

    Future<void> generateSystemInvoice(
      StateSetter setDialogState, {
      required bool printOnly,
    }) async {
      recalculateSaleValue();
      if (literPrice == null || totalAfterVat <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل سعر اللتر أولاً لتوليد الفاتورة.')),
        );
        return;
      }

      final file = await _buildGeneratedTaxInvoiceFileV2(
        order: order,
        invoiceQuantity: calculationQuantity,
        literPrice: literPrice!,
        subtotal: subtotal,
        vatAmount: vatAmount,
        total: totalAfterVat,
      );
      if (printOnly) {
        await Printing.layoutPdf(onLayout: (_) async => file.bytes!);
        return;
      }

      setDialogState(() => systemInvoiceFiles = <PlatformFile>[file]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم توليد الفاتورة الضريبية وإرفاقها.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }

    Future<void> submit(StateSetter setDialogState) async {
      recalculateSaleValue();
      final saleValue = totalAfterVat > 0 ? totalAfterVat : null;
      final transportValue = _parseAmount(transportValueController.text);

      if (taxInvoiceFiles.isEmpty ||
          fuelReceiptFiles.isEmpty ||
          actualQuantityStatementFiles.isEmpty ||
          literPrice == null ||
          (calculateUsingActualQuantity &&
              (actualSupplyQuantity == null || actualSupplyQuantity! <= 0)) ||
          saleValue == null ||
          transportValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'أرفق الفاتورة وسند الاستلام وسند الكمية الفعلية وأدخل القيم قبل الحفظ.',
            ),
          ),
        );
        return;
      }

      setDialogState(() => saving = true);
      setState(() => _busyOrderId = order.id);

      final success = await context.read<OrderProvider>().completeMovementArchiveOrder(
            orderId: order.id,
            taxInvoiceFiles: taxInvoiceFiles,
            systemInvoiceFiles: systemInvoiceFiles,
            fuelReceiptFiles: fuelReceiptFiles,
            actualQuantityStatementFiles: actualQuantityStatementFiles,
            actualSupplyQuantity: actualSupplyQuantity,
            calculationQuantitySource:
                calculateUsingActualQuantity ? 'actual' : 'order',
            literPrice: literPrice!,
            saleSubtotal: subtotal,
            saleVatAmount: vatAmount,
            saleValue: saleValue,
            transportValue: transportValue,
            addAllIncludedVat: addAllIncludedVat,
            notes: notesController.text,
          );

      if (!mounted) return;

      setDialogState(() => saving = false);
      setState(() {
        _busyOrderId = null;
        if (success) {
          _orders.removeWhere((item) => item.id == order.id);
        }
      });

      if (!success) {
        final error = context.read<OrderProvider>().error ??
            'تعذر إنهاء أرشفة الطلب.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }

      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ مستندات وقيم الطلب ${order.orderNumber} وإنهاء الأرشفة.',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('إنهاء أرشفة ${order.orderNumber}'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _uploadField(
                        title: 'الفاتورة الضريبية',
                        files: taxInvoiceFiles,
                        onPick: () async {
                          await _pickFiles(
                            onPicked: (files) =>
                                setDialogState(() => taxInvoiceFiles = files),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _uploadField(
                        title: 'سند استلام المحروقات',
                        files: fuelReceiptFiles,
                        onPick: () async {
                          await _pickFiles(
                            onPicked: (files) =>
                                setDialogState(() => fuelReceiptFiles = files),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _uploadField(
                        title: 'سند الكمية الفعلية',
                        files: actualQuantityStatementFiles,
                        onPick: () async {
                          await _pickFiles(
                            onPicked: (files) => setDialogState(
                              () => actualQuantityStatementFiles = files,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: actualSupplyQuantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) =>
                                  setDialogState(recalculateSaleValue),
                              decoration: InputDecoration(
                                labelText: 'كمية التوريد الفعلي',
                                suffixText: order.unit ?? 'لتر',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SegmentedButton<bool>(
                              segments: const <ButtonSegment<bool>>[
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('كمية الطلب'),
                                  icon: Icon(Icons.receipt_long_outlined),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('الكمية الفعلية'),
                                  icon: Icon(Icons.scale_outlined),
                                ),
                              ],
                              selected: <bool>{calculateUsingActualQuantity},
                              onSelectionChanged: (selection) {
                                setDialogState(() {
                                  calculateUsingActualQuantity =
                                      selection.first;
                                  recalculateSaleValue();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: literPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setDialogState(recalculateSaleValue),
                        decoration: const InputDecoration(
                          labelText: 'سعر اللتر قبل الضريبة',
                          suffixIcon: const _RiyalSuffixIcon(),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _pricingSummary(
                        quantity: _quantityTextFor(order, calculationQuantity),
                        quantitySource: calculateUsingActualQuantity
                            ? 'الكمية الفعلية'
                            : 'كمية الطلب',
                        vatRate: vatRate,
                        subtotal: subtotal,
                        vatAmount: vatAmount,
                        totalAfterVat: totalAfterVat,
                      ),
                      const SizedBox(height: 12),
                      _systemInvoiceField(
                        files: systemInvoiceFiles,
                        onGenerate: saving
                            ? null
                            : () => generateSystemInvoice(
                                  setDialogState,
                                  printOnly: false,
                                ),
                        onPrint: saving
                            ? null
                            : () => generateSystemInvoice(
                                  setDialogState,
                                  printOnly: true,
                                ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: saleValueController,
                              readOnly: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'قيمة الرد',
                                suffixText: 'شامل الضريبة',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: transportValueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'قيمة النقل',
                                suffixText: 'شامل الضريبة',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _requiredTotalSummary(
                        totalAfterVat +
                            (_parseAmount(transportValueController.text) ?? 0),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: addAllIncludedVat,
                        onChanged: (value) => setDialogState(
                          () => addAllIncludedVat = value ?? true,
                        ),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('إضافة الكل'),
                        subtitle: const Text(
                          'القيم المدخلة تعتبر شاملة الضريبة.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : () => submit(setDialogState),
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.task_alt_rounded),
                  label: const Text('حفظ وإنهاء'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
    actualSupplyQuantityController.dispose();
    literPriceController.dispose();
    saleValueController.dispose();
    transportValueController.dispose();
  }

  Widget _riyalSymbol({
    required Color color,
    double size = 14,
  }) {
    return SvgPicture.asset(
      _saudiRiyalSymbolAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _pricingSummary({
    required String quantity,
    required String quantitySource,
    required double vatRate,
    required double subtotal,
    required double vatAmount,
    required double totalAfterVat,
  }) {
    Widget item(String label, String value, {Color? color, bool currency = false}) {
      final valueStyle = TextStyle(
        color: color ?? AppColors.primaryDarkBlue,
        fontWeight: FontWeight.w900,
      );
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primaryBlue).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (color ?? AppColors.primaryBlue).withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              currency
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(value, style: valueStyle),
                        const SizedBox(width: 4),
                        _riyalSymbol(
                          color: color ?? AppColors.primaryDarkBlue,
                          size: 13,
                        ),
                      ],
                    )
                  : Text(value, style: valueStyle),
            ],
          ),
        ),
      );
    }

    final vatPercent = (vatRate * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            item('الكمية ($quantitySource)', quantity),
            const SizedBox(width: 8),
            item(
              'السعر قبل الضريبة',
              _moneyText(subtotal),
              currency: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            item(
              'الضريبة $vatPercent%',
              _moneyText(vatAmount),
              currency: true,
            ),
            const SizedBox(width: 8),
            item(
              'الإجمالي بعد الضريبة',
              _moneyText(totalAfterVat),
              color: AppColors.successGreen,
              currency: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _requiredTotalSummary(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primaryBlue.withValues(alpha: 0.12),
            AppColors.successGreen.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.request_quote_outlined,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'الإجمالي المطلوب',
              style: TextStyle(
                color: AppColors.primaryDarkBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _moneyText(total),
                style: const TextStyle(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 5),
              _riyalSymbol(color: AppColors.successGreen, size: 15),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadField({
    required String title,
    required List<PlatformFile> files,
    required VoidCallback onPick,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.16)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('إرفاق'),
              ),
            ],
          ),
          if (files.isEmpty)
            Text(
              'لم يتم إرفاق ملفات بعد',
              style: TextStyle(color: AppColors.mediumGray),
            )
          else
            ...files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.insert_drive_file_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _systemInvoiceField({
    required List<PlatformFile> files,
    required VoidCallback? onGenerate,
    required VoidCallback? onPrint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.2)),
        color: AppColors.successGreen.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'فاتورة من داخل النظام',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('طباعة فقط'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('توليد وإرفاق'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (files.isEmpty)
            Text(
              'هذه فاتورة نظام مستقلة ولا تُحسب ضمن الفاتورة الضريبية.',
              style: TextStyle(color: AppColors.mediumGray),
            )
          else
            ...files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.receipt_long_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filteredOrders;
    final viewport = MediaQuery.sizeOf(context);
    final isWideWeb = viewport.width >= 1200;
    final contentMaxWidth = isWideWeb ? 1580.0 : 980.0;
    final horizontalPadding = isWideWeb ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشفة طلبات الحركة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              end: isWideWeb ? 16 : 8,
              start: 8,
            ),
            child: isWideWeb
                ? OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('تسجيل خروج'),
                  )
                : IconButton(
                    tooltip: 'تسجيل خروج',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.primaryBlue.withValues(alpha: 0.06),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  children: <Widget>[
                    _headerCard(filteredOrders.length, isWideWeb),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            'ابحث برقم الطلب أو رقم طلب المورد أو العميل أو السائق',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredOrders.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لا توجد طلبات موجهة بانتظار الأرشفة حاليًا.',
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadOrders,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      0,
                                      0,
                                      24,
                                    ),
                                    itemCount: filteredOrders.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) =>
                                        _orderCard(filteredOrders[index]),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(int visibleCount, bool isWideWeb) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isWideWeb ? 24 : 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'طلبات بانتظار الإنهاء',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'أرفق مستندات الطلب وسجل القيم المالية لإنهاء أرشفة الحركة.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _statChip('بانتظار الأرشفة', '${_orders.length}'),
              _statChip('الظاهر الآن', '$visibleCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Order order) {
    final busy = _busyOrderId == order.id;
    final arrivalDate = order.movementExpectedArrivalDate ?? order.arrivalDate;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.10),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              _statusPill('بانتظار الإنهاء'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              _detailChip('المورد', order.supplierName),
              _detailChip(
                'رقم طلب المورد الخارجي',
                order.supplierOrderNumber ?? '-',
              ),
              _detailChip('العميل', order.movementCustomerName ?? '-'),
              _detailChip('السائق', order.driverName ?? '-'),
              _detailChip('المركبة', order.vehicleNumber ?? '-'),
              _detailChip('الوقود', order.fuelType ?? '-'),
              _detailChip(
                'الكمية',
                '${order.quantity ?? 0} ${order.unit ?? ''}'.trim(),
              ),
              _detailChip(
                'موعد التحميل',
                _formatSchedule(order.loadingDate, order.loadingTime),
              ),
              _detailChip(
                'موعد الوصول',
                _formatSchedule(arrivalDate, order.arrivalTime),
              ),
              _detailChip('تاريخ التوجيه', _formatDate(order.movementDirectedAt)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailsScreen(
                        orderId: order.id,
                        screenTitle: 'تفاصيل أرشفة الطلب',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('التفاصيل'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : () => _showCompletionDialog(order),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.task_alt_rounded),
                label: const Text('إنهاء'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.warningOrange,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDarkBlue,
            ),
          ),
        ],
      ),
    );
  }
}

