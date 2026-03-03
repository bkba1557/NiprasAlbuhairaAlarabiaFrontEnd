import 'package:flutter/material.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class SupplierDataSource extends DataGridSource {
  SupplierDataSource(List<Supplier> suppliers, {this.onDelete}) {
    _suppliers = suppliers;
    _buildDataGridRows();
  }

  final void Function(String supplierId)? onDelete;

  List<DataGridRow> dataGridRows = [];
  List<Supplier> _suppliers = [];

  void _buildDataGridRows() {
    dataGridRows = _suppliers.map<DataGridRow>((supplier) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(columnName: 'name', value: supplier.name),
          DataGridCell<String>(columnName: 'company', value: supplier.company),
          DataGridCell<String>(
            columnName: 'contactPerson',
            value: supplier.contactPerson,
          ),
          DataGridCell<String>(columnName: 'phone', value: supplier.phone),
          DataGridCell<String>(
            columnName: 'supplierType',
            value: supplier.supplierType,
          ),
          DataGridCell<Widget>(
            columnName: 'statusRating',
            value: _buildStatusRatingCell(supplier),
          ),
          DataGridCell<String>(columnName: 'actions', value: supplier.id),
        ],
      );
    }).toList();
  }

  Widget _buildStatusRatingCell(Supplier supplier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: supplier.isActive
                    ? AppColors.successGreen
                    : AppColors.errorRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              supplier.isActive ? 'نشط' : 'غير نشط',
              style: TextStyle(
                color: supplier.isActive
                    ? AppColors.successGreen
                    : AppColors.errorRed,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < supplier.rating.round() ? Icons.star : Icons.star_border,
              size: 14,
              color: AppColors.warningOrange,
            );
          }),
        ),
      ],
    );
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'statusRating') {
          return Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerRight,
            child: dataGridCell.value,
          );
        }

        if (dataGridCell.columnName == 'actions') {
          return Center(
            child: IconButton(
              tooltip: 'حذف المورد',
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.errorRed,
                size: 20,
              ),
              onPressed: onDelete != null
                  ? () => onDelete!(dataGridCell.value)
                  : null,
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerRight,
          child: Text(
            dataGridCell.value.toString(),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            textAlign: TextAlign.right,
          ),
        );
      }).toList(),
    );
  }
}

class SupplierDataGrid extends StatelessWidget {
  final SupplierDataSource dataSource;
  final void Function(Supplier)? onRowTap;

  const SupplierDataGrid({super.key, required this.dataSource, this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SfDataGrid(
      source: dataSource,
      columns: [
        _buildColumn('name', 'اسم المورد', screenWidth * 0.16),
        _buildColumn('company', 'الشركة', screenWidth * 0.16),
        _buildColumn('contactPerson', 'جهة الاتصال', screenWidth * 0.14),
        _buildColumn('phone', 'الهاتف', screenWidth * 0.12),
        _buildColumn('supplierType', 'نوع المورد', screenWidth * 0.12),
        _buildColumn('statusRating', 'الحالة / التقييم', screenWidth * 0.16),
        GridColumn(
          columnName: 'actions',
          width: 70,
          label: const Center(child: Icon(Icons.more_vert)),
        ),
      ],
      gridLinesVisibility: GridLinesVisibility.both,
      headerGridLinesVisibility: GridLinesVisibility.both,
      allowSorting: true,
      allowFiltering: true,
      selectionMode: SelectionMode.single,
      onCellTap: (details) {
        // تجاهل الضغط على الهيدر
        if (details.rowColumnIndex.rowIndex <= 0) return;

        // تجاهل عمود الإجراءات
        final columnIndex = details.rowColumnIndex.columnIndex;
        if (columnIndex == dataSource.rows.first.getCells().length - 1) {
          return;
        }

        if (onRowTap != null) {
          final supplierIndex = details.rowColumnIndex.rowIndex - 1;
          if (supplierIndex < dataSource._suppliers.length) {
            onRowTap!(dataSource._suppliers[supplierIndex]);
          }
        }
      },
    );
  }

  GridColumn _buildColumn(String name, String title, double width) {
    return GridColumn(
      columnName: name,
      width: width,
      label: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}
