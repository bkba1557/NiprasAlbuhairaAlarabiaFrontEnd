import 'package:flutter/material.dart';
import 'package:order_tracker/models/fuel_station_model.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// ===============================
/// DataSource
/// ===============================
class FuelStationDataSource extends DataGridSource {
  FuelStationDataSource(this.context, List<FuelStation> stations) {
    _stations = stations;
    _buildDataGridRows();
  }

  final BuildContext context;
  List<FuelStation> _stations = [];
  List<DataGridRow> dataGridRows = [];

  void _buildDataGridRows() {
    dataGridRows = _stations.map<DataGridRow>((station) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'stationCode',
            value: station.stationCode,
          ),
          DataGridCell<String>(
            columnName: 'stationName',
            value: station.stationName,
          ),
          DataGridCell<String>(
            columnName: 'location',
            value: '${station.city} - ${station.region}',
          ),
          DataGridCell<String>(
            columnName: 'stationType',
            value: station.stationType,
          ),
          DataGridCell<String>(columnName: 'status', value: station.status),
          DataGridCell<String>(
            columnName: 'manager',
            value: station.managerName,
          ),
          DataGridCell<String>(
            columnName: 'contact',
            value: station.managerPhone,
          ),
          DataGridCell<FuelStation>(columnName: 'actions', value: station),
        ],
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  Color _statusColor(String status) {
    switch (status) {
      case 'نشطة':
        return Colors.green;
      case 'صيانة':
        return Colors.orange;
      case 'متوقفة':
        return Colors.red;
      case 'مغلقة':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final int rowIndex = rows.indexOf(row);

    return DataGridRowAdapter(
      color: rowIndex.isEven ? Colors.grey.shade50 : Colors.white,
      cells: row.getCells().map<Widget>((cell) {
        // Actions
       if (cell.columnName == 'actions') {
          final station = cell.value as FuelStation;

          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👁 عرض
                IconButton(
                  tooltip: 'عرض',
                  icon: const Icon(Icons.visibility, size: 18),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.fuelStationDetails,
                      arguments: station.id,
                    );
                  },
                ),

                // ✏️ تعديل
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.fuelStationForm,
                      arguments: station,
                    );
                  },
                ),

                // 🗑 حذف
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('تأكيد الحذف'),
                        content: Text(
                          'هل أنت متأكد من حذف محطة "${station.stationName}"؟',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              // اغلاق نافذة التأكيد
                              Navigator.of(context).pop();

                              final provider = context
                                  .read<FuelStationProvider>();

                              try {
                                await provider.deleteStation(station.id);

                                // رسالة نجاح
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حذف المحطة بنجاح'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                // رسالة خطأ
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('فشل حذف المحطة: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },

                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }


        // Status badge
        if (cell.columnName == 'status') {
          final status = cell.value.toString();
          final color = _statusColor(status);

          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          );
        }

        // Default cell
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              cell.value.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// ===============================
/// Grid Widget
/// ===============================
class FuelStationDataGrid extends StatelessWidget {
  final List<FuelStation> stations;
  final Function(FuelStation) onStationTap;

  const FuelStationDataGrid({
    super.key,
    required this.stations,
    required this.onStationTap,
  });

  GridColumn _header(String title, double width) {
    return GridColumn(
      width: width,
      columnName: title,
      label: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.all(8),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = FuelStationDataSource(context, stations);

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1200,
          height: MediaQuery.of(context).size.height * 0.65,
          child: SfDataGrid(
            source: dataSource,
            headerRowHeight: 48,
            rowHeight: 50,
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
            allowSorting: true,
            allowFiltering: true,
            selectionMode: SelectionMode.single,
            columns: [
              _header('كود المحطة', 130),
              _header('اسم المحطة', 200),
              _header('الموقع', 180),
              _header('النوع', 110),
              _header('الحالة', 120),
              _header('مدير المحطة', 160),
              _header('الهاتف', 140),
              _header('الإجراءات', 160),
            ],
          ),
        ),
      ),
    );
  }
}
