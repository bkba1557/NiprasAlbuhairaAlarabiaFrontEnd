import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_treasury_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class CustomerTreasuryReceiptsScreen extends StatefulWidget {
  final List<CustomerTreasuryBranch> branches;
  final String? selectedBranchId;

  const CustomerTreasuryReceiptsScreen({
    super.key,
    required this.branches,
    required this.selectedBranchId,
  });

  @override
  State<CustomerTreasuryReceiptsScreen> createState() =>
      _CustomerTreasuryReceiptsScreenState();
}

class _CustomerTreasuryReceiptsScreenState
    extends State<CustomerTreasuryReceiptsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س',
    decimalDigits: 2,
  );
  final DateFormat _date = DateFormat('yyyy/MM/dd - hh:mm a', 'ar');

  String? _branchId;
  DateTimeRange? _range;
  bool _loading = false;
  String? _error;
  List<CustomerTreasuryReceipt> _receipts = const [];

  @override
  void initState() {
    super.initState();
    _branchId = widget.selectedBranchId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
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

      final uri = Uri.parse('${ApiEndpoints.baseUrl}/customer-treasury/receipts')
          .replace(
        queryParameters: {
          if ((_branchId ?? '').trim().isNotEmpty) 'branchId': _branchId!,
          if (_formatApiDate(_range?.start) != null)
            'startDate': _formatApiDate(_range?.start)!,
          if (_formatApiDate(_range?.end) != null)
            'endDate': _formatApiDate(_range?.end)!,
          if (_searchController.text.trim().isNotEmpty)
            'q': _searchController.text.trim(),
          'limit': '200',
        },
      );

      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل السجل');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final list = decoded is Map ? decoded['receipts'] : decoded;
      final receipts = (list as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => CustomerTreasuryReceipt.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();

      setState(() => _receipts = receipts);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل سندات القبض'),
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
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 240,
                            maxWidth: 420,
                          ),
                          child: AppSurfaceCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _branchId,
                                isExpanded: true,
                                hint: const Text('اختر الفرع'),
                                items: widget.branches
                                    .map(
                                      (b) => DropdownMenuItem<String>(
                                        value: b.id,
                                        child: Text(
                                          b.code.trim().isEmpty
                                              ? b.name
                                              : '${b.name} (${b.code})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  setState(() => _branchId = value);
                                  await _load();
                                },
                              ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 240,
                            maxWidth: 520,
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => _load(),
                            decoration: InputDecoration(
                              hintText: 'بحث بالعميل أو رقم السند...',
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
                        if (_range != null)
                          AppSurfaceCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Text(
                              '${DateFormat('yyyy/MM/dd', 'ar').format(_range!.start)} - ${DateFormat('yyyy/MM/dd', 'ar').format(_range!.end)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryBlue,
                              ),
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
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _receipts.isEmpty
                            ? const Center(child: Text('لا يوجد سندات'))
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                itemCount: _receipts.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
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
                                            color: AppColors.successGreen
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long_outlined,
                                            color: AppColors.successGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r.voucherNumber.isNotEmpty
                                                    ? r.voucherNumber
                                                    : 'سند قبض',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.primaryBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                r.customerCode.trim().isEmpty
                                                    ? r.customerName
                                                    : '${r.customerName} (${r.customerCode})',
                                                style: TextStyle(
                                                  color: Colors.black87
                                                      .withValues(alpha: 0.66),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${r.branchName} • ${r.createdAt == null ? '—' : _date.format(r.createdAt!)}',
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

