import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

class TransportOrdersScreen extends StatefulWidget {
  const TransportOrdersScreen({super.key});

  @override
  State<TransportOrdersScreen> createState() => _TransportOrdersScreenState();
}

class _TransportOrdersScreenState extends State<TransportOrdersScreen> {
  DateTimeRange? _range;
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    setState(() => _loading = true);

    try {
      await context.read<OrderProvider>().fetchOrders(
        page: 1,
        filters: {
          'orderSource': 'عميل',
          'requestType': 'نقل',
          'limit': 200,
          if (_formatApiDate(_range?.start) != null)
            'startDate': _formatApiDate(_range?.start)!,
          if (_formatApiDate(_range?.end) != null)
            'endDate': _formatApiDate(_range?.end)!,
        },
        silent: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Order> _filtered(List<Order> orders) {
    final list = orders.where((o) => o.requestType == 'نقل').toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((o) {
      return o.orderNumber.toLowerCase().contains(q) ||
          (o.customer?.name.toLowerCase().contains(q) ?? false) ||
          (o.city?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = _filtered(provider.orders);
    final df = DateFormat('yyyy/MM/dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة طلبات النقل'),
        actions: [
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
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: 'بحث برقم الطلب أو اسم العميل...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.86),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AppSurfaceCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined),
                              const SizedBox(width: 8),
                              Text('${orders.length} طلب'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : orders.isEmpty
                            ? const Center(child: Text('لا توجد طلبات نقل'))
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  itemCount: orders.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final o = orders[index];
                                    final date = o.orderDate;
                                    return AppSurfaceCard(
                                      padding: const EdgeInsets.all(16),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.orderDetails,
                                          arguments: o.id,
                                        );
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue
                                                  .withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.local_shipping_outlined,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                  '${o.customer?.name ?? 'عميل غير محدد'} • ${df.format(date)}',
                                                  style: TextStyle(
                                                    color: Colors.black87
                                                        .withValues(alpha: 0.66),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${(o.quantity ?? 0).toStringAsFixed(0)} ${o.unit ?? 'لتر'} • ${o.city ?? '—'}',
                                                  style: TextStyle(
                                                    color: Colors.black87
                                                        .withValues(alpha: 0.66),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: AppColors.warningOrange
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
