import 'dart:async';

import 'package:flutter/material.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/utils/constants.dart';

class OrderDataGrid extends StatefulWidget {
  const OrderDataGrid({super.key, required this.orders, this.onRowTap});

  final List<Order> orders;
  final void Function(Order)? onRowTap;

  @override
  State<OrderDataGrid> createState() => _OrderDataGridState();
}

class _OrderDataGridState extends State<OrderDataGrid> {
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _columnFilterController = TextEditingController();
  final FocusNode _columnFilterFocusNode = FocusNode();
  final Map<String, String> _columnFilters = {};

  Timer? _ticker;
  String? _activeFilterColumnKey;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _columnFilterFocusNode.dispose();
    _columnFilterController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final baseColumns = _buildColumns(screenWidth);
        final baseTableWidth = baseColumns.fold<double>(
          0,
          (sum, column) => sum + column.width,
        );
        final scale = baseTableWidth < viewportWidth
            ? viewportWidth / baseTableWidth
            : 1.0;
        final columns = baseColumns
            .map((column) => column.copyWith(width: column.width * scale))
            .toList();
        final visibleColumnKeys = columns.map((column) => column.key).toSet();
        final activeFilterColumnKey =
            visibleColumnKeys.contains(_activeFilterColumnKey)
            ? _activeFilterColumnKey
            : null;
        final effectiveColumnFilters = Map<String, String>.fromEntries(
          _columnFilters.entries.where(
            (entry) => visibleColumnKeys.contains(entry.key),
          ),
        );
        final filteredOrders = _applyColumnFilters(
          widget.orders,
          effectiveColumnFilters,
        );
        final tableWidth = columns.fold<double>(
          0,
          (sum, column) => sum + column.width,
        );

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.backgroundGray.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.lightGray.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              interactive: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: CustomScrollView(
                    primary: true,
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _OrdersTableHeaderDelegate(
                          columns: columns,
                          activeFilterColumnKey: activeFilterColumnKey,
                          activeFilterText: activeFilterColumnKey == null
                              ? ''
                              : effectiveColumnFilters[activeFilterColumnKey] ??
                                    '',
                          activeFilterCount: effectiveColumnFilters.length,
                          controller: _columnFilterController,
                          focusNode: _columnFilterFocusNode,
                          onFilterPressed: _handleFilterPressed,
                          onFilterChanged: _handleFilterChanged,
                          onClearActiveFilter: _clearActiveFilter,
                          hasActiveFilter: (columnKey) =>
                              effectiveColumnFilters.containsKey(columnKey),
                        ),
                      ),
                      if (filteredOrders.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _OrdersGridEmptyState(),
                        )
                      else
                        SliverList.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _buildRow(order, index, columns);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleFilterPressed(String columnKey) {
    final isCurrentColumn = _activeFilterColumnKey == columnKey;
    final nextValue = isCurrentColumn ? '' : (_columnFilters[columnKey] ?? '');

    setState(() {
      _activeFilterColumnKey = isCurrentColumn ? null : columnKey;
      _columnFilterController.value = TextEditingValue(
        text: nextValue,
        selection: TextSelection.collapsed(offset: nextValue.length),
      );
    });

    if (!isCurrentColumn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _columnFilterFocusNode.requestFocus();
        }
      });
    }
  }

  void _handleFilterChanged(String value) {
    final activeKey = _activeFilterColumnKey;
    if (activeKey == null) return;

    final normalizedValue = value.trim();
    setState(() {
      if (normalizedValue.isEmpty) {
        _columnFilters.remove(activeKey);
      } else {
        _columnFilters[activeKey] = normalizedValue;
      }
    });
  }

  void _clearActiveFilter() {
    final activeKey = _activeFilterColumnKey;
    if (activeKey == null) return;

    setState(() {
      _columnFilters.remove(activeKey);
      _columnFilterController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _columnFilterFocusNode.requestFocus();
      }
    });
  }

  List<Order> _applyColumnFilters(
    List<Order> orders,
    Map<String, String> filters,
  ) {
    if (filters.isEmpty) return orders;

    return orders.where((order) {
      for (final entry in filters.entries) {
        if (!_matchesColumnFilter(order, entry.key, entry.value)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _matchesColumnFilter(Order order, String columnKey, String filterValue) {
    final normalizedFilter = filterValue.trim().toLowerCase();
    if (normalizedFilter.isEmpty) return true;

    return _filterValuesForColumn(columnKey, order).any((value) {
      return value.toLowerCase().contains(normalizedFilter);
    });
  }

  List<String> _filterValuesForColumn(String columnKey, Order order) {
    switch (columnKey) {
      case 'orderDate':
        return [_formatDate(order.orderDate)];
      case 'supplierName':
        return [
          _partnerDisplayName(order),
          order.supplierName.trim(),
          order.customer?.name.trim() ?? '',
        ];
      case 'requestType':
        return [_displayRequestType(order)];
      case 'fuelQuantity':
        return [
          _buildFuelQuantityText(order),
          order.fuelType?.trim() ?? '',
          if (order.quantity != null) order.quantity!.toString(),
          order.unit?.trim() ?? '',
        ];
      case 'orderNumber':
        return [order.orderNumber.trim()];
      case 'supplierOrderNumber':
        return [_supplierOrderNumberText(order)];
      case 'loadingDate':
        return [_formatDate(order.loadingDate), order.loadingTime.trim()];
      case 'timer':
        return [_timerText(order)];
      case 'statusDriver':
        return [order.status.trim(), order.driverName?.trim() ?? ''];
      default:
        return const [];
    }
  }

  List<_OrdersTableColumn> _buildColumns(double width) {
    if (width < 700) {
      return const [
        _OrdersTableColumn('orderDate', 'تاريخ الطلب', 118),
        _OrdersTableColumn('supplierName', 'المورد / العميل', 156),
        _OrdersTableColumn('orderNumber', 'رقم الطلب', 124),
        _OrdersTableColumn('fuelQuantity', 'الوقود / الكمية', 168),
        _OrdersTableColumn('timer', 'الوقت المتبقي', 132),
        _OrdersTableColumn('statusDriver', 'الحالة / السائق', 156),
      ];
    }

    if (width < 1100) {
      return const [
        _OrdersTableColumn('orderDate', 'تاريخ الطلب', 120),
        _OrdersTableColumn('supplierName', 'المورد / العميل', 170),
        _OrdersTableColumn('requestType', 'نوع الطلب', 96),
        _OrdersTableColumn('fuelQuantity', 'الوقود / الكمية', 168),
        _OrdersTableColumn('orderNumber', 'رقم الطلب', 126),
        _OrdersTableColumn('supplierOrderNumber', 'طلب المورد', 126),
        _OrdersTableColumn('loadingDate', 'تاريخ التحميل', 126),
        _OrdersTableColumn('timer', 'الوقت المتبقي', 132),
        _OrdersTableColumn('statusDriver', 'الحالة / السائق', 156),
      ];
    }

    return const [
      _OrdersTableColumn('orderDate', 'تاريخ الطلب', 134),
      _OrdersTableColumn('supplierName', 'اسم المورد / العميل', 184),
      _OrdersTableColumn('requestType', 'نوع الطلب', 106),
      _OrdersTableColumn('fuelQuantity', 'الوقود / الكمية', 176),
      _OrdersTableColumn('orderNumber', 'رقم الطلب', 130),
      _OrdersTableColumn('supplierOrderNumber', 'رقم طلب المورد', 138),
      _OrdersTableColumn('loadingDate', 'تاريخ التحميل', 132),
      _OrdersTableColumn('timer', 'الوقت المتبقي', 136),
      _OrdersTableColumn('statusDriver', 'الحالة / السائق', 168),
    ];
  }

  Widget _buildRow(Order order, int index, List<_OrdersTableColumn> columns) {
    final baseColor = index.isEven
        ? Colors.white
        : AppColors.backgroundGray.withValues(alpha: 0.40);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(order),
          child: Row(
            children: columns.map((column) {
              return _buildCell(
                column: column,
                backgroundColor: baseColor,
                child: _buildCellContent(column.key, order),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCell({
    required _OrdersTableColumn column,
    required Color backgroundColor,
    required Widget child,
  }) {
    return SizedBox(
      width: column.width,
      child: Container(
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: AppColors.lightGray.withValues(alpha: 0.26),
          ),
        ),
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }

  Widget _buildCellContent(String key, Order order) {
    switch (key) {
      case 'orderDate':
        return _buildText(_formatDate(order.orderDate));
      case 'supplierName':
        return _buildText(_partnerDisplayName(order));
      case 'requestType':
        return _buildText(_displayRequestType(order));
      case 'fuelQuantity':
        return _buildText(_buildFuelQuantityText(order));
      case 'orderNumber':
        return _buildText(order.orderNumber);
      case 'supplierOrderNumber':
        return _buildText(_supplierOrderNumberText(order));
      case 'loadingDate':
        return _buildText(_formatDate(order.loadingDate));
      case 'timer':
        return _buildTimerCell(order);
      case 'statusDriver':
        return _buildStatusCell(order);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildText(String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.darkGray,
        height: 1.1,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _partnerDisplayName(Order order) {
    final customerName = order.customer?.name.trim() ?? '';
    final supplierName = order.supplierName.trim();
    if (order.orderSource == 'عميل') {
      return customerName.isNotEmpty ? customerName : '—';
    }
    return supplierName.isNotEmpty ? supplierName : '—';
  }

  String _buildFuelQuantityText(Order order) {
    final fuelType = order.fuelType?.trim();
    if (fuelType == null || fuelType.isEmpty || order.quantity == null) {
      return '—';
    }

    final quantity = order.quantity!;
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    final unit = (order.unit?.trim().isNotEmpty ?? false)
        ? order.unit!.trim()
        : 'لتر';
    return '$fuelType • $quantityText $unit';
  }

  String _displayRequestType(Order order) {
    final type = order.effectiveRequestType.trim();
    return type.isEmpty || type == 'غير محدد' ? '—' : type;
  }

  String _supplierOrderNumberText(Order order) {
    final value = order.supplierOrderNumber?.trim() ?? '';
    return value.isEmpty ? '—' : value;
  }

  String _timerText(Order order) {
    if (order.loadingTime.isEmpty ||
        order.status == 'تم التحميل' ||
        order.status == 'ملغى') {
      return '—';
    }

    final parts = order.loadingTime.split(':');
    if (parts.length < 2) {
      return '—';
    }

    final loadingDateTime = DateTime(
      order.loadingDate.year,
      order.loadingDate.month,
      order.loadingDate.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );

    return _formatDuration(loadingDateTime.difference(DateTime.now()));
  }

  Widget _buildTimerCell(Order order) {
    if (order.loadingTime.isEmpty ||
        order.status == 'تم التحميل' ||
        order.status == 'ملغى') {
      return _buildText('—');
    }

    final parts = order.loadingTime.split(':');
    if (parts.length < 2) {
      return _buildText('—');
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
    final color = isLate ? AppColors.errorRed : AppColors.successGreen;

    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _formatDuration(diff),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return 'انتهى';

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}ي');
    if (hours > 0 || days > 0) parts.add('${hours}س');
    if (minutes > 0 || hours > 0 || days > 0) parts.add('${minutes}د');
    parts.add('${seconds}ث');

    return parts.join(' ');
  }

  Widget _buildStatusCell(Order order) {
    final color = _statusColor(order.status);

    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Text(
              order.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        if (order.driverName != null &&
            order.driverName!.trim().isNotEmpty) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              order.driverName!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: AppColors.mediumGray,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'قيد الانتظار':
        return AppColors.pendingYellow;
      case 'قيد التجهيز':
        return AppColors.warningOrange;
      case 'جاهز للتحميل':
        return AppColors.infoBlue;
      case 'تم التحميل':
      case 'تم التنفيذ':
      case 'مكتمل':
        return AppColors.successGreen;
      case 'ملغى':
        return AppColors.errorRed;
      default:
        return AppColors.lightGray;
    }
  }
}

class _OrdersTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OrdersTableHeaderDelegate({
    required this.columns,
    required this.activeFilterColumnKey,
    required this.activeFilterText,
    required this.activeFilterCount,
    required this.controller,
    required this.focusNode,
    required this.onFilterPressed,
    required this.onFilterChanged,
    required this.onClearActiveFilter,
    required this.hasActiveFilter,
  });

  final List<_OrdersTableColumn> columns;
  final String? activeFilterColumnKey;
  final String activeFilterText;
  final int activeFilterCount;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onFilterPressed;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onClearActiveFilter;
  final bool Function(String columnKey) hasActiveFilter;

  bool get _showFilterField => activeFilterColumnKey != null;

  @override
  double get minExtent => _showFilterField ? 92 : 44;

  @override
  double get maxExtent => _showFilterField ? 92 : 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.backgroundGray.withValues(
        alpha: overlapsContent ? 0.98 : 0.94,
      ),
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        children: [
          Row(
            children: columns.map((column) {
              final isColumnActive = activeFilterColumnKey == column.key;
              final columnHasFilter = hasActiveFilter(column.key);
              final iconColor = isColumnActive || columnHasFilter
                  ? AppColors.primaryBlue
                  : AppColors.primaryBlue.withValues(alpha: 0.85);

              return SizedBox(
                width: column.width,
                child: Container(
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: (isColumnActive || columnHasFilter)
                          ? AppColors.primaryBlue.withValues(alpha: 0.34)
                          : AppColors.primaryBlue.withValues(alpha: 0.12),
                    ),
                    boxShadow: overlapsContent
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDarkBlue,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onFilterPressed(column.key),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.filter_alt_outlined,
                                size: 14,
                                color: iconColor,
                              ),
                              if (columnHasFilter)
                                Positioned(
                                  top: -1,
                                  right: -1,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.successGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.swap_vert,
                        size: 13,
                        color: AppColors.primaryBlue.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_showFilterField) ...[
            const SizedBox(height: 8),
            Row(
              children: columns.map((column) {
                if (column.key != activeFilterColumnKey) {
                  return SizedBox(width: column.width);
                }

                return SizedBox(
                  width: column.width,
                  child: Container(
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onFilterChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'اكتب للتصفية',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        suffixIcon: activeFilterText.isEmpty
                            ? (activeFilterCount > 1
                                  ? const Tooltip(
                                      message: 'يوجد فلاتر نشطة في أعمدة أخرى',
                                      child: Icon(
                                        Icons.filter_alt_outlined,
                                        size: 16,
                                        color: AppColors.primaryBlue,
                                      ),
                                    )
                                  : null)
                            : IconButton(
                                tooltip: 'مسح',
                                onPressed: onClearActiveFilter,
                                icon: const Icon(Icons.close, size: 16),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.48,
                            ),
                          ),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _OrdersTableHeaderDelegate oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.activeFilterColumnKey != activeFilterColumnKey ||
        oldDelegate.activeFilterText != activeFilterText ||
        oldDelegate.activeFilterCount != activeFilterCount;
  }
}

class _OrdersGridEmptyState extends StatelessWidget {
  const _OrdersGridEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.filter_alt_off_outlined, size: 42, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'لا توجد صفوف مطابقة للفلاتر الحالية.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTableColumn {
  const _OrdersTableColumn(this.key, this.title, this.width);

  final String key;
  final String title;
  final double width;

  _OrdersTableColumn copyWith({double? width}) {
    return _OrdersTableColumn(key, title, width ?? this.width);
  }
}
