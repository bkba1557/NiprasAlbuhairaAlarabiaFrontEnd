import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_treasury_models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class CustomerTreasuryCustomerScreen extends StatefulWidget {
  final CustomerTreasuryBranch branch;
  final CustomerTreasuryCustomerBalance customer;
  final DateTimeRange? initialRange;

  const CustomerTreasuryCustomerScreen({
    super.key,
    required this.branch,
    required this.customer,
    this.initialRange,
  });

  @override
  State<CustomerTreasuryCustomerScreen> createState() =>
      _CustomerTreasuryCustomerScreenState();
}

class _CustomerTreasuryCustomerScreenState
    extends State<CustomerTreasuryCustomerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س',
    decimalDigits: 2,
  );
  final DateFormat _date = DateFormat('yyyy/MM/dd', 'ar');
  final DateFormat _dateTime = DateFormat('yyyy/MM/dd - hh:mm a', 'ar');

  DateTimeRange? _range;
  bool _loading = false;
  String? _error;

  double? _billed;
  double? _collected;
  double? _remaining;
  List<Order> _orders = const [];
  List<CustomerTreasuryReceipt> _receipts = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _range = widget.initialRange;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String? _formatApiDate(DateTime? value) {
    if (value == null) return null;
    return value.toIso8601String().split('T').first;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.loadToken();

      final uri = Uri.parse(
        '${ApiEndpoints.baseUrl}/customer-treasury/customers/${widget.customer.customerId}/ledger',
      ).replace(
        queryParameters: {
          'branchId': widget.branch.id,
          if (_formatApiDate(_range?.start) != null)
            'startDate': _formatApiDate(_range?.start)!,
          if (_formatApiDate(_range?.end) != null)
            'endDate': _formatApiDate(_range?.end)!,
          'limit': '200',
        },
      );

      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل كشف الحساب');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw Exception('استجابة غير صالحة');

      final summary = decoded['summary'];
      final billed = summary is Map ? (summary['billed'] ?? summary['totalBilled']) : null;
      final collected =
          summary is Map ? (summary['collected'] ?? summary['totalCollected']) : null;
      final remaining =
          summary is Map ? (summary['remaining'] ?? summary['totalRemaining']) : null;

      final ordersJson = decoded['orders'] as List<dynamic>? ?? const [];
      final receiptsJson = decoded['receipts'] as List<dynamic>? ?? const [];

      final orders = ordersJson
          .whereType<Map>()
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final receipts = receiptsJson
          .whereType<Map>()
          .map((e) => CustomerTreasuryReceipt.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();

      setState(() {
        _billed = billed is num ? billed.toDouble() : double.tryParse('${billed ?? ''}');
        _collected = collected is num
            ? collected.toDouble()
            : double.tryParse('${collected ?? ''}');
        _remaining = remaining is num
            ? remaining.toDouble()
            : double.tryParse('${remaining ?? ''}');
        _orders = orders;
        _receipts = receipts;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createReceipt() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    var paymentMethod = 'نقداً';
    DateTime receivedAt = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('سند قبض - ${widget.customer.customerName}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'المبلغ',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        suffixText: 'ر.س',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      items: const [
                        DropdownMenuItem(value: 'نقداً', child: Text('نقداً')),
                        DropdownMenuItem(
                          value: 'تحويل بنكي',
                          child: Text('تحويل بنكي'),
                        ),
                        DropdownMenuItem(value: 'شبكة', child: Text('شبكة')),
                        DropdownMenuItem(value: 'شيك', child: Text('شيك')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'طريقة السداد',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => paymentMethod = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDate: receivedAt,
                          );
                          if (picked == null) return;
                          setDialogState(() {
                            receivedAt = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              receivedAt.hour,
                              receivedAt.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text('التاريخ: ${_date.format(receivedAt)}'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      amountController.dispose();
      notesController.dispose();
      return;
    }

    final amountText = amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    final notes = notesController.text.trim();

    amountController.dispose();
    notesController.dispose();

    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل مبلغ صحيح'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/customer-treasury/receipts');
      final body = json.encode({
        'branchId': widget.branch.id,
        'customerId': widget.customer.customerId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'receivedAt': receivedAt.toIso8601String(),
      });

      final response = await http.post(uri, headers: ApiService.headers, body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('تعذر إنشاء سند القبض');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء سند القبض'),
          backgroundColor: AppColors.successGreen,
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billed = _billed ?? widget.customer.billed;
    final collected = _collected ?? widget.customer.collected;
    final remaining = _remaining ?? widget.customer.remaining;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.customerName),
        actions: [
          IconButton(
            tooltip: 'سند قبض',
            onPressed: _loading ? null : _createReceipt,
            icon: const Icon(Icons.payments_outlined),
          ),
          IconButton(
            tooltip: 'تحديد فترة',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
          ),
          IconButton(
            tooltip: 'مسح الفترة',
            onPressed: _range == null ? null : _clearRange,
            icon: const Icon(Icons.filter_alt_off),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الطلبات'),
            Tab(text: 'سندات القبض'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryCard(
                      title: 'إجمالي الفواتير',
                      value: _money.format(billed),
                      icon: Icons.request_quote_outlined,
                      color: AppColors.primaryBlue,
                    ),
                    _summaryCard(
                      title: 'المقبوض',
                      value: _money.format(collected),
                      icon: Icons.payments_outlined,
                      color: AppColors.successGreen,
                    ),
                    _summaryCard(
                      title: 'المتبقي',
                      value: _money.format(remaining),
                      icon: Icons.account_balance_outlined,
                      color: remaining > 0
                          ? AppColors.errorRed
                          : AppColors.successGreen,
                    ),
                    AppSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_tree_outlined,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'الفرع: ${widget.branch.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppSurfaceCard(
                    color: AppColors.errorRed.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.22),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _ordersTab(),
                          _receiptsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ordersTab() {
    if (_orders.isEmpty) {
      return const Center(child: Text('لا يوجد طلبات'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final o = _orders[index];
          final qty = o.quantity ?? 0;
          final subtotal = o.effectiveSubtotal;
          final vat = o.effectiveVatAmount;
          final total = o.effectiveTotalWithVat;

          return AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${o.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_date.format(o.orderDate)} • ${qty.toStringAsFixed(0)} ${o.unit ?? 'لتر'}',
                        style: TextStyle(
                          color: Colors.black87.withValues(alpha: 0.66),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'قبل الضريبة: ${_money.format(subtotal)} • شامل الضريبة: ${_money.format(total)}',
                        style: TextStyle(
                          color: Colors.black87.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.warningOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      o.status,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.warningOrange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _receiptsTab() {
    if (_receipts.isEmpty) {
      return const Center(child: Text('لا يوجد سندات قبض'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _receipts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final r = _receipts[index];
          return AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.successGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.voucherNumber.isNotEmpty ? r.voucherNumber : 'سند قبض',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${r.paymentMethod} • ${r.createdAt == null ? '—' : _dateTime.format(r.createdAt!)}',
                        style: TextStyle(
                          color: Colors.black87.withValues(alpha: 0.66),
                        ),
                      ),
                      if (r.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black87.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _money.format(r.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.black87.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
