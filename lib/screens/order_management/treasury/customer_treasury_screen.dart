import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/models/customer_treasury_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

import 'customer_treasury_customer_screen.dart';
import 'treasury_branches_screen.dart';
import 'treasury_receipts_screen.dart';

class CustomerTreasuryScreen extends StatefulWidget {
  const CustomerTreasuryScreen({super.key});

  @override
  State<CustomerTreasuryScreen> createState() => _CustomerTreasuryScreenState();
}

class _CustomerTreasuryScreenState extends State<CustomerTreasuryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: 'ر.س',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  List<CustomerTreasuryBranch> _branches = const [];
  String? _selectedBranchId;
  CustomerTreasurySummary? _summary;
  List<CustomerTreasuryCustomerBalance> _customers = const [];

  DateTimeRange? _range;
  bool _loadingBranches = false;
  bool _loadingOverview = false;
  String? _error;

  bool get _isBusy => _loadingBranches || _loadingOverview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
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

  String _rangeLabel() {
    if (_range == null) return 'كل الفترات';
    return '${_dateFormat.format(_range!.start)} - ${_dateFormat.format(_range!.end)}';
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
    await _loadOverview();
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _loadOverview();
  }

  Future<void> _loadInitial() async {
    await ApiService.loadToken();
    await _loadBranches();
    await _loadOverview();
  }

  Future<void> _loadBranches() async {
    if (_loadingBranches) return;
    setState(() {
      _loadingBranches = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/customer-treasury/branches');
      final response = await http.get(uri, headers: ApiService.headers);

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل فروع الخزينة');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final list = decoded is Map ? decoded['branches'] : decoded;
      final branches = (list as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => CustomerTreasuryBranch.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _branches = branches;
        if (_selectedBranchId == null) {
          _selectedBranchId = branches.isNotEmpty ? branches.first.id : null;
        } else if (_selectedBranchId != null &&
            _selectedBranchId!.isNotEmpty &&
            !branches.any((b) => b.id == _selectedBranchId)) {
          _selectedBranchId = branches.isNotEmpty ? branches.first.id : null;
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  Future<void> _loadOverview() async {
    if (_loadingOverview) return;

    final branchId = _selectedBranchId;
    if (branchId == null || branchId.isEmpty) {
      setState(() {
        _summary = null;
        _customers = const [];
      });
      return;
    }

    setState(() {
      _loadingOverview = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/customer-treasury/overview')
          .replace(
        queryParameters: {
          'branchId': branchId,
          if (_formatApiDate(_range?.start) != null)
            'startDate': _formatApiDate(_range?.start)!,
          if (_formatApiDate(_range?.end) != null)
            'endDate': _formatApiDate(_range?.end)!,
        },
      );

      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        throw Exception('فشل تحميل ملخص الخزينة');
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw Exception('استجابة غير صالحة');
      }

      final summaryJson = decoded['summary'];
      final customersJson = decoded['customers'];

      final summary = summaryJson is Map
          ? CustomerTreasurySummary.fromJson(
              Map<String, dynamic>.from(summaryJson),
            )
          : null;

      final customers = (customersJson as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) =>
              CustomerTreasuryCustomerBalance.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      setState(() {
        _summary = summary;
        _customers = customers;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingOverview = false);
    }
  }

  List<CustomerTreasuryCustomerBalance> _filteredCustomers() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) {
      return c.customerName.toLowerCase().contains(q) ||
          c.customerCode.toLowerCase().contains(q);
    }).toList();
  }

  CustomerTreasuryBranch? _selectedBranch() {
    final id = _selectedBranchId;
    if (id == null) return null;
    return _branches.firstWhere(
      (b) => b.id == id,
      orElse: () => CustomerTreasuryBranch(
        id: id,
        name: 'فرع',
        code: '',
        isActive: true,
      ),
    );
  }

  Future<void> _openBranches() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CustomerTreasuryBranchesScreen(),
      ),
    );

    if (changed == true) {
      await _loadBranches();
      await _loadOverview();
    }
  }

  Future<void> _openReceipts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomerTreasuryReceiptsScreen(
          branches: _branches,
          selectedBranchId: _selectedBranchId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = _selectedBranch();
    final customers = _filteredCustomers();
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الخزينة'),
        actions: [
          IconButton(
            tooltip: 'سجل سندات القبض',
            onPressed: _branches.isEmpty ? null : _openReceipts,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'إدارة الفروع',
            onPressed: _openBranches,
            icon: const Icon(Icons.account_tree_outlined),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: AppColors.primaryBlue,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedBranchId,
                                          isExpanded: true,
                                          hint: const Text('اختر الفرع'),
                                          items: _branches
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
                                          onChanged: _isBusy
                                              ? null
                                              : (value) async {
                                                  if (value == null) return;
                                                  setState(
                                                    () => _selectedBranchId =
                                                        value,
                                                  );
                                                  await _loadOverview();
                                                },
                                        ),
                                      ),
                                    ),
                                  ],
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
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'بحث باسم/كود العميل...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.86),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
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
                                    Icons.calendar_today,
                                    size: 18,
                                    color: AppColors.primaryBlue,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _rangeLabel(),
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
                        const SizedBox(height: 14),
                        if ((branch?.name ?? '').trim().isNotEmpty)
                          Text(
                            'فرع: ${branch!.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _summaryCard(
                              title: 'إجمالي الفواتير',
                              value: summary == null
                                  ? '—'
                                  : _money.format(summary.totalBilled),
                              icon: Icons.request_quote_outlined,
                              color: AppColors.primaryBlue,
                            ),
                            _summaryCard(
                              title: 'المقبوض',
                              value: summary == null
                                  ? '—'
                                  : _money.format(summary.totalCollected),
                              icon: Icons.payments_outlined,
                              color: AppColors.successGreen,
                            ),
                            _summaryCard(
                              title: 'المتبقي',
                              value: summary == null
                                  ? '—'
                                  : _money.format(summary.totalRemaining),
                              icon: Icons.account_balance_outlined,
                              color: summary != null &&
                                      summary.totalRemaining > 0
                                  ? AppColors.errorRed
                                  : AppColors.successGreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isBusy
                        ? const Center(child: CircularProgressIndicator())
                        : customers.isEmpty
                            ? const Center(child: Text('لا توجد بيانات'))
                            : RefreshIndicator(
                                onRefresh: _loadOverview,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  itemCount: customers.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = customers[index];
                                    final remaining = item.remaining;
                                    final remainingColor =
                                        remaining > 0
                                            ? AppColors.errorRed
                                            : AppColors.successGreen;

                                    return AppSurfaceCard(
                                      onTap: () {
                                        final selectedBranch = _selectedBranch();
                                        if (selectedBranch == null) return;
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CustomerTreasuryCustomerScreen(
                                              branch: selectedBranch,
                                              customer: item,
                                              initialRange: _range,
                                            ),
                                          ),
                                        );
                                      },
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppColors.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.person_outline,
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
                                                  item.customerCode
                                                          .trim()
                                                          .isNotEmpty
                                                      ? '${item.customerName} (${item.customerCode})'
                                                      : item.customerName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color:
                                                        AppColors.primaryBlue,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'فواتير: ${_money.format(item.billed)} • مقبوض: ${_money.format(item.collected)}',
                                                  style: TextStyle(
                                                    color: Colors.black87
                                                        .withValues(alpha: 0.66),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'طلبات: ${item.ordersCount}',
                                                  style: TextStyle(
                                                    color: Colors.black87
                                                        .withValues(alpha: 0.66),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'المتبقي',
                                                style: TextStyle(
                                                  color: Colors.black87
                                                      .withValues(alpha: 0.66),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _money.format(remaining),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: remainingColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.chevron_left,
                                            color: Colors.grey.shade600,
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

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
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
