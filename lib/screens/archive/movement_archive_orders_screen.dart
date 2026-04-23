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
import 'package:order_tracker/utils/platform_file_bytes.dart';
import 'package:order_tracker/utils/tax_invoice_parser.dart';
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
    final invoiceNumberController = TextEditingController();
    final invoiceDateController = TextEditingController();
    final supplierNameController = TextEditingController();
    final supplierVatController = TextEditingController();
    final supplierAddressController = TextEditingController();
    final supplierPostalController = TextEditingController();
    final supplierBuildingController = TextEditingController();
    final supplierCommercialController = TextEditingController();
    final customerNameController = TextEditingController();
    final customerVatController = TextEditingController();
    final customerAddressController = TextEditingController();
    final customerPostalController = TextEditingController();
    final customerBuildingController = TextEditingController();
    final customerCommercialController = TextEditingController();
    final referenceNumberController = TextEditingController();
    final transportOrderNumberController = TextEditingController();
    final itemDescriptionController = TextEditingController();
    final fromLocationController = TextEditingController();
    final toLocationController = TextEditingController();
    final invoiceSubtotalController = TextEditingController();
    final invoiceVatController = TextEditingController();
    final invoiceTotalController = TextEditingController();
    final vatRate = _vatRateForOrder(order);
    var taxInvoiceFiles = <PlatformFile>[];
    var fuelReceiptFiles = <PlatformFile>[];
    var actualQuantityStatementFiles = <PlatformFile>[];
    var addAllIncludedVat = true;
    var calculateUsingActualQuantity = false;
    var saving = false;
    TaxInvoiceData? parsedTaxInvoice;
    double? actualSupplyQuantity;
    double calculationQuantity = _orderQuantity(order);
    double? literPrice;
    double subtotal = 0;
    double vatAmount = 0;
    double totalAfterVat = 0;

    void fillInvoiceMetaFromOrderIfEmpty() {
      if (invoiceDateController.text.trim().isEmpty) {
        invoiceDateController.text = _formatDate(DateTime.now());
      }

      final supplierName =
          order.supplier?.company ??
          order.supplierCompany ??
          order.supplierName ??
          '';
      if (supplierNameController.text.trim().isEmpty) {
        supplierNameController.text = supplierName.trim();
      }
      if (supplierVatController.text.trim().isEmpty) {
        supplierVatController.text = (order.supplier?.taxNumber ?? '').trim();
      }

      final customerName = (order.movementCustomerName ?? '').trim().isNotEmpty
          ? order.movementCustomerName!
          : (order.customer?.name ?? '');
      if (customerNameController.text.trim().isEmpty) {
        customerNameController.text = customerName.trim();
      }
      if (customerVatController.text.trim().isEmpty) {
        customerVatController.text = (order.customer?.taxNumber ?? '').trim();
      }
    }

    void fillInvoiceTotalsFromCalculationIfEmpty() {
      if (subtotal <= 0) return;
      if (invoiceSubtotalController.text.trim().isEmpty) {
        invoiceSubtotalController.text = _moneyText(subtotal);
      }
      if (invoiceVatController.text.trim().isEmpty) {
        invoiceVatController.text = _moneyText(vatAmount);
      }
      if (invoiceTotalController.text.trim().isEmpty) {
        invoiceTotalController.text = _moneyText(totalAfterVat);
      }
    }

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
      fillInvoiceMetaFromOrderIfEmpty();
      fillInvoiceTotalsFromCalculationIfEmpty();
    }

    fillInvoiceMetaFromOrderIfEmpty();
    if (literPriceController.text.trim().isEmpty) {
      final pricing =
          order.transportPricingOverride ??
          order.pricingSnapshot ??
          const <String, dynamic>{};
      final value =
          pricing['archiveLiterPrice'] ??
          pricing['unitPricePerLiter'] ??
          order.unitPrice ??
          0;
      final asDouble = value is num
          ? value.toDouble()
          : double.tryParse(value.toString());
      if (asDouble != null && asDouble > 0) {
        literPriceController.text = asDouble.toString();
        recalculateSaleValue();
      }
    }

    Future<void> autofillFromTaxInvoice(StateSetter setDialogState) async {
      if (taxInvoiceFiles.isEmpty) return;
      final file = taxInvoiceFiles.firstWhere(
        (item) => (item.extension ?? '').toLowerCase() == 'pdf',
        orElse: () => taxInvoiceFiles.first,
      );
      final ext = (file.extension ?? '').toLowerCase();
      if (ext != 'pdf') return;

      try {
        final bytes = await readPlatformFileBytes(file);
        if (bytes == null || bytes.isEmpty) {
          throw Exception('تعذر قراءة ملف الفاتورة');
        }

        final data = TaxInvoiceParser.parse(bytes);
        parsedTaxInvoice = data;

        if (data.toJson().isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لم يتم العثور على بيانات قابلة للقراءة داخل ملف الفاتورة (قد يكون نموذج فارغ أو مسح ضوئي). أدخل البيانات يدوياً أو أرفق فاتورة تحتوي نصوص/قيم.',
              ),
            ),
          );
        }

        void setIfProvided(TextEditingController c, String? v) {
          final value = (v ?? '').trim();
          if (value.isEmpty) return;
          c.text = value;
        }

        setIfProvided(invoiceNumberController, data.invoiceNumber);
        setIfProvided(invoiceDateController, data.invoiceDateText);
        setIfProvided(supplierNameController, data.supplierName);
        setIfProvided(supplierVatController, data.supplierVatNumber);
        setIfProvided(supplierAddressController, data.supplierAddress);
        setIfProvided(supplierPostalController, data.supplierPostalCode);
        setIfProvided(supplierBuildingController, data.supplierBuildingNumber);
        setIfProvided(
          supplierCommercialController,
          data.supplierCommercialNumber,
        );
        setIfProvided(customerNameController, data.customerName);
        setIfProvided(customerVatController, data.customerVatNumber);
        setIfProvided(customerAddressController, data.customerAddress);
        setIfProvided(customerPostalController, data.customerPostalCode);
        setIfProvided(customerBuildingController, data.customerBuildingNumber);
        setIfProvided(
          customerCommercialController,
          data.customerCommercialNumber,
        );
        setIfProvided(referenceNumberController, data.referenceNumber);
        setIfProvided(
          transportOrderNumberController,
          data.transportOrderNumber,
        );
        setIfProvided(itemDescriptionController, data.itemDescription);
        setIfProvided(fromLocationController, data.fromLocation);
        setIfProvided(toLocationController, data.toLocation);

        if (data.subtotalBeforeVat != null) {
          invoiceSubtotalController.text = _moneyText(data.subtotalBeforeVat!);
        }
        if (data.vatAmount != null) {
          invoiceVatController.text = _moneyText(data.vatAmount!);
        }
        if (data.totalWithVat != null) {
          invoiceTotalController.text = _moneyText(data.totalWithVat!);
        }

        final invoiceSubtotal = _parseAmount(invoiceSubtotalController.text);
        final invoiceQuantity = data.quantity != null && data.quantity! > 0
            ? data.quantity!
            : _orderQuantity(order);
        if (invoiceQuantity > 0) {
          calculateUsingActualQuantity = false;
          actualSupplyQuantityController.text = invoiceQuantity.toString();
          if (invoiceSubtotal != null && invoiceSubtotal > 0) {
            literPriceController.text = (invoiceSubtotal / invoiceQuantity)
                .toString();
          }
        }

        setDialogState(recalculateSaleValue);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تعبئة بيانات الفاتورة تلقائياً: $e')),
        );
      }
    }

    Future<void> submit(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final invoiceSubtotal = _parseAmount(invoiceSubtotalController.text);
      final invoiceVat = _parseAmount(invoiceVatController.text);
      final invoiceTotal = _parseAmount(invoiceTotalController.text);

      final derivedSubtotal =
          invoiceSubtotal ??
          (invoiceTotal != null && invoiceVat != null
              ? (invoiceTotal - invoiceVat)
              : null);

      final derivedVat =
          invoiceVat ??
          (invoiceTotal != null && invoiceSubtotal != null
              ? (invoiceTotal - invoiceSubtotal)
              : (derivedSubtotal != null ? (derivedSubtotal * vatRate) : null));
      final derivedTotal =
          invoiceTotal ??
          (derivedSubtotal != null && derivedVat != null
              ? (derivedSubtotal + derivedVat)
              : null);

      final usedQuantity =
          (parsedTaxInvoice?.quantity != null &&
              parsedTaxInvoice!.quantity! > 0)
          ? parsedTaxInvoice!.quantity!
          : _orderQuantity(order);

      final derivedLiterPrice =
          (derivedSubtotal != null && usedQuantity > 0 && derivedSubtotal > 0)
          ? (derivedSubtotal / usedQuantity)
          : null;

      final saleValue = derivedTotal;
      final transportValue = parsedTaxInvoice?.transportValueWithVat ?? 0;

      if (taxInvoiceFiles.isEmpty ||
          fuelReceiptFiles.isEmpty ||
          actualQuantityStatementFiles.isEmpty ||
          saleValue == null ||
          derivedSubtotal == null ||
          derivedVat == null ||
          derivedLiterPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'أرفق الفاتورة وسند الاستلام وسند الكمية الفعلية وتأكد من تعبئة إجماليات الفاتورة.',
            ),
          ),
        );
        return;
      }

      setDialogState(() => saving = true);
      setState(() => _busyOrderId = order.id);

      final success = await context
          .read<OrderProvider>()
          .completeMovementArchiveOrder(
            orderId: order.id,
            taxInvoiceFiles: taxInvoiceFiles,
            fuelReceiptFiles: fuelReceiptFiles,
            actualQuantityStatementFiles: actualQuantityStatementFiles,
            actualSupplyQuantity: null,
            calculationQuantitySource: 'order',
            literPrice: derivedLiterPrice,
            saleSubtotal: derivedSubtotal,
            saleVatAmount: derivedVat,
            saleValue: saleValue,
            transportValue: transportValue,
            addAllIncludedVat: addAllIncludedVat,
            taxInvoiceData:
                parsedTaxInvoice?.toJson() ??
                <String, dynamic>{
                  if (invoiceNumberController.text.trim().isNotEmpty)
                    'invoiceNumber': invoiceNumberController.text.trim(),
                  if (invoiceDateController.text.trim().isNotEmpty)
                    'invoiceDateText': invoiceDateController.text.trim(),
                  if (supplierNameController.text.trim().isNotEmpty)
                    'supplierName': supplierNameController.text.trim(),
                  if (supplierVatController.text.trim().isNotEmpty)
                    'supplierVatNumber': supplierVatController.text.trim(),
                  if (supplierAddressController.text.trim().isNotEmpty)
                    'supplierAddress': supplierAddressController.text.trim(),
                  if (supplierPostalController.text.trim().isNotEmpty)
                    'supplierPostalCode': supplierPostalController.text.trim(),
                  if (supplierBuildingController.text.trim().isNotEmpty)
                    'supplierBuildingNumber': supplierBuildingController.text
                        .trim(),
                  if (supplierCommercialController.text.trim().isNotEmpty)
                    'supplierCommercialNumber': supplierCommercialController
                        .text
                        .trim(),
                  if (customerNameController.text.trim().isNotEmpty)
                    'customerName': customerNameController.text.trim(),
                  if (customerVatController.text.trim().isNotEmpty)
                    'customerVatNumber': customerVatController.text.trim(),
                  if (customerAddressController.text.trim().isNotEmpty)
                    'customerAddress': customerAddressController.text.trim(),
                  if (customerPostalController.text.trim().isNotEmpty)
                    'customerPostalCode': customerPostalController.text.trim(),
                  if (customerBuildingController.text.trim().isNotEmpty)
                    'customerBuildingNumber': customerBuildingController.text
                        .trim(),
                  if (customerCommercialController.text.trim().isNotEmpty)
                    'customerCommercialNumber': customerCommercialController
                        .text
                        .trim(),
                  if (referenceNumberController.text.trim().isNotEmpty)
                    'referenceNumber': referenceNumberController.text.trim(),
                  if (transportOrderNumberController.text.trim().isNotEmpty)
                    'transportOrderNumber': transportOrderNumberController.text
                        .trim(),
                  if (itemDescriptionController.text.trim().isNotEmpty)
                    'itemDescription': itemDescriptionController.text.trim(),
                  if (fromLocationController.text.trim().isNotEmpty)
                    'fromLocation': fromLocationController.text.trim(),
                  if (toLocationController.text.trim().isNotEmpty)
                    'toLocation': toLocationController.text.trim(),
                  if (invoiceSubtotalController.text.trim().isNotEmpty)
                    'subtotalBeforeVat': _parseAmount(
                      invoiceSubtotalController.text,
                    ),
                  if (invoiceVatController.text.trim().isNotEmpty)
                    'vatAmount': _parseAmount(invoiceVatController.text),
                  if (invoiceTotalController.text.trim().isNotEmpty)
                    'totalWithVat': _parseAmount(invoiceTotalController.text),
                  if (parsedTaxInvoice?.transportValueWithVat != null)
                    'transportValueWithVat':
                        parsedTaxInvoice!.transportValueWithVat,
                },
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
        final error =
            context.read<OrderProvider>().error ?? 'تعذر إنهاء أرشفة الطلب.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }

      final dialogElement = dialogContext as Element;
      if (dialogElement.mounted && Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop();
      }
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
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async => !saving,
              child: AlertDialog(
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
                          if (!mounted) return;
                          await autofillFromTaxInvoice(setDialogState);
                        },
                      ),
                      if (taxInvoiceFiles.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        _invoiceDataCard(
                          invoiceNumberController: invoiceNumberController,
                          invoiceDateController: invoiceDateController,
                          supplierNameController: supplierNameController,
                          supplierVatController: supplierVatController,
                          supplierAddressController: supplierAddressController,
                          supplierPostalController: supplierPostalController,
                          supplierBuildingController:
                              supplierBuildingController,
                          supplierCommercialController:
                              supplierCommercialController,
                          customerNameController: customerNameController,
                          customerVatController: customerVatController,
                          customerAddressController: customerAddressController,
                          customerPostalController: customerPostalController,
                          customerBuildingController:
                              customerBuildingController,
                          customerCommercialController:
                              customerCommercialController,
                          referenceNumberController: referenceNumberController,
                          transportOrderNumberController:
                              transportOrderNumberController,
                          itemDescriptionController: itemDescriptionController,
                          fromLocationController: fromLocationController,
                          toLocationController: toLocationController,
                          invoiceSubtotalController: invoiceSubtotalController,
                          invoiceVatController: invoiceVatController,
                          invoiceTotalController: invoiceTotalController,
                        ),
                      ],
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
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () => submit(setDialogState, dialogContext),
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
            ),
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
    invoiceNumberController.dispose();
    invoiceDateController.dispose();
    supplierNameController.dispose();
    supplierVatController.dispose();
    supplierAddressController.dispose();
    supplierPostalController.dispose();
    supplierBuildingController.dispose();
    supplierCommercialController.dispose();
    customerNameController.dispose();
    customerVatController.dispose();
    customerAddressController.dispose();
    customerPostalController.dispose();
    customerBuildingController.dispose();
    customerCommercialController.dispose();
    referenceNumberController.dispose();
    transportOrderNumberController.dispose();
    itemDescriptionController.dispose();
    fromLocationController.dispose();
    toLocationController.dispose();
    invoiceSubtotalController.dispose();
    invoiceVatController.dispose();
    invoiceTotalController.dispose();
  }

  Widget _riyalSymbol({required Color color, double size = 14}) {
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
    Widget item(
      String label,
      String value, {
      Color? color,
      bool currency = false,
    }) {
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
            item('السعر قبل الضريبة', _moneyText(subtotal), currency: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            item('الضريبة $vatPercent%', _moneyText(vatAmount), currency: true),
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
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.16),
        ),
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

  Widget _invoiceDataCard({
    required TextEditingController invoiceNumberController,
    required TextEditingController invoiceDateController,
    required TextEditingController supplierNameController,
    required TextEditingController supplierVatController,
    required TextEditingController supplierAddressController,
    required TextEditingController supplierPostalController,
    required TextEditingController supplierBuildingController,
    required TextEditingController supplierCommercialController,
    required TextEditingController customerNameController,
    required TextEditingController customerVatController,
    required TextEditingController customerAddressController,
    required TextEditingController customerPostalController,
    required TextEditingController customerBuildingController,
    required TextEditingController customerCommercialController,
    required TextEditingController referenceNumberController,
    required TextEditingController transportOrderNumberController,
    required TextEditingController itemDescriptionController,
    required TextEditingController fromLocationController,
    required TextEditingController toLocationController,
    required TextEditingController invoiceSubtotalController,
    required TextEditingController invoiceVatController,
    required TextEditingController invoiceTotalController,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.2)),
        color: AppColors.infoBlue.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'بيانات الفاتورة الضريبية',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: invoiceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الفاتورة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: invoiceDateController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الفاتورة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'بيانات الشركة',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: supplierNameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: supplierVatController,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الضريبي',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'بيانات العميل',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: customerNameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: customerVatController,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الضريبي',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'تفاصيل إضافية (من الفاتورة)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDarkBlue,
              ),
            ),
            children: <Widget>[
              TextField(
                controller: supplierAddressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: supplierPostalController,
                      decoration: const InputDecoration(
                        labelText: 'الرمز البريدي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: supplierBuildingController,
                      decoration: const InputDecoration(
                        labelText: 'رقم المبنى',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: supplierCommercialController,
                decoration: const InputDecoration(
                  labelText: 'السجل التجاري',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: customerAddressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: customerPostalController,
                      decoration: const InputDecoration(
                        labelText: 'الرمز البريدي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: customerBuildingController,
                      decoration: const InputDecoration(
                        labelText: 'رقم المبنى',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: customerCommercialController,
                decoration: const InputDecoration(
                  labelText: 'السجل التجاري',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: referenceNumberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم مرجع ارامكو',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: transportOrderNumberController,
                      decoration: const InputDecoration(
                        labelText: 'امر نقل رقم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: itemDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'اسم المادة (DES)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: fromLocationController,
                      decoration: const InputDecoration(
                        labelText: 'موقع التحميل (From)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: toLocationController,
                      decoration: const InputDecoration(
                        labelText: 'موقع التنزيل (To)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: invoiceSubtotalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الإجمالي قبل الضريبة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: invoiceVatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ضريبة القيمة المضافة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: invoiceTotalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الإجمالي شامل الضريبة',
              border: OutlineInputBorder(),
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
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
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
              _detailChip(
                'تاريخ التوجيه',
                _formatDate(order.movementDirectedAt),
              ),
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
