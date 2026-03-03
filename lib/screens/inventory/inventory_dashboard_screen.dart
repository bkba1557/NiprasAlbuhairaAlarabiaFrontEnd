import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/inventory_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryProvider>();
      provider.fetchDashboardData();
      provider.fetchStock();
    });
  }

  Future<void> _showAddBranchDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فرع جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'اسم الفرع',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<InventoryProvider>();
              final success = await provider.createBranch(controller.text);
              if (mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'فشل إنشاء الفرع'),
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddWarehouseDialog() async {
    final provider = context.read<InventoryProvider>();
    if (provider.branches.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف فرعًا أولًا قبل إنشاء مخزن.')),
      );
      return;
    }

    final nameController = TextEditingController();
    String? selectedBranchId = provider.branches.first.id;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('إضافة مخزن جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBranchId,
                  items: provider.branches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    selectedBranchId = value;
                  }),
                  decoration: const InputDecoration(
                    labelText: 'الفرع المرتبط',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المخزن',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedBranchId != null) {
                    final success = await provider.createWarehouse(
                      name: nameController.text,
                      branchId: selectedBranchId!,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.error ?? 'فشل إنشاء المخزن',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final taxController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مورد مخزون'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المورد',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: taxController,
                decoration: const InputDecoration(
                  labelText: 'الرقم الضريبي',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<InventoryProvider>();
              final success = await provider.createSupplier(
                name: nameController.text,
                taxNumber: taxController.text,
                address: addressController.text,
                phone: phoneController.text,
              );
              if (mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.error ?? 'فشل إنشاء المورد'),
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المخزون', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'فاتورة مخزون جديدة',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.inventoryInvoiceForm);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: AppColors.errorRed),
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildStatCard(
                        'الفروع',
                        provider.branches.length.toString(),
                        Icons.account_tree_outlined,
                        AppColors.primaryBlue,
                      ),
                      _buildStatCard(
                        'المخازن',
                        provider.warehouses.length.toString(),
                        Icons.warehouse_outlined,
                        AppColors.successGreen,
                      ),
                      _buildStatCard(
                        'موردي المخزون',
                        provider.suppliers.length.toString(),
                        Icons.group_outlined,
                        AppColors.warningOrange,
                      ),
                      _buildStatCard(
                        'أصناف بالمخزون',
                        provider.stockItems.length.toString(),
                        Icons.inventory_2_outlined,
                        AppColors.errorRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionButton(
                        label: 'إضافة فرع جديد',
                        icon: Icons.add_location_alt_outlined,
                        color: AppColors.primaryBlue,
                        onPressed: _showAddBranchDialog,
                      ),
                      _buildActionButton(
                        label: 'إضافة مخزن جديد',
                        icon: Icons.warehouse_outlined,
                        color: AppColors.successGreen,
                        onPressed: _showAddWarehouseDialog,
                      ),
                      _buildActionButton(
                        label: 'إضافة مورد مخزون',
                        icon: Icons.person_add_alt_outlined,
                        color: AppColors.warningOrange,
                        onPressed: _showAddSupplierDialog,
                      ),
                      _buildActionButton(
                        label: 'فاتورة مخزون جديدة',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.primaryBlue,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.inventoryInvoiceForm,
                          );
                        },
                      ),
                      _buildActionButton(
                        label: 'عرض المخزون',
                        icon: Icons.inventory_outlined,
                        color: AppColors.mediumGray,
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.inventoryStock);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('المخازن'),
                  const SizedBox(height: 12),
                  _buildWarehouseTable(provider),
                  const SizedBox(height: 24),
                  _buildSectionTitle('الفروع'),
                  const SizedBox(height: 12),
                  _buildBranchTable(provider),
                  const SizedBox(height: 24),
                  _buildSectionTitle('موردي المخزون'),
                  const SizedBox(height: 12),
                  _buildSupplierTable(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      label: Text(label),
    );
  }

  Widget _buildWarehouseTable(InventoryProvider provider) {
    if (provider.warehouses.isEmpty) {
      return _emptyState('لا توجد مخازن حتى الآن');
    }

    return _buildTable(
      columns: const ['اسم المخزن', 'الفرع', 'تاريخ الإنشاء'],
      rows: provider.warehouses.map((warehouse) {
        return [
          warehouse.name,
          warehouse.branchName.isNotEmpty
              ? warehouse.branchName
              : provider.branchName(warehouse.branchId),
          _dateFormat.format(warehouse.createdAt),
        ];
      }).toList(),
    );
  }

  Widget _buildBranchTable(InventoryProvider provider) {
    if (provider.branches.isEmpty) {
      return _emptyState('لا توجد فروع حتى الآن');
    }

    return _buildTable(
      columns: const ['اسم الفرع', 'عدد المخازن', 'تاريخ الإنشاء'],
      rows: provider.branches.map((branch) {
        final count = provider.warehouses
            .where((warehouse) => warehouse.branchId == branch.id)
            .length;
        return [
          branch.name,
          count.toString(),
          _dateFormat.format(branch.createdAt),
        ];
      }).toList(),
    );
  }

  Widget _buildSupplierTable(InventoryProvider provider) {
    if (provider.suppliers.isEmpty) {
      return _emptyState('لا توجد مورّدين للمخزون حتى الآن');
    }

    return _buildTable(
      columns: const ['اسم المورد', 'الرقم الضريبي', 'العنوان'],
      rows: provider.suppliers.map((supplier) {
        return [
          supplier.name,
          supplier.taxNumber,
          supplier.address,
        ];
      }).toList(),
    );
  }

  Widget _buildTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map((label) => DataColumn(label: Text(label)))
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: row.map((cell) => DataCell(Text(cell))).toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.mediumGray),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: AppColors.mediumGray)),
        ],
      ),
    );
  }
}
