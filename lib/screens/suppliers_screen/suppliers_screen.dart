import 'package:flutter/material.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/supplier/supplier_data_grid.dart';
import 'package:order_tracker/widgets/supplier/supplier_filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late SupplierDataSource _supplierDataSource;

  @override
  void initState() {
    super.initState();
    _supplierDataSource = SupplierDataSource([]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuppliers();
    });
  }

  Future<void> _loadSuppliers() async {
    await Provider.of<SupplierProvider>(
      context,
      listen: false,
    ).fetchSuppliers();
    _updateDataSource();
  }

  void _confirmDeleteSupplier(BuildContext context, String supplierId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف المورد'),
          content: const Text(
            'هل أنت متأكد من حذف هذا المورد؟\nلا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('حذف', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(context);

                final provider = Provider.of<SupplierProvider>(
                  context,
                  listen: false,
                );

                final success = await provider.deleteSupplier(supplierId);

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف المورد بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadSuppliers();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'فشل حذف المورد'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _updateDataSource() {
    final supplierProvider = Provider.of<SupplierProvider>(
      context,
      listen: false,
    );

    setState(() {
      _supplierDataSource = SupplierDataSource(
        supplierProvider.suppliers,
        onDelete: (supplierId) {
          _confirmDeleteSupplier(context, supplierId);
        },
      );
    });
  }

  void _applySearch(String query) {
    final supplierProvider = Provider.of<SupplierProvider>(
      context,
      listen: false,
    );
    final filtered = supplierProvider.suppliers.where((supplier) {
      return supplier.name.contains(query) ||
          supplier.company.contains(query) ||
          supplier.contactPerson.contains(query) ||
          supplier.phone.contains(query);
    }).toList();
    setState(() {
      _supplierDataSource = SupplierDataSource(filtered);
    });
  }

  Future<void> _showSupplierFilters() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SupplierFilterDialog(),
    );

    if (result != null) {
      final supplierProvider = Provider.of<SupplierProvider>(
        context,
        listen: false,
      );
      await supplierProvider.fetchSuppliers(filters: result);
      _updateDataSource();
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final statistics = supplierProvider.statistics;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردين', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _showSupplierFilters,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              // TODO: Export suppliers
            },
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.supplierForm);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Statistics cards
          if (statistics.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.backgroundGray,
              child: isMobile
                  ? GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        _buildStatCard(
                          'إجمالي الموردين',
                          statistics['total']?.toString() ?? '0',
                          Icons.group,
                          AppColors.primaryBlue,
                          compact: true,
                        ),
                        _buildStatCard(
                          'نشط',
                          statistics['active']?.toString() ?? '0',
                          Icons.check_circle,
                          AppColors.successGreen,
                          compact: true,
                        ),
                        _buildStatCard(
                          'غير نشط',
                          statistics['inactive']?.toString() ?? '0',
                          Icons.cancel,
                          AppColors.errorRed,
                          compact: true,
                        ),
                        _buildStatCard(
                          'متوسط التقييم',
                          statistics['avgRating']?.toStringAsFixed(1) ?? '0.0',
                          Icons.star,
                          AppColors.warningOrange,
                          compact: true,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'إجمالي الموردين',
                            statistics['total']?.toString() ?? '0',
                            Icons.group,
                            AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'نشط',
                            statistics['active']?.toString() ?? '0',
                            Icons.check_circle,
                            AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'غير نشط',
                            statistics['inactive']?.toString() ?? '0',
                            Icons.cancel,
                            AppColors.errorRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'متوسط التقييم',
                            statistics['avgRating']?.toStringAsFixed(1) ?? '0.0',
                            Icons.star,
                            AppColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _applySearch,
                    decoration: InputDecoration(
                      hintText: 'بحث عن مورد...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (supplierProvider.filters.isNotEmpty)
                  Chip(
                    label: Text('مفعلة ${supplierProvider.filters.length}'),
                    onDeleted: () {
                      supplierProvider.clearFilters();
                      _updateDataSource();
                    },
                    deleteIcon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          // Data grid
          Expanded(
            child: supplierProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : supplierProvider.suppliers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد موردين',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SupplierDataGrid(
                    dataSource: _supplierDataSource,
                    onRowTap: (supplier) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.supplierDetails,
                        arguments: supplier,
                      );
                    },
                  ),
          ),
          // Pagination
          if (supplierProvider.totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: supplierProvider.currentPage > 1
                        ? () {
                            supplierProvider.fetchSuppliers(
                              page: supplierProvider.currentPage - 1,
                              filters: supplierProvider.filters,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  Text(
                    'الصفحة ${supplierProvider.currentPage} من ${supplierProvider.totalPages}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  IconButton(
                    onPressed:
                        supplierProvider.currentPage <
                            supplierProvider.totalPages
                        ? () {
                            supplierProvider.fetchSuppliers(
                              page: supplierProvider.currentPage + 1,
                              filters: supplierProvider.filters,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(title, style: TextStyle(fontSize: 12, color: color)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
