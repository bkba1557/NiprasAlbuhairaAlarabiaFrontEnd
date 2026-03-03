import 'package:flutter/material.dart';
import 'package:order_tracker/models/inventory_models.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class InventoryStockDataSource extends DataGridSource {
  InventoryStockDataSource(List<InventoryStockItem> items) {
    _items = items;
    _buildRows();
  }

  List<InventoryStockItem> _items = [];
  List<DataGridRow> dataGridRows = [];

  void updateData(List<InventoryStockItem> items) {
    _items = items;
    _buildRows();
    notifyListeners();
  }

  void _buildRows() {
    dataGridRows = _items.map<DataGridRow>((item) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'date',
            value: _fmtDate(item.date),
          ),
          DataGridCell<String>(
            columnName: 'invoice',
            value: item.invoiceNumber,
          ),
          DataGridCell<String>(
            columnName: 'branch',
            value: item.branchName,
          ),
          DataGridCell<String>(
            columnName: 'warehouse',
            value: item.warehouseName,
          ),
          DataGridCell<String>(
            columnName: 'supplier',
            value: item.supplierName,
          ),
          DataGridCell<String>(
            columnName: 'supplierTax',
            value: item.supplierTaxNumber,
          ),
          DataGridCell<String>(
            columnName: 'supplierAddress',
            value: item.supplierAddress,
          ),
          DataGridCell<String>(
            columnName: 'description',
            value: item.description,
          ),
          DataGridCell<String>(
            columnName: 'quantity',
            value: item.quantity.toStringAsFixed(2),
          ),
          DataGridCell<String>(
            columnName: 'unitPrice',
            value: item.unitPrice.toStringAsFixed(2),
          ),
          DataGridCell<String>(
            columnName: 'subtotal',
            value: item.subtotal.toStringAsFixed(2),
          ),
          DataGridCell<String>(
            columnName: 'tax',
            value: item.taxAmount.toStringAsFixed(2),
          ),
          DataGridCell<String>(
            columnName: 'total',
            value: item.total.toStringAsFixed(2),
          ),
        ],
      );
    }).toList();
  }

  String _fmtDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.all(10),
          child: Text(
            cell.value.toString(),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            textAlign: TextAlign.right,
          ),
        );
      }).toList(),
    );
  }
}

class InventoryStockDataGrid extends StatelessWidget {
  final InventoryStockDataSource dataSource;

  const InventoryStockDataGrid({super.key, required this.dataSource});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SfDataGrid(
      source: dataSource,
      columns: [
        _buildColumn('date', 'التاريخ', 120),
        _buildColumn('invoice', 'رقم الفاتورة', 140),
        _buildColumn('branch', 'الفرع', screenWidth * 0.12),
        _buildColumn('warehouse', 'المخزن', screenWidth * 0.12),
        _buildColumn('supplier', 'المورد', screenWidth * 0.14),
        _buildColumn('supplierTax', 'الرقم الضريبي', 140),
        _buildColumn('supplierAddress', 'العنوان', screenWidth * 0.2),
        _buildColumn('description', 'التفاصيل', screenWidth * 0.2),
        _buildColumn('quantity', 'الكمية', 90),
        _buildColumn('unitPrice', 'السعر', 90),
        _buildColumn('subtotal', 'قبل الضريبة', 110),
        _buildColumn('tax', 'الضريبة', 90),
        _buildColumn('total', 'الإجمالي', 110),
      ],
      gridLinesVisibility: GridLinesVisibility.both,
      headerGridLinesVisibility: GridLinesVisibility.both,
      allowSorting: true,
      allowFiltering: true,
      columnWidthMode: ColumnWidthMode.auto,
    );
  }

  GridColumn _buildColumn(String name, String title, double width) {
    return GridColumn(
      columnName: name,
      width: width,
      label: Container(
        padding: const EdgeInsets.all(10),
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
