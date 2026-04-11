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
    final quantity = _orderQuantity(order);
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return '$quantityText ${order.unit ?? 'Ù„ØªØ±'}'.trim();
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

  double _subtotalFromLiterPrice(Order order, double literPrice) {
    return _orderQuantity(order) * literPrice;
  }

  Future<PlatformFile> _buildGeneratedTaxInvoiceFile({
    required Order order,
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
    final invoiceFields = <String, String>{
      'Ù†ÙˆØ¹ Ø§Ù„ÙˆÙ‚ÙˆØ¯': _safeText(order.fuelType),
      'Ø§Ù„ÙƒÙ…ÙŠØ©': _quantityText(order),
      'Ù†ÙˆØ¹ Ø§Ù„Ø·Ù„Ø¨': _safeText(order.effectiveRequestType),
      'Ø§Ù„Ù…ÙˆØ±Ø¯': _safeText(order.supplierName),
      'Ø§Ù„Ø¹Ù…ÙŠÙ„': _customerDisplayName(order),
    };
    final barcodeData = invoiceFields.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Widget row(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        child: pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(
                  color: PdfColors.blue900,
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: <pw.Widget>[
                    pw.Text(
                      'ÙØ§ØªÙˆØ±Ø© Ø¶Ø±ÙŠØ¨ÙŠØ©',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      order.orderNumber,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  children: invoiceFields.entries
                      .map((entry) => row(entry.key, entry.value))
                      .toList(),
                ),
              ),
              if (false) ...[
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text('Ø³Ø¹Ø± Ø§Ù„Ù„ØªØ±: ${_moneyText(literPrice)}'),
                    pw.Text('Ù‚Ø¨Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©: ${_moneyText(subtotal)}'),
                    pw.Text('Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©: ${_moneyText(vatAmount)}'),
                    pw.Text('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ: ${_moneyText(total)}'),
                  ],
                ),
              ),
              ],
              pw.Spacer(),
              pw.Center(
                child: pw.Container(
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

  Future<PlatformFile> _buildGeneratedTaxInvoiceFileV2({
    required Order order,
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
      MapEntry('Ù†ÙˆØ¹ Ø§Ù„ÙˆÙ‚ÙˆØ¯', _safeText(order.fuelType)),
      MapEntry('Ø§Ù„ÙƒÙ…ÙŠØ©', _quantityText(order)),
      MapEntry('Ù†ÙˆØ¹ Ø§Ù„Ø·Ù„Ø¨', _safeText(order.effectiveRequestType)),
      MapEntry('Ø§Ø³Ù… Ø§Ù„Ù…ÙˆØ±Ø¯', _safeText(order.supplierName)),
      MapEntry('Ø§Ø³Ù… Ø§Ù„Ø¹Ù…ÙŠÙ„', _customerDisplayName(order)),
    ];
    final amountRows = <MapEntry<String, String>>[
      MapEntry('Ø³Ø¹Ø± Ø§Ù„Ù„ØªØ±', '${_moneyText(literPrice)} Ø±.Ø³'),
      MapEntry(
        'Ø§Ù„Ø³Ø¹Ø± Ù‚Ø¨Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
        '${_moneyText(subtotal)} Ø±.Ø³',
      ),
      MapEntry('Ù‚ÙŠÙ…Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©', '${_moneyText(vatAmount)} Ø±.Ø³'),
      MapEntry(
        'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø¨Ø¹Ø¯ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
        '${_moneyText(total)} Ø±.Ø³',
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
                            'Ø´Ø±ÙƒØ© Ø§Ù„Ø¨Ø­ÙŠØ±Ø© Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'ÙØ§ØªÙˆØ±Ø© Ø¶Ø±ÙŠØ¨ÙŠØ© ØµØ§Ø¯Ø±Ø© Ù…Ù† Ù†Ø¸Ø§Ù… Ù†Ø¨Ø±Ø§Ø³',
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
                          'ÙØ§ØªÙˆØ±Ø© Ø¶Ø±ÙŠØ¨ÙŠØ©',
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
              sectionTitle('Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø·Ù„Ø¨'),
              pw.SizedBox(height: 8),
              buildTable(orderRows),
              pw.SizedBox(height: 18),
              sectionTitle('Ø§Ù„Ù…Ù„Ø®Øµ Ø§Ù„Ù…Ø§Ù„ÙŠ'),
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
                        'ØªÙ… Ø¥ØµØ¯Ø§Ø± Ù‡Ø°Ù‡ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø¢Ù„ÙŠØ§Ù‹ Ù…Ù† Ù†Ø¸Ø§Ù… Ù†Ø¨Ø±Ø§Ø³. Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯ ÙŠØ­ØªÙˆÙŠ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø·Ù„Ø¨ Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ© Ù„Ù„ØªØ­Ù‚Ù‚ Ø§Ù„Ø³Ø±ÙŠØ¹.',
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
                'Ø´Ø±ÙƒØ© Ø§Ù„Ø¨Ø­ÙŠØ±Ø© Ø§Ù„Ø¹Ø±Ø¨ÙŠØ© - Ù†Ø¸Ø§Ù… Ù†Ø¨Ø±Ø§Ø³ Ù„Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ø·Ù„Ø¨Ø§Øª',
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
    final literPriceController = TextEditingController();
    final saleValueController = TextEditingController();
    final transportValueController = TextEditingController();
    final vatRate = _vatRateForOrder(order);
    var taxInvoiceFiles = <PlatformFile>[];
    var systemInvoiceFiles = <PlatformFile>[];
    var fuelReceiptFiles = <PlatformFile>[];
    var actualQuantityStatementFiles = <PlatformFile>[];
    var addAllIncludedVat = true;
    var saving = false;
    double? literPrice;
    double subtotal = 0;
    double vatAmount = 0;
    double totalAfterVat = 0;

    void recalculateSaleValue() {
      final parsedLiterPrice = _parseAmount(literPriceController.text);
      literPrice = parsedLiterPrice;
      if (parsedLiterPrice == null || _orderQuantity(order) <= 0) {
        subtotal = 0;
        vatAmount = 0;
        totalAfterVat = 0;
        saleValueController.clear();
        return;
      }
      subtotal = _subtotalFromLiterPrice(order, parsedLiterPrice);
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
          const SnackBar(content: Text('Ø£Ø¯Ø®Ù„ Ø³Ø¹Ø± Ø§Ù„Ù„ØªØ± Ø£ÙˆÙ„Ø§Ù‹ Ù„ØªÙˆÙ„ÙŠØ¯ Ø§Ù„ÙØ§ØªÙˆØ±Ø©.')),
        );
        return;
      }

      final file = await _buildGeneratedTaxInvoiceFileV2(
        order: order,
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
          content: Text('ØªÙ… ØªÙˆÙ„ÙŠØ¯ Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨ÙŠØ© ÙˆØ¥Ø±ÙØ§Ù‚Ù‡Ø§.'),
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
          saleValue == null ||
          transportValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ø£Ø±ÙÙ‚ Ø§Ù„ÙØ§ØªÙˆØ±Ø© ÙˆØ³Ù†Ø¯ Ø§Ù„Ø§Ø³ØªÙ„Ø§Ù… ÙˆØ³Ù†Ø¯ Ø§Ù„ÙƒÙ…ÙŠØ© Ø§Ù„ÙØ¹Ù„ÙŠØ© ÙˆØ£Ø¯Ø®Ù„ Ø§Ù„Ù‚ÙŠÙ… Ù‚Ø¨Ù„ Ø§Ù„Ø­ÙØ¸.',
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
            'ØªØ¹Ø°Ø± Ø¥Ù†Ù‡Ø§Ø¡ Ø£Ø±Ø´ÙØ© Ø§Ù„Ø·Ù„Ø¨.';
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
            'ØªÙ… Ø­ÙØ¸ Ù…Ø³ØªÙ†Ø¯Ø§Øª ÙˆÙ‚ÙŠÙ… Ø§Ù„Ø·Ù„Ø¨ ${order.orderNumber} ÙˆØ¥Ù†Ù‡Ø§Ø¡ Ø§Ù„Ø£Ø±Ø´ÙØ©.',
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
              title: Text('Ø¥Ù†Ù‡Ø§Ø¡ Ø£Ø±Ø´ÙØ© ${order.orderNumber}'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _uploadField(
                        title: 'Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨ÙŠØ©',
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
                        title: 'Ø³Ù†Ø¯ Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ù…Ø­Ø±ÙˆÙ‚Ø§Øª',
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
                        title: 'Ø³Ù†Ø¯ Ø§Ù„ÙƒÙ…ÙŠØ© Ø§Ù„ÙØ¹Ù„ÙŠØ©',
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
                      TextField(
                        controller: literPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setDialogState(recalculateSaleValue),
                        decoration: const InputDecoration(
                          labelText: 'Ø³Ø¹Ø± Ø§Ù„Ù„ØªØ± Ù‚Ø¨Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
                          suffixIcon: const _RiyalSuffixIcon(),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _pricingSummary(
                        quantity: _quantityText(order),
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
                                labelText: 'Ù‚ÙŠÙ…Ø© Ø§Ù„Ø±Ø¯',
                                suffixText: 'Ø´Ø§Ù…Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
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
                                labelText: 'Ù‚ÙŠÙ…Ø© Ø§Ù„Ù†Ù‚Ù„',
                                suffixText: 'Ø´Ø§Ù…Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
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
                        title: const Text('Ø¥Ø¶Ø§ÙØ© Ø§Ù„ÙƒÙ„'),
                        subtitle: const Text(
                          'Ø§Ù„Ù‚ÙŠÙ… Ø§Ù„Ù…Ø¯Ø®Ù„Ø© ØªØ¹ØªØ¨Ø± Ø´Ø§Ù…Ù„Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª',
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
                  child: const Text('Ø¥Ù„ØºØ§Ø¡'),
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
                  label: const Text('Ø­ÙØ¸ ÙˆØ¥Ù†Ù‡Ø§Ø¡'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
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
            item('Ø§Ù„ÙƒÙ…ÙŠØ©', quantity),
            const SizedBox(width: 8),
            item(
              'Ø§Ù„Ø³Ø¹Ø± Ù‚Ø¨Ù„ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
              _moneyText(subtotal),
              currency: true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            item(
              'Ø§Ù„Ø¶Ø±ÙŠØ¨Ø© $vatPercent%',
              _moneyText(vatAmount),
              currency: true,
            ),
            const SizedBox(width: 8),
            item(
              'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø¨Ø¹Ø¯ Ø§Ù„Ø¶Ø±ÙŠØ¨Ø©',
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
              'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø·Ù„ÙˆØ¨',
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
                label: const Text('Ø¥Ø±ÙØ§Ù‚'),
              ),
            ],
          ),
          if (files.isEmpty)
            Text(
              'Ù„Ù… ÙŠØªÙ… Ø¥Ø±ÙØ§Ù‚ Ù…Ù„ÙØ§Øª Ø¨Ø¹Ø¯',
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
                  'ÙØ§ØªÙˆØ±Ø© Ù…Ù† Ø¯Ø§Ø®Ù„ Ø§Ù„Ù†Ø¸Ø§Ù…',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDarkBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Ø·Ø¨Ø§Ø¹Ø© ÙÙ‚Ø·'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('ØªÙˆÙ„ÙŠØ¯ ÙˆØ¥Ø±ÙØ§Ù‚'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (files.isEmpty)
            Text(
              'Ù‡Ø°Ù‡ ÙØ§ØªÙˆØ±Ø© Ù†Ø¸Ø§Ù… Ù…Ø³ØªÙ‚Ù„Ø© ÙˆÙ„Ø§ ØªÙØ­Ø³Ø¨ Ø¶Ù…Ù† Ø§Ù„ÙØ§ØªÙˆØ±Ø© Ø§Ù„Ø¶Ø±ÙŠØ¨ÙŠØ©.',
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
        title: const Text('Ø£Ø±Ø´ÙØ© Ø·Ù„Ø¨Ø§Øª Ø§Ù„Ø­Ø±ÙƒØ©'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ØªØ­Ø¯ÙŠØ«',
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
                    label: const Text('ØªØ³Ø¬ÙŠÙ„ Ø®Ø±ÙˆØ¬'),
                  )
                : IconButton(
                    tooltip: 'ØªØ³Ø¬ÙŠÙ„ Ø®Ø±ÙˆØ¬',
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
                            'Ø§Ø¨Ø­Ø« Ø¨Ø±Ù‚Ù… Ø§Ù„Ø·Ù„Ø¨ Ø£Ùˆ Ø±Ù‚Ù… Ø·Ù„Ø¨ Ø§Ù„Ù…ÙˆØ±Ø¯ Ø£Ùˆ Ø§Ù„Ø¹Ù…ÙŠÙ„ Ø£Ùˆ Ø§Ù„Ø³Ø§Ø¦Ù‚',
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
                                    'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ù„Ø¨Ø§Øª Ù…ÙˆØ¬Ù‡Ø© Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ø£Ø±Ø´ÙØ© Ø­Ø§Ù„ÙŠÙ‹Ø§.',
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
            'Ø·Ù„Ø¨Ø§Øª Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ø¥Ù†Ù‡Ø§Ø¡',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ø£Ø±ÙÙ‚ Ù…Ø³ØªÙ†Ø¯Ø§Øª Ø§Ù„Ø·Ù„Ø¨ ÙˆØ³Ø¬Ù„ Ø§Ù„Ù‚ÙŠÙ… Ø§Ù„Ù…Ø§Ù„ÙŠØ© Ù„Ø¥Ù†Ù‡Ø§Ø¡ Ø£Ø±Ø´ÙØ© Ø§Ù„Ø­Ø±ÙƒØ©.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _statChip('Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ø£Ø±Ø´ÙØ©', '${_orders.length}'),
              _statChip('Ø§Ù„Ø¸Ø§Ù‡Ø± Ø§Ù„Ø¢Ù†', '$visibleCount'),
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
              _statusPill('Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ø¥Ù†Ù‡Ø§Ø¡'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              _detailChip('Ø§Ù„Ù…ÙˆØ±Ø¯', order.supplierName),
              _detailChip(
                'Ø±Ù‚Ù… Ø·Ù„Ø¨ Ø§Ù„Ù…ÙˆØ±Ø¯ Ø§Ù„Ø®Ø§Ø±Ø¬ÙŠ',
                order.supplierOrderNumber ?? '-',
              ),
              _detailChip('Ø§Ù„Ø¹Ù…ÙŠÙ„', order.movementCustomerName ?? '-'),
              _detailChip('Ø§Ù„Ø³Ø§Ø¦Ù‚', order.driverName ?? '-'),
              _detailChip('Ø§Ù„Ù…Ø±ÙƒØ¨Ø©', order.vehicleNumber ?? '-'),
              _detailChip('Ø§Ù„ÙˆÙ‚ÙˆØ¯', order.fuelType ?? '-'),
              _detailChip(
                'Ø§Ù„ÙƒÙ…ÙŠØ©',
                '${order.quantity ?? 0} ${order.unit ?? ''}'.trim(),
              ),
              _detailChip(
                'Ù…ÙˆØ¹Ø¯ Ø§Ù„ØªØ­Ù…ÙŠÙ„',
                _formatSchedule(order.loadingDate, order.loadingTime),
              ),
              _detailChip(
                'Ù…ÙˆØ¹Ø¯ Ø§Ù„ÙˆØµÙˆÙ„',
                _formatSchedule(arrivalDate, order.arrivalTime),
              ),
              _detailChip('ØªØ§Ø±ÙŠØ® Ø§Ù„ØªÙˆØ¬ÙŠÙ‡', _formatDate(order.movementDirectedAt)),
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
                        screenTitle: 'ØªÙØ§ØµÙŠÙ„ Ø£Ø±Ø´ÙØ© Ø§Ù„Ø·Ù„Ø¨',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ø§Ù„ØªÙØ§ØµÙŠÙ„'),
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
                label: const Text('Ø¥Ù†Ù‡Ø§Ø¡'),
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
