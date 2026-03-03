import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/inventory_models.dart';
import 'package:order_tracker/providers/inventory_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class InventoryInvoiceFormScreen extends StatefulWidget {
  const InventoryInvoiceFormScreen({super.key});

  @override
  State<InventoryInvoiceFormScreen> createState() =>
      _InventoryInvoiceFormScreenState();
}

class _InventoryInvoiceFormScreenState
    extends State<InventoryInvoiceFormScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  String? _selectedBranchId;
  String? _selectedWarehouseId;
  String? _selectedSupplierId;
  DateTime _invoiceDate = DateTime.now();

  final List<_LineEntry> _lines = [];

  @override
  void initState() {
    super.initState();
    _lines.add(_LineEntry(onChanged: _onLineChanged));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryProvider>();
      if (provider.branches.isEmpty ||
          provider.warehouses.isEmpty ||
          provider.suppliers.isEmpty) {
        provider.fetchDashboardData();
      }
    });
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _ensureTrailingEmptyRow() {
    if (_lines.isEmpty || !_lines.last.isEmpty) {
      setState(() => _lines.add(_LineEntry(onChanged: _onLineChanged)));
    }
  }

  void _addEmptyRow() {
    setState(() => _lines.add(_LineEntry(onChanged: _onLineChanged)));
  }

  void _onLineChanged() {
    _ensureTrailingEmptyRow();
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _invoiceDate,
    );
    if (picked != null) {
      setState(() => _invoiceDate = picked);
    }
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    setState(() {
      final entry = _lines.removeAt(index);
      entry.dispose();
    });
  }

  Future<void> _submit() async {
    final provider = context.read<InventoryProvider>();
    final items = _lines
        .where((line) => !line.isEmpty)
        .map((line) => line.toItem())
        .where(
          (item) =>
              item.description.isNotEmpty &&
              item.quantity > 0 &&
              item.unitPrice > 0,
        )
        .toList();

    if (_selectedSupplierId == null ||
        _selectedWarehouseId == null ||
        _selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد المورد والفرع والمخزن.')),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة أصناف للمخزون.')),
      );
      return;
    }

    final success = await provider.createInvoice(
      supplierId: _selectedSupplierId!,
      branchId: _selectedBranchId!,
      warehouseId: _selectedWarehouseId!,
      date: _invoiceDate,
      items: items,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ فاتورة المخزون بنجاح.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'فشل حفظ الفاتورة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final warehousesForBranch = provider.warehousesByBranch(_selectedBranchId);

    final subtotal = _lines
        .where((line) => !line.isEmpty)
        .fold(0.0, (sum, line) => sum + line.subtotal);
    final tax = subtotal * InventoryTax.rate;
    final total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة مخزون', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _submit,
            tooltip: 'حفظ الفاتورة',
          ),
        ],
        bottom: provider.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDropdown(
                  label: 'المورد',
                  value: _selectedSupplierId,
                  items: provider.suppliers
                      .map(
                        (supplier) => DropdownMenuItem(
                          value: supplier.id,
                          child: Text(supplier.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedSupplierId = value;
                  }),
                  emptyHint: 'أضف موردًا من لوحة المخزون',
                ),
                _buildDropdown(
                  label: 'الفرع',
                  value: _selectedBranchId,
                  items: provider.branches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedBranchId = value;
                    _selectedWarehouseId = null;
                  }),
                  emptyHint: 'أضف فرعًا من لوحة المخزون',
                ),
                _buildDropdown(
                  label: 'المخزن',
                  value: _selectedWarehouseId,
                  items: warehousesForBranch
                      .map(
                        (warehouse) => DropdownMenuItem(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedWarehouseId = value;
                  }),
                  emptyHint: _selectedBranchId == null
                      ? 'حدد فرعًا أولًا'
                      : 'أضف مخزنًا من لوحة المخزون',
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    'تاريخ الفاتورة: ${_dateFormat.format(_invoiceDate)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTableHeader(),
            const SizedBox(height: 8),
            _buildItemsTable(),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalRow('الإجمالي قبل الضريبة', subtotal),
                  _buildTotalRow('ضريبة 15%', tax),
                  _buildTotalRow('الإجمالي بعد الضريبة', total, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ الفاتورة'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('رجوع'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Text(
      'إضافة المخزون (جدول أفقي مرن)',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildItemsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(AppColors.backgroundGray),
        columns: const [
          DataColumn(label: Text('التفاصيل')),
          DataColumn(label: Text('الكمية')),
          DataColumn(label: Text('السعر قبل الضريبة')),
          DataColumn(label: Text('ضريبة 15%')),
          DataColumn(label: Text('الإجمالي')),
          DataColumn(label: Text('')),
        ],
        rows: List.generate(_lines.length, (index) {
          final line = _lines[index];
          final isLast = index == _lines.length - 1;
          final tax = line.subtotal * InventoryTax.rate;
          final total = line.subtotal + tax;

          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: line.description,
                    onChanged: (_) => line.onChanged(),
                    decoration: const InputDecoration(
                      hintText: 'مثال: كابلات، أدوات...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: line.quantity,
                    onChanged: (_) => line.onChanged(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: line.unitPrice,
                    onChanged: (_) => line.onChanged(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              DataCell(Text(tax.toStringAsFixed(2))),
              DataCell(Text(total.toStringAsFixed(2))),
              DataCell(
                IconButton(
                  icon: Icon(
                    isLast ? Icons.add_circle_outline : Icons.delete_outline,
                    color: isLast ? AppColors.primaryBlue : Colors.red,
                  ),
                  onPressed: isLast ? _addEmptyRow : () => _removeLine(index),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold ? AppColors.primaryBlue : AppColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required String emptyHint,
  }) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: items.isEmpty ? null : onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: items.isEmpty ? emptyHint : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _LineEntry {
  final TextEditingController description = TextEditingController();
  final TextEditingController quantity = TextEditingController();
  final TextEditingController unitPrice = TextEditingController();
  final VoidCallback onChanged;

  _LineEntry({required this.onChanged});

  bool get isEmpty =>
      description.text.trim().isEmpty &&
      quantity.text.trim().isEmpty &&
      unitPrice.text.trim().isEmpty;

  double get qty => double.tryParse(quantity.text) ?? 0;
  double get price => double.tryParse(unitPrice.text) ?? 0;
  double get subtotal => qty * price;

  InventoryLineItem toItem() {
    return InventoryLineItem(
      description: description.text.trim(),
      quantity: qty,
      unitPrice: price,
    );
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
