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
  static const PdfColor _blueDark = PdfColor.fromInt(0xFF1A2980);
  static const PdfColor _blueMedium = PdfColor.fromInt(0xFF2646A2);
  static const PdfColor _blueLight = PdfColor.fromInt(0xFF7FB3E6);

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
        fontFallback: [cairoRegular],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 20),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: cairoRegular,
            bold: cairoBold,
            fontFallback: [cairoRegular],
          ),
          buildBackground: (_) => _buildBackground(),
        ),
        maxPages: 250,
        header: (_) => _buildHeader(logoImage: logo, request: request),
        footer: (context) =>
            _buildFooter(context: context, generatedAt: request.generatedAt),
        build: (_) => <pw.Widget>[
          _buildReportSummary(request: request, orders: orders),
          pw.SizedBox(height: 12),
          if (orders.isEmpty) _buildEmptyState() else _buildOrdersTable(orders),
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
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.Container(
            width: 58,
            height: 58,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColors.blue100, width: 0.8),
            ),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: <pw.Widget>[
                pw.Text(
                  request.companyArabicName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  request.companyEnglishName,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.blue900,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text(
                      'الرقم الموحد: ${request.unifiedNumber}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.Text(
                      request.title,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _blueDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _blueDark, width: 1.3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'صفحة ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
          pw.Text(
            'ALBUHAIRA ALARABIA',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
          pw.Text(
            DateFormat('yyyy/MM/dd HH:mm').format(generatedAt),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportSummary({
    required MovementOrdersReportPdfRequest request,
    required List<Order> orders,
  }) {
    final totalOrders = orders.length;
    final supplierOrders = orders
        .where((order) => order.orderSource == 'مورد')
        .length;
    final customerOrders = orders.where(_isCustomerRelatedOrder).length;
    final directedOrders = orders
        .where((order) => order.isMovementDirected)
        .length;
    final pendingOrders = orders
        .where(
          (order) =>
              order.isMovementPendingDriver || order.isMovementPendingDispatch,
        )
        .length;

    final totalQuantity = orders.fold<double>(
      0,
      (sum, order) => sum + (order.quantity ?? 0),
    );
    final generatedBy = (request.generatedByName ?? '').trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColors.blue100, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: <pw.Widget>[
              pw.Text(
                request.title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _blueDark,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Wrap(
                spacing: 12,
                runSpacing: 6,
                children: <pw.Widget>[
                  _metaChip('الفترة', request.periodLabel),
                  _metaChip('نوع البيانات', request.scopeLabel),
                  _metaChip(
                    'تاريخ التصدير',
                    DateFormat('yyyy/MM/dd HH:mm').format(request.generatedAt),
                  ),
                  _metaChip(
                    'المصدر',
                    generatedBy.isEmpty ? 'غير محدد' : generatedBy,
                  ),
                  _metaChip('اعتماد التقرير', 'حسب تاريخ الطلب'),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: <pw.Widget>[
            _summaryCard('إجمالي الطلبات', totalOrders.toString(), _blueDark),
            pw.SizedBox(width: 8),
            _summaryCard(
              'طلبات المورد',
              supplierOrders.toString(),
              _blueMedium,
            ),
            pw.SizedBox(width: 8),
            _summaryCard('طلبات العميل', customerOrders.toString(), _blueLight),
            pw.SizedBox(width: 8),
            _summaryCard(
              'الطلبات الموجهة',
              directedOrders.toString(),
              PdfColors.green700,
            ),
            pw.SizedBox(width: 8),
            _summaryCard(
              'بانتظار الإجراء',
              pendingOrders.toString(),
              PdfColors.orange700,
            ),
            pw.SizedBox(width: 8),
            _summaryCard(
              'إجمالي الكمية',
              totalQuantity == 0 ? '0' : _formatNumber(totalQuantity),
              PdfColors.teal700,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _metaChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: PdfColors.blue100, width: 0.7),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8.8, color: PdfColors.grey800),
          children: <pw.TextSpan>[
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: color, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildOrdersTable(List<Order> orders) {
    final headers = <String>[
      '#',
      'رقم الطلب',
      'المصدر',
      'المورد',
      'العميل',
      'الحالة',
      'تاريخ الطلب',
      'التحميل',
      'الوصول',
      'الكمية',
      'السائق / المركبة',
      'الموقع',
      'ملاحظات',
    ];

    final rows = List<List<String>>.generate(orders.length, (index) {
      final order = orders[index];
      return <String>[
        (index + 1).toString(),
        _textOrDash(order.orderNumber),
        _sourceLabel(order),
        _compactText(order.supplierName, 30),
        _compactText(_customerLabel(order), 28),
        _compactText(order.status, 24),
        DateFormat('yyyy/MM/dd').format(order.orderDate),
        _formatDateWithTime(order.loadingDate, order.loadingTime),
        _formatDateWithTime(order.arrivalDate, order.arrivalTime),
        _formatQuantity(order),
        _compactText(_driverVehicleLabel(order), 24),
        _compactText(_locationLabel(order), 28),
        _compactText(order.notes, 70),
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: _blueDark),
      headerStyle: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 6.1, color: PdfColors.black),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(0.35),
        1: const pw.FlexColumnWidth(0.85),
        2: const pw.FlexColumnWidth(0.65),
        3: const pw.FlexColumnWidth(1.1),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(0.85),
        6: const pw.FlexColumnWidth(0.75),
        7: const pw.FlexColumnWidth(0.95),
        8: const pw.FlexColumnWidth(0.95),
        9: const pw.FlexColumnWidth(0.75),
        10: const pw.FlexColumnWidth(1.1),
        11: const pw.FlexColumnWidth(1.0),
        12: const pw.FlexColumnWidth(1.6),
      },
    );
  }

  static pw.Widget _buildEmptyState() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.blue100, width: 0.8),
      ),
      child: pw.Center(
        child: pw.Text(
          'لا توجد طلبات مطابقة للفلاتر المحددة.',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ),
    );
  }

  static bool _isCustomerRelatedOrder(Order order) {
    final movementCustomer = (order.movementCustomerName ?? '').trim();
    final customerName = (order.customer?.name ?? '').trim();
    return order.orderSource == 'عميل' ||
        movementCustomer.isNotEmpty ||
        customerName.isNotEmpty;
  }

  static String _sourceLabel(Order order) {
    switch (order.orderSource) {
      case 'مورد':
        return 'مورد';
      case 'عميل':
        return 'عميل';
      case 'مدمج':
        return 'مدمج';
      default:
        return _textOrDash(order.orderSource);
    }
  }

  static String _customerLabel(Order order) {
    final movementCustomer = (order.movementCustomerName ?? '').trim();
    if (movementCustomer.isNotEmpty) return movementCustomer;
    final customerName = (order.customer?.name ?? '').trim();
    if (customerName.isNotEmpty) return customerName;
    return '-';
  }

  static String _driverVehicleLabel(Order order) {
    final driverName = (order.driverName ?? order.driver?.name ?? '').trim();
    final vehicleNumber = (order.vehicleNumber ?? '').trim();
    if (driverName.isEmpty && vehicleNumber.isEmpty) return '-';
    if (driverName.isNotEmpty && vehicleNumber.isNotEmpty) {
      return '$driverName - $vehicleNumber';
    }
    return driverName.isNotEmpty ? driverName : vehicleNumber;
  }

  static String _locationLabel(Order order) {
    final city = (order.city ?? '').trim();
    final area = (order.area ?? '').trim();
    if (city.isEmpty && area.isEmpty) return '-';
    if (city.isNotEmpty && area.isNotEmpty) return '$city - $area';
    return city.isNotEmpty ? city : area;
  }

  static String _formatDateWithTime(DateTime date, String? time) {
    final dateText = DateFormat('yyyy/MM/dd').format(date);
    final safeTime = (time ?? '').trim();
    return safeTime.isEmpty ? dateText : '$dateText $safeTime';
  }

  static String _formatQuantity(Order order) {
    final quantity = order.quantity;
    if (quantity == null) return '-';
    final unit = (order.unit ?? '').trim();
    final value = _formatNumber(quantity);
    return unit.isEmpty ? value : '$value $unit';
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _compactText(String? value, int maxChars) {
    final text = _textOrDash(value);
    if (text == '-') return text;
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
  }

  static String _textOrDash(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  static pw.Widget _buildBackground() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.LayoutBuilder(
        builder: (_, constraints) {
          final width =
              constraints?.maxWidth ?? PdfPageFormat.a4.landscape.width;
          final height =
              constraints?.maxHeight ?? PdfPageFormat.a4.landscape.height;

          return pw.Stack(
            children: <pw.Widget>[
              pw.Polygon(
                points: <PdfPoint>[
                  PdfPoint(0, 30),
                  PdfPoint(width * 0.78, 30),
                  PdfPoint(width * 0.61, 68),
                  PdfPoint(0, 68),
                ],
                fillColor: _blueLight,
              ),
              pw.Polygon(
                points: <PdfPoint>[
                  PdfPoint(0, 15),
                  PdfPoint(width * 0.74, 15),
                  PdfPoint(width * 0.58, 49),
                  PdfPoint(0, 49),
                ],
                fillColor: _blueMedium,
              ),
              pw.Polygon(
                points: <PdfPoint>[
                  PdfPoint(0, 0),
                  PdfPoint(width * 0.70, 0),
                  PdfPoint(width * 0.55, 30),
                  PdfPoint(0, 30),
                ],
                fillColor: _blueDark,
              ),
              pw.Polygon(
                points: <PdfPoint>[
                  PdfPoint(width, height - (height * 0.16)),
                  PdfPoint(width, height),
                  PdfPoint(width - (width * 0.22), height),
                  PdfPoint(width - (width * 0.18), height - (height * 0.16)),
                ],
                fillColor: _blueDark,
              ),
            ],
          );
        },
      ),
    );
  }
}
