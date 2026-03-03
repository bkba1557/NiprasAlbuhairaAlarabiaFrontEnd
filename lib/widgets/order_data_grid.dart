import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class OrderDataSource extends DataGridSource {
  OrderDataSource(List<Order> orders) {
    _orders = orders;
    _startTimer();
    _buildDataGridRows();
  }

  List<DataGridRow> dataGridRows = [];
  List<Order> _orders = [];
  late Timer _timer;
  final Map<DataGridRow, Order> _rowToOrder = {};
  final Map<DataGridRow, int> _rowIndexMap = {};

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _buildDataGridRows();
      notifyListeners();
    });
  }

  void dispose() {
    _timer.cancel();
  }

  void _buildDataGridRows() {
    _rowToOrder.clear();
    _rowIndexMap.clear();
    dataGridRows = _orders.asMap().entries.map<DataGridRow>((entry) {
      final index = entry.key;
      final order = entry.value;
      final row = DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'orderDate',
            value: _formatDate(order.orderDate),
          ),
          DataGridCell<String>(
            columnName: 'supplierName',
            value: order.orderSource == 'عميل'
                ? (order.customer!.name.isNotEmpty == true
                      ? order.customer!.name
                      : '—')
                : (order.supplierName?.isNotEmpty == true
                      ? order.supplierName!
                      : '—'),
          ),

          DataGridCell<String>(
            columnName: 'requestType',
            value: _displayRequestType(order),
          ),
          DataGridCell<String>(
            columnName: 'fuelQuantity',
            value: _buildFuelQuantityText(order),
          ),

          DataGridCell<String>(
            columnName: 'orderNumber',
            value: order.orderNumber,
          ),
          DataGridCell<String>(
            columnName: 'supplierOrderNumber',
            value: order.supplierOrderNumber ?? '—',
          ),
          DataGridCell<String>(
            columnName: 'loadingDate',
            value: _formatDate(order.loadingDate),
          ),
          DataGridCell<Widget>(
            columnName: 'timer',
            value: _buildTimerCell(order),
          ),
          DataGridCell<String>(
            columnName: 'statusDriver',
            value: order.status,
          ),
        ],
      );
      _rowToOrder[row] = order;
      _rowIndexMap[row] = index;
      return row;
    }).toList();
  }

  Order? orderForRow(DataGridRow row) => _rowToOrder[row];

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _buildFuelQuantityText(Order order) {
    if (order.fuelType == null || order.quantity == null) {
      return '—';
    }

    final unit = order.unit ?? 'لتر';
    return '${order.fuelType} • ${order.quantity} $unit';
  }

  String _displayRequestType(Order order) {
    final type = order.effectiveRequestType;
    if (type.trim().isEmpty || type == 'غير محدد') {
      return '—';
    }
    return type;
  }

  Widget _buildTimerCell(Order order) {
    if (order.loadingTime == null ||
        order.loadingTime!.isEmpty ||
        order.status == 'تم التحميل' ||
        order.status == 'ملغى') {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }

    final parts = order.loadingTime!.split(':');
    if (parts.length < 2) {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }

    final loadingDateTime = DateTime(
      order.loadingDate.year,
      order.loadingDate.month,
      order.loadingDate.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );

    final diff = loadingDateTime.difference(DateTime.now());
    final isLate = diff.inSeconds < 0;

    return Row(
      children: [
        Icon(
          Icons.timer,
          size: 16,
          color: isLate ? AppColors.errorRed : AppColors.successGreen,
        ),
        const SizedBox(width: 6),
        Text(
          _formatDuration(diff),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isLate ? AppColors.errorRed : AppColors.successGreen,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return 'انتهى';

    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}ي');
    if (hours > 0 || days > 0) parts.add('${hours}س');
    if (minutes > 0 || hours > 0 || days > 0) parts.add('${minutes}د');
    parts.add('${seconds}ث');

    return parts.join(' ');
  }

  Widget _buildStatusCell(Order order) {
    Color statusColor;
    switch (order.status) {
      case 'قيد الانتظار':
        statusColor = AppColors.pendingYellow;
        break;
      case 'قيد التجهيز':
        statusColor = AppColors.warningOrange;
        break;
      case 'جاهز للتحميل':
        statusColor = AppColors.infoBlue;
        break;
      case 'تم التحميل':
        statusColor = AppColors.successGreen;
        break;
      case 'ملغى':
        statusColor = AppColors.errorRed;
        break;
      default:
        statusColor = AppColors.lightGray;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor, width: 0.8),
          ),
          child: Text(
            order.status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (order.driverName != null && order.driverName!.isNotEmpty)
          Text(
            order.driverName!,
            style: const TextStyle(fontSize: 10, color: AppColors.mediumGray),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _rowIndexMap[row] ?? rows.indexOf(row);
    final isEven = rowIndex.isEven;
    final cellBackground = isEven
        ? AppColors.white
        : AppColors.backgroundGray.withOpacity(0.35);
    final cellBorder = AppColors.lightGray.withOpacity(0.35);

    return DataGridRowAdapter(
      color: Colors.transparent,
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'statusDriver') {
          final order = _rowToOrder[row];
          if (order != null) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: cellBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cellBorder),
              ),
              alignment: Alignment.centerRight,
              child: _buildStatusCell(order),
            );
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: cellBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cellBorder),
          ),
          alignment: Alignment.centerRight,
          child: cell.value is Widget
              ? cell.value
              : Text(
                  cell.value.toString(),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.darkGray,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
        );
      }).toList(),
    );
  }
}

class OrderDataGrid extends StatelessWidget {
  final OrderDataSource dataSource;
  final void Function(Order)? onRowTap;

  const OrderDataGrid({super.key, required this.dataSource, this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1024;
    final isDesktop = width >= 1024;
    final gridTheme = SfDataGridThemeData(
      headerColor: AppColors.primaryBlue.withOpacity(0.08),
      headerHoverColor: AppColors.primaryBlue.withOpacity(0.12),
      rowHoverColor: AppColors.primaryBlue.withOpacity(0.06),
      selectionColor: AppColors.primaryBlue.withOpacity(0.12),
      gridLineColor: AppColors.lightGray.withOpacity(0.35),
      sortIconColor: AppColors.primaryBlue,
      filterIconColor: AppColors.primaryBlue,
      filterIconHoverColor: AppColors.primaryBlue,
      filterPopupBackgroundColor: AppColors.white,
      filterPopupInputBorderColor: AppColors.primaryBlue.withOpacity(0.5),
      filterPopupTextStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: AppColors.darkGray,
      ),
      filterPopupDisabledTextStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        color: AppColors.lightGray,
      ),
      filterPopupCheckColor: AppColors.primaryBlue,
      filterPopupIconColor: AppColors.primaryBlue,
      filterPopupDisabledIconColor: AppColors.lightGray,
      okFilteringLabelColor: AppColors.primaryBlue,
      okFilteringLabelButtonColor: AppColors.primaryBlue.withOpacity(0.12),
      cancelFilteringLabelColor: AppColors.mediumGray,
      cancelFilteringLabelButtonColor: AppColors.lightGray.withOpacity(0.2),
      searchAreaFocusedBorderColor: AppColors.primaryBlue,
      searchAreaCursorColor: AppColors.primaryBlue,
      searchIconColor: AppColors.primaryBlue,
      closeIconColor: AppColors.mediumGray,
      filterPopupTopDividerColor: AppColors.lightGray.withOpacity(0.3),
      filterPopupBottomDividerColor: AppColors.lightGray.withOpacity(0.3),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = math.max(
            constraints.maxWidth,
            isDesktop ? constraints.maxWidth : 1000,
          ).toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth, // 👈 عرض الشاشة بالكامل
              child: Align(
                alignment: Alignment.topCenter, // 👈 توسيط حقيقي
                child: SizedBox(
                  width: tableWidth, // 👈 عرض الجدول
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.lightGray.withOpacity(0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SfDataGridTheme(
                        data: gridTheme,
                        child: SfDataGrid(
                          source: dataSource,
                          columns: _buildResponsiveColumns(
                            width,
                            isMobile,
                            isTablet,
                            isDesktop,
                          ),
                          gridLinesVisibility: GridLinesVisibility.none,
                          headerGridLinesVisibility: GridLinesVisibility.none,
                          allowSorting: true,
                          allowFiltering: true,
                          selectionMode: SelectionMode.single,

                          columnWidthMode: ColumnWidthMode.fill,
                          rowHeight: 64,
                          headerRowHeight: 52,

                          onCellTap: (details) {
                            if (details.rowColumnIndex.rowIndex > 0 &&
                                onRowTap != null) {
                              final index = details.rowColumnIndex.rowIndex - 1;
                              if (index < dataSource.effectiveRows.length) {
                                final row = dataSource.effectiveRows[index];
                                final order = dataSource.orderForRow(row);
                                if (order != null) {
                                  onRowTap!(order);
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<GridColumn> _buildResponsiveColumns(
    double width,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    // تعريف العناوين
    final columnTitles = {
      'orderDate': 'تاريخ الطلب',
      'supplierName': 'اسم المورد / العميل',
      'requestType': 'نوع الطلب',
      'fuelQuantity': 'الوقود / الكمية', // 👈 جديد
      'orderNumber': 'رقم الطلب',
      'supplierOrderNumber': 'رقم طلب المورد',
      'loadingDate': 'تاريخ التحميل',
      'timer': 'الوقت المتبقي',
      'statusDriver': 'الحالة / السائق',
    };

    if (isMobile) {
      // للموبايل: عرض الأعمدة الأساسية فقط
      return [
        _createColumn('orderDate', columnTitles['orderDate']!, 85),
        _createColumn('supplierName', columnTitles['supplierName']!, 115),
        _createColumn('orderNumber', columnTitles['orderNumber']!, 65),
        _createColumn('fuelQuantity', columnTitles['fuelQuantity']!, 110),

        _createColumn('timer', columnTitles['timer']!, 95),
        _createColumn(
          'statusDriver',
          columnTitles['statusDriver']!,
          100,
        ), // أقل عرضاً
      ];
    } else if (isTablet) {
      // للتابلت: عرض معظم الأعمدة
      return [
        _createColumn('orderDate', columnTitles['orderDate']!, 95),
        _createColumn('supplierName', columnTitles['supplierName']!, 135),
        _createColumn('orderNumber', columnTitles['orderNumber']!, 85),
        _createColumn('fuelQuantity', columnTitles['fuelQuantity']!, 130),

        _createColumn('requestType', columnTitles['requestType']!, 95),
        _createColumn('timer', columnTitles['timer']!, 115),
        _createColumn(
          'statusDriver',
          columnTitles['statusDriver']!,
          120,
        ), // أقل عرضاً
      ];
    } else {
      // للكمبيوتر/الويب: عرض جميع الأعمدة
      return [
        _createColumn('orderDate', 'تاريخ الطلب', 130),

        _createColumn(
          'supplierName',
          'اسم المورد / العميل',
          170,
        ), // ⬅️ كان أعرض

        _createColumn('requestType', 'نوع الطلب', 100),

        _createColumn('fuelQuantity', 'الوقود / الكمية', 160),

        _createColumn('orderNumber', 'رقم الطلب', 120),

        _createColumn('supplierOrderNumber', 'رقم طلب المورد', 120),

        _createColumn('loadingDate', 'تاريخ التحميل', 130),

        _createColumn('timer', 'الوقت المتبقي', 130),

        _createColumn('statusDriver', 'الحالة / السائق', 140),
      ];
    }
  }

  GridColumn _createColumn(String name, String title, double width) {
    final fontSize = width < 600
        ? 11.0
        : width < 1024
        ? 12.0
        : 14.0;
    final padding = width < 600
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 10)
        : width < 1024
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
        : const EdgeInsets.all(12);

    return GridColumn(
      columnName: name,
      minimumWidth: width,
      columnWidthMode: ColumnWidthMode.fill,
      allowFiltering: true,
      label: Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
            fontSize: fontSize,
            color: AppColors.primaryDarkBlue,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
