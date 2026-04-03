// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:order_tracker/widgets/activity_item.dart';
import 'package:order_tracker/widgets/order_status_timeline.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedTab = 0;
  Supplier? _supplier;
  Driver? _driver;

  Timer? _countdownTimer;
  Duration? _remainingLoadingTime;
  Uint8List? _companyLogo;
  pw.Font? _cairoRegular;
  pw.Font? _cairoBold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
      _loadCompanyLogo();
      _loadSupplierDetails();
      _loadDriverDetails();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCompanyLogo() async {
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      _companyLogo = logoData.buffer.asUint8List();
    } catch (_) {
      _companyLogo = null;
    }
  }

  Future<void> _loadSupplierDetails() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = orderProvider.selectedOrder;

    if (order != null &&
        order.supplierId != null &&
        order.supplierId!.isNotEmpty) {
      try {
        // قم بجلب المورد باستخدام الـ supplierId
        // _supplier = await supplierProvider.getSupplierById(order.supplierId!);
      } catch (e) {
        debugPrint('Error loading supplier: $e');
      }
    }
  }

  Future<void> _loadDriverDetails() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = orderProvider.selectedOrder;

    if (order != null && order.driverId != null && order.driverId!.isNotEmpty) {
      try {
        // قم بجلب السائق باستخدام الـ driverId
        // _driver = await driverProvider.getDriverById(order.driverId!);
      } catch (e) {
        debugPrint('Error loading driver: $e');
      }
    }
  }

  void _startCountdown(Order order) {
    _countdownTimer?.cancel();

    // ✅ حماية كاملة من null
    if (order.loadingDate == null ||
        order.loadingTime == null ||
        order.loadingTime!.isEmpty) {
      setState(() {
        _remainingLoadingTime = null;
      });
      return;
    }

    final parts = order.loadingTime!.split(':');
    if (parts.length < 2) {
      setState(() {
        _remainingLoadingTime = null;
      });
      return;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      setState(() {
        _remainingLoadingTime = null;
      });
      return;
    }

    final loadingDateTime = DateTime(
      order.loadingDate.year,
      order.loadingDate.month,
      order.loadingDate.day,
      hour,
      minute,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final diff = loadingDateTime.difference(DateTime.now());

      if (diff.isNegative || order.status == 'تم التنفيذ') {
        timer.cancel();
        setState(() {
          _remainingLoadingTime = Duration.zero;
        });
      } else {
        setState(() {
          _remainingLoadingTime = diff;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) {
      return 'انتهى الوقت';
    }

    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    final parts = <String>[];

    if (days > 0) parts.add('$days يوم');
    if (hours > 0 || days > 0) parts.add('$hours ساعة');
    if (minutes > 0 || hours > 0 || days > 0) parts.add('$minutes دقيقة');
    parts.add('$seconds ثانية');

    return parts.join(' ');
  }

  Future<void> _loadOrderDetails() async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    await provider.fetchOrderById(widget.orderId);

    final order = provider.selectedOrder;
    if (order != null && order.status != 'تم التنفيذ') {
      _startCountdown(order);
    }
  }

  Future<void> _loadArabicFont() async {
    if (_cairoRegular != null && _cairoBold != null) return;

    try {
      final regularData = await rootBundle.load(
        'assets/fonts/Cairo-Regular.ttf',
      );
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

      _cairoRegular = pw.Font.ttf(regularData);
      _cairoBold = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('❌ Error loading Cairo font: $e');
      _cairoRegular = pw.Font.courier();
      _cairoBold = pw.Font.courierBold();
    }
  }

  // تحديد نوع الطلب - محدثة
  String _getOrderType(Order order) {
    // أولاً: التحقق من orderSource إذا كان موجوداً
    if (order.orderSource != null && order.orderSource!.isNotEmpty) {
      return order.orderSource!;
    }

    // ثانياً: التحقق من mergeStatus
    if (order.mergeStatus == 'مدمج' || order.mergeStatus == 'مكتمل') {
      return 'مدمج';
    }

    // ثالثاً: التحقق من requestType
    if (order.requestType == 'مورد' || order.isSupplierOrder) {
      return 'مورد';
    }

    if (order.requestType == 'عميل') {
      return 'عميل';
    }

    // رابعاً: التحقق من وجود عميل
    if (order.customer != null || order.customer!.name != null) {
      return 'عميل';
    }

    // أخيراً: الافتراضي
    return 'مورد';
  }

  String _safeOrderType([Order? order]) {
    final o = order ?? context.read<OrderProvider>().selectedOrder;
    if (o == null) return 'غير معروف';
    return _getOrderType(o);
  }

  // تحديد لون حسب نوع الطلب
  Color _getOrderTypeColor(String type) {
    switch (type) {
      case 'مورد':
        return AppColors.primaryBlue;
      case 'عميل':
        return AppColors.secondaryTeal;
      case 'مدمج':
        return AppColors.successGreen;
      default:
        return AppColors.mediumGray;
    }
  }

  // الحصول على اسم العميل - محدثة
  String? _getCustomerName(Order order) {
    final customer = order.customer;

    if (customer == null) return null;

    final name = customer.name;
    if (name == null || name.trim().isEmpty) return null;

    return name;
  }

  // الحصول على اسم السائق - محدثة
  String? _getDriverName(Order order) {
    if (order.driver != null && order.driver!.name.isNotEmpty) {
      return order.driver!.name;
    }
    if (order.driverName != null && order.driverName!.isNotEmpty) {
      return order.driverName;
    }
    return null;
  }

  // الحصول على هاتف السائق - محدثة
  String? _getDriverPhone(Order order) {
    if (order.driver != null && order.driver!.phone.isNotEmpty) {
      return order.driver!.phone;
    }
    if (order.driverPhone != null && order.driverPhone!.isNotEmpty) {
      return order.driverPhone;
    }
    return null;
  }

  pw.Widget _buildPdfHeader({
    required Uint8List? logo,
    required String crNumber,
    required String vatNumber,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Commercial Register',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
                pw.Text(
                  crNumber,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'VAT Number',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
                pw.Text(
                  vatNumber,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),

          pw.Container(
            width: 80,
            height: 80,
            alignment: pw.Alignment.center,
            child: logo != null
                ? pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain)
                : pw.Container(
                    width: 80,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Logo',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ),
                  ),
          ),

          pw.Expanded(
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'السجل التجاري',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.Text(
                    crNumber,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'الرقم الضريبي',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.Text(
                    vatNumber,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
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

  // عرض خيارات التصدير
  void _showExportOptions() {
    final order = Provider.of<OrderProvider>(
      context,
      listen: false,
    ).selectedOrder;
    if (order == null) return;

    final orderType = _safeOrderType(order);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'خيارات التصدير',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        orderType == 'مورد'
                            ? Icons.business
                            : orderType == 'عميل'
                            ? Icons.person
                            : Icons.link,
                        color: _getOrderTypeColor(orderType),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تقرير $orderType',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'رقم الطلب: ${order.orderNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getOrderTypeColor(orderType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getOrderTypeColor(orderType),
                          ),
                        ),
                        child: Text(
                          orderType,
                          style: TextStyle(
                            color: _getOrderTypeColor(orderType),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('تقرير تفصيلي (PDF)'),
                subtitle: const Text('تقرير كامل مع جميع التفاصيل'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportToDetailedPDF();
                },
              ),

              // ListTile(
              //   leading: const Icon(Icons.picture_as_pdf, color: Colors.orange),
              //   title: const Text('تقرير سريع (PDF)'),
              //   subtitle: const Text('ملخص الطلب الرئيسي فقط'),
              //   onTap: () async {
              //     Navigator.pop(context);
              //     await _exportToQuickPDF();
              //   },
              // ),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.share, color: AppColors.successGreen),
                title: const Text('مشاركة التقرير'),
                onTap: () {
                  Navigator.pop(context);
                  _shareOrderDetails();
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // PDF Export Functions
  // ============================================

  // Future<void> _exportToDetailedPDF() async {
  //   try {
  //     final order = context.read<OrderProvider>().selectedOrder;
  //     if (order == null) return;

  //     await _loadArabicFont();
  //     await _loadCompanyLogo();

  //     final orderType = _safeOrderType(order);

  //     final pdf = pw.Document();

  //     // إضافة جميع صفحات PDF التفصيلي
  //     pdf.addPage(_buildCoverPage(order));
  //     pdf.addPage(_buildBasicInfoPage(order));
  //     pdf.addPage(_buildCustomerSupplierPage(order));
  //     pdf.addPage(_buildDriverVehiclePage(order));
  //     pdf.addPage(_buildTechnicalDetailsPage(order));
  //     pdf.addPage(_buildTimelinePage(order));
  //     pdf.addPage(_buildFinancialDetailsPage(order));

  //     await Printing.sharePdf(
  //       bytes: await pdf.save(),
  //       filename:
  //           '${orderType}_طلب_${order.orderNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
  //     );

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text('تم تصدير التقرير التفصيلي بنجاح'),
  //           backgroundColor: AppColors.successGreen,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Error exporting PDF: $e');

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text('خطأ في تصدير PDF'),
  //           backgroundColor: AppColors.errorRed,
  //         ),
  //       );
  //     }
  //   }
  // }

  // Future<void> _exportToQuickPDF() async {
  //   try {
  //     final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  //     final order = orderProvider.selectedOrder;
  //     if (order == null) return;

  //     final orderType = _safeOrderType(order);

  //     await _loadArabicFont();

  //     final pdf = pw.Document();

  //     pdf.addPage(
  //       pw.Page(
  //         pageFormat: PdfPageFormat.a4,
  //         margin: const pw.EdgeInsets.all(28.35), // 1 سم = 28.35 نقطة
  //         theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //         build: (pw.Context context) {
  //           return pw.Directionality(
  //             textDirection: pw.TextDirection.rtl,
  //             child: pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //               children: [
  //                 // الهيدر
  //                 _buildPdfHeader(
  //                   logo: _companyLogo,
  //                   crNumber: '7011144750',
  //                   vatNumber: '313061665400003',
  //                 ),

  //                 pw.SizedBox(height: 20),

  //                 // العنوان
  //                 pw.Text(
  //                   'ملخص طلب $orderType',
  //                   style: pw.TextStyle(
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                     color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //                   ),
  //                   textAlign: pw.TextAlign.center,
  //                 ),

  //                 pw.SizedBox(height: 30),

  //                 // المعلومات الرئيسية
  //                 pw.Container(
  //                   padding: const pw.EdgeInsets.all(20),
  //                   decoration: pw.BoxDecoration(
  //                     border: pw.Border.all(
  //                       color: PdfColor.fromInt(AppColors.lightGray.value),
  //                       width: 1,
  //                     ),
  //                     borderRadius: const pw.BorderRadius.all(
  //                       pw.Radius.circular(12),
  //                     ),
  //                     color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //                   ),
  //                   child: pw.Column(
  //                     children: [
  //                       _buildPdfDetailRow('رقم الطلب', order.orderNumber),
  //                       _buildPdfDetailRow('نوع الطلب', orderType),
  //                       _buildPdfDetailRow('الحالة', order.status),
  //                       _buildPdfDetailRow(
  //                         'تاريخ الطلب',
  //                         DateFormat('yyyy/MM/dd').format(order.orderDate),
  //                       ),
  //                       if (order.supplierName != null)
  //                         _buildPdfDetailRow('المورد', order.supplierName!),
  //                       if (_getCustomerName(order) != null)
  //                         _buildPdfDetailRow(
  //                           'العميل',
  //                           _getCustomerName(order)!,
  //                         ),
  //                       if (order.fuelType != null)
  //                         _buildPdfDetailRow('نوع الوقود', order.fuelType!),
  //                       if (order.quantity != null)
  //                         _buildPdfDetailRow(
  //                           'الكمية',
  //                           '${order.quantity} ${order.unit ?? "لتر"}',
  //                         ),
  //                       if (order.totalPrice != null)
  //                         _buildPdfDetailRow(
  //                           'القيمة الإجمالية',
  //                           '${order.totalPrice!.toStringAsFixed(2)} ريال',
  //                         ),
  //                     ],
  //                   ),
  //                 ),

  //                 pw.SizedBox(height: 30),

  //                 // الموقع والمواعيد
  //                 pw.Row(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                   children: [
  //                     pw.Expanded(
  //                       child: pw.Container(
  //                         padding: const pw.EdgeInsets.all(16),
  //                         decoration: pw.BoxDecoration(
  //                           border: pw.Border.all(
  //                             color: PdfColor.fromInt(AppColors.infoBlue.value),
  //                             width: 1,
  //                           ),
  //                           borderRadius: const pw.BorderRadius.all(
  //                             pw.Radius.circular(8),
  //                           ),
  //                         ),
  //                         child: pw.Column(
  //                           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                           children: [
  //                             pw.Text(
  //                               'الموقع',
  //                               style: pw.TextStyle(
  //                                 fontSize: 16,
  //                                 fontWeight: pw.FontWeight.bold,
  //                                 color: PdfColor.fromInt(
  //                                   AppColors.infoBlue.value,
  //                                 ),
  //                               ),
  //                             ),
  //                             pw.SizedBox(height: 8),
  //                             _buildPdfDetailRow('المدينة', order.city ?? '-'),
  //                             _buildPdfDetailRow('المنطقة', order.area ?? '-'),
  //                           ],
  //                         ),
  //                       ),
  //                     ),
  //                     pw.SizedBox(width: 10),
  //                     pw.Expanded(
  //                       child: pw.Container(
  //                         padding: const pw.EdgeInsets.all(16),
  //                         decoration: pw.BoxDecoration(
  //                           border: pw.Border.all(
  //                             color: PdfColor.fromInt(
  //                               AppColors.warningOrange.value,
  //                             ),
  //                             width: 1,
  //                           ),
  //                           borderRadius: const pw.BorderRadius.all(
  //                             pw.Radius.circular(8),
  //                           ),
  //                         ),
  //                         child: pw.Column(
  //                           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                           children: [
  //                             pw.Text(
  //                               'المواعيد',
  //                               style: pw.TextStyle(
  //                                 fontSize: 16,
  //                                 fontWeight: pw.FontWeight.bold,
  //                                 color: PdfColor.fromInt(
  //                                   AppColors.warningOrange.value,
  //                                 ),
  //                               ),
  //                             ),
  //                             pw.SizedBox(height: 8),
  //                             _buildPdfDetailRow(
  //                               'التحميل',
  //                               '${DateFormat('yyyy/MM/dd').format(order.loadingDate)} ${order.loadingTime}',
  //                             ),
  //                             _buildPdfDetailRow(
  //                               'الوصول',
  //                               '${DateFormat('yyyy/MM/dd').format(order.arrivalDate)} ${order.arrivalTime}',
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),

  //                 // الفوتر
  //                 pw.Container(
  //                   margin: const pw.EdgeInsets.only(top: 30),
  //                   padding: const pw.EdgeInsets.symmetric(vertical: 12),
  //                   decoration: pw.BoxDecoration(
  //                     border: pw.Border(
  //                       top: pw.BorderSide(
  //                         color: PdfColor.fromInt(AppColors.lightGray.value),
  //                         width: 0.5,
  //                       ),
  //                     ),
  //                   ),
  //                   child: pw.Row(
  //                     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                     children: [
  //                       pw.Text(
  //                         'نظام إدارة الطلبات',
  //                         style: pw.TextStyle(
  //                           fontSize: 10,
  //                           color: PdfColor.fromInt(AppColors.mediumGray.value),
  //                         ),
  //                       ),
  //                       pw.Text(
  //                         '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
  //                         style: pw.TextStyle(
  //                           fontSize: 10,
  //                           color: PdfColor.fromInt(AppColors.mediumGray.value),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       ),
  //     );

  //     await Printing.sharePdf(
  //       bytes: await pdf.save(),
  //       filename: 'ملخص_${orderType}_طلب_${order.orderNumber}.pdf',
  //     );
  //   } catch (e) {
  //     debugPrint('Error exporting quick PDF: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('خطأ في تصدير PDF: $e'),
  //           backgroundColor: AppColors.errorRed,
  //         ),
  //       );
  //     }
  //   }
  // }

  // // ============================================
  // // Helper Functions for PDF Building (محدثة)
  // // ============================================

  // pw.Page _buildCoverPage(Order order) {
  //   final orderType = _safeOrderType(order);
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final secondaryColor = PdfColor.fromInt(AppColors.primaryDarkBlue.value);
  //   final accentColor = PdfColor.fromInt(AppColors.accentBlue.value);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35), // 1 سم
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Container(
  //           decoration: pw.BoxDecoration(
  //             gradient: pw.LinearGradient(
  //               begin: pw.Alignment.topCenter,
  //               end: pw.Alignment.bottomCenter,
  //               colors: [primaryColor, secondaryColor],
  //             ),
  //           ),
  //           child: pw.Padding(
  //             padding: const pw.EdgeInsets.all(40),
  //             child: pw.Column(
  //               mainAxisAlignment: pw.MainAxisAlignment.center,
  //               children: [
  //                 // شعار الشركة
  //                 if (_companyLogo != null)
  //                   pw.Container(
  //                     width: 120,
  //                     height: 120,
  //                     margin: const pw.EdgeInsets.only(bottom: 30),
  //                     child: pw.Image(
  //                       pw.MemoryImage(_companyLogo!),
  //                       fit: pw.BoxFit.contain,
  //                     ),
  //                   ),

  //                 pw.Text(
  //                   'نظام إدارة الطلبات',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 22,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),

  //                 pw.SizedBox(height: 40),

  //                 // عنوان التقرير
  //                 pw.Container(
  //                   padding: const pw.EdgeInsets.symmetric(vertical: 20),
  //                   child: pw.Text(
  //                     'تقرير تفصيلي للطلب',
  //                     style: pw.TextStyle(
  //                       color: PdfColors.white,
  //                       fontSize: 32,
  //                       fontWeight: pw.FontWeight.bold,

  //                     ),
  //                     textAlign: pw.TextAlign.center,
  //                   ),
  //                 ),

  //                 pw.SizedBox(height: 20),

  //                 // رقم الطلب في مربع مميز
  //                 pw.Container(
  //                   width: double.infinity,
  //                   padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //                   decoration: pw.BoxDecoration(
  //                     color: accentColor,
  //                     borderRadius: pw.BorderRadius.circular(12),
  //                     boxShadow: [
  //                       pw.BoxShadow(color: PdfColors.black, blurRadius: 10),
  //                     ],
  //                   ),
  //                   child: pw.Column(
  //                     children: [
  //                       pw.Text(
  //                         'رقم الطلب',
  //                         style: pw.TextStyle(
  //                           color: PdfColors.white,
  //                           fontSize: 18,
  //                           fontWeight: pw.FontWeight.normal,
  //                         ),
  //                       ),
  //                       pw.SizedBox(height: 8),
  //                       pw.Text(
  //                         order.orderNumber,
  //                         style: pw.TextStyle(
  //                           color: PdfColors.white,
  //                           fontSize: 28,
  //                           fontWeight: pw.FontWeight.bold,
  //                           letterSpacing: 2,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),

  //                 pw.SizedBox(height: 40),

  //                 // معلومات مختصرة
  //                 pw.Container(
  //                   padding: const pw.EdgeInsets.all(24),
  //                   decoration: pw.BoxDecoration(
  //                     color: PdfColor.fromInt(0x33FFFFFF), // شفافية بيضاء
  //                     borderRadius: pw.BorderRadius.circular(16),
  //                     border: pw.Border.all(
  //                       color: PdfColor.fromInt(0x66FFFFFF),
  //                     ),
  //                   ),
  //                   child: pw.Column(
  //                     children: [
  //                       _buildCoverDetailRow('نوع الطلب', orderType),
  //                       _buildCoverDetailRow('الحالة', order.status),
  //                       _buildCoverDetailRow(
  //                         'تاريخ الطلب',
  //                         DateFormat('yyyy/MM/dd').format(order.orderDate),
  //                       ),
  //                       if (_getCustomerName(order) != null)
  //                         _buildCoverDetailRow(
  //                           'العميل',
  //                           _getCustomerName(order)!,
  //                         ),
  //                       if (order.supplierName != null &&
  //                           order.supplierName!.isNotEmpty)
  //                         _buildCoverDetailRow('المورد', order.supplierName!),
  //                       _buildCoverDetailRow(
  //                         'تاريخ الإصدار',
  //                         DateFormat('yyyy/MM/dd').format(DateTime.now()),
  //                       ),
  //                     ],
  //                   ),
  //                 ),

  //                 pw.Spacer(),

  //                 // تذييل الغلاف
  //                 pw.Container(
  //                   padding: const pw.EdgeInsets.only(top: 20),
  //                   child: pw.Column(
  //                     children: [
  //                       pw.Divider(color: PdfColor.fromInt(0x66FFFFFF)),
  //                       pw.SizedBox(height: 10),
  //                       pw.Text(
  //                         'السجل التجاري: 7011144750 | الرقم الضريبي: 313061665400003',
  //                         style: pw.TextStyle(
  //                           color: PdfColor.fromInt(0xCCFFFFFF),
  //                           fontSize: 12,
  //                         ),
  //                         textAlign: pw.TextAlign.center,
  //                       ),
  //                       pw.SizedBox(height: 5),
  //                       pw.Text(
  //                         'تم إنشاء هذا التقرير آلياً بواسطة نظام إدارة الطلبات',
  //                         style: pw.TextStyle(
  //                           color: PdfColor.fromInt(0xCCFFFFFF),
  //                           fontSize: 10,
  //                         ),
  //                         textAlign: pw.TextAlign.center,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Widget _buildCoverDetailRow(String label, String value) {
  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.symmetric(vertical: 6),
  //     child: pw.Row(
  //       children: [
  //         pw.Expanded(
  //           flex: 2,
  //           child: pw.Text(
  //             label,
  //             style: pw.TextStyle(
  //               color: PdfColors.white,
  //               fontSize: 14,
  //               fontWeight: pw.FontWeight.bold,
  //             ),
  //             textDirection: pw.TextDirection.rtl,
  //           ),
  //         ),
  //         pw.Expanded(
  //           flex: 3,
  //           child: pw.Text(
  //             value,
  //             style: pw.TextStyle(color: PdfColors.white, fontSize: 14),
  //             textDirection: pw.TextDirection.rtl,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Page _buildBasicInfoPage(Order order) {
  //   final orderType = _safeOrderType(order);
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final backgroundColor = PdfColor.fromInt(AppColors.backgroundGray.value);
  //   final borderColor = PdfColor.fromInt(AppColors.lightGray.value);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35),
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //           children: [
  //             // الهيدر
  //             _buildPdfHeader(
  //               logo: _companyLogo,
  //               crNumber: '7011144750',
  //               vatNumber: '313061665400003',
  //             ),

  //             pw.SizedBox(height: 20),

  //             // عنوان الصفحة
  //             pw.Container(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //               decoration: pw.BoxDecoration(
  //                 color: primaryColor,
  //                 borderRadius: pw.BorderRadius.circular(8),
  //               ),
  //               child: pw.Center(
  //                 child: pw.Text(
  //                   'معلومات الطلب الأساسية',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             ),

  //             pw.SizedBox(height: 20),

  //             // جدول المعلومات الأساسية
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(16),
  //               decoration: pw.BoxDecoration(
  //                 color: backgroundColor,
  //                 borderRadius: pw.BorderRadius.circular(12),
  //                 border: pw.Border.all(color: borderColor, width: 1),
  //               ),
  //               child: pw.Column(
  //                 children: [
  //                   _buildPdfDetailRow('رقم الطلب', order.orderNumber),
  //                   _buildPdfDetailRow('نوع الطلب', orderType),
  //                   _buildPdfDetailRow('مصدر الطلب', order.orderSource),
  //                   _buildPdfDetailRow('حالة الدمج', order.mergeStatus),
  //                   _buildPdfDetailRow('حالة الطلب', order.status),
  //                   _buildPdfDetailRow(
  //                     'تاريخ الإنشاء',
  //                     DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt),
  //                   ),
  //                   _buildPdfDetailRow(
  //                     'آخر تحديث',
  //                     DateFormat('yyyy/MM/dd HH:mm').format(order.updatedAt),
  //                   ),
  //                   if (order.supplierOrderNumber != null &&
  //                       order.supplierOrderNumber!.isNotEmpty)
  //                     _buildPdfDetailRow(
  //                       'رقم طلب المورد',
  //                       order.supplierOrderNumber!,
  //                     ),
  //                 ],
  //               ),
  //             ),

  //             pw.SizedBox(height: 30),

  //             // معلومات المصدر
  //             pw.Row(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Expanded(
  //                   child: _buildInfoBox(
  //                     title: 'معلومات المصدر',
  //                     iconColor: PdfColor.fromInt(AppColors.infoBlue.value),
  //                     children: [
  //                       _buildPdfDetailRow('نوع المصدر', order.orderSource),
  //                       _buildPdfDetailRow('طلب #', order.orderNumber),
  //                       if (order.requestType != null)
  //                         _buildPdfDetailRow('نوع العملية', order.requestType!),
  //                       if (order.productType != null)
  //                         _buildPdfDetailRow('نوع المنتج', order.productType!),
  //                     ],
  //                   ),
  //                 ),
  //                 pw.SizedBox(width: 10),
  //                 pw.Expanded(
  //                   child: _buildInfoBox(
  //                     title: 'معلومات النظام',
  //                     iconColor: PdfColor.fromInt(AppColors.successGreen.value),
  //                     children: [
  //                       _buildPdfDetailRow('الحالة', order.status),
  //                       _buildPdfDetailRow('حالة الدمج', order.mergeStatus),
  //                       _buildPdfDetailRow(
  //                         'تاريخ الإنشاء',
  //                         DateFormat(
  //                           'yyyy/MM/dd HH:mm',
  //                         ).format(order.createdAt),
  //                       ),
  //                       _buildPdfDetailRow(
  //                         'آخر تحديث',
  //                         DateFormat(
  //                           'yyyy/MM/dd HH:mm',
  //                         ).format(order.updatedAt),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),

  //             _buildPageFooter(context.pageNumber, 'معلومات أساسية'),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Page _buildCustomerSupplierPage(Order order) {
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final tealColor = PdfColor.fromInt(AppColors.secondaryTeal.value);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35),
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //           children: [
  //             _buildPdfHeader(
  //               logo: _companyLogo,
  //               crNumber: '7011144750',
  //               vatNumber: '313061665400003',
  //             ),

  //             pw.SizedBox(height: 20),

  //             // عنوان الصفحة
  //             pw.Container(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //               decoration: pw.BoxDecoration(
  //                 color: primaryColor,
  //                 borderRadius: pw.BorderRadius.circular(8),
  //               ),
  //               child: pw.Center(
  //                 child: pw.Text(
  //                   'معلومات العميل والمورد',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             ),

  //             pw.SizedBox(height: 20),

  //             // معلومات العميل
  //             if (_getCustomerName(order) != null)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader('معلومات العميل', color: tealColor),
  //                   pw.SizedBox(height: 10),
  //                   _buildCustomerInfoCard(order),
  //                   pw.SizedBox(height: 30),
  //                 ],
  //               ),

  //             // معلومات المورد
  //             if (order.supplierName != null && order.supplierName!.isNotEmpty)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader('معلومات المورد', color: primaryColor),
  //                   pw.SizedBox(height: 10),
  //                   _buildSupplierInfoCard(order),
  //                   pw.SizedBox(height: 30),
  //                 ],
  //               ),

  //             // معلومات الدمج
  //             if (order.isMerged)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader(
  //                     'معلومات الدمج',
  //                     color: PdfColor.fromInt(AppColors.successGreen.value),
  //                   ),
  //                   pw.SizedBox(height: 10),
  //                   _buildMergeInfoCard(order),
  //                   pw.SizedBox(height: 30),
  //                 ],
  //               ),

  //             _buildPageFooter(context.pageNumber, 'العميل والمورد'),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Page _buildDriverVehiclePage(Order order) {
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final tealColor = PdfColor.fromInt(AppColors.secondaryTeal.value);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35),
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //           children: [
  //             _buildPdfHeader(
  //               logo: _companyLogo,
  //               crNumber: '7011144750',
  //               vatNumber: '313061665400003',
  //             ),

  //             pw.SizedBox(height: 20),

  //             // عنوان الصفحة
  //             pw.Container(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //               decoration: pw.BoxDecoration(
  //                 color: primaryColor,
  //                 borderRadius: pw.BorderRadius.circular(8),
  //               ),
  //               child: pw.Center(
  //                 child: pw.Text(
  //                   'معلومات السائق والمركبة',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             ),

  //             pw.SizedBox(height: 20),

  //             // معلومات السائق
  //             if (_getDriverName(order) != null || order.driver != null)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader('معلومات السائق', color: tealColor),
  //                   pw.SizedBox(height: 10),
  //                   _buildDriverInfoCard(order),
  //                   pw.SizedBox(height: 30),
  //                 ],
  //               ),

  //             // معلومات المركبة
  //             if (order.vehicleNumber != null &&
  //                 order.vehicleNumber!.isNotEmpty)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader(
  //                     'معلومات المركبة',
  //                     color: PdfColor.fromInt(0xFF795548),
  //                   ),
  //                   pw.SizedBox(height: 10),
  //                   _buildVehicleInfoCard(order),
  //                   pw.SizedBox(height: 30),
  //                 ],
  //               ),

  //             // معلومات التحميل والتسليم
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader(
  //                   'تفاصيل التحميل والتسليم',
  //                   color: PdfColor.fromInt(AppColors.warningOrange.value),
  //                 ),
  //                 pw.SizedBox(height: 10),
  //                 _buildLoadingInfoCard(order),
  //               ],
  //             ),

  //             _buildPageFooter(context.pageNumber, 'السائق والمركبة'),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Page _buildTechnicalDetailsPage(Order order) {
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final orangeColor = PdfColor.fromInt(AppColors.warningOrange.value);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35),
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //           children: [
  //             _buildPdfHeader(
  //               logo: _companyLogo,
  //               crNumber: '7011144750',
  //               vatNumber: '313061665400003',
  //             ),

  //             pw.SizedBox(height: 20),

  //             // عنوان الصفحة
  //             pw.Container(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //               decoration: pw.BoxDecoration(
  //                 color: primaryColor,
  //                 borderRadius: pw.BorderRadius.circular(8),
  //               ),
  //               child: pw.Center(
  //                 child: pw.Text(
  //                   'التفاصيل الفنية للطلب',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             ),

  //             pw.SizedBox(height: 20),

  //             // معلومات المنتج/الوقود
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader('تفاصيل المنتج', color: orangeColor),
  //                 pw.SizedBox(height: 10),
  //                 _buildProductInfoCard(order),
  //                 pw.SizedBox(height: 30),
  //               ],
  //             ),

  //             // معلومات الموقع
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader(
  //                   'معلومات الموقع',
  //                   color: PdfColor.fromInt(AppColors.infoBlue.value),
  //                 ),
  //                 pw.SizedBox(height: 10),
  //                 _buildLocationInfoCard(order),
  //                 pw.SizedBox(height: 30),
  //               ],
  //             ),

  //             // معلومات المواعيد
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader(
  //                   'المواعيد والتواريخ',
  //                   color: PdfColor.fromInt(AppColors.pendingYellow.value),
  //                 ),
  //                 pw.SizedBox(height: 10),
  //                 _buildScheduleInfoCard(order),
  //               ],
  //             ),

  //             _buildPageFooter(context.pageNumber, 'التفاصيل الفنية'),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Page _buildTimelinePage(Order order) {
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final purpleColor = PdfColor.fromInt(0xFF9C27B0);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35),
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //           children: [
  //             _buildPdfHeader(
  //               logo: _companyLogo,
  //               crNumber: '7011144750',
  //               vatNumber: '313061665400003',
  //             ),

  //             pw.SizedBox(height: 20),

  //             // عنوان الصفحة
  //             pw.Container(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //               decoration: pw.BoxDecoration(
  //                 color: primaryColor,
  //                 borderRadius: pw.BorderRadius.circular(8),
  //               ),
  //               child: pw.Center(
  //                 child: pw.Text(
  //                   'الجدول الزمني للأحداث',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             ),

  //             pw.SizedBox(height: 20),

  //             // الجدول الزمني
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader('سجل الأحداث', color: purpleColor),
  //                 pw.SizedBox(height: 10),
  //                 _buildTimelineCard(order),
  //                 pw.SizedBox(height: 30),
  //               ],
  //             ),

  //             // الإحصائيات
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader(
  //                   'إحصائيات الطلب',
  //                   color: PdfColor.fromInt(AppColors.successGreen.value),
  //                 ),
  //                 pw.SizedBox(height: 10),
  //                 _buildStatisticsCard(order),
  //               ],
  //             ),

  //             _buildPageFooter(context.pageNumber, 'السجل الزمني'),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Page _buildFinancialDetailsPage(Order order) {
  //   final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
  //   final greenColor = PdfColor.fromInt(AppColors.successGreen.value);

  //   return pw.Page(
  //     pageFormat: PdfPageFormat.a4,
  //     margin: const pw.EdgeInsets.all(28.35),
  //     theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
  //     build: (pw.Context context) {
  //       return pw.Directionality(
  //         textDirection: pw.TextDirection.rtl,
  //         child: pw.Column(
  //           crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //           children: [
  //             _buildPdfHeader(
  //               logo: _companyLogo,
  //               crNumber: '7011144750',
  //               vatNumber: '313061665400003',
  //             ),

  //             pw.SizedBox(height: 20),

  //             // عنوان الصفحة
  //             pw.Container(
  //               padding: const pw.EdgeInsets.symmetric(vertical: 16),
  //               decoration: pw.BoxDecoration(
  //                 color: primaryColor,
  //                 borderRadius: pw.BorderRadius.circular(8),
  //               ),
  //               child: pw.Center(
  //                 child: pw.Text(
  //                   'المعلومات المالية والملاحظات',
  //                   style: pw.TextStyle(
  //                     color: PdfColors.white,
  //                     fontSize: 24,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //               ),
  //             ),

  //             pw.SizedBox(height: 20),

  //             // المعلومات المالية
  //             pw.Column(
  //               children: [
  //                 _buildSectionHeader('المعلومات المالية', color: greenColor),
  //                 pw.SizedBox(height: 10),
  //                 _buildFinancialInfoCard(order),
  //                 pw.SizedBox(height: 30),
  //               ],
  //             ),

  //             // الملاحظات
  //             if (order.notes != null && order.notes!.isNotEmpty)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader(
  //                     'ملاحظات الطلب',
  //                     color: PdfColor.fromInt(AppColors.mediumGray.value),
  //                   ),
  //                   pw.SizedBox(height: 10),
  //                   _buildNotesCard(order),
  //                   pw.SizedBox(height: 30),
  //                 ],
  //               ),

  //             // المرفقات
  //             if (order.attachments.isNotEmpty)
  //               pw.Column(
  //                 children: [
  //                   _buildSectionHeader('المرفقات', color: primaryColor),
  //                   pw.SizedBox(height: 10),
  //                   _buildAttachmentsCard(order),
  //                 ],
  //               ),

  //             // خاتمة التقرير
  //             pw.Container(
  //               margin: const pw.EdgeInsets.only(top: 30),
  //               padding: const pw.EdgeInsets.all(20),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //                 borderRadius: pw.BorderRadius.circular(8),
  //                 border: pw.Border.all(
  //                   color: PdfColor.fromInt(AppColors.lightGray.value),
  //                 ),
  //               ),
  //               child: pw.Column(
  //                 children: [
  //                   pw.Text(
  //                     '--- نهاية التقرير ---',
  //                     style: pw.TextStyle(
  //                       color: primaryColor,
  //                       fontSize: 16,
  //                       fontWeight: pw.FontWeight.bold,
  //                     ),
  //                   ),
  //                   pw.SizedBox(height: 10),
  //                   pw.Text(
  //                     'تم إنشاء هذا التقرير بتاريخ ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
  //                     style: pw.TextStyle(
  //                       color: PdfColor.fromInt(AppColors.mediumGray.value),
  //                       fontSize: 12,
  //                     ),
  //                   ),
  //                   pw.SizedBox(height: 5),
  //                   pw.Text(
  //                     'نظام إدارة الطلبات - جميع الحقوق محفوظة © ${DateTime.now().year}',
  //                     style: pw.TextStyle(
  //                       color: PdfColor.fromInt(AppColors.lightGray.value),
  //                       fontSize: 10,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),

  //             _buildPageFooter(context.pageNumber, 'المعلومات المالية'),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // pw.Widget _buildSectionHeader(String title, {required PdfColor color}) {
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  //     decoration: pw.BoxDecoration(
  //       color: color,
  //       borderRadius: pw.BorderRadius.circular(8),
  //     ),
  //     child: pw.Row(
  //       children: [
  //         pw.Expanded(
  //           child: pw.Text(
  //             title,
  //             style: pw.TextStyle(
  //               color: PdfColors.white,
  //               fontSize: 18,
  //               fontWeight: pw.FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildInfoBox({
  //   required String title,
  //   required PdfColor iconColor,
  //   required List<pw.Widget> children,
  // }) {
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.lightGray.value),
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               width: 4,
  //               height: 20,
  //               color: iconColor,
  //               margin: const pw.EdgeInsets.only(left: 8),
  //             ),
  //             pw.Text(
  //               title,
  //               style: pw.TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: pw.FontWeight.bold,
  //                 color: PdfColor.fromInt(AppColors.darkGray.value),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 12),
  //         ...children,
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildCustomerInfoCard(Order order) {
  //   final customer = order.customer;
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.secondaryTeal.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.secondaryTeal.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.user,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 _getCustomerName(order) ?? 'غير محدد',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             if (customer?.code != null && customer!.code!.isNotEmpty)
  //               _buildDetailItem('كود العميل', customer.code!),
  //             if (customer?.phone != null && customer!.phone!.isNotEmpty)
  //               _buildDetailItem('الهاتف', customer.phone!),
  //             if (customer?.email != null && customer!.email!.isNotEmpty)
  //               _buildDetailItem('البريد الإلكتروني', customer.email!),
  //             if (customer?.customerType != null)
  //               _buildDetailItem('نوع العميل', customer!.customerType!),
  //             if (customer?.company != null && customer!.company!.isNotEmpty)
  //               _buildDetailItem('الشركة', customer.company!),
  //             if (customer?.taxNumber != null &&
  //                 customer!.taxNumber!.isNotEmpty)
  //               _buildDetailItem('الرقم الضريبي', customer.taxNumber!),
  //             if (customer?.commercialRecord != null &&
  //                 customer!.commercialRecord!.isNotEmpty)
  //               _buildDetailItem('السجل التجاري', customer.commercialRecord!),
  //             if (customer?.totalOrders != null)
  //               _buildDetailItem(
  //                 'عدد الطلبات',
  //                 customer!.totalOrders!.toString(),
  //               ),
  //             if (customer?.totalSpent != null)
  //               _buildDetailItem(
  //                 'إجمالي الإنفاق',
  //                 '${customer!.totalSpent!.toStringAsFixed(2)} ريال',
  //               ),
  //             if (customer?.lastOrderDate != null)
  //               _buildDetailItem(
  //                 'آخر طلب',
  //                 DateFormat('yyyy/MM/dd').format(customer!.lastOrderDate!),
  //               ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildSupplierInfoCard(Order order) {
  //   final supplier = order.supplier;
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.supplier,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 supplier?.name ?? order.supplierName ?? 'غير محدد',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             if (supplier?.company != null && supplier!.company.isNotEmpty)
  //               _buildDetailItem('الشركة', supplier.company),
  //             if (supplier?.contactPerson != null &&
  //                 supplier!.contactPerson.isNotEmpty)
  //               _buildDetailItem('جهة الاتصال', supplier!.contactPerson),
  //             if (order.supplierContactPerson != null &&
  //                 order.supplierContactPerson!.isNotEmpty)
  //               _buildDetailItem('جهة الاتصال', order.supplierContactPerson!),
  //             if (supplier?.phone != null && supplier!.phone.isNotEmpty)
  //               _buildDetailItem('الهاتف', supplier.phone),
  //             if (order.supplierPhone != null &&
  //                 order.supplierPhone!.isNotEmpty)
  //               _buildDetailItem('الهاتف', order.supplierPhone!),
  //             if (supplier?.email != null && supplier!.email!.isNotEmpty)
  //               _buildDetailItem('البريد الإلكتروني', supplier.email!),
  //             if (order.supplierCompany != null &&
  //                 order.supplierCompany!.isNotEmpty)
  //               _buildDetailItem('الشركة', order.supplierCompany!),
  //             if (supplier?.supplierType != null)
  //               _buildDetailItem('نوع المورد', supplier!.supplierType),
  //             if (supplier?.rating != null)
  //               _buildDetailItem(
  //                 'التقييم',
  //                 '${supplier!.rating.toStringAsFixed(1)}/5.0',
  //               ),
  //             if (supplier?.taxNumber != null &&
  //                 supplier!.taxNumber!.isNotEmpty)
  //               _buildDetailItem('الرقم الضريبي', supplier.taxNumber!),
  //             if (supplier?.commercialNumber != null &&
  //                 supplier!.commercialNumber!.isNotEmpty)
  //               _buildDetailItem('السجل التجاري', supplier.commercialNumber!),
  //             if (supplier?.address != null && supplier!.address!.isNotEmpty)
  //               _buildDetailItem('العنوان', supplier.address!),
  //             if (supplier?.city != null && supplier!.city!.isNotEmpty)
  //               _buildDetailItem('المدينة', supplier.city!),
  //             if (supplier?.country != null && supplier!.country!.isNotEmpty)
  //               _buildDetailItem('البلد', supplier.country!),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildDriverInfoCard(Order order) {
  //   final driver = order.driver;
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.secondaryTeal.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.secondaryTeal.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.driver,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 driver?.name ?? order.driverName ?? 'غير محدد',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             if (driver?.licenseNumber != null &&
  //                 driver!.licenseNumber.isNotEmpty)
  //               _buildDetailItem('رقم الرخصة', driver.licenseNumber),
  //             if (driver?.phone != null && driver!.phone.isNotEmpty)
  //               _buildDetailItem('الهاتف', driver.phone),
  //             if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
  //               _buildDetailItem('الهاتف', order.driverPhone!),
  //             if (driver?.email != null && driver!.email!.isNotEmpty)
  //               _buildDetailItem('البريد الإلكتروني', driver.email!),
  //             if (driver?.vehicleType != null)
  //               _buildDetailItem('نوع المركبة', driver!.vehicleType),
  //             if (driver?.status != null)
  //               _buildDetailItem('حالة السائق', driver!.status),
  //             if (driver?.licenseExpiryDate != null)
  //               _buildDetailItem(
  //                 'انتهاء الرخصة',
  //                 DateFormat('yyyy/MM/dd').format(driver!.licenseExpiryDate!),
  //               ),
  //             if (driver?.address != null && driver!.address!.isNotEmpty)
  //               _buildDetailItem('العنوان', driver.address!),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildVehicleInfoCard(Order order) {
  //   final driver = order.driver;
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(color: PdfColor.fromInt(0xFF795548), width: 1),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(0xFF795548),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.vehicle,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'معلومات المركبة',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             if (order.vehicleNumber != null &&
  //                 order.vehicleNumber!.isNotEmpty)
  //               _buildDetailItem('رقم المركبة', order.vehicleNumber!),
  //             if (driver?.vehicleType != null)
  //               _buildDetailItem('نوع المركبة', driver!.vehicleType),
  //             if (order.distance != null)
  //               _buildDetailItem(
  //                 'المسافة',
  //                 '${order.distance!.toStringAsFixed(2)} كم',
  //               ),
  //             if (order.deliveryDuration != null)
  //               _buildDetailItem(
  //                 'مدة التوصيل',
  //                 '${order.deliveryDuration} دقيقة',
  //               ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildProductInfoCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.warningOrange.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.warningOrange.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.fuel,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'تفاصيل المنتج',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             _buildDetailItem(
  //               'نوع المنتج',
  //               order.fuelType ?? order.productType ?? '-',
  //             ),
  //             _buildDetailItem(
  //               'الكمية',
  //               '${order.quantity?.toStringAsFixed(0) ?? '0'} ${order.unit ?? 'لتر'}',
  //             ),
  //             if (order.productType != null && order.productType!.isNotEmpty)
  //               _buildDetailItem('نوع المنتج', order.productType!),
  //             if (order.requestType != null && order.requestType!.isNotEmpty)
  //               _buildDetailItem('نوع العملية', order.requestType!),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildLocationInfoCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.infoBlue.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.infoBlue.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.location,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'معلومات الموقع',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             _buildDetailItem('المدينة', order.city ?? '-'),
  //             _buildDetailItem('المنطقة', order.area ?? '-'),
  //             _buildDetailItem('العنوان التفصيلي', order.address ?? '-'),
  //             if (order.supplierAddress != null &&
  //                 order.supplierAddress!.isNotEmpty)
  //               _buildDetailItem('عنوان المورد', order.supplierAddress!),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildScheduleInfoCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.pendingYellow.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.pendingYellow.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.attachment,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'المواعيد والتواريخ',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             _buildDetailRow(
  //               'تاريخ الطلب',
  //               DateFormat('yyyy/MM/dd').format(order.orderDate),
  //             ),
  //             _buildDetailRow(
  //               'تاريخ الوصول',
  //               DateFormat('yyyy/MM/dd').format(order.arrivalDate),
  //             ),
  //             _buildDetailRow('وقت الوصول', order.arrivalTime),
  //             _buildDetailRow(
  //               'تاريخ التحميل',
  //               DateFormat('yyyy/MM/dd').format(order.loadingDate),
  //             ),
  //             _buildDetailRow('وقت التحميل', order.loadingTime),
  //             if (order.actualArrivalTime != null)
  //               _buildDetailRow('وقت الوصول الفعلي', order.actualArrivalTime!),
  //             if (order.loadingCompletedAt != null)
  //               _buildDetailRow(
  //                 'تاريخ انتهاء التحميل',
  //                 _formatDateTime(order.loadingCompletedAt!),
  //               ),
  //             if (order.loadingDuration != null)
  //               _buildDetailRow(
  //                 'مدة التحميل',
  //                 '${order.loadingDuration} دقيقة',
  //               ),
  //             if (order.delayReason != null && order.delayReason!.isNotEmpty)
  //               _buildDetailRow('سبب التأخير', order.delayReason!),
  //             if (order.completedAt != null)
  //               _buildDetailRow(
  //                 'تاريخ الإكمال',
  //                 _formatDateTime(order.completedAt!),
  //               ),
  //             if (order.cancelledAt != null)
  //               _buildDetailRow(
  //                 'تاريخ الإلغاء',
  //                 _formatDateTime(order.cancelledAt!),
  //               ),
  //             if (order.mergedAt != null)
  //               _buildDetailRow(
  //                 'تاريخ الدمج',
  //                 _formatDateTime(order.mergedAt!),
  //               ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildLoadingInfoCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.warningOrange.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.warningOrange.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.clock,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'تفاصيل التحميل والتسليم',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             if (order.actualArrivalTime != null)
  //               _buildDetailItem('وقت الوصول الفعلي', order.actualArrivalTime!),
  //             if (order.loadingDuration != null)
  //               _buildDetailItem(
  //                 'مدة التحميل',
  //                 '${order.loadingDuration} دقيقة',
  //               ),
  //             if (order.loadingCompletedAt != null)
  //               _buildDetailItem(
  //                 'تاريخ انتهاء التحميل',
  //                 _formatDateTime(order.loadingCompletedAt!),
  //               ),
  //             if (order.delayReason != null && order.delayReason!.isNotEmpty)
  //               _buildDetailItem('سبب التأخير', order.delayReason!),
  //             if (order.completedAt != null)
  //               _buildDetailItem(
  //                 'تاريخ الإكمال',
  //                 _formatDateTime(order.completedAt!),
  //               ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildMergeInfoCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(0xFFF3E5F5),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(color: PdfColor.fromInt(0xFF9C27B0), width: 1),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(0xFF9C27B0),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.merge,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 8),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'معلومات الدمج',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(0xFF9C27B0),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 12),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             _buildDetailItem('حالة الدمج', order.mergeStatus),
  //             if (order.mergedWithOrderId != null)
  //               _buildDetailItem(
  //                 'رقم الطلب المدمج معه',
  //                 order.mergedWithOrderId!,
  //               ),
  //             if (order.mergedAt != null)
  //               _buildDetailItem(
  //                 'تاريخ الدمج',
  //                 _formatDateTime(order.mergedAt!),
  //               ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildFinancialInfoCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.successGreen.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.successGreen.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.money,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'المعلومات المالية',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 16),
  //         pw.Wrap(
  //           spacing: 20,
  //           runSpacing: 12,
  //           children: [
  //             if (order.unitPrice != null)
  //               _buildDetailItem(
  //                 'سعر الوحدة',
  //                 '${order.unitPrice!.toStringAsFixed(2)} ريال',
  //               ),
  //             if (order.totalPrice != null)
  //               _buildDetailItem(
  //                 'السعر الإجمالي',
  //                 '${order.totalPrice!.toStringAsFixed(2)} ريال',
  //               ),
  //             if (order.driverEarnings != null)
  //               _buildDetailItem(
  //                 'أرباح السائق',
  //                 '${order.driverEarnings!.toStringAsFixed(2)} ريال',
  //               ),
  //             if (order.paymentMethod != null &&
  //                 order.paymentMethod!.isNotEmpty)
  //               _buildDetailItem('طريقة الدفع', order.paymentMethod!),
  //             if (order.paymentStatus != null &&
  //                 order.paymentStatus!.isNotEmpty)
  //               _buildDetailItem('حالة الدفع', order.paymentStatus!),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildNotesCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.mediumGray.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.mediumGray.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.note,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'ملاحظات الطلب',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 12),
  //         pw.Container(
  //           width: double.infinity,
  //           padding: const pw.EdgeInsets.all(12),
  //           decoration: pw.BoxDecoration(
  //             color: PdfColors.white,
  //             borderRadius: pw.BorderRadius.circular(4),
  //           ),
  //           child: pw.Text(
  //             order.notes!,
  //             style: const pw.TextStyle(
  //               color: PdfColors.black,
  //               fontSize: 12,
  //               height: 1.5,
  //             ),
  //             textDirection: pw.TextDirection.rtl,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildAttachmentsCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Row(
  //           children: [
  //             pw.Container(
  //               padding: const pw.EdgeInsets.all(8),
  //               decoration: pw.BoxDecoration(
  //                 color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //                 borderRadius: pw.BorderRadius.circular(4),
  //               ),
  //               child: pw.Text(
  //                 PdfTextIcons.attachment,
  //                 style: pw.TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: pw.FontWeight.bold,
  //                   color: PdfColors.white,
  //                 ),
  //               ),
  //             ),
  //             pw.SizedBox(width: 12),
  //             pw.Expanded(
  //               child: pw.Text(
  //                 'المرفقات (${order.attachments.length})',
  //                 style: pw.TextStyle(
  //                   color: PdfColor.fromInt(AppColors.darkGray.value),
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         pw.SizedBox(height: 12),
  //         pw.Column(
  //           children: [
  //             for (var attachment in order.attachments)
  //               pw.Container(
  //                 margin: const pw.EdgeInsets.only(bottom: 8),
  //                 padding: const pw.EdgeInsets.all(12),
  //                 decoration: pw.BoxDecoration(
  //                   color: PdfColors.white,
  //                   borderRadius: pw.BorderRadius.circular(4),
  //                   border: pw.Border.all(
  //                     color: PdfColor.fromInt(AppColors.lightGray.value),
  //                   ),
  //                 ),
  //                 child: pw.Row(
  //                   children: [
  //                     pw.Container(
  //                       padding: const pw.EdgeInsets.all(4),
  //                       decoration: pw.BoxDecoration(
  //                         color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //                         borderRadius: pw.BorderRadius.circular(4),
  //                       ),
  //                       child: pw.Text(
  //                         '📄',
  //                         style: const pw.TextStyle(fontSize: 12),
  //                       ),
  //                     ),
  //                     pw.SizedBox(width: 8),
  //                     pw.Expanded(
  //                       child: pw.Column(
  //                         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                         children: [
  //                           pw.Text(
  //                             attachment.filename,
  //                             style: pw.TextStyle(
  //                               color: PdfColors.black,
  //                               fontSize: 12,
  //                               fontWeight: pw.FontWeight.bold,
  //                             ),
  //                           ),
  //                           pw.Text(
  //                             DateFormat(
  //                               'yyyy/MM/dd HH:mm',
  //                             ).format(attachment.uploadedAt),
  //                             style: pw.TextStyle(
  //                               color: PdfColor.fromInt(
  //                                 AppColors.mediumGray.value,
  //                               ),
  //                               fontSize: 10,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildTimelineCard(Order order) {
  //   final events = <Map<String, dynamic>>[
  //     if (order.createdAt != null)
  //       {
  //         'title': 'إنشاء الطلب',
  //         'date': order.createdAt,
  //         'icon': PdfTextIcons.created,
  //         'color': PdfColor.fromInt(0xFF2196F3),
  //       },
  //     if (order.orderDate != null)
  //       {
  //         'title': 'تاريخ الطلب',
  //         'date': order.orderDate,
  //         'icon': PdfTextIcons.calendar,
  //         'color': PdfColor.fromInt(0xFF4CAF50),
  //       },
  //     if (order.arrivalDate != null)
  //       {
  //         'title': 'تاريخ الوصول المخطط',
  //         'date': order.arrivalDate,
  //         'time': order.arrivalTime,
  //         'icon': PdfTextIcons.clock,
  //         'color': PdfColor.fromInt(0xFFFF9800),
  //       },
  //     if (order.loadingDate != null)
  //       {
  //         'title': 'تاريخ التحميل المخطط',
  //         'date': order.loadingDate,
  //         'time': order.loadingTime,
  //         'icon': PdfTextIcons.driver,
  //         'color': PdfColor.fromInt(0xFF9C27B0),
  //       },
  //     if (order.mergedAt != null)
  //       {
  //         'title': 'دمج الطلب',
  //         'date': order.mergedAt,
  //         'icon': PdfTextIcons.merge,
  //         'color': PdfColor.fromInt(0xFF00BCD4),
  //       },
  //     if (order.loadingCompletedAt != null)
  //       {
  //         'title': 'انتهاء التحميل',
  //         'date': order.loadingCompletedAt,
  //         'icon': PdfTextIcons.done,
  //         'color': PdfColor.fromInt(0xFF8BC34A),
  //       },
  //     if (order.completedAt != null)
  //       {
  //         'title': 'إكمال الطلب',
  //         'date': order.completedAt,
  //         'icon': PdfTextIcons.completed,
  //         'color': PdfColor.fromInt(0xFF4CAF50),
  //       },
  //     if (order.cancelledAt != null)
  //       {
  //         'title': 'إلغاء الطلب',
  //         'date': order.cancelledAt,
  //         'icon': PdfTextIcons.canceled,
  //         'color': PdfColor.fromInt(0xFFF44336),
  //       },
  //   ];

  //   // ترتيب الأحداث حسب التاريخ
  //   events.sort((a, b) => a['date'].compareTo(b['date']));

  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(color: PdfColor.fromInt(0xFF9C27B0), width: 1),
  //     ),
  //     child: pw.Column(
  //       children: [
  //         for (int i = 0; i < events.length; i++)
  //           pw.Padding(
  //             padding: const pw.EdgeInsets.only(bottom: 16),
  //             child: pw.Row(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 // الخط العمودي
  //                 pw.Container(
  //                   width: 2,
  //                   height: i == events.length - 1 ? 24 : 40,
  //                   color: events[i]['color'],
  //                   margin: const pw.EdgeInsets.only(left: 11, right: 11),
  //                 ),
  //                 // النقطة
  //                 pw.Container(
  //                   width: 24,
  //                   height: 24,
  //                   decoration: pw.BoxDecoration(
  //                     color: events[i]['color'],
  //                     shape: pw.BoxShape.circle,
  //                   ),
  //                   child: pw.Center(
  //                     child: pw.Text(
  //                       events[i]['icon'],
  //                       style: const pw.TextStyle(
  //                         fontSize: 12,
  //                         color: PdfColors.white,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //                 pw.SizedBox(width: 12),
  //                 pw.Expanded(
  //                   child: pw.Column(
  //                     crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                     children: [
  //                       pw.Text(
  //                         events[i]['title'],
  //                         style: pw.TextStyle(
  //                           color: PdfColor.fromInt(AppColors.darkGray.value),
  //                           fontSize: 14,
  //                           fontWeight: pw.FontWeight.bold,
  //                         ),
  //                       ),
  //                       pw.SizedBox(height: 4),
  //                       pw.Text(
  //                         '${DateFormat('yyyy/MM/dd').format(events[i]['date'])}${events[i]['time'] != null ? ' ${events[i]['time']}' : ''}',
  //                         style: pw.TextStyle(
  //                           color: PdfColor.fromInt(AppColors.mediumGray.value),
  //                           fontSize: 12,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildStatisticsCard(Order order) {
  //   return pw.Container(
  //     width: double.infinity,
  //     padding: const pw.EdgeInsets.all(16),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColor.fromInt(AppColors.backgroundGray.value),
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.successGreen.value),
  //         width: 1,
  //       ),
  //     ),
  //     child: pw.Wrap(
  //       spacing: 16,
  //       runSpacing: 16,
  //       children: [
  //         _buildStatCard(
  //           'المدة الكلية',
  //           order.createdAt != null && order.completedAt != null
  //               ? '${order.completedAt!.difference(order.createdAt).inHours} ساعة'
  //               : 'قيد التنفيذ',
  //           PdfTextIcons.clock,
  //         ),
  //         _buildStatCard('حالة الطلب', order.status, PdfTextIcons.status),
  //         _buildStatCard('نوع المصدر', order.orderSource, PdfTextIcons.source),
  //         if (order.totalPrice != null)
  //           _buildStatCard(
  //             'القيمة الإجمالية',
  //             '${order.totalPrice!.toStringAsFixed(2)} ريال',
  //             PdfTextIcons.money,
  //           ),
  //         if (order.quantity != null)
  //           _buildStatCard(
  //             'الكمية',
  //             '${order.quantity!.toStringAsFixed(0)} ${order.unit ?? 'وحدة'}',
  //             PdfTextIcons.quantity,
  //           ),
  //         if (order.attachments.isNotEmpty)
  //           _buildStatCard('المرفقات', '${order.attachments.length}', '📎'),
  //         _buildStatCard('حالة الدمج', order.mergeStatus, '🔄'),
  //         if (order.distance != null)
  //           _buildStatCard(
  //             'المسافة',
  //             '${order.distance!.toStringAsFixed(2)} كم',
  //             PdfTextIcons.distance,
  //           ),
  //         if (order.deliveryDuration != null)
  //           _buildStatCard(
  //             'مدة التوصيل',
  //             '${order.deliveryDuration} دقيقة',
  //             PdfTextIcons.clock,
  //           ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildStatCard(String title, String value, String emoji) {
  //   return pw.Container(
  //     width: 120,
  //     padding: const pw.EdgeInsets.all(12),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColors.white,
  //       borderRadius: pw.BorderRadius.circular(8),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.lightGray.value),
  //       ),
  //     ),
  //     child: pw.Column(
  //       children: [
  //         pw.Text(emoji, style: const pw.TextStyle(fontSize: 20)),
  //         pw.SizedBox(height: 8),
  //         pw.Text(
  //           title,
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.mediumGray.value),
  //             fontSize: 10,
  //           ),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //         pw.SizedBox(height: 4),
  //         pw.Text(
  //           value,
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.darkGray.value),
  //             fontSize: 12,
  //             fontWeight: pw.FontWeight.bold,
  //           ),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildDetailItem(String label, String value) {
  //   return pw.Container(
  //     padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //     decoration: pw.BoxDecoration(
  //       color: PdfColors.white,
  //       borderRadius: pw.BorderRadius.circular(4),
  //       border: pw.Border.all(
  //         color: PdfColor.fromInt(AppColors.lightGray.value),
  //       ),
  //     ),
  //     child: pw.Column(
  //       children: [
  //         pw.Text(
  //           label,
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.mediumGray.value),
  //             fontSize: 10,
  //           ),
  //         ),
  //         pw.SizedBox(height: 2),
  //         pw.Text(
  //           value,
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.darkGray.value),
  //             fontSize: 12,
  //             fontWeight: pw.FontWeight.bold,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildDetailRow(String label, String value) {
  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.symmetric(vertical: 4),
  //     child: pw.Row(
  //       children: [
  //         pw.Expanded(
  //           flex: 2,
  //           child: pw.Text(
  //             '$label:',
  //             style: pw.TextStyle(
  //               color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //               fontSize: 12,
  //               fontWeight: pw.FontWeight.bold,
  //             ),
  //             textDirection: pw.TextDirection.rtl,
  //           ),
  //         ),
  //         pw.Expanded(
  //           flex: 3,
  //           child: pw.Text(
  //             value,
  //             style: const pw.TextStyle(color: PdfColors.black, fontSize: 12),
  //             textDirection: pw.TextDirection.rtl,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // pw.Widget _buildPdfDetailRow(String label, dynamic value) {
  //   final String displayValue = value == null
  //       ? '-'
  //       : value is String
  //       ? value
  //       : value.toString();

  //   return pw.Directionality(
  //     textDirection: pw.TextDirection.rtl,
  //     child: pw.Padding(
  //       padding: const pw.EdgeInsets.symmetric(vertical: 6),
  //       child: pw.Row(
  //         crossAxisAlignment: pw.CrossAxisAlignment.start,
  //         children: [
  //           pw.Expanded(
  //             flex: 2,
  //             child: pw.Text(
  //               '$label:',
  //               style: pw.TextStyle(
  //                 fontSize: 12,
  //                 fontWeight: pw.FontWeight.bold,
  //                 color: PdfColor.fromInt(AppColors.primaryBlue.value),
  //               ),
  //             ),
  //           ),
  //           pw.Expanded(
  //             flex: 3,
  //             child: pw.Text(
  //               displayValue,
  //               style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // pw.Widget _buildPageFooter(int pageNumber, String section) {
  //   return pw.Container(
  //     margin: const pw.EdgeInsets.only(top: 20),
  //     padding: const pw.EdgeInsets.symmetric(vertical: 12),
  //     decoration: pw.BoxDecoration(
  //       border: pw.Border(
  //         top: pw.BorderSide(
  //           color: PdfColor.fromInt(AppColors.lightGray.value),
  //           width: 0.5,
  //         ),
  //       ),
  //     ),
  //     child: pw.Row(
  //       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //       children: [
  //         pw.Text(
  //           'الصفحة $pageNumber - $section',
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.mediumGray.value),
  //             fontSize: 10,
  //           ),
  //         ),
  //         pw.Text(
  //           '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.mediumGray.value),
  //             fontSize: 10,
  //           ),
  //         ),
  //         pw.Text(
  //           'نظام إدارة الطلبات',
  //           style: pw.TextStyle(
  //             color: PdfColor.fromInt(AppColors.mediumGray.value),
  //             fontSize: 10,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _exportToDetailedPDF() async {
    try {
      final order = context.read<OrderProvider>().selectedOrder;
      if (order == null) return;

      await _loadArabicFont();
      await _loadCompanyLogo();

      final orderType = _safeOrderType(order);

      final pdf = pw.Document();

      // صفحة واحدة فقط تحتوي على كل التفاصيل
      final isMergedOrder = order.orderSource == 'مدمج';
      pdf.addPage(
        isMergedOrder
            ? _buildMergedOrderTableReport(order, orderType)
            : _buildSinglePageReport(order, orderType),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${orderType}_طلب_${order.orderNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تصدير التقرير التفصيلي بنجاح'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error exporting PDF: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطأ في تصدير PDF'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ============================================
  // صفحة واحدة تحتوي على كل التفاصيل
  // ============================================

  pw.Page _buildSinglePageReport(Order order, String orderType) {
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final backgroundColor = PdfColor.fromInt(AppColors.backgroundGray.value);
    final borderColor = PdfColor.fromInt(AppColors.lightGray.value);
    final tealColor = PdfColor.fromInt(AppColors.secondaryTeal.value);
    final orangeColor = PdfColor.fromInt(AppColors.warningOrange.value);
    final greenColor = PdfColor.fromInt(AppColors.successGreen.value);
    final infoBlueColor = PdfColor.fromInt(AppColors.infoBlue.value);
    final pendingYellowColor = PdfColor.fromInt(AppColors.pendingYellow.value);
    final purpleColor = PdfColor.fromInt(0xFF9C27B0);
    final brownColor = PdfColor.fromInt(0xFF795548);
    final mediumGrayColor = PdfColor.fromInt(AppColors.mediumGray.value);
    final darkGrayColor = PdfColor.fromInt(AppColors.darkGray.value);
    final effectiveRequestType = order.effectiveRequestType;
    final bool showRequestType =
        effectiveRequestType.trim().isNotEmpty &&
        effectiveRequestType != 'غير محدد' &&
        (order.orderSource == 'عميل' || order.orderSource == 'مدمج');
    final String requestTypeLabel = order.orderSource == 'مدمج'
        ? 'نوع طلب العميل'
        : 'نوع العملية';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // الهيدر
              _buildPdfHeader(
                logo: _companyLogo,
                crNumber: '7011144750',
                vatNumber: '313061665400003',
              ),

              pw.SizedBox(height: 10),

              // عنوان الصفحة
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'تقرير تفصيلي للطلب',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              // معلومات الطلب الأساسية - صفين
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // العمود الأول - المعلومات الأساسية
                  pw.Expanded(
                    child: _buildInfoBox(
                      title: 'معلومات الطلب الأساسية',
                      iconColor: primaryColor,
                      children: [
                        _buildPdfDetailRow('رقم الطلب', order.orderNumber),
                        _buildPdfDetailRow('نوع الطلب', orderType),
                        _buildPdfDetailRow('الحالة', order.status),
                        _buildPdfDetailRow('مصدر الطلب', order.orderSource),
                        _buildPdfDetailRow('حالة الدمج', order.mergeStatus),
                        _buildPdfDetailRow(
                          'تاريخ الإنشاء',
                          DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(order.createdAt),
                        ),
                        _buildPdfDetailRow(
                          'آخر تحديث',
                          DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(order.updatedAt),
                        ),
                        if (order.supplierOrderNumber != null &&
                            order.supplierOrderNumber!.isNotEmpty)
                          _buildPdfDetailRow(
                            'رقم طلب المورد',
                            order.supplierOrderNumber!,
                          ),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 10),

                  // العمود الثاني - المعلومات الإضافية
                  pw.Expanded(
                    child: _buildInfoBox(
                      title: 'تفاصيل الطلب',
                      iconColor: infoBlueColor,
                      children: [
                        if (order.productType != null)
                          _buildPdfDetailRow('نوع المنتج', order.productType!),

                        if (order.fuelType != null)
                          _buildPdfDetailRow('نوع الوقود', order.fuelType!),

                        if (order.quantity != null)
                          _buildPdfDetailRow(
                            'الكمية',
                            '${order.quantity} ${order.unit ?? "لتر"}',
                          ),

                        if (showRequestType)
                          _buildPdfDetailRow(
                            requestTypeLabel,
                            effectiveRequestType,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 1),

              // معلومات العميل والمورد - صفين
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // معلومات العميل
                  pw.Expanded(child: _buildCustomerInfoCard(order)),

                  pw.SizedBox(width: 10),

                  // معلومات المورد
                  pw.Expanded(child: _buildSupplierInfoCard(order)),
                ],
              ),

              pw.SizedBox(height: 15),

              // معلومات السائق والمركبة - صفين
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // معلومات السائق
                  pw.Expanded(child: _buildDriverInfoCard(order)),

                  pw.SizedBox(width: 10),

                  // معلومات المركبة والتحميل
                  // pw.Expanded(
                  //   child: pw.Column(
                  //     children: [
                  //       _buildVehicleInfoCard(order),
                  //       pw.SizedBox(height: 10),
                  //       _buildLoadingInfoCard(order),
                  //     ],
                  //   ),
                  // ),
                ],
              ),

              pw.SizedBox(height: 15),

              // المواعيد والتواريخ - صفين
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // العمود الأول للمواعيد
                  pw.Expanded(child: _buildScheduleInfoCard(order)),

                  pw.SizedBox(width: 10),

                  // العمود الثاني للمواعيد والأحداث
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        _buildProductInfoCard(order),
                        pw.SizedBox(height: 10),
                        _buildLocationInfoCard(order),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 15),

              // معلومات الدمج (إذا كان مدمجاً)
              if (order.isMerged)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: _buildMergeInfoCard(order),
                ),

              pw.SizedBox(height: 15),

              // المعلومات المالية - صف واحد
              _buildFinancialInfoCard(order),

              pw.SizedBox(height: 15),

              // الملاحظات والمرفقات - صفين
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // الملاحظات
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        if (order.notes != null && order.notes!.isNotEmpty)
                          _buildNotesCard(order),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 10),

                  // المرفقات
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        if (order.attachments.isNotEmpty)
                          _buildAttachmentsCard(order),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 15),

              // الجدول الزمني والإحصائيات
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // الجدول الزمني
                  pw.Expanded(child: _buildTimelineCard(order)),

                  pw.SizedBox(width: 10),

                  // الإحصائيات
                  pw.Expanded(child: _buildStatisticsCard(order)),
                ],
              ),

              pw.SizedBox(height: 15),

              // الفوتر
              _buildPageFooter(1, 'التقرير الكامل'),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // تقرير الجدول الأفقي للطلب المدمج
  // ============================================
  pw.Page _buildMergedOrderTableReport(Order order, String orderType) {
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final borderColor = PdfColor.fromInt(AppColors.lightGray.value);
    final headerBg = PdfColor.fromInt(AppColors.primaryBlue.value);
    final headerText = PdfColors.white;
    final rowAlt = PdfColor.fromInt(AppColors.backgroundGray.value);
    final effectiveRequestType = order.effectiveRequestType;
    final customerAddress = order.customerAddress ?? order.customer?.address;
    final supplierAddress = order.supplierAddress ?? order.supplier?.address;
    final driverName = _getDriverName(order);
    final driverPhone = _getDriverPhone(order);

    String formatDate(DateTime? date) {
      if (date == null) return '—';
      return DateFormat('yyyy/MM/dd').format(date);
    }

    String formatDateTime(DateTime? date) {
      if (date == null) return '—';
      return DateFormat('yyyy/MM/dd HH:mm').format(date);
    }

    String formatNumber(num? value, {String suffix = ''}) {
      if (value == null) return '—';
      return '${value.toString()}$suffix';
    }

    final items = <MapEntry<String, String>>[];
    void addItem(String label, String? value) {
      final v = value == null || value.trim().isEmpty ? '—' : value;
      items.add(MapEntry(label, v));
    }

    addItem('رقم الطلب المدمج', order.orderNumber);
    addItem('نوع الطلب', orderType);
    if (effectiveRequestType.trim().isNotEmpty &&
        effectiveRequestType != 'غير محدد') {
      addItem('نوع طلب العميل', effectiveRequestType);
    }
    addItem('الحالة', order.status);
    addItem('مصدر الطلب', order.orderSource);
    addItem('حالة الدمج', order.mergeStatus);
    addItem('تاريخ الطلب', formatDate(order.orderDate));
    addItem('تاريخ الإنشاء', formatDateTime(order.createdAt));
    addItem('آخر تحديث', formatDateTime(order.updatedAt));
    if (order.supplierOrderNumber != null) {
      addItem('رقم طلب المورد', order.supplierOrderNumber);
    }
    addItem('اسم المورد', order.supplierName);
    addItem('شركة المورد', order.supplierCompany);
    addItem('عنوان المورد', supplierAddress);
    addItem('اسم العميل', _getCustomerName(order));
    addItem('كود العميل', order.customer?.code);
    addItem('عنوان العميل', customerAddress);
    addItem('اسم السائق', driverName);
    addItem('هاتف السائق', driverPhone);
    addItem('رقم المركبة', order.vehicleNumber);
    addItem('العنوان', order.address);
    addItem('نوع المنتج', order.productType);
    addItem('نوع الوقود', order.fuelType);
    if (order.quantity != null) {
      addItem('الكمية', '${order.quantity} ${order.unit ?? "لتر"}');
    } else {
      addItem('الكمية', '—');
    }
    addItem('سعر الوحدة', formatNumber(order.unitPrice, suffix: ' ريال'));
    addItem('الإجمالي', formatNumber(order.totalPrice, suffix: ' ريال'));
    addItem('طريقة الدفع', order.paymentMethod);
    addItem('حالة الدفع', order.paymentStatus);
    addItem('تاريخ التحميل', formatDate(order.loadingDate));
    addItem('وقت التحميل', order.loadingTime);
    addItem('تاريخ الوصول', formatDate(order.arrivalDate));
    addItem('وقت الوصول', order.arrivalTime);

    final tableRows = <pw.TableRow>[];
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerBg),
        children: [
          _buildMergedTableCell(
            'القيمة',
            headerText,
            isHeader: true,
            isValue: true,
          ),
          _buildMergedTableCell('البيان', headerText, isHeader: true),
          _buildMergedTableCell(
            'القيمة',
            headerText,
            isHeader: true,
            isValue: true,
          ),
          _buildMergedTableCell('البيان', headerText, isHeader: true),
        ],
      ),
    );

    for (var i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = (i + 1 < items.length) ? items[i + 1] : null;
      final bg = (i ~/ 2) % 2 == 0 ? PdfColors.white : rowAlt;
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            _buildMergedTableCell(left.value, PdfColors.black, isValue: true),
            _buildMergedTableCell(left.key, PdfColors.black),
            _buildMergedTableCell(
              right?.value ?? '',
              PdfColors.black,
              isValue: true,
            ),
            _buildMergedTableCell(right?.key ?? '', PdfColors.black),
          ],
        ),
      );
    }

    final baseFont = _cairoRegular ?? pw.Font.courier();
    final boldFont = _cairoBold ?? pw.Font.courierBold();

    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildMaintenancePdfHeader(_companyLogo, order, orderType),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'تقرير شامل للطلب المدمج',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: 0.4),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.25),
                    1: pw.FlexColumnWidth(0.75),
                    2: pw.FlexColumnWidth(2.25),
                    3: pw.FlexColumnWidth(0.75),
                  },
                  children: tableRows,
                ),
              ),
              pw.SizedBox(height: 4),
              _buildMaintenancePdfFooter(),
            ],
          ),
        );
      },
    );
  }

  pw.Widget _buildMaintenancePdfHeader(
    Uint8List? logoBytes,
    Order order,
    String orderType,
  ) {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final orderNumber = order.orderNumber.trim().isEmpty
        ? '—'
        : order.orderNumber;
    final customerName = _getCustomerName(order) ?? '—';

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
                  pw.Text(
                    'تقرير شامل للطلب المدمج',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'رقم الطلب: $orderNumber | نوع الطلب: $orderType',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    'العميل: $customerName',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    'التاريخ: $date',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              width: 90,
              height: 90,
              child: logoBytes != null
                  ? pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain)
                  : pw.Container(
                      color: PdfColors.grey200,
                      child: pw.Center(
                        child: pw.Text(
                          'Logo',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildMaintenancePdfFooter() {
    pw.Widget signatureLine() => pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Container(width: 70, height: 0.8, color: PdfColors.grey700),
        pw.SizedBox(height: 2),
        pw.Text('التوقيع', style: const pw.TextStyle(fontSize: 7)),
      ],
    );

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.8),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildMaintenanceFooterPerson(
                  'المدير العام',
                  'Hamada Rashidy - حمادة الرشيدى',
                  signatureLine(),
                ),
              ),
              pw.SizedBox(width: 10),
              // pw.Expanded(child: Container()), // مساحة فارغة في المنتصف
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildMaintenanceFooterPerson(
                  'رئيس مجلس الإدارة',
                  'ناصر المطيرى - Nasser Khaled',
                  signatureLine(),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _buildMaintenanceFooterAddress(),
        ],
      ),
    );
  }

  pw.Widget _buildMaintenanceFooterPerson(
    String title,
    String name,
    pw.Widget signature,
  ) {
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
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
          softWrap: true,
          maxLines: 2,
        ),
        signature,
      ],
    );
  }

  // pw.Widget _buildMaintenanceFooterMaintenance(String officerName) {
  //   return pw.SizedBox(
  //     width: 140,
  //     child: pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.center,
  //       children: [

  //         pw.SizedBox(height: 3),
  //         pw.Text(
  //           officerName,
  //           style: const pw.TextStyle(fontSize: 8),
  //           textAlign: pw.TextAlign.center,
  //         ),
  //         pw.SizedBox(height: 6),
  //         pw.Container(
  //           padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  //           decoration: pw.BoxDecoration(
  //             border: pw.Border.all(color: PdfColors.grey700),
  //             borderRadius: pw.BorderRadius.circular(4),
  //           ),
  //           child: pw.Text(
  //             'معتمد منه',
  //             style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  pw.Widget _buildMaintenanceFooterAddress() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Column(
          children: [
            pw.Divider(thickness: 0.8, color: PdfColors.grey700),
            pw.SizedBox(height: 6),
            pw.Text(
              'المنطقة الصناعية – شركة البحيرة العربية للنقليات, المملكة العربية السعودية – منطقة حائل – حائل',
              style: const pw.TextStyle(fontSize: 7.5),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '“Industrial Area – Al Buhaira Al Arabia Transport Company, Kingdom of Saudi Arabia – Hail Region – Hail.”',
              style: const pw.TextStyle(fontSize: 7.5),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'جوال: 0535550130   |   البريد الإلكتروني: n.n.66@hotmail.com',
              style: const pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'نظام نبراس | شركة البحيرة العربية',
              style: const pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildMergedTableCell(
    String text,
    PdfColor color, {
    bool isHeader = false,
    bool isValue = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Align(
        alignment: isHeader
            ? pw.Alignment.center
            : (isValue ? pw.Alignment.centerLeft : pw.Alignment.centerRight),
        child: pw.Text(
          text,
          textAlign: isHeader
              ? pw.TextAlign.center
              : (isValue ? pw.TextAlign.left : pw.TextAlign.right),
          style: pw.TextStyle(
            fontSize: isHeader ? 7 : 6.5,
            fontWeight: isHeader
                ? pw.FontWeight.bold
                : (isValue ? pw.FontWeight.normal : pw.FontWeight.bold),
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _exportToQuickPDF() async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final order = orderProvider.selectedOrder;
      if (order == null) return;

      final orderType = _safeOrderType(order);

      await _loadArabicFont();

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28.35), // 1 سم = 28.35 نقطة
          theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // الهيدر
                  _buildPdfHeader(
                    logo: _companyLogo,
                    crNumber: '7011144750',
                    vatNumber: '313061665400003',
                  ),

                  pw.SizedBox(height: 20),

                  // العنوان
                  pw.Text(
                    'ملخص طلب $orderType',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(AppColors.primaryBlue.value),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),

                  pw.SizedBox(height: 30),

                  // المعلومات الرئيسية
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromInt(AppColors.lightGray.value),
                        width: 1,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(12),
                      ),
                      color: PdfColor.fromInt(AppColors.backgroundGray.value),
                    ),
                    child: pw.Column(
                      children: [
                        _buildPdfDetailRow('رقم الطلب', order.orderNumber),
                        _buildPdfDetailRow('نوع الطلب', orderType),
                        _buildPdfDetailRow('الحالة', order.status),
                        _buildPdfDetailRow(
                          'تاريخ الطلب',
                          DateFormat('yyyy/MM/dd').format(order.orderDate),
                        ),
                        if (order.supplierName != null)
                          _buildPdfDetailRow('المورد', order.supplierName!),
                        if (_getCustomerName(order) != null)
                          _buildPdfDetailRow(
                            'العميل',
                            _getCustomerName(order)!,
                          ),
                        if (order.fuelType != null)
                          _buildPdfDetailRow('نوع الوقود', order.fuelType!),
                        if (order.quantity != null)
                          _buildPdfDetailRow(
                            'الكمية',
                            '${order.quantity} ${order.unit ?? "لتر"}',
                          ),
                        if (order.totalPrice != null)
                          _buildPdfDetailRow(
                            'القيمة الإجمالية',
                            '${order.totalPrice!.toStringAsFixed(2)} ريال',
                          ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 30),

                  // الموقع والمواعيد
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColor.fromInt(AppColors.infoBlue.value),
                              width: 1,
                            ),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(8),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'الموقع',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(
                                    AppColors.infoBlue.value,
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              _buildPdfDetailRow('المدينة', order.city ?? '-'),
                              _buildPdfDetailRow('المنطقة', order.area ?? '-'),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColor.fromInt(
                                AppColors.warningOrange.value,
                              ),
                              width: 1,
                            ),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(8),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'المواعيد',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(
                                    AppColors.warningOrange.value,
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              _buildPdfDetailRow(
                                'التحميل',
                                '${DateFormat('yyyy/MM/dd').format(order.loadingDate)} ${order.loadingTime}',
                              ),
                              _buildPdfDetailRow(
                                'الوصول',
                                '${DateFormat('yyyy/MM/dd').format(order.arrivalDate)} ${order.arrivalTime}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // الفوتر
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 30),
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          color: PdfColor.fromInt(AppColors.lightGray.value),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'نظام إدارة الطلبات',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromInt(AppColors.mediumGray.value),
                          ),
                        ),
                        pw.Text(
                          '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromInt(AppColors.mediumGray.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'ملخص_${orderType}_طلب_${order.orderNumber}.pdf',
      );
    } catch (e) {
      debugPrint('Error exporting quick PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير PDF: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ============================================
  // Helper Functions for PDF Building (محدثة)
  // ============================================

  pw.Page _buildCoverPage(Order order) {
    final orderType = _safeOrderType(order);
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final secondaryColor = PdfColor.fromInt(AppColors.primaryDarkBlue.value);
    final accentColor = PdfColor.fromInt(AppColors.accentBlue.value);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35), // 1 سم
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topCenter,
                end: pw.Alignment.bottomCenter,
                colors: [primaryColor, secondaryColor],
              ),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // شعار الشركة
                  if (_companyLogo != null)
                    pw.Container(
                      width: 120,
                      height: 120,
                      margin: const pw.EdgeInsets.only(bottom: 30),
                      child: pw.Image(
                        pw.MemoryImage(_companyLogo!),
                        fit: pw.BoxFit.contain,
                      ),
                    ),

                  pw.Text(
                    'نظام إدارة الطلبات',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 40),

                  // عنوان التقرير
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 20),
                    child: pw.Text(
                      'تقرير تفصيلي للطلب',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  // رقم الطلب في مربع مميز
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 16),
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(12),
                      boxShadow: [
                        pw.BoxShadow(color: PdfColors.black, blurRadius: 10),
                      ],
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'رقم الطلب',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          order.orderNumber,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 40),

                  // معلومات مختصرة
                  pw.Container(
                    padding: const pw.EdgeInsets.all(24),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0x33FFFFFF), // شفافية بيضاء
                      borderRadius: pw.BorderRadius.circular(16),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0x66FFFFFF),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        _buildCoverDetailRow('نوع الطلب', orderType),
                        _buildCoverDetailRow('الحالة', order.status),
                        _buildCoverDetailRow(
                          'تاريخ الطلب',
                          DateFormat('yyyy/MM/dd').format(order.orderDate),
                        ),
                        if (_getCustomerName(order) != null)
                          _buildCoverDetailRow(
                            'العميل',
                            _getCustomerName(order)!,
                          ),
                        if (order.supplierName != null &&
                            order.supplierName!.isNotEmpty)
                          _buildCoverDetailRow('المورد', order.supplierName!),
                        _buildCoverDetailRow(
                          'تاريخ الإصدار',
                          DateFormat('yyyy/MM/dd').format(DateTime.now()),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // تذييل الغلاف
                  pw.Container(
                    padding: const pw.EdgeInsets.only(top: 20),
                    child: pw.Column(
                      children: [
                        pw.Divider(color: PdfColor.fromInt(0x66FFFFFF)),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'السجل التجاري: 7011144750 | الرقم الضريبي: 313061665400003',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xCCFFFFFF),
                            fontSize: 12,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'تم إنشاء هذا التقرير آلياً بواسطة نظام إدارة الطلبات',
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xCCFFFFFF),
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  pw.Widget _buildCoverDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 14),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  pw.Page _buildBasicInfoPage(Order order) {
    final orderType = _safeOrderType(order);
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final backgroundColor = PdfColor.fromInt(AppColors.backgroundGray.value);
    final borderColor = PdfColor.fromInt(AppColors.lightGray.value);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35),
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // الهيدر
              _buildPdfHeader(
                logo: _companyLogo,
                crNumber: '7011144750',
                vatNumber: '313061665400003',
              ),

              pw.SizedBox(height: 20),

              // عنوان الصفحة
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'معلومات الطلب الأساسية',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // جدول المعلومات الأساسية
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: backgroundColor,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: borderColor, width: 1),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfDetailRow('رقم الطلب', order.orderNumber),
                    _buildPdfDetailRow('نوع الطلب', orderType),
                    _buildPdfDetailRow('مصدر الطلب', order.orderSource),
                    _buildPdfDetailRow('حالة الدمج', order.mergeStatus),
                    _buildPdfDetailRow('حالة الطلب', order.status),
                    _buildPdfDetailRow(
                      'تاريخ الإنشاء',
                      DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt),
                    ),
                    _buildPdfDetailRow(
                      'آخر تحديث',
                      DateFormat('yyyy/MM/dd HH:mm').format(order.updatedAt),
                    ),
                    if (order.supplierOrderNumber != null &&
                        order.supplierOrderNumber!.isNotEmpty)
                      _buildPdfDetailRow(
                        'رقم طلب المورد',
                        order.supplierOrderNumber!,
                      ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // معلومات المصدر
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildInfoBox(
                      title: 'معلومات المصدر',
                      iconColor: PdfColor.fromInt(AppColors.infoBlue.value),
                      children: [
                        _buildPdfDetailRow('نوع المصدر', order.orderSource),
                        _buildPdfDetailRow('طلب #', order.orderNumber),
                        if (order.requestType != null)
                          _buildPdfDetailRow('نوع العملية', order.requestType!),
                        if (order.productType != null)
                          _buildPdfDetailRow('نوع المنتج', order.productType!),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildInfoBox(
                      title: 'معلومات النظام',
                      iconColor: PdfColor.fromInt(AppColors.successGreen.value),
                      children: [
                        _buildPdfDetailRow('الحالة', order.status),
                        _buildPdfDetailRow('حالة الدمج', order.mergeStatus),
                        _buildPdfDetailRow(
                          'تاريخ الإنشاء',
                          DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(order.createdAt),
                        ),
                        _buildPdfDetailRow(
                          'آخر تحديث',
                          DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(order.updatedAt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              _buildPageFooter(context.pageNumber, 'معلومات أساسية'),
            ],
          ),
        );
      },
    );
  }

  pw.Page _buildCustomerSupplierPage(Order order) {
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final tealColor = PdfColor.fromInt(AppColors.secondaryTeal.value);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35),
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPdfHeader(
                logo: _companyLogo,
                crNumber: '7011144750',
                vatNumber: '313061665400003',
              ),

              pw.SizedBox(height: 20),

              // عنوان الصفحة
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'معلومات العميل والمورد',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // معلومات العميل
              if (_getCustomerName(order) != null)
                pw.Column(
                  children: [
                    _buildSectionHeader('معلومات العميل', color: tealColor),
                    pw.SizedBox(height: 10),
                    _buildCustomerInfoCard(order),
                    pw.SizedBox(height: 30),
                  ],
                ),

              // معلومات المورد
              if (order.supplierName != null && order.supplierName!.isNotEmpty)
                pw.Column(
                  children: [
                    _buildSectionHeader('معلومات المورد', color: primaryColor),
                    pw.SizedBox(height: 10),
                    _buildSupplierInfoCard(order),
                    pw.SizedBox(height: 30),
                  ],
                ),

              // معلومات الدمج
              if (order.isMerged)
                pw.Column(
                  children: [
                    _buildSectionHeader(
                      'معلومات الدمج',
                      color: PdfColor.fromInt(AppColors.successGreen.value),
                    ),
                    pw.SizedBox(height: 10),
                    _buildMergeInfoCard(order),
                    pw.SizedBox(height: 30),
                  ],
                ),

              _buildPageFooter(context.pageNumber, 'العميل والمورد'),
            ],
          ),
        );
      },
    );
  }

  pw.Page _buildDriverVehiclePage(Order order) {
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final tealColor = PdfColor.fromInt(AppColors.secondaryTeal.value);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35),
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPdfHeader(
                logo: _companyLogo,
                crNumber: '7011144750',
                vatNumber: '313061665400003',
              ),

              pw.SizedBox(height: 20),

              // عنوان الصفحة
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'معلومات السائق والمركبة',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // معلومات السائق
              if (_getDriverName(order) != null || order.driver != null)
                pw.Column(
                  children: [
                    _buildSectionHeader('معلومات السائق', color: tealColor),
                    pw.SizedBox(height: 10),
                    _buildDriverInfoCard(order),
                    pw.SizedBox(height: 30),
                  ],
                ),

              // معلومات المركبة
              if (order.vehicleNumber != null &&
                  order.vehicleNumber!.isNotEmpty)
                pw.Column(
                  children: [
                    _buildSectionHeader(
                      'معلومات المركبة',
                      color: PdfColor.fromInt(0xFF795548),
                    ),
                    pw.SizedBox(height: 10),
                    _buildVehicleInfoCard(order),
                    pw.SizedBox(height: 30),
                  ],
                ),

              // معلومات التحميل والتسليم
              pw.Column(
                children: [
                  _buildSectionHeader(
                    'تفاصيل التحميل والتسليم',
                    color: PdfColor.fromInt(AppColors.warningOrange.value),
                  ),
                  pw.SizedBox(height: 10),
                  _buildLoadingInfoCard(order),
                ],
              ),

              _buildPageFooter(context.pageNumber, 'السائق والمركبة'),
            ],
          ),
        );
      },
    );
  }

  pw.Page _buildTechnicalDetailsPage(Order order) {
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final orangeColor = PdfColor.fromInt(AppColors.warningOrange.value);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35),
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPdfHeader(
                logo: _companyLogo,
                crNumber: '7011144750',
                vatNumber: '313061665400003',
              ),

              pw.SizedBox(height: 20),

              // عنوان الصفحة
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'التفاصيل الفنية للطلب',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // معلومات المنتج/الوقود
              pw.Column(
                children: [
                  _buildSectionHeader('تفاصيل المنتج', color: orangeColor),
                  pw.SizedBox(height: 10),
                  _buildProductInfoCard(order),
                  pw.SizedBox(height: 30),
                ],
              ),

              // معلومات الموقع
              pw.Column(
                children: [
                  _buildSectionHeader(
                    'معلومات الموقع',
                    color: PdfColor.fromInt(AppColors.infoBlue.value),
                  ),
                  pw.SizedBox(height: 10),
                  _buildLocationInfoCard(order),
                  pw.SizedBox(height: 30),
                ],
              ),

              // معلومات المواعيد
              pw.Column(
                children: [
                  _buildSectionHeader(
                    'المواعيد والتواريخ',
                    color: PdfColor.fromInt(AppColors.pendingYellow.value),
                  ),
                  pw.SizedBox(height: 10),
                  _buildScheduleInfoCard(order),
                ],
              ),

              _buildPageFooter(context.pageNumber, 'التفاصيل الفنية'),
            ],
          ),
        );
      },
    );
  }

  pw.Page _buildTimelinePage(Order order) {
    final primaryColor = PdfColor.fromInt(AppColors.primaryBlue.value);
    final purpleColor = PdfColor.fromInt(0xFF9C27B0);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35),
      theme: pw.ThemeData.withFont(base: _cairoRegular!, bold: _cairoBold!),
      build: (pw.Context context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildPdfHeader(
                logo: _companyLogo,
                crNumber: '7011144750',
                vatNumber: '313061665400003',
              ),

              pw.SizedBox(height: 20),

              // عنوان الصفحة
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'الجدول الزمني للأحداث',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // الجدول الزمني
              pw.Column(
                children: [
                  _buildSectionHeader('سجل الأحداث', color: purpleColor),
                  pw.SizedBox(height: 10),
                  _buildTimelineCard(order),
                  pw.SizedBox(height: 30),
                ],
              ),

              // الإحصائيات
              pw.Column(
                children: [
                  _buildSectionHeader(
                    'إحصائيات الطلب',
                    color: PdfColor.fromInt(AppColors.successGreen.value),
                  ),
                  pw.SizedBox(height: 10),
                  _buildStatisticsCard(order),
                ],
              ),

              _buildPageFooter(context.pageNumber, 'السجل الزمني'),
            ],
          ),
        );
      },
    );
  }

  pw.Widget _buildSectionHeader(String title, {required PdfColor color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(6),
          topRight: pw.Radius.circular(6),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoBox({
    required String title,
    required PdfColor iconColor,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.lightGray.value),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: iconColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(children: children),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerInfoCard(Order order) {
    final customer = order.customer;
    final customerAddress = order.customerAddress ?? customer?.address;
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.secondaryTeal.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.secondaryTeal.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'معلومات العميل',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                if (_getCustomerName(order) != null)
                  _buildPdfDetailRow('الاسم', _getCustomerName(order)!),
                if (customer?.code != null && customer!.code!.isNotEmpty)
                  _buildPdfDetailRow('الكود', customer.code!),
                if (customer?.phone != null && customer!.phone!.isNotEmpty)
                  _buildPdfDetailRow('الهاتف', customer.phone!),
                if (customer?.email != null && customer!.email!.isNotEmpty)
                  _buildPdfDetailRow('البريد الإلكتروني', customer.email!),
                if (customerAddress != null && customerAddress.isNotEmpty)
                  _buildPdfDetailRow('العنوان', customerAddress),
                if (customer?.customerType != null)
                  _buildPdfDetailRow('نوع العميل', customer!.customerType!),
                if (customer?.company != null && customer!.company!.isNotEmpty)
                  _buildPdfDetailRow('الشركة', customer.company!),
                if (customer?.taxNumber != null &&
                    customer!.taxNumber!.isNotEmpty)
                  _buildPdfDetailRow('الرقم الضريبي', customer.taxNumber!),
                if (customer?.commercialRecord != null &&
                    customer!.commercialRecord!.isNotEmpty)
                  _buildPdfDetailRow(
                    'السجل التجاري',
                    customer.commercialRecord!,
                  ),
                if (customer?.totalOrders != null)
                  _buildPdfDetailRow(
                    'عدد الطلبات',
                    customer!.totalOrders!.toString(),
                  ),
                if (customer?.totalSpent != null)
                  _buildPdfDetailRow(
                    'إجمالي الإنفاق',
                    '${customer!.totalSpent!.toStringAsFixed(2)} ريال',
                  ),
                if (customer?.lastOrderDate != null)
                  _buildPdfDetailRow(
                    'آخر طلب',
                    DateFormat('yyyy/MM/dd').format(customer!.lastOrderDate!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSupplierInfoCard(Order order) {
    final supplier = order.supplier;
    final supplierAddress = order.supplierAddress ?? supplier?.address;
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.primaryBlue.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.primaryBlue.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'معلومات المورد',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                if (order.supplierName != null &&
                    order.supplierName!.isNotEmpty)
                  _buildPdfDetailRow('الاسم', order.supplierName!),
                if (order.supplierPhone != null &&
                    order.supplierPhone!.isNotEmpty)
                  _buildPdfDetailRow('الهاتف', order.supplierPhone!),
                if (supplierAddress != null && supplierAddress.isNotEmpty)
                  _buildPdfDetailRow('العنوان', supplierAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDriverInfoCard(Order order) {
    final driver = order.driver;
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.secondaryTeal.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.secondaryTeal.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'معلومات السائق الأساسية',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                if (_getDriverName(order) != null)
                  _buildPdfDetailRow('الاسم', _getDriverName(order)!),

                _buildPdfDetailRow('نوع المركبة', driver!.vehicleType),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVehicleInfoCard(Order order) {
    final driver = order.driver;
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF795548), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF795548),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'معلومات المركبة',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                if (order.vehicleNumber != null &&
                    order.vehicleNumber!.isNotEmpty)
                  _buildPdfDetailRow('رقم المركبة', order.vehicleNumber!),
                if (driver?.vehicleType != null)
                  _buildPdfDetailRow('نوع المركبة', driver!.vehicleType),
                if (order.distance != null)
                  _buildPdfDetailRow(
                    'المسافة',
                    '${order.distance!.toStringAsFixed(2)} كم',
                  ),
                if (order.deliveryDuration != null)
                  _buildPdfDetailRow(
                    'مدة التوصيل',
                    '${order.deliveryDuration} دقيقة',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProductInfoCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.warningOrange.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.warningOrange.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'تفاصيل المنتج',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _buildPdfDetailRow(
                  'نوع المنتج',
                  order.fuelType ?? order.productType ?? '-',
                ),
                _buildPdfDetailRow(
                  'الكمية',
                  '${order.quantity?.toStringAsFixed(0) ?? '0'} ${order.unit ?? 'لتر'}',
                ),
                if (order.productType != null && order.productType!.isNotEmpty)
                  _buildPdfDetailRow('نوع المنتج', order.productType!),
                if (order.requestType != null && order.requestType!.isNotEmpty)
                  _buildPdfDetailRow('نوع العملية', order.requestType!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLocationInfoCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.infoBlue.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.infoBlue.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'معلومات الموقع',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _buildPdfDetailRow('المدينة', order.city ?? '-'),
                _buildPdfDetailRow('المنطقة', order.area ?? '-'),
                _buildPdfDetailRow('العنوان التفصيلي', order.address ?? '-'),
                if (order.supplierAddress != null &&
                    order.supplierAddress!.isNotEmpty)
                  _buildPdfDetailRow('عنوان المورد', order.supplierAddress!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildScheduleInfoCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.pendingYellow.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.pendingYellow.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'المواعيد والتواريخ',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _buildPdfDetailRow(
                  'تاريخ الطلب',
                  DateFormat('yyyy/MM/dd').format(order.orderDate),
                ),
                _buildPdfDetailRow(
                  'تاريخ الوصول',
                  DateFormat('yyyy/MM/dd').format(order.arrivalDate),
                ),
                _buildPdfDetailRow('وقت الوصول', order.arrivalTime),
                _buildPdfDetailRow(
                  'تاريخ التحميل',
                  DateFormat('yyyy/MM/dd').format(order.loadingDate),
                ),
                _buildPdfDetailRow('وقت التحميل', order.loadingTime),
                if (order.actualArrivalTime != null)
                  _buildPdfDetailRow(
                    'وقت الوصول الفعلي',
                    order.actualArrivalTime!,
                  ),
                if (order.loadingCompletedAt != null)
                  _buildPdfDetailRow(
                    'تاريخ انتهاء التحميل',
                    _formatDateTime(order.loadingCompletedAt!),
                  ),
                if (order.loadingDuration != null)
                  _buildPdfDetailRow(
                    'مدة التحميل',
                    '${order.loadingDuration} دقيقة',
                  ),
                if (order.delayReason != null && order.delayReason!.isNotEmpty)
                  _buildPdfDetailRow('سبب التأخير', order.delayReason!),
                if (order.completedAt != null)
                  _buildPdfDetailRow(
                    'تاريخ الإكمال',
                    _formatDateTime(order.completedAt!),
                  ),
                if (order.cancelledAt != null)
                  _buildPdfDetailRow(
                    'تاريخ الإلغاء',
                    _formatDateTime(order.cancelledAt!),
                  ),
                if (order.mergedAt != null)
                  _buildPdfDetailRow(
                    'تاريخ الدمج',
                    _formatDateTime(order.mergedAt!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLoadingInfoCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.warningOrange.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.warningOrange.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'تفاصيل التحميل والتسليم',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                if (order.actualArrivalTime != null)
                  _buildPdfDetailRow(
                    'وقت الوصول الفعلي',
                    order.actualArrivalTime!,
                  ),
                if (order.loadingDuration != null)
                  _buildPdfDetailRow(
                    'مدة التحميل',
                    '${order.loadingDuration} دقيقة',
                  ),
                if (order.loadingCompletedAt != null)
                  _buildPdfDetailRow(
                    'تاريخ انتهاء التحميل',
                    _formatDateTime(order.loadingCompletedAt!),
                  ),
                if (order.delayReason != null && order.delayReason!.isNotEmpty)
                  _buildPdfDetailRow('سبب التأخير', order.delayReason!),
                if (order.completedAt != null)
                  _buildPdfDetailRow(
                    'تاريخ الإكمال',
                    _formatDateTime(order.completedAt!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMergeInfoCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF3E5F5),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF9C27B0), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF9C27B0),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'معلومات الدمج',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _buildPdfDetailRow('حالة الدمج', order.mergeStatus),
                if (order.mergedWithOrderId != null)
                  _buildPdfDetailRow(
                    'رقم الطلب المدمج معه',
                    order.mergedWithOrderId!,
                  ),
                if (order.mergedAt != null)
                  _buildPdfDetailRow(
                    'تاريخ الدمج',
                    _formatDateTime(order.mergedAt!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialInfoCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.successGreen.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.successGreen.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'المعلومات المالية',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                if (order.unitPrice != null)
                  _buildPdfDetailRow(
                    'سعر الوحدة',
                    '${order.unitPrice!.toStringAsFixed(2)} ريال',
                  ),
                if (order.totalPrice != null)
                  _buildPdfDetailRow(
                    'السعر الإجمالي',
                    '${order.totalPrice!.toStringAsFixed(2)} ريال',
                  ),
                if (order.driverEarnings != null)
                  _buildPdfDetailRow(
                    'أرباح السائق',
                    '${order.driverEarnings!.toStringAsFixed(2)} ريال',
                  ),
                if (order.paymentMethod != null &&
                    order.paymentMethod!.isNotEmpty)
                  _buildPdfDetailRow('طريقة الدفع', order.paymentMethod!),
                if (order.paymentStatus != null &&
                    order.paymentStatus!.isNotEmpty)
                  _buildPdfDetailRow('حالة الدفع', order.paymentStatus!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNotesCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.mediumGray.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.mediumGray.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'ملاحظات الطلب',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Text(
              order.notes!,
              style: const pw.TextStyle(
                color: PdfColors.black,
                fontSize: 10,
                height: 1.5,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAttachmentsCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.primaryBlue.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.primaryBlue.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'المرفقات (${order.attachments.length})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                for (var attachment in order.attachments)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(AppColors.lightGray.value),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(
                              AppColors.primaryBlue.value,
                            ),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            '📄',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                attachment.filename,
                                style: pw.TextStyle(
                                  color: PdfColors.black,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                DateFormat(
                                  'yyyy/MM/dd HH:mm',
                                ).format(attachment.uploadedAt),
                                style: pw.TextStyle(
                                  color: PdfColor.fromInt(
                                    AppColors.mediumGray.value,
                                  ),
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTimelineCard(Order order) {
    final events = <Map<String, dynamic>>[
      if (order.createdAt != null)
        {
          'title': 'إنشاء الطلب',
          'date': order.createdAt,
          'icon': PdfTextIcons.created,
          'color': PdfColor.fromInt(0xFF2196F3),
        },
      if (order.orderDate != null)
        {
          'title': 'تاريخ الطلب',
          'date': order.orderDate,
          'icon': PdfTextIcons.calendar,
          'color': PdfColor.fromInt(0xFF4CAF50),
        },
      if (order.arrivalDate != null)
        {
          'title': 'تاريخ الوصول المخطط',
          'date': order.arrivalDate,
          'time': order.arrivalTime,
          'icon': PdfTextIcons.clock,
          'color': PdfColor.fromInt(0xFFFF9800),
        },
      if (order.loadingDate != null)
        {
          'title': 'تاريخ التحميل المخطط',
          'date': order.loadingDate,
          'time': order.loadingTime,
          'icon': PdfTextIcons.driver,
          'color': PdfColor.fromInt(0xFF9C27B0),
        },
      if (order.mergedAt != null)
        {
          'title': 'دمج الطلب',
          'date': order.mergedAt,
          'icon': PdfTextIcons.merge,
          'color': PdfColor.fromInt(0xFF00BCD4),
        },
      if (order.loadingCompletedAt != null)
        {
          'title': 'انتهاء التحميل',
          'date': order.loadingCompletedAt,
          'icon': PdfTextIcons.done,
          'color': PdfColor.fromInt(0xFF8BC34A),
        },
      if (order.completedAt != null)
        {
          'title': 'إكمال الطلب',
          'date': order.completedAt,
          'icon': PdfTextIcons.completed,
          'color': PdfColor.fromInt(0xFF4CAF50),
        },
      if (order.cancelledAt != null)
        {
          'title': 'إلغاء الطلب',
          'date': order.cancelledAt,
          'icon': PdfTextIcons.canceled,
          'color': PdfColor.fromInt(0xFFF44336),
        },
    ];

    // ترتيب الأحداث حسب التاريخ
    events.sort((a, b) => a['date'].compareTo(b['date']));

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF9C27B0), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF9C27B0),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'سجل الأحداث',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                for (int i = 0; i < events.length; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // النقطة
                        pw.Container(
                          width: 20,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: events[i]['color'],
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              events[i]['icon'],
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                events[i]['title'],
                                style: pw.TextStyle(
                                  color: PdfColor.fromInt(
                                    AppColors.darkGray.value,
                                  ),
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${DateFormat('yyyy/MM/dd').format(events[i]['date'])}${events[i]['time'] != null ? ' ${events[i]['time']}' : ''}',
                                style: pw.TextStyle(
                                  color: PdfColor.fromInt(
                                    AppColors.mediumGray.value,
                                  ),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatisticsCard(Order order) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(AppColors.backgroundGray.value),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.successGreen.value),
          width: 1,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.successGreen.value),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'إحصائيات الطلب',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatCard(
                  'المدة الكلية',
                  order.createdAt != null && order.completedAt != null
                      ? '${order.completedAt!.difference(order.createdAt).inHours} ساعة'
                      : 'قيد التنفيذ',
                  PdfTextIcons.clock,
                ),
                _buildStatCard('حالة الطلب', order.status, PdfTextIcons.status),
                _buildStatCard(
                  'نوع المصدر',
                  order.orderSource,
                  PdfTextIcons.source,
                ),
                if (order.totalPrice != null)
                  _buildStatCard(
                    'القيمة الإجمالية',
                    '${order.totalPrice!.toStringAsFixed(2)} ريال',
                    PdfTextIcons.money,
                  ),
                if (order.quantity != null)
                  _buildStatCard(
                    'الكمية',
                    '${order.quantity!.toStringAsFixed(0)} ${order.unit ?? 'وحدة'}',
                    PdfTextIcons.quantity,
                  ),
                if (order.attachments.isNotEmpty)
                  _buildStatCard(
                    'المرفقات',
                    '${order.attachments.length}',
                    '📎',
                  ),
                _buildStatCard('حالة الدمج', order.mergeStatus, '🔄'),
                if (order.distance != null)
                  _buildStatCard(
                    'المسافة',
                    '${order.distance!.toStringAsFixed(2)} كم',
                    PdfTextIcons.distance,
                  ),
                if (order.deliveryDuration != null)
                  _buildStatCard(
                    'مدة التوصيل',
                    '${order.deliveryDuration} دقيقة',
                    PdfTextIcons.clock,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatCard(String title, String value, String emoji) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.lightGray.value),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(emoji, style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 2),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.mediumGray.value),
              fontSize: 7,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.darkGray.value),
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDetailItem(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(
          color: PdfColor.fromInt(AppColors.lightGray.value),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.mediumGray.value),
              fontSize: 8,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.darkGray.value),
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                color: PdfColor.fromInt(AppColors.primaryBlue.value),
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: const pw.TextStyle(color: PdfColors.black, fontSize: 9),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDetailRow(String label, dynamic value) {
    final String displayValue = value == null
        ? '-'
        : value is String
        ? value
        : value.toString();

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(AppColors.primaryBlue.value),
                ),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                displayValue,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPageFooter(int pageNumber, String section) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColor.fromInt(AppColors.lightGray.value),
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'الصفحة $pageNumber - $section',
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.mediumGray.value),
              fontSize: 8,
            ),
          ),
          pw.Text(
            '${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.mediumGray.value),
              fontSize: 8,
            ),
          ),
          pw.Text(
            'نظام إدارة الطلبات',
            style: pw.TextStyle(
              color: PdfColor.fromInt(AppColors.mediumGray.value),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Helper Functions العامة
  // ============================================

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
  }

  // String? _getCustomerName(Order order) {
  //   return order.customer?.name ?? order.customerName;
  // }

  // String? _getDriverName(Order order) {
  //   return order.driver?.name ?? order.driverName;
  // }

  // String _safeOrderType(Order order) {
  //   try {
  //     return order.type ?? 'غير محدد';
  //   } catch (e) {
  //     return 'غير محدد';
  //   }
  // }

  void _shareOrderDetails() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سيتم تفعيل المشاركة في تحديثات لاحقة'),
          backgroundColor: AppColors.infoBlue,
        ),
      );
    }
  }

  void _showDeleteDialog() {
    final order = Provider.of<OrderProvider>(
      context,
      listen: false,
    ).selectedOrder;
    if (order == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الطلب'),
        content: Text(
          'هل أنت متأكد من حذف الطلب ${order.orderNumber}؟\nلا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final orderProvider = Provider.of<OrderProvider>(
                context,
                listen: false,
              );
              final success = await orderProvider.deleteOrder(widget.orderId);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف الطلب بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح المرفق'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _downloadAttachment(
    String url, {
    required String filename,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        throw Exception('Download failed with status ${response.statusCode}');
      }
      await saveAndLaunchFile(response.bodyBytes, filename);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل المرفق'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  String _attachmentDownloadName(Attachment attachment) {
    final trimmed = attachment.filename.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final uri = Uri.tryParse(attachment.path);
    final lastSegment = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : '';
    return lastSegment.isNotEmpty ? lastSegment : 'attachment';
  }

  Widget _buildOrderAttachmentItem(Attachment attachment) {
    final uploadedAt = DateFormat(
      'yyyy/MM/dd HH:mm',
    ).format(attachment.uploadedAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  attachment.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            attachment.path,
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
          const SizedBox(height: 6),
          Text(
            'تم الرفع: $uploadedAt',
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAttachment(attachment.path),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('فتح الرابط'),
              ),
              OutlinedButton.icon(
                onPressed: () => _downloadAttachment(
                  attachment.path,
                  filename: _attachmentDownloadName(attachment),
                ),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('تحميل'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLimitedEditDialog() {
    final order = context.read<OrderProvider>().selectedOrder;
    if (order == null) return;

    final orderType = _safeOrderType(order);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل الطلب'),
        content: Text(
          orderType == 'مورد'
              ? 'سيتم فتح تعديل طلب المورد'
              : orderType == 'عميل'
              ? 'سيتم فتح تعديل طلب العميل'
              : 'سيتم فتح تعديل الطلب المدمج',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // 🔴 أغلق الـ Dialog أولًا

              // ✅ استخدم نفس الطلب بدون إعادة تعريف
              if (orderType == 'مورد') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.supplierOrderForm,
                  arguments: order,
                );
              } else if (orderType == 'عميل') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.customerOrderForm,
                  arguments: order,
                );
              } else if (orderType == 'مدمج') {
                Navigator.pushNamed(
                  context,
                  AppRoutes.mergeOrders,
                  arguments: order,
                );
              }
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.selectedOrder;
    final activities = orderProvider.activities;

    if (orderProvider.isLoading && order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('الطلب غير موجود')),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final orderType = _safeOrderType(order);
    final orderTypeColor = _getOrderTypeColor(orderType);
    final customerName = _getCustomerName(order);
    final driverName = _getDriverName(order);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(isDesktop, order, orderType, orderTypeColor),
        body: isDesktop
            ? _buildDesktopLayout(
                context,
                order,
                activities,
                orderType,
                orderTypeColor,
              )
            : _buildMobileLayout(
                context,
                order,
                activities,
                orderType,
                orderTypeColor,
              ),
      ),
    );
  }

  AppBar _buildAppBar(
    bool isDesktop,
    Order order,
    String orderType,
    Color orderTypeColor,
  ) {
    return AppBar(
      title: isDesktop
          ? Row(
              children: [
                Text(
                  'تفاصيل الطلب - ${order.orderNumber}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: orderTypeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: orderTypeColor),
                  ),
                  child: Text(
                    orderType,
                    style: TextStyle(
                      color: orderTypeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    'الطلب ${order.orderNumber}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: orderTypeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: orderTypeColor),
                  ),
                  child: Text(
                    orderType,
                    style: TextStyle(
                      color: orderTypeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      foregroundColor: Colors.white,
      actions: [
        // ⭐ تعديل محدود بدلاً من التعديل الكامل
        IconButton(
          onPressed: _showLimitedEditDialog,
          icon: const Icon(Icons.edit),
          tooltip: 'تعديل محدود',
        ),
        IconButton(
          onPressed: _showExportOptions,
          icon: const Icon(Icons.download),
          tooltip: 'تصدير',
        ),
        PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'delete') _showDeleteDialog();
          },
        ),
      ],
      bottom: TabBar(
        tabs: const [
          Tab(text: 'الملخص'),
          Tab(text: 'التفاصيل'),
          Tab(text: 'سجل الحركات'),
        ],
        onTap: (index) => setState(() => _selectedTab = index),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    Order order,
    List<Activity> activities,
    String orderType,
    Color orderTypeColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildOrderDetailsPanel(
              context,
              order,
              orderType,
              orderTypeColor,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _buildActivitiesPanel(activities),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    Order order,
    List<Activity> activities,
    String orderType,
    Color orderTypeColor,
  ) {
    return TabBarView(
      children: [
        _buildSummaryTab(context, order, orderType, orderTypeColor),
        _buildDetailsTab(context, order, orderType),
        _buildActivitiesTab(activities),
      ],
    );
  }

  Widget _buildSummaryTab(
    BuildContext context,
    Order order,
    String orderType,
    Color orderTypeColor,
  ) {
    final customerName = _getCustomerName(order);
    final driverName = _getDriverName(order);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: orderTypeColor, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: orderTypeColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          orderType == 'مورد'
                              ? Icons.business
                              : orderType == 'عميل'
                              ? Icons.person
                              : Icons.link,
                          color: orderTypeColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلب $orderType',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: orderTypeColor,
                              ),
                            ),
                            Text(
                              'رقم الطلب: ${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.mediumGray,
                              ),
                            ),
                            if ((orderType == 'مدمج' || orderType == 'مورد') &&
                                order.supplierOrderNumber != null &&
                                order.supplierOrderNumber!.isNotEmpty)
                              Text(
                                'رقم طلب المورد: ${order.supplierOrderNumber}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.infoBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(order.status),
                          ),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (customerName != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, color: orderTypeColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (order.customer?.phone != null)
                                Text(
                                  'هاتف: ${order.customer!.phone!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              if (order.city != null)
                                Text(
                                  'المدينة: ${order.city!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              if (order.orderNumber.startsWith('CUS-'))
                                Text(
                                  'رقم طلب العميل: ${order.orderNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.successGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (order.supplierName != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.business, color: orderTypeColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.supplierName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (order.supplierContactPerson != null)
                                Text(
                                  'جهة الاتصال: ${order.supplierContactPerson!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              if (order.supplierPhone != null)
                                Text(
                                  'هاتف: ${order.supplierPhone!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              if (_supplier?.city != null)
                                Text(
                                  'المدينة: ${_supplier!.city!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              if (order.city != null)
                                Text(
                                  'موقع التسليم: ${order.city!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              if (order.supplierOrderNumber != null &&
                                  order.supplierOrderNumber!.isNotEmpty)
                                Text(
                                  'رقم طلب المورد: ${order.supplierOrderNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else if (order.orderNumber.startsWith('SUP-'))
                                Text(
                                  'رقم طلب المورد: ${order.orderNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OrderStatusTimeline(order: order),
          const SizedBox(height: 16),
          if (_remainingLoadingTime != null &&
              _remainingLoadingTime != Duration.zero &&
              order.loadingTime != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.successGreen),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppColors.successGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الوقت المتبقي حتى التحميل',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGray,
                            ),
                          ),
                          Text(
                            _formatDuration(_remainingLoadingTime!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildInfoCard(
                icon: orderType == 'مورد' ? Icons.business : Icons.person,
                title: orderType == 'مورد' ? 'المورد' : 'العميل',
                value: orderType == 'مورد'
                    ? (order.supplierName ?? 'غير محدد')
                    : (_getCustomerName(order) ?? 'غير محدد'),
                color: orderTypeColor,
              ),
              _buildInfoCard(
                icon: Icons.local_gas_station,
                title: 'نوع الوقود',
                value: order.fuelType ?? 'غير محدد',
                color: AppColors.warningOrange,
              ),
              _buildInfoCard(
                icon: Icons.scale,
                title: 'الكمية',
                value:
                    '${order.quantity?.toStringAsFixed(0) ?? '0'} ${order.unit ?? 'لتر'}',
                color: AppColors.infoBlue,
              ),
              _buildInfoCard(
                icon: Icons.date_range,
                title: 'تاريخ التحميل',
                value: DateFormat('yyyy/MM/dd').format(order.loadingDate),
                color: AppColors.pendingYellow,
              ),
              if (driverName != null)
                _buildInfoCard(
                  icon: Icons.directions_car,
                  title: 'السائق',
                  value: driverName,
                  color: AppColors.secondaryTeal,
                ),
              if (order.city != null)
                _buildInfoCard(
                  icon: Icons.location_city,
                  title: 'المدينة',
                  value: order.city!,
                  color: AppColors.primaryBlue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, Order order, String orderType) {
    final customerName = _getCustomerName(order);
    final driverName = _getDriverName(order);
    final driverPhone = _getDriverPhone(order);
    final money = NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    );
    // التحقق من null لمنع الأخطاء
    final customer = order.customer;
    final customerCode = customer?.code;
    final customerPhone = customer?.phone;
    final customerEmail = customer?.email;
    final customerAddress = order.customerAddress ?? customer?.address;
    final supplierAddress = order.supplierAddress ?? _supplier?.address;
    final effectiveRequestType = order.effectiveRequestType;
    final bool showRequestType =
        effectiveRequestType.trim().isNotEmpty &&
        effectiveRequestType != 'غير محدد' &&
        (order.orderSource == 'عميل' || order.orderSource == 'مدمج');
    final String requestTypeLabel = order.orderSource == 'مدمج'
        ? 'نوع طلب العميل'
        : 'نوع العملية';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            title: 'معلومات الطلب الأساسية',
            icon: Icons.info,
            color: AppColors.primaryBlue,
            children: [
              _buildUiDetailRow('رقم الطلب', order.orderNumber),
              if (order.supplierOrderNumber != null &&
                  order.supplierOrderNumber!.isNotEmpty)
                _buildUiDetailRow('رقم طلب المورد', order.supplierOrderNumber!),
              _buildUiDetailRow('نوع الطلب', orderType),
              if (showRequestType)
                _buildUiDetailRow(requestTypeLabel, effectiveRequestType),

              _buildUiDetailRow('الحالة', order.status),
              _buildUiDetailRow(
                'تاريخ الإنشاء',
                DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt),
              ),
              _buildUiDetailRow(
                'آخر تحديث',
                DateFormat('yyyy/MM/dd HH:mm').format(order.updatedAt),
              ),
              if (orderType == 'مورد' && order.orderNumber.startsWith('SUP-'))
                _buildUiDetailRowWithIcon(
                  'رقم طلب المورد',
                  order.orderNumber,
                  Icons.business,
                  AppColors.primaryBlue,
                ),
              if (orderType == 'عميل' && order.orderNumber.startsWith('CUS-'))
                _buildUiDetailRowWithIcon(
                  'رقم طلب العميل',
                  order.orderNumber,
                  Icons.person,
                  AppColors.secondaryTeal,
                ),
              if (orderType == 'مدمج' && order.orderNumber.startsWith('MIX-'))
                _buildUiDetailRowWithIcon(
                  'رقم الطلب المدمج',
                  order.orderNumber,
                  Icons.link,
                  AppColors.successGreen,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // معلومات العميل
          if (customerName != null)
            _buildInfoSection(
              title: 'معلومات العميل',
              icon: Icons.person,
              color: AppColors.secondaryTeal,
              children: [
                _buildUiDetailRow('اسم العميل', customerName),
                if (customerCode != null && customerCode.isNotEmpty)
                  _buildUiDetailRow('كود العميل', customerCode),
                if (customerPhone != null && customerPhone.isNotEmpty)
                  _buildUiDetailRow('هاتف العميل', customerPhone),
                if (customerEmail != null && customerEmail.isNotEmpty)
                  _buildUiDetailRow('البريد الإلكتروني', customerEmail),
                if (customerAddress != null && customerAddress.isNotEmpty)
                  _buildUiDetailRow('العنوان', customerAddress),
                if (order.city != null)
                  _buildUiDetailRow('المدينة', order.city!),
                if (order.area != null)
                  _buildUiDetailRow('المنطقة', order.area!),
                if (order.orderNumber.startsWith('CUS-'))
                  _buildUiDetailRowWithIcon(
                    'رقم طلب العميل',
                    order.orderNumber,
                    Icons.confirmation_number,
                    AppColors.successGreen,
                  ),
              ],
            ),

          if (customerName != null) const SizedBox(height: 16),

          // معلومات المورد
          if (order.supplierName != null && order.supplierName!.isNotEmpty)
            _buildInfoSection(
              title: 'معلومات المورد',
              icon: Icons.business,
              color: AppColors.primaryBlue,
              children: [
                _buildUiDetailRow('اسم المورد', order.supplierName!),
                if (order.supplierContactPerson != null &&
                    order.supplierContactPerson!.isNotEmpty)
                  _buildUiDetailRow(
                    'جهة الاتصال',
                    order.supplierContactPerson!,
                  ),
                if (order.supplierPhone != null &&
                    order.supplierPhone!.isNotEmpty)
                  _buildUiDetailRow('هاتف المورد', order.supplierPhone!),
                if (order.supplierCompany != null &&
                    order.supplierCompany!.isNotEmpty)
                  _buildUiDetailRow('الشركة', order.supplierCompany!),
                if (_supplier?.city != null && _supplier!.city!.isNotEmpty)
                  _buildUiDetailRow('المدينة', _supplier!.city!),
                if (supplierAddress != null && supplierAddress.isNotEmpty)
                  _buildUiDetailRow('العنوان', supplierAddress),
                if (order.supplierOrderNumber != null &&
                    order.supplierOrderNumber!.isNotEmpty)
                  _buildUiDetailRowWithIcon(
                    'رقم طلب المورد',
                    order.supplierOrderNumber!,
                    Icons.confirmation_number,
                    AppColors.primaryBlue,
                  )
                else if (order.orderNumber.startsWith('SUP-'))
                  _buildUiDetailRowWithIcon(
                    'رقم طلب المورد',
                    order.orderNumber,
                    Icons.confirmation_number,
                    AppColors.primaryBlue,
                  ),
                if (order.city != null && order.area != null)
                  _buildUiDetailRow(
                    'موقع التسليم',
                    '${order.city!} - ${order.area!}',
                  ),
              ],
            ),

          if (order.supplierName != null && order.supplierName!.isNotEmpty)
            const SizedBox(height: 16),

          // معلومات الوقود
          _buildInfoSection(
            title: 'معلومات الوقود',
            icon: Icons.local_gas_station,
            color: AppColors.warningOrange,
            children: [
              _buildUiDetailRow('نوع الوقود', order.fuelType ?? 'غير محدد'),
              _buildUiDetailRow(
                'الكمية',
                '${order.quantity?.toStringAsFixed(0) ?? '0'} ${order.unit ?? 'لتر'}',
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoSection(
            title: 'المعلومات المالية',
            icon: Icons.calculate_outlined,
            color: AppColors.successGreen,
            children: [
              _buildUiDetailRow(
                'سعر الوقود/لتر',
                money.format(order.effectiveFuelPricePerLiter),
              ),
              if (order.effectiveRequestType == 'نقل' &&
                  order.effectiveTransportValue != null)
                _buildUiDetailRow(
                  order.effectiveTransportMode == 'per_liter'
                      ? 'إيجار النقل/لتر'
                      : 'إيجار النقل',
                  order.effectiveTransportMode == 'per_liter'
                      ? '${money.format(order.effectiveTransportValue!)} / لتر'
                      : money.format(order.effectiveTransportValue!),
                ),
              if (order.effectiveRequestType == 'نقل' &&
                  order.effectiveReturnValue != null)
                _buildUiDetailRow(
                  order.effectiveReturnMode == 'per_liter' ? 'الرد/لتر' : 'الرد',
                  order.effectiveReturnMode == 'per_liter'
                      ? '${money.format(order.effectiveReturnValue!)} / لتر'
                      : money.format(order.effectiveReturnValue!),
                ),
              if (order.effectiveTransportSourceCity?.trim().isNotEmpty == true)
                _buildUiDetailRow(
                  'مدينة المصدر',
                  order.effectiveTransportSourceCity!,
                ),
              if (order.effectiveTransportCapacityLiters != null)
                _buildUiDetailRow(
                  'السعة',
                  '${order.effectiveTransportCapacityLiters} لتر',
                ),
              if (order.unitPrice != null || order.hasPricingSnapshot)
                _buildUiDetailRow(
                  'سعر الوحدة/لتر',
                  money.format(order.effectiveUnitPricePerLiter),
                ),
              if (order.totalPrice != null || order.hasPricingSnapshot) ...[
                _buildUiDetailRow(
                  'الإجمالي قبل الضريبة',
                  money.format(order.effectiveSubtotal),
                ),
                _buildUiDetailRow(
                  'VAT ${(order.effectiveVatRate * 100).toStringAsFixed(0)}%',
                  money.format(order.effectiveVatAmount),
                ),
                _buildUiDetailRow(
                  'الإجمالي شامل الضريبة',
                  money.format(order.effectiveTotalWithVat),
                ),
              ],
              if (order.paymentMethod != null &&
                  order.paymentMethod!.trim().isNotEmpty)
                _buildUiDetailRow('طريقة الدفع', order.paymentMethod!),
              if (order.paymentStatus != null &&
                  order.paymentStatus!.trim().isNotEmpty)
                _buildUiDetailRow('حالة الدفع', order.paymentStatus!),
            ],
          ),

          const SizedBox(height: 16),

          // المواعيد
          _buildInfoSection(
            title: 'المواعيد',
            icon: Icons.access_time,
            color: AppColors.infoBlue,
            children: [
              _buildUiDetailRow(
                'تاريخ الطلب',
                DateFormat('yyyy/MM/dd').format(order.orderDate),
              ),
              _buildUiDetailRow(
                'تاريخ الوصول',
                DateFormat('yyyy/MM/dd').format(order.arrivalDate),
              ),
              _buildUiDetailRow('وقت الوصول', order.arrivalTime),
              _buildUiDetailRow(
                'تاريخ التحميل',
                DateFormat('yyyy/MM/dd').format(order.loadingDate),
              ),
              _buildUiDetailRow('وقت التحميل', order.loadingTime),
              if (order.actualArrivalTime != null)
                _buildUiDetailRow(
                  'وقت الوصول الفعلي',
                  order.actualArrivalTime!,
                ),
              if (order.loadingDuration != null)
                _buildUiDetailRow(
                  'مدة التحميل',
                  '${order.loadingDuration} دقيقة',
                ),
              if (order.delayReason != null && order.delayReason!.isNotEmpty)
                _buildUiDetailRow('سبب التأخير', order.delayReason!),
            ],
          ),

          const SizedBox(height: 16),

          // معلومات السائق
          if (driverName != null)
            _buildInfoSection(
              title: 'معلومات السائق',
              icon: Icons.directions_car,
              color: AppColors.secondaryTeal,
              children: [
                _buildUiDetailRow('اسم السائق', driverName),
                if (driverPhone != null && driverPhone.isNotEmpty)
                  _buildUiDetailRow('هاتف السائق', driverPhone),
                if (order.vehicleNumber != null &&
                    order.vehicleNumber!.isNotEmpty)
                  _buildUiDetailRow('رقم المركبة', order.vehicleNumber!),
              ],
            ),

          const SizedBox(height: 16),

          // الملاحظات
          if (order.notes != null && order.notes!.isNotEmpty)
            _buildInfoSection(
              title: 'ملاحظات',
              icon: Icons.note,
              color: AppColors.mediumGray,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    order.notes!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // المرفقات
          if (order.attachments.isNotEmpty)
            _buildInfoSection(
              title: 'المرفقات (${order.attachments.length})',
              icon: Icons.attach_file,
              color: AppColors.primaryBlue,
              children: [...order.attachments.map(_buildOrderAttachmentItem)],
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsPanel(
    BuildContext context,
    Order order,
    String orderType,
    Color orderTypeColor,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSummaryTab(context, order, orderType, orderTypeColor),
          const SizedBox(height: 24),
          _buildDetailsTab(context, order, orderType),
        ],
      ),
    );
  }

  Widget _buildActivitiesPanel(List<Activity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'سجل الحركات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        if (activities.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد حركات مسجلة',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrderDetails,
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: activities.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    ActivityItem(activity: activities[index]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivitiesTab(List<Activity> activities) {
    if (activities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد حركات مسجلة',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrderDetails,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            ActivityItem(activity: activities[index]),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUiDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUiDetailRowWithIcon(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'قيد الانتظار':
      case 'في انتظار إنشاء طلب العميل':
      case 'في انتظار عمل طلب جديد':
      case 'قيد الإنشاء':
      case 'في انتظار التخصيص':
        return AppColors.pendingYellow;
      case 'مخصص للعميل':
      case 'تم إنشاء الطلب':
      case 'تم الإنشاء':
      case 'تم تخصيص طلب المورد':
        return AppColors.infoBlue;
      case 'في انتظار التحميل':
      case 'جاهز للتحميل':
      case 'مدمج وجاهز للتنفيذ':
        return AppColors.warningOrange;
      case 'تم التنفيذ':
      case 'تم التسليم':
      case 'مكتمل':
        return AppColors.successGreen;
      case 'ملغى':
      case 'ملغي - تأخر التحميل':
        return AppColors.errorRed;
      case 'تأخير في الوصول':
      case 'في الطريق':
        return Colors.orange;
      case 'تم دمجه':
      case 'تم دمجه مع العميل':
      case 'تم دمجه مع المورد':
      case 'مدمج':
        return Colors.purple;
      default:
        return AppColors.lightGray;
    }
  }
}
