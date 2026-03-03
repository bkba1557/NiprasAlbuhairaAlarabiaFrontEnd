// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:order_tracker/models/models.dart';
// import 'package:order_tracker/models/order_model.dart';
// import 'package:order_tracker/models/order_timer.dart';
// import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pdf;

// class ExportUtils {
//   static Future<void> exportOrdersToExcel(
//     BuildContext context,
//     List<Order> orders,
//     String title,
//   ) async {
//     try {
//       final excel.Workbook workbook = excel.Workbook();
//       final excel.Worksheet sheet = workbook.worksheets[0];

//       // Set Arabic font
//       sheet.getRangeByName('A1').cellStyle.fontName = 'Arial';

//       // Add title
//       sheet.getRangeByName('A1').setText(title);
//       sheet.getRangeByName('A1').cellStyle.fontSize = 18;
//       sheet.getRangeByName('A1').cellStyle.bold = true;
//       sheet.getRangeByName('A1').cellStyle.hAlign = excel.HAlignType.center;
//       sheet.getRangeByName('A1').cellStyle.vAlign = excel.VAlignType.center;
//       sheet.getRangeByName('A1:F1').merge();

//       // Add date
//       sheet
//           .getRangeByName('A2')
//           .setText(
//             'تاريخ التصدير: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
//           );
//       sheet.getRangeByName('A2:F2').merge();
//       sheet.getRangeByName('A2').cellStyle.fontSize = 12;
//       sheet.getRangeByName('A2').cellStyle.hAlign = excel.HAlignType.center;

//       // Headers
//       final headers = [
//         'رقم الطلب',
//         'نوع الطلب',
//         'المورد/العميل',
//         'الحالة',
//         'تاريخ الطلب',
//         'وقت التحميل',
//         'المدة المتبقية',
//         'ملاحظات',
//       ];

//       for (int i = 0; i < headers.length; i++) {
//         sheet.getRangeByIndex(4, i + 1).setText(headers[i]);
//         sheet.getRangeByIndex(4, i + 1).cellStyle.bold = true;
//         sheet.getRangeByIndex(4, i + 1).cellStyle.backColor = '#4CAF50';
//         sheet.getRangeByIndex(4, i + 1).cellStyle.fontColor = '#FFFFFF';
//         sheet.getRangeByIndex(4, i + 1).cellStyle.hAlign =
//             excel.HAlignType.center;
//         sheet.getRangeByIndex(4, i + 1).cellStyle.vAlign =
//             excel.VAlignType.center;
//       }

//       // Data rows
//       int row = 5;
//       for (final order in orders) {
//         final timer = OrderTimer.fromOrder(order);

//         sheet.getRangeByIndex(row, 1).setText(order.orderNumber);
//         sheet
//             .getRangeByIndex(row, 2)
//             .setText(_getOrderSourceText(order.orderSource));
//         sheet
//             .getRangeByIndex(row, 3)
//             .setText(order.supplierName ?? order.customer?.name ?? 'غير محدد');
//         sheet.getRangeByIndex(row, 4).setText(order.status);
//         sheet
//             .getRangeByIndex(row, 5)
//             .setText(DateFormat('yyyy/MM/dd').format(order.orderDate));

//         final loadingDateTime = DateTime(
//           order.loadingDate.year,
//           order.loadingDate.month,
//           order.loadingDate.day,
//           int.parse(order.loadingTime.split(':')[0]),
//           int.parse(order.loadingTime.split(':')[1]),
//         );

//         sheet
//             .getRangeByIndex(row, 6)
//             .setText(DateFormat('yyyy/MM/dd HH:mm').format(loadingDateTime));
//         sheet.getRangeByIndex(row, 7).setText(timer.formattedLoadingCountdown);
//         sheet.getRangeByIndex(row, 8).setText(order.notes ?? '');

//         // Color coding based on status
//         final statusColor = _getStatusColor(order.status);
//         sheet.getRangeByIndex(row, 4).cellStyle.fontColor = statusColor;

//         if (timer.isOverdue) {
//           for (int col = 1; col <= 8; col++) {
//             sheet.getRangeByIndex(row, col).cellStyle.backColor = '#FFEBEE';
//           }
//         } else if (timer.isApproachingLoading) {
//           for (int col = 1; col <= 8; col++) {
//             sheet.getRangeByIndex(row, col).cellStyle.backColor = '#FFF3E0';
//           }
//         }

//         row++;
//       }

//       // Auto fit columns
//       for (int i = 1; i <= 8; i++) {
//         sheet.autoFitColumn(i);
//       }

//       // Save file
//       final List<int> bytes = workbook.saveAsStream();
//       workbook.dispose();

//       final directory = await getExternalStorageDirectory();
//       final file = File(
//         '${directory!.path}/طلبات_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx',
//       );
//       await file.writeAsBytes(bytes);

//       // Open file
//       await OpenFile.open(file.path);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('تم تصدير ${orders.length} طلب إلى ملف Excel'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('خطأ في التصدير: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   static Future<void> exportOrdersToPDF(
//     BuildContext context,
//     List<Order> orders,
//     String title,
//   ) async {
//     try {
//       final pdf.Document document = pdf.Document();

//       document.addPage(
//         pdf.MultiPage(
//           pageFormat: PdfPageFormat.a4,
//           build: (pdf.Context context) {
//             return [
//               // Header
//               pdf.Header(
//                 level: 0,
//                 child: pdf.Column(
//                   crossAxisAlignment: pdf.CrossAxisAlignment.start,
//                   children: [
//                     pdf.Text(
//                       title,
//                       style: pdf.TextStyle(
//                         fontSize: 24,
//                         fontWeight: pdf.FontWeight.bold,
//                         color: PdfColors.blue,
//                       ),
//                     ),
//                     pdf.SizedBox(height: 10),
//                     pdf.Text(
//                       'تاريخ التصدير: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
//                       style: pdf.TextStyle(fontSize: 12),
//                     ),
//                     pdf.Divider(),
//                   ],
//                 ),
//               ),

//               // Summary
//               pdf.Container(
//                 margin: const pdf.EdgeInsets.only(bottom: 20),
//                 child: pdf.Row(
//                   mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
//                   children: [
//                     pdf.Text('إجمالي الطلبات: ${orders.length}'),
//                     pdf.Text(
//                       'الطلبات المتأخرة: ${orders.where((o) => OrderTimer.fromOrder(o).isOverdue).length}',
//                     ),
//                     pdf.Text(
//                       'الطلبات المقتربة: ${orders.where((o) => OrderTimer.fromOrder(o).isApproachingLoading).length}',
//                     ),
//                   ],
//                 ),
//               ),

//               // Table
//               pdf.Table.fromTextArray(
//                 context: context,
//                 data: _buildPDFTableData(orders),
//                 headers: [
//                   'رقم الطلب',
//                   'النوع',
//                   'المورد/العميل',
//                   'الحالة',
//                   'تاريخ الطلب',
//                   'وقت التحميل',
//                   'المدة المتبقية',
//                 ],
//                 headerStyle: pdf.TextStyle(
//                   fontWeight: pdf.FontWeight.bold,
//                   color: PdfColors.white,
//                 ),
//                 headerDecoration: const pdf.BoxDecoration(
//                   color: PdfColors.green,
//                 ),
//                 cellAlignment: pdf.Alignment.center,
//                 cellPadding: const pdf.EdgeInsets.all(4),
//                 border: pdf.TableBorder.all(color: PdfColors.grey300),
//                 oddRowDecoration: const pdf.BoxDecoration(
//                   color: PdfColors.grey50,
//                 ),
//               ),
//             ];
//           },
//         ),
//       );

//       // Save file
//       final directory = await getExternalStorageDirectory();
//       final file = File(
//         '${directory!.path}/طلبات_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
//       );
//       await file.writeAsBytes(await document.save());

//       // Open file
//       await OpenFile.open(file.path);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('تم تصدير ${orders.length} طلب إلى ملف PDF'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('خطأ في التصدير: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   static List<List<String>> _buildPDFTableData(List<Order> orders) {
//     final data = <List<String>>[];

//     for (final order in orders) {
//       final timer = OrderTimer.fromOrder(order);

//       data.add([
//         order.orderNumber,
//         _getOrderSourceText(order.orderSource),
//         order.supplierName ?? order.customer?.name ?? 'غير محدد',
//         order.status,
//         DateFormat('yyyy/MM/dd').format(order.orderDate),
//         '${DateFormat('yyyy/MM/dd').format(order.loadingDate)} ${order.loadingTime}',
//         timer.formattedLoadingCountdown,
//       ]);
//     }

//     return data;
//   }

//   static String _getOrderSourceText(String orderSource) {
//     switch (orderSource) {
//       case 'مورد':
//         return 'طلب مورد';
//       case 'عميل':
//         return 'طلب عميل';
//       case 'مدمج':
//         return 'طلب مدمج';
//       default:
//         return orderSource;
//     }
//   }

//   static String _getStatusColor(String status) {
//     if (status.contains('انتظار')) return '#FF9800';
//     if (status.contains('تحميل')) return '#2196F3';
//     if (status.contains('في الطريق')) return '#3F51B5';
//     if (status.contains('تم التسليم') || status.contains('مكتمل'))
//       return '#4CAF50';
//     if (status.contains('ملغى')) return '#F44336';
//     return '#000000';
//   }
// }
