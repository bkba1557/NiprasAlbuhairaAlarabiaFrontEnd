import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class CustomerLitersReportScreen extends StatefulWidget {
  const CustomerLitersReportScreen({super.key});

  @override
  State<CustomerLitersReportScreen> createState() =>
      _CustomerLitersReportScreenState();
}

class _CustomerLitersReportScreenState extends State<CustomerLitersReportScreen> {
  DateTimeRange? _range;
  bool _loading = false;
  String _query = '';
  Map<String, dynamic>? _payload;
  String? _error;

  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س',
    decimalDigits: 2,
  );

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.loadToken();

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reports/customers').replace(
        queryParameters: {
          'includeDetails': 'false',
          'limit': '300',
          if (_formatApiDate(_range?.start) != null)
            'startDate': _formatApiDate(_range?.start)!,
          if (_formatApiDate(_range?.end) != null)
            'endDate': _formatApiDate(_range?.end)!,
        },
      );

      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل التقرير (${response.statusCode})');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('استجابة غير صالحة');
      }

      setState(() => _payload = decoded);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _items() {
    final list =
        (_payload?['customers'] as List<dynamic>? ?? []).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            );

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list.toList();

    return list
        .where((row) {
          final name = (row['customerName'] ?? '').toString().toLowerCase();
          final code = (row['customerCode'] ?? '').toString().toLowerCase();
          return name.contains(q) || code.contains(q);
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final df = DateFormat('yyyy/MM/dd', 'ar');
    final rangeLabel = _range == null
        ? 'كل الفترات'
        : '${df.format(_range!.start)} - ${df.format(_range!.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير اللترات للعملاء'),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => _query = v),
                                decoration: InputDecoration(
                                  hintText: 'بحث باسم العميل أو الكود...',
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
                                  const Icon(Icons.date_range),
                                  const SizedBox(width: 8),
                                  Text(rangeLabel),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AppSurfaceCard(
                            color: AppColors.errorRed.withValues(alpha: 0.08),
                            border: Border.all(
                              color: AppColors.errorRed.withValues(alpha: 0.18),
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                            ? const Center(child: Text('لا توجد بيانات'))
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final row = items[index];
                                    final name =
                                        (row['customerName'] ?? '—').toString();
                                    final code =
                                        (row['customerCode'] ?? '').toString();
                                    final liters = (row['totalQuantity'] is num)
                                        ? (row['totalQuantity'] as num)
                                            .toDouble()
                                        : double.tryParse(
                                              row['totalQuantity']?.toString() ??
                                                  '',
                                            ) ??
                                            0;
                                    final totalAmount =
                                        (row['totalAmount'] is num)
                                            ? (row['totalAmount'] as num)
                                                .toDouble()
                                            : double.tryParse(
                                                  row['totalAmount']?.toString() ??
                                                      '',
                                                ) ??
                                                0;
                                    final totalOrders = (row['totalOrders'] is int)
                                        ? row['totalOrders'] as int
                                        : int.tryParse(
                                              row['totalOrders']?.toString() ?? '',
                                            ) ??
                                            0;

                                    return AppSurfaceCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              gradient: AppColors.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.people_alt_outlined,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  code.isNotEmpty
                                                      ? '$name ($code)'
                                                      : name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.primaryBlue,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'طلبات: $totalOrders • لترات: ${liters.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: Colors.black87
                                                        .withValues(alpha: 0.66),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _money.format(totalAmount),
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

