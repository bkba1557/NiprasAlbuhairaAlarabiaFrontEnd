import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class MovementOrdersReportPdfRequest {
  const MovementOrdersReportPdfRequest({
    required this.title,
    required this.periodLabel,
    required this.scopeLabel,
    required this.orders,
    required this.generatedAt,
    this.generatedByName,
    this.companyArabicName = 'شركة البحيرة العربية',
    this.companyEnglishName = 'ALBUHAIRA ALARABIA CO.',
    this.unifiedNumber = '7011144750',
  });

  final String title;
  final String periodLabel;
  final String scopeLabel;
  final List<Order> orders;
  final DateTime generatedAt;
  final String? generatedByName;
  final String companyArabicName;
  final String companyEnglishName;
  final String unifiedNumber;
}

class MovementOrdersReportPdfService {
  static const List<String> _completedStatusKeywords = <String>[
    'تم التنفيذ',
    'تم التسليم',
    'مكتمل',
  ];
  static const List<String> _canceledStatusKeywords = <String>[
    'ملغي',
    'ملغى',
    'ملغاة',
    'تم الإلغاء',
    'إلغاء',
  ];
  static const List<String> _purchaseRequestTypeKeywords = <String>[
    'purchase',
    'buy',
    'شراء',
  ];
  static const List<String> _transportRequestTypeKeywords = <String>[
    'transport',
    'delivery',
    'نقل',
  ];

  static pw.MemoryImage? _cachedLogo;
  static pw.Font? _cachedCairoRegular;
  static pw.Font? _cachedCairoBold;

  static Future<Uint8List> buildPdfBytes(
    MovementOrdersReportPdfRequest request,
  ) async {
    final logo = await _loadLogoImage();
    final cairoRegular = await _loadCairoRegular();
    final cairoBold = await _loadCairoBold();

    final orders = List<Order>.from(request.orders)
      ..sort((a, b) {
        final byOrderDate = a.orderDate.compareTo(b.orderDate);
        if (byOrderDate != 0) return byOrderDate;
        return a.createdAt.compareTo(b.createdAt);
      });

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: cairoRegular,
        bold: cairoBold,
        fontFallback: <pw.Font>[cairoRegular],
      ),
    );

    final estimatedPages = (orders.length / 22).ceil() + 8;
    final maxPages = math.max(60, math.min(6000, estimatedPages));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: maxPages,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
        theme: pw.ThemeData.withFont(
          base: cairoRegular,
          bold: cairoBold,
          fontFallback: <pw.Font>[cairoRegular],
        ),
        header: (context) => context.pageNumber == 1
            ? _buildHeader(logoImage: logo, request: request)
            : pw.SizedBox(),
        footer: (context) => context.pageNumber == context.pagesCount
            ? _buildFooter(context)
            : pw.SizedBox(),
        build: (_) => <pw.Widget>[
          if (orders.isEmpty)
            _buildEmptyState()
          else ...<pw.Widget>[
            _buildOrdersTable(orders),
            pw.NewPage(),
            ..._buildStatsWidgets(request, orders),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static Future<pw.MemoryImage> _loadLogoImage() async {
    final cached = _cachedLogo;
    if (cached != null) return cached;
    final logoData = await rootBundle.load(AppImages.logo);
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    _cachedLogo = logo;
    return logo;
  }

  static Future<pw.Font> _loadCairoRegular() async {
    final cached = _cachedCairoRegular;
    if (cached != null) return cached;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    _cachedCairoRegular = font;
    return font;
  }

  static Future<pw.Font> _loadCairoBold() async {
    final cached = _cachedCairoBold;
    if (cached != null) return cached;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    _cachedCairoBold = font;
    return font;
  }

  static pw.Widget _buildHeader({
    required pw.MemoryImage logoImage,
    required MovementOrdersReportPdfRequest request,
  }) {
    final companyName = _sanitizePdfText(request.companyArabicName);
    final exportDate = DateFormat('yyyy/MM/dd HH:mm').format(request.generatedAt);
    final periodLabel = _sanitizePdfText(request.periodLabel);
    final scopeLabel = _sanitizePdfText(request.scopeLabel);

    return pw.SizedBox(
      height: 60,
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.7),
        ),
        child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Container(
                height: 3,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: <pw.Widget>[
                  pw.SizedBox(
                    width: 34,
                    height: 34,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: <pw.Widget>[
                        pw.Text(
                          companyName,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                          maxLines: 1,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'الرقم الوطني: ${request.unifiedNumber}  |  نوع التقرير: $scopeLabel',
                          style: const pw.TextStyle(fontSize: 6.2),
                          maxLines: 1,
                        ),
                        pw.Text(
                          'الفترة: $periodLabel  |  تاريخ التصدير: $exportDate',
                          style: const pw.TextStyle(fontSize: 6.2),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.SizedBox(
      height: 20,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey600, width: 0.6),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              'توقيع المدير العام: __________',
              style: const pw.TextStyle(fontSize: 5.8),
            ),
            pw.Text(
              'صفحة ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 5.8),
            ),
            pw.Text(
              'توقيع رئيس مجلس الإدارة: __________',
              style: const pw.TextStyle(fontSize: 5.8),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildOrdersTable(List<Order> orders) {
    const headers = <String>[
      'رقم طلب المورد',
      'اسم المورد',
      'اسم العميل',
      'اسم السائق',
      'نوع الوقود',
      'الكمية',
      'التاريخ',
      'الملاحظات',
      'المستخدم المنشئ',
      'رقم الطلب',
    ];

    final data = orders.map((order) {
      final supplierOrderNumber = _sanitizePdfText(order.supplierOrderNumber);
      final supplierName = _sanitizePdfText(order.supplierName);
      final customerName = _pdfCustomerDisplayName(order);
      final driverName = _sanitizePdfText(
        order.driver?.name ?? order.driverName,
      );
      final fuelType = _sanitizePdfText(order.fuelType).isEmpty
          ? '-'
          : _sanitizePdfText(order.fuelType);
      final quantity = _formatPdfQuantity(order.quantity, order.unit);
      final dateText = DateFormat('yyyy/MM/dd').format(order.orderDate);
      final notes = _truncatePdfText(
        _sanitizePdfText(order.notes),
        maxChars: 80,
      );
      final createdBy = _sanitizePdfText(order.createdByName);
      final orderNumber = _sanitizePdfText(order.orderNumber);

      return <String>[
        supplierOrderNumber,
        supplierName,
        customerName,
        driverName,
        fuelType,
        quantity,
        dateText,
        notes,
        createdBy,
        orderNumber,
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.2),
      cellStyle: const pw.TextStyle(fontSize: 5.6),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 1.2,
        vertical: 0.6,
      ),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(1.1),
        2: const pw.FlexColumnWidth(1.3),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(0.85),
        5: const pw.FlexColumnWidth(0.9),
        6: const pw.FlexColumnWidth(0.9),
        7: const pw.FlexColumnWidth(2.4),
        8: const pw.FlexColumnWidth(1.0),
        9: const pw.FlexColumnWidth(1.0),
      },
    );
  }

  static List<pw.Widget> _buildStatsWidgets(
    MovementOrdersReportPdfRequest request,
    List<Order> orders,
  ) {
    final statsTitle = 'إحصائيات ${_sanitizePdfText(request.periodLabel)}';
    final activeOrders = orders
        .where((order) => !_isCanceledStatus(order.status))
        .toList();
    final completedCount = activeOrders
        .where((order) => _isCompletedStatus(order.status))
        .length;
    final purchaseCount = activeOrders
        .where((order) => _isPurchaseRequestType(order.effectiveRequestType))
        .length;
    final transportCount = activeOrders
        .where((order) => _isTransportRequestType(order.effectiveRequestType))
        .length;

    final Map<String, int> supplierCounts = <String, int>{};
    final Map<String, int> customerCounts = <String, int>{};

    for (final order in activeOrders) {
      final supplier = _pdfSupplierDisplayName(order);
      if (supplier.isNotEmpty) {
        supplierCounts[supplier] = (supplierCounts[supplier] ?? 0) + 1;
      }

      final customer = _pdfCustomerDisplayName(order);
      if (customer.isNotEmpty && customer != '-') {
        customerCounts[customer] = (customerCounts[customer] ?? 0) + 1;
      }
    }

    final supplierRows = supplierCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final customerRows = customerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return <pw.Widget>[
      pw.Text(
        statsTitle,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          _buildStatCard(
            label: 'عدد الطلبات المكتملة',
            value: completedCount.toString(),
            color: PdfColors.green700,
          ),
          _buildStatCard(
            label: 'عدد طلبات النقل',
            value: transportCount.toString(),
            color: PdfColors.orange700,
          ),
          _buildStatCard(
            label: 'عدد طلبات الشراء',
            value: purchaseCount.toString(),
            color: PdfColors.blue700,
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      ..._buildSplitNamedCountSections(
        customerRows: customerRows,
        supplierRows: supplierRows,
      ),
    ];
  }

  static pw.Widget _buildStatCard({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: <pw.Widget>[
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 6.8,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static List<pw.Widget> _buildSplitNamedCountSections({
    required List<MapEntry<String, int>> customerRows,
    required List<MapEntry<String, int>> supplierRows,
  }) {
    const rowsPerSection = 18;
    final sectionCount = math.max(
      (customerRows.length / rowsPerSection).ceil(),
      (supplierRows.length / rowsPerSection).ceil(),
    );

    if (sectionCount == 0) {
      return <pw.Widget>[
        _buildSplitNamedCountSection(
          customerRows: const <MapEntry<String, int>>[],
          supplierRows: const <MapEntry<String, int>>[],
        ),
      ];
    }

    return List<pw.Widget>.generate(sectionCount, (index) {
      final customerStart = index * rowsPerSection;
      final supplierStart = index * rowsPerSection;
      final customerEnd = math.min(
        customerStart + rowsPerSection,
        customerRows.length,
      );
      final supplierEnd = math.min(
        supplierStart + rowsPerSection,
        supplierRows.length,
      );

      return pw.Padding(
        padding: pw.EdgeInsets.only(top: index == 0 ? 0 : 8),
        child: _buildSplitNamedCountSection(
          customerRows: customerStart < customerRows.length
              ? customerRows.sublist(customerStart, customerEnd)
              : const <MapEntry<String, int>>[],
          supplierRows: supplierStart < supplierRows.length
              ? supplierRows.sublist(supplierStart, supplierEnd)
              : const <MapEntry<String, int>>[],
          sectionIndex: index,
        ),
      );
    });
  }

  static pw.Widget _buildSplitNamedCountSection({
    required List<MapEntry<String, int>> customerRows,
    required List<MapEntry<String, int>> supplierRows,
    int sectionIndex = 0,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: _buildNamedCountTable(
            title: sectionIndex == 0
                ? 'العملاء وعدد طلباتهم للفترة'
                : 'العملاء وعدد طلباتهم للفترة (${sectionIndex + 1})',
            nameHeader: 'العميل',
            rows: customerRows,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildNamedCountTable(
            title: sectionIndex == 0
                ? 'الموردين وعدد طلباتهم للفترة'
                : 'الموردين وعدد طلباتهم للفترة (${sectionIndex + 1})',
            nameHeader: 'المورد',
            rows: supplierRows,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNamedCountTable({
    required String title,
    required String nameHeader,
    required List<MapEntry<String, int>> rows,
  }) {
    final data = rows.isEmpty
        ? const <List<String>>[
            <String>['-', '0'],
          ]
        : rows
              .map((entry) => <String>[entry.key, entry.value.toString()])
              .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 3),
        pw.Table.fromTextArray(
          headers: <String>[nameHeader, 'عدد الطلبات'],
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 6.4,
          ),
          cellStyle: const pw.TextStyle(fontSize: 6.1),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.center,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 1,
          ),
          columnWidths: <int, pw.TableColumnWidth>{
            0: const pw.FlexColumnWidth(2.4),
            1: const pw.FlexColumnWidth(0.8),
          },
        ),
      ],
    );
  }

  static pw.Widget _buildEmptyState() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.7),
      ),
      child: pw.Center(
        child: pw.Text(
          'لا توجد طلبات حركة مطابقة للفلاتر المحددة.',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ),
    );
  }

  static String _pdfSupplierDisplayName(Order order) {
    final directName = _sanitizePdfText(order.supplierName);
    if (directName.isNotEmpty) return directName;

    final nestedName = _sanitizePdfText(order.supplier?.name);
    if (nestedName.isNotEmpty) return nestedName;

    final mergedName = _sanitizePdfText(
      order.mergedWithInfo?['supplierName']?.toString(),
    );
    if (mergedName.isNotEmpty) return mergedName;

    return '';
  }

  static String _pdfCustomerDisplayName(Order order) {
    final movementCustomerName = _sanitizePdfText(order.movementCustomerName);
    if (movementCustomerName.isNotEmpty) return movementCustomerName;

    final customerName = _sanitizePdfText(order.customer?.name);
    if (customerName.isNotEmpty) return customerName;

    final mergedName = _sanitizePdfText(
      order.mergedWithInfo?['customerName']?.toString(),
    );
    if (mergedName.isNotEmpty) return mergedName;

    final customerAddress = _sanitizePdfText(order.customerAddress);
    if (customerAddress.isNotEmpty) return customerAddress;

    return '-';
  }

  static bool _isCompletedStatus(String status) {
    return _statusMatches(status, _completedStatusKeywords);
  }

  static bool _isCanceledStatus(String status) {
    return _statusMatches(status, _canceledStatusKeywords);
  }

  static bool _statusMatches(String status, List<String> keywords) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final keyword in keywords) {
      final needle = keyword.trim().toLowerCase();
      if (needle.isEmpty) continue;
      if (normalized == needle || normalized.contains(needle)) return true;
    }
    return false;
  }

  static bool _isPurchaseRequestType(String? requestType) {
    return _requestTypeMatches(requestType, _purchaseRequestTypeKeywords);
  }

  static bool _isTransportRequestType(String? requestType) {
    return _requestTypeMatches(requestType, _transportRequestTypeKeywords);
  }

  static bool _requestTypeMatches(String? requestType, List<String> keywords) {
    final normalized = (requestType ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final keyword in keywords) {
      final needle = keyword.trim().toLowerCase();
      if (needle.isEmpty) continue;
      if (normalized == needle || normalized.contains(needle)) return true;
    }
    return false;
  }

  static String _sanitizePdfText(String? value) {
    if (value == null) return '';
    return value
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _truncatePdfText(String value, {int maxChars = 120}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  static String _formatPdfQuantity(double? quantity, String? unit) {
    if (quantity == null) return '-';
    final isWhole = quantity % 1 == 0;
    final value = isWhole
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    final safeUnit = _sanitizePdfText(unit);
    return safeUnit.isEmpty ? value : '$value $safeUnit';
  }
}
