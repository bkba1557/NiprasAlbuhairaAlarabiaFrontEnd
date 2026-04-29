import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class CustomerAccountsScreen extends StatefulWidget {
  const CustomerAccountsScreen({super.key});

  @override
  State<CustomerAccountsScreen> createState() => _CustomerAccountsScreenState();
}

class _CustomerAccountsScreenState extends State<CustomerAccountsScreen> {
  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: '',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');
  final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd hh:mm a', 'ar');
  final TextEditingController _snapshotSearchController =
      TextEditingController();

  _DebtSnapshot? _snapshot;
  List<_DebtCustomer> _customers = const [];
  List<_DebtCollection> _collections = const [];
  List<_BankAccount> _bankAccounts = const [];
  List<_DepositRequest> _deposits = const [];
  List<_SettlementRequest> _settlements = const [];
  _FinanceDashboard? _dashboard;

  bool _loading = false;
  bool _importing = false;
  String? _error;
  DateTime? _selectedDate;
  String _snapshotSearchQuery = '';
  Set<String> _snapshotSelectedAccounts = <String>{};
  _SnapshotBalanceFilter _snapshotBalanceFilter = _SnapshotBalanceFilter.all;
  String _depositStatusFilter = 'pending';
  String _settlementStatusFilter = 'pending';

  @override
  void dispose() {
    _snapshotSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadSnapshot(),
        _loadCustomers(),
        _loadCollections(),
        _loadBankAccounts(),
        _loadDashboard(),
        _loadDeposits(),
        _loadSettlements(),
      ]);
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _getJson(String endpoint) async {
    final response = await ApiService.get(endpoint);
    return ApiService.decodeJsonMap(response);
  }

  String _dateQuery() =>
      _selectedDate == null ? '' : '?date=${DateFormat('yyyy-MM-dd').format(_selectedDate!)}';

  String _reportDateOnly() =>
      DateFormat('yyyy-MM-dd').format(_selectedDate ?? DateTime.now());

  String? _selectedAccountForExport() {
    if (_snapshotSelectedAccounts.isEmpty) return null;
    if (_snapshotSelectedAccounts.length == 1) {
      return _snapshotSelectedAccounts.first;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اختر عميل واحد للتصدير أو اترك الاختيار فارغ (الكل)'),
      ),
    );
    return null;
  }

  Future<void> _exportDebtCollections({required String format}) async {
    try {
      final dateOnly = _reportDateOnly();
      final selectedAccount = _selectedAccountForExport();

      final baseQuery =
          'reportType=customer_debt_collections&startDate=$dateOnly&endDate=$dateOnly';
      final query = selectedAccount == null
          ? baseQuery
          : '$baseQuery&customerAccountNumber=${Uri.encodeComponent(selectedAccount)}';

      final endpoint = format == 'pdf'
          ? '/reports/export/pdf?$query'
          : '/reports/export/excel?$query';

      final response = await ApiService.download(endpoint);
      final fileStamp = DateTime.now().millisecondsSinceEpoch;
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      await saveAndLaunchFile(
        response.bodyBytes,
        'finance_collections_${dateOnly}_$fileStamp.$ext',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _exportDebtLedger({required String format}) async {
    try {
      final selectedAccount = _selectedAccountForExport();
      if (selectedAccount == null) return;

      final query =
          'reportType=customer_debt_ledger&customerAccountNumber=${Uri.encodeComponent(selectedAccount)}';
      final endpoint = format == 'pdf'
          ? '/reports/export/pdf?$query'
          : '/reports/export/excel?$query';

      final response = await ApiService.download(endpoint);
      final fileStamp = DateTime.now().millisecondsSinceEpoch;
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      await saveAndLaunchFile(
        response.bodyBytes,
        'finance_ledger_${selectedAccount}_$fileStamp.$ext',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _loadSnapshot() async {
    final decoded = await _getJson(ApiEndpoints.customerDebtLatest);
    final raw = decoded['snapshot'];
    if (raw is Map<String, dynamic>) {
      _snapshot = _DebtSnapshot.fromJson(raw);
    } else if (raw is Map) {
      _snapshot = _DebtSnapshot.fromJson(Map<String, dynamic>.from(raw));
    } else {
      _snapshot = null;
    }
  }

  Future<void> _loadCustomers() async {
    final decoded = await _getJson('/customer-debts/customers');
    final list = decoded['customers'] as List<dynamic>? ?? const [];
    _customers = list
        .whereType<Map>()
        .map((item) => _DebtCustomer.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _loadCollections() async {
    final decoded = await _getJson('/customer-debts/collections${_dateQuery()}');
    final list = decoded['collections'] as List<dynamic>? ?? const [];
    _collections = list
        .whereType<Map>()
        .map((item) => _DebtCollection.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _loadBankAccounts() async {
    final decoded = await _getJson('/customer-debts/bank-accounts');
    final list = decoded['bankAccounts'] as List<dynamic>? ?? const [];
    _bankAccounts = list
        .whereType<Map>()
        .map((item) => _BankAccount.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _loadDashboard() async {
    final decoded =
        await _getJson('/customer-debts/finance/dashboard${_dateQuery()}');
    final raw = decoded['dashboard'];
    if (raw is Map<String, dynamic>) {
      _dashboard = _FinanceDashboard.fromJson(raw);
    } else if (raw is Map) {
      _dashboard = _FinanceDashboard.fromJson(Map<String, dynamic>.from(raw));
    } else {
      _dashboard = null;
    }
  }

  Future<void> _loadDeposits() async {
    final statusQuery =
        _depositStatusFilter == 'all' ? '' : '?status=$_depositStatusFilter';
    final decoded = await _getJson('/customer-debts/deposits$statusQuery');
    final list = decoded['deposits'] as List<dynamic>? ?? const [];
    _deposits = list
        .whereType<Map>()
        .map((item) => _DepositRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _loadSettlements() async {
    final statusQuery = _settlementStatusFilter == 'all'
        ? ''
        : '?status=$_settlementStatusFilter';
    final decoded = await _getJson('/customer-debts/settlements$statusQuery');
    final list = decoded['settlements'] as List<dynamic>? ?? const [];
    _settlements = list
        .whereType<Map>()
        .map((item) => _SettlementRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: _selectedDate ?? DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _loadAll();
  }

  Future<void> _clearDate() async {
    setState(() => _selectedDate = null);
    await _loadAll();
  }

  List<_DebtSnapshotRow> _filteredSnapshotRows(_DebtSnapshot snapshot) {
    return snapshot.rows.where((row) {
      final matchesSearch = _snapshotSearchQuery.trim().isEmpty ||
          '${row.customerName} ${row.accountNumber}'
              .toLowerCase()
              .contains(_snapshotSearchQuery.trim().toLowerCase());

      final matchesSelectedAccounts = _snapshotSelectedAccounts.isEmpty ||
          _snapshotSelectedAccounts.contains(row.accountNumber);

      final matchesBalanceFilter = switch (_snapshotBalanceFilter) {
        _SnapshotBalanceFilter.all => true,
        _SnapshotBalanceFilter.outstanding => row.currentBalance > 0,
        _SnapshotBalanceFilter.collected => row.totalCollected > 0,
        _SnapshotBalanceFilter.settled => row.currentBalance <= 0,
      };

      return matchesSearch && matchesSelectedAccounts && matchesBalanceFilter;
    }).toList();
  }

  Future<void> _showSnapshotCustomerFilter(_DebtSnapshot snapshot) async {
    final selectedAccounts = Set<String>.from(_snapshotSelectedAccounts);
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredRows = snapshot.rows.where((row) {
              final haystack =
                  '${row.customerName} ${row.accountNumber}'.toLowerCase();
              return haystack.contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'فلترة العملاء',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setModalState(() => query = value),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن عميل أو رقم حساب',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF4F7FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(selectedAccounts.clear),
                          child: const Text('مسح الكل'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, selectedAccounts),
                          child: const Text('تطبيق'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredRows.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = filteredRows[index];
                          final selected =
                              selectedAccounts.contains(row.accountNumber);
                          return CheckboxListTile(
                            value: selected,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primaryBlue,
                            title: Text(
                              row.customerName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(row.accountNumber),
                            secondary: CircleAvatar(
                              backgroundColor:
                                  AppColors.primaryBlue.withValues(alpha: 0.10),
                              child: const Icon(
                                Icons.people_alt_outlined,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            onChanged: (_) {
                              setModalState(() {
                                if (selected) {
                                  selectedAccounts.remove(row.accountNumber);
                                } else {
                                  selectedAccounts.add(row.accountNumber);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => _snapshotSelectedAccounts = picked);
    }
  }

  Future<void> _importExcelFile() async {
    if (_importing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) return;

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      await ApiService.loadToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.customerDebtImport}'),
      );
      final authorization = ApiService.headers['Authorization'];
      if (authorization != null && authorization.isNotEmpty) {
        request.headers['Authorization'] = authorization;
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractHttpMessage(response));
      }
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استيراد كشف العملاء واستبدال البيانات السابقة'),
        ),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _showBankDialog() async {
    final bankNameController = TextEditingController();
    final accountNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final ibanController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة حساب بنكي'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: bankNameController,
                  decoration: const InputDecoration(labelText: 'اسم البنك'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: accountNameController,
                  decoration: const InputDecoration(labelText: 'اسم الحساب'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: accountNumberController,
                  decoration: const InputDecoration(labelText: 'رقم الحساب'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ibanController,
                  decoration: const InputDecoration(labelText: 'IBAN'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ApiService.post('/customer-debts/bank-accounts', {
                'bankName': bankNameController.text.trim(),
                'accountName': accountNameController.text.trim(),
                'accountNumber': accountNumberController.text.trim(),
                'iban': ibanController.text.trim(),
              });
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              await _loadBankAccounts();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDirectReceiptDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    _DebtCustomer? selectedCustomer =
        _customers.isNotEmpty ? _customers.first : null;
    String paymentMethod = 'cash';
    _BankAccount? selectedBank =
        _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
    final formKey = GlobalKey<FormState>();

    Future<_DebtCustomer?> pickCustomer() async {
      final searchController = TextEditingController();
      try {
        return await showDialog<_DebtCustomer>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              final query = searchController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? _customers
                  : _customers.where((c) {
                      final haystack =
                          '${c.customerName} ${c.accountNumber}'.toLowerCase();
                      return haystack.contains(query);
                    }).toList();

              return AlertDialog(
                title: const Text('اختيار العميل'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'بحث بالاسم أو رقم الحساب',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return ListTile(
                              title: Text(
                                item.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(item.accountNumber),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
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
                ],
              );
            },
          ),
        );
      } finally {
        searchController.dispose();
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('سند قبض من العميل'),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await pickCustomer();
                          if (picked == null) return;
                          setModalState(() => selectedCustomer = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'العميل',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedCustomer?.displayName ?? 'اختر العميل',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المبلغ'),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          return (parsed == null || parsed <= 0)
                              ? 'مبلغ غير صالح'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'طريقة الدفع'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                          DropdownMenuItem(value: 'card', child: Text('شبكة')),
                          DropdownMenuItem(
                            value: 'bank_transfer',
                            child: Text('تحويل بنكي'),
                          ),
                        ],
                        onChanged: (value) => setModalState(() {
                          paymentMethod = value ?? 'cash';
                        }),
                      ),
                      if (paymentMethod == 'bank_transfer') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<_BankAccount>(
                          initialValue: selectedBank,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'الحساب البنكي',
                          ),
                          items: _bankAccounts
                              .map(
                                (item) => DropdownMenuItem<_BankAccount>(
                                  value: item,
                                  child: Text(
                                    item.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setModalState(() {
                            selectedBank = value;
                          }),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'ملاحظات'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() ||
                      selectedCustomer == null) {
                    return;
                  }

                  await ApiService.post('/customer-debts/collections', {
                    'customerAccountNumber': selectedCustomer!.accountNumber,
                    'amount': double.parse(amountController.text.trim()),
                    'paymentMethod': paymentMethod,
                    'bankAccountId': paymentMethod == 'bank_transfer'
                        ? selectedBank?.id
                        : null,
                    'bankName': paymentMethod == 'bank_transfer'
                        ? selectedBank?.bankName
                        : '',
                    'notes': notesController.text.trim(),
                  });

                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadAll();
                },
                child: const Text('تسجيل'),
              ),
            ],
          );
        },
      ),
    );
  }


  Future<void> _reviewDeposit(_DepositRequest item, String status) async {
    await ApiService.patch('/customer-debts/deposits/${item.id}/review', {
      'status': status,
    });
    await _loadAll();
  }

  Future<void> _reviewSettlement(_SettlementRequest item, String status) async {
    await ApiService.patch('/customer-debts/settlements/${item.id}/review', {
      'status': status,
    });
    await _loadAll();
  }

  String _extractHttpMessage(http.Response response) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        return (decoded['error'] ?? decoded['message'] ?? 'حدث خطأ').toString();
      }
    } catch (_) {}
    return 'حدث خطأ';
  }

  String _decodePossiblyMisencodedText(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return raw;

    try {
      final units = raw.codeUnits;
      if (units.any((unit) => unit > 255)) return raw;
      final decoded = utf8.decode(units).trim();
      return decoded.isEmpty ? raw : decoded;
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideScreen = width >= 1100;
    final contentMaxWidth = width >= 1600 ? 1500.0 : 1280.0;
    final horizontalPadding = width >= 1400 ? 24.0 : width >= 900 ? 20.0 : 16.0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
       appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          toolbarHeight: isWideScreen ? 58 : 52,
         title: Text(
            'مديونات العملاء',
            style: TextStyle(
              fontSize: isWideScreen ? 22 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(isWideScreen ? 126 : 118),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildToolbarAction(
                            icon: Icons.refresh_rounded,
                            label: 'تحديث',
                            onTap: _loading ? null : _loadAll,
                          ),
                          _buildToolbarAction(
                            icon: Icons.calendar_month_rounded,
                            label: 'اختيار التاريخ',
                            onTap: _pickDate,
                          ),
                          _buildToolbarAction(
                            icon: Icons.filter_alt_off_rounded,
                            label: 'مسح التاريخ',
                            onTap: _selectedDate == null ? null : _clearDate,
                            enabled: _selectedDate != null,
                          ),
                          if (_selectedDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primaryBlue.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Text(
                                'التاريخ: ${_dateFormat.format(_selectedDate!)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: isWideScreen ? 58 : 54,
                        width: double.infinity,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.10,
                            ),
                          ),
                        ),
                        child: TabBar(
                          isScrollable: false,
                          splashBorderRadius: BorderRadius.circular(18),
                          labelColor: AppColors.primaryBlue,
                          unselectedLabelColor: Colors.black54,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.16,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.file_open_outlined, size: 20),
                              text: 'الكشف',
                            ),
                            Tab(
                              icon: Icon(
                                Icons.dashboard_customize_outlined,
                                size: 20,
                              ),
                              text: 'لوحة المالية',
                            ),
                            Tab(
                              icon: Icon(Icons.payments_outlined, size: 20),
                              text: 'التحصيلات',
                            ),
                            Tab(
                              icon: Icon(Icons.fact_check_outlined, size: 20),
                              text: 'المراجعات',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            const AppSoftBackground(),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    children: [
                      if (_error != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildSnapshotTab(horizontalPadding),
                            _buildDashboardTab(horizontalPadding),
                            _buildCollectionsTab(horizontalPadding),
                            _buildReviewsTab(horizontalPadding),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled
                  ? AppColors.primaryBlue.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.12),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? AppColors.primaryBlue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? AppColors.primaryBlue : Colors.grey,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveListView({
    required double horizontalPadding,
    required List<Widget> children,
  }) {
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 24),
      children: children,
    );
  }

  Widget _buildSnapshotFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withValues(alpha: 0.12)
              : const Color(0xFFF5F7FC),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.30)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primaryBlue : Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

 Widget _buildSnapshotTab(double horizontalPadding) {
    final snapshot = _snapshot;
    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استيراد كشف العملاء من Excel',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'استورد بيانات العملاء من ملف Excel، ثم راجع الإجماليات والأرصدة الحالية مع إمكانية البحث والتصفية حسب العميل أو حالة الرصيد.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _importing ? null : _importExcelFile,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(_importing ? 'جاري الاستيراد...' : 'رفع ملف Excel'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (snapshot != null) ...[
          Builder(
            builder: (context) {
              final filteredRows = _filteredSnapshotRows(snapshot);
              final filteredTotals = filteredRows.fold<_SnapshotTableTotals>(
                _SnapshotTableTotals.zero(),
                (acc, row) => acc.add(row),
              );

              return Column(
                children: [
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'تصفية العملاء',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showSnapshotCustomerFilter(snapshot),
                              icon: const Icon(Icons.filter_list_rounded),
                              label: Text(
                                _snapshotSelectedAccounts.isEmpty
                                    ? 'اختيار العملاء'
                                    : 'المحدد (${_snapshotSelectedAccounts.length})',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _snapshotSearchController,
                          onChanged: (value) =>
                              setState(() => _snapshotSearchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'ابحث باسم العميل أو رقم الحساب',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _snapshotSearchQuery.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () => setState(() {
                                      _snapshotSearchController.clear();
                                      _snapshotSearchQuery = '';
                                    }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true,
                            fillColor: const Color(0xFFF5F7FC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildSnapshotFilterChip(
                              label: 'الكل',
                              selected:
                                  _snapshotBalanceFilter ==
                                  _SnapshotBalanceFilter.all,
                              onTap: () => setState(
                                () => _snapshotBalanceFilter =
                                    _SnapshotBalanceFilter.all,
                              ),
                            ),
                            _buildSnapshotFilterChip(
                              label: 'رصيد مستحق',
                              selected:
                                  _snapshotBalanceFilter ==
                                  _SnapshotBalanceFilter.outstanding,
                              onTap: () => setState(
                                () => _snapshotBalanceFilter =
                                    _SnapshotBalanceFilter.outstanding,
                              ),
                            ),
                            _buildSnapshotFilterChip(
                              label: 'تم التحصيل كاملًا',
                              selected:
                                  _snapshotBalanceFilter ==
                                  _SnapshotBalanceFilter.collected,
                              onTap: () => setState(
                                () => _snapshotBalanceFilter =
                                    _SnapshotBalanceFilter.collected,
                              ),
                            ),
                            _buildSnapshotFilterChip(
                              label: 'مسدد',
                              selected:
                                  _snapshotBalanceFilter ==
                                  _SnapshotBalanceFilter.settled,
                              onTap: () => setState(
                                () => _snapshotBalanceFilter =
                                    _SnapshotBalanceFilter.settled,
                              ),
                            ),
                            if (_snapshotSearchQuery.trim().isNotEmpty ||
                                _snapshotSelectedAccounts.isNotEmpty ||
                                _snapshotBalanceFilter !=
                                    _SnapshotBalanceFilter.all)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _snapshotSearchController.clear();
                                  _snapshotSearchQuery = '';
                                  _snapshotSelectedAccounts = <String>{};
                                  _snapshotBalanceFilter =
                                      _SnapshotBalanceFilter.all;
                                }),
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: const Text('إعادة التصفية'),
                              ),
                          ],
                        ),
                        if (_snapshotSelectedAccounts.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: snapshot.rows
                                .where(
                                  (row) => _snapshotSelectedAccounts.contains(
                                    row.accountNumber,
                                  ),
                                )
                                .map(
                                  (row) => Chip(
                                    label: Text(row.customerName),
                                    onDeleted: () => setState(
                                      () => _snapshotSelectedAccounts.remove(
                                        row.accountNumber,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statusCard(
                        'العملاء المعروضون',
                        '${filteredRows.length}',
                        AppColors.primaryBlue,
                      ),
                      _moneyCard(
                        'إجمالي المدين',
                        _formatMoney(filteredTotals.totalDebit),
                        Icons.south_west_outlined,
                      ),
                      _moneyCard(
                        'إجمالي الدائن',
                        _formatMoney(filteredTotals.totalCredit),
                        Icons.north_east_outlined,
                      ),
                      _moneyCard(
                        'المحصل',
                        _formatMoney(filteredTotals.totalCollected),
                        Icons.payments_outlined,
                      ),
                      _moneyCard(
                        'الرصيد الحالي',
                        _formatMoney(filteredTotals.totalCurrentBalance),
                        Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        _metaItem(
                          'اسم الملف',
                          _decodePossiblyMisencodedText(snapshot.fileName),
                        ),
                        _metaItem('الشيت', snapshot.sheetName),
                        _metaItem(
                          'وقت الاستيراد',
                          _dateTimeFormat.format(snapshot.importedAt.toLocal()),
                        ),
                        _metaItem('المستورد', snapshot.importedByName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(12),
                    child: filteredRows.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                              child: Text(
                                'لا توجد نتائج مطابقة للتصفية الحالية',
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 52,
                              dataRowMinHeight: 56,
                              dataRowMaxHeight: 72,
                              columns: const [
                                DataColumn(label: Text('رقم الحساب')),
                                DataColumn(label: Text('اسم العميل')),
                                DataColumn(label: Text('مدين')),
                                DataColumn(label: Text('دائن')),
                                DataColumn(label: Text('المحصل')),
                                DataColumn(label: Text('الرصيد')),
                              ],
                              rows: filteredRows
                                  .map(
                                    (row) => DataRow(
                                      cells: [
                                        DataCell(Text(row.accountNumber)),
                                        DataCell(
                                          SizedBox(
                                            width: 320,
                                            child: Text(row.customerName),
                                          ),
                                        ),
                                        DataCell(Text(_formatMoney(row.debit))),
                                        DataCell(
                                          Text(_formatMoney(row.credit)),
                                        ),
                                        DataCell(
                                          Text(
                                            _formatMoney(row.totalCollected),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _formatMoney(row.currentBalance),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: row.currentBalance > 0
                                                  ? AppColors.errorRed
                                                  : AppColors.successGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statusCard(
                'عدد العملاء',
                '${snapshot.customersCount}',
                AppColors.primaryBlue,
              ),
              _moneyCard(
                'إجمالي المدين',
                _formatMoney(snapshot.totalDebit),
                Icons.south_west_outlined,
              ),
              _moneyCard(
                'إجمالي الدائن',
                _formatMoney(snapshot.totalCredit),
                Icons.north_east_outlined,
              ),
              _moneyCard(
                'صافي الرصيد',
                _formatMoney(snapshot.totalNetBalance),
                Icons.balance_outlined,
              ),
            ],
          ),
        ] else
          AppSurfaceCard(
            padding: const EdgeInsets.all(24),
            child: const Center(child: Text('لا توجد بيانات مستوردة حاليًا')),
          ),
      ],
    );
  }




  Widget _buildDashboardTab(double horizontalPadding) {
    final dashboard = _dashboard;
    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        if (dashboard == null)
          const AppSurfaceCard(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('لا توجد بيانات متاحة')),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _moneyCard('إجمالي التحصيل', _formatMoney(dashboard.total), Icons.payments_outlined),
              _moneyCard('نقدي', _formatMoney(dashboard.cash), Icons.money_outlined),
              _moneyCard('شبكة', _formatMoney(dashboard.card), Icons.credit_card_outlined),
              _moneyCard('تحويل', _formatMoney(dashboard.bankTransfer), Icons.account_balance_outlined),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _exportDebtCollections(format: 'pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('تصدير التحصيلات PDF'),
              ),
              FilledButton.icon(
                onPressed: () => _exportDebtCollections(format: 'excel'),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('تصدير التحصيلات Excel'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportDebtLedger(format: 'pdf'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('حركة عميل PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportDebtLedger(format: 'excel'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('حركة عميل Excel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statusCard('طلبات الإيداع المعلقة', '${dashboard.pendingDeposits}', AppColors.warningOrange),
              _statusCard('طلبات التصفية المعلقة', '${dashboard.pendingSettlements}', AppColors.errorRed),
            ],
          ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حالة المحصلين النقدية',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 12),
                ...dashboard.collectorCashStatus.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.collectorName),
                    subtitle: Text(
                      'المحصل نقداً: ${_formatMoney(item.collected)} • مودع: ${_formatMoney(item.deposited)} • مصفى: ${_formatMoney(item.settled)}',
                    ),
                    trailing: Text(
                      _formatMoney(item.outstanding),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.errorRed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'العملاء المحصل منهم',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 12),
                ...dashboard.customers.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.customerName),
                    subtitle: Text(item.customerAccountNumber),
                    trailing: Text(
                      _formatMoney(item.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCollectionsTab(double horizontalPadding) {
    final totals = _collections.fold<_CollectionTotals>(
      _CollectionTotals.zero(),
      (acc, item) => acc.add(item),
    );
    final balanceByAccount = <String, double>{
      for (final row in (_snapshot?.rows ?? const <_DebtSnapshotRow>[]))
        row.accountNumber: row.currentBalance,
    };

    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _customers.isEmpty ? null : _showDirectReceiptDialog,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('سند قبض'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _moneyCard('الإجمالي', _formatMoney(totals.total), Icons.payments_outlined),
            _moneyCard('نقدي', _formatMoney(totals.cash), Icons.money_outlined),
            _moneyCard('شبكة', _formatMoney(totals.card), Icons.credit_card_outlined),
            _moneyCard('تحويل', _formatMoney(totals.bankTransfer), Icons.account_balance_outlined),
          ],
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: _collections.isEmpty
                ? const [Padding(padding: EdgeInsets.all(24), child: Text('لا توجد تحصيلات'))]
                : _collections
                    .map((item) {
                      final double remaining =
                          (balanceByAccount[item.customerAccountNumber] ??
                                  item.remainingAfter)
                              .toDouble();
                      final double remainingDue = remaining > 0 ? remaining : 0;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.customerName),
                        subtitle: Text(
                          '${item.collectorName} • ${_paymentMethodLabel(item.paymentMethod)} • ${_dateTimeFormat.format(item.createdAt.toLocal())}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatMoney(item.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.successGreen,
                              ),
                            ),
                            Text(
                              'متبقي ${_formatMoney(remainingDue)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab(double horizontalPadding) {
    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _showBankDialog,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('إضافة حساب بنكي'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الحسابات البنكية',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 12),
              ..._bankAccounts.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.bankName),
                  subtitle: Text(item.accountName),
                  trailing: Text(item.accountNumber),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'طلبات الإيداع تحت المراجعة',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 12),
              if (_deposits.isEmpty)
                const Text('لا توجد طلبات إيداع معلقة')
              else
                ..._deposits.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.collectorName),
                    subtitle: Text('${item.bankName} • ${item.accountName}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Text(_formatMoney(item.amount)),
                        IconButton(
                          onPressed: () => _reviewDeposit(item, 'approved'),
                          icon: const Icon(Icons.check_circle, color: AppColors.successGreen),
                        ),
                        IconButton(
                          onPressed: () => _reviewDeposit(item, 'rejected'),
                          icon: const Icon(Icons.cancel, color: AppColors.errorRed),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'طلبات التصفية تحت المراجعة',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 12),
              if (_settlements.isEmpty)
                const Text('لا توجد طلبات تصفية معلقة')
              else
                ..._settlements.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.collectorName),
                    subtitle: Text(item.notes.isEmpty ? 'بدون ملاحظات' : item.notes),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Text(_formatMoney(item.amount)),
                        IconButton(
                          onPressed: () => _reviewSettlement(item, 'approved'),
                          icon: const Icon(Icons.check_circle, color: AppColors.successGreen),
                        ),
                        IconButton(
                          onPressed: () => _reviewSettlement(item, 'rejected'),
                          icon: const Icon(Icons.cancel, color: AppColors.errorRed),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moneyCard(String title, String value, IconData icon) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 250),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _MoneyValue(text: value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(String title, String value, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 250),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  String _paymentMethodLabel(String value) {
    switch (value) {
      case 'cash':
        return 'نقدي';
      case 'card':
        return 'شبكة';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return value;
    }
  }

  String _formatMoney(double value) => _money.format(value).trim();
}

class _MoneyValue extends StatelessWidget {
  const _MoneyValue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.primaryBlue,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 6),
        SvgPicture.asset(
          'assets/images/saudi_riyal_symbol.svg',
          width: 14,
          height: 14,
          colorFilter: const ColorFilter.mode(
            AppColors.primaryBlue,
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}

class _DebtSnapshot {
  _DebtSnapshot({
    required this.fileName,
    required this.sheetName,
    required this.importedAt,
    required this.importedByName,
    required this.customersCount,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalNetBalance,
    required this.rows,
  });

  final String fileName;
  final String sheetName;
  final DateTime importedAt;
  final String importedByName;
  final int customersCount;
  final double totalDebit;
  final double totalCredit;
  final double totalNetBalance;
  final List<_DebtSnapshotRow> rows;

  factory _DebtSnapshot.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => _DebtSnapshotRow.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return _DebtSnapshot(
      fileName: json['fileName']?.toString() ?? '',
      sheetName: json['sheetName']?.toString() ?? '',
      importedAt: DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      importedByName: json['importedByName']?.toString() ?? '',
      customersCount: _asInt(totals['customersCount']),
      totalDebit: _asDouble(totals['totalDebit']),
      totalCredit: _asDouble(totals['totalCredit']),
      totalNetBalance: _asDouble(totals['totalNetBalance']),
      rows: rows,
    );
  }
}

class _DebtSnapshotRow {
  _DebtSnapshotRow({
    required this.accountNumber,
    required this.customerName,
    required this.debit,
    required this.credit,
    required this.totalCollected,
    required this.currentBalance,
  });

  final String accountNumber;
  final String customerName;
  final double debit;
  final double credit;
  final double totalCollected;
  final double currentBalance;

  factory _DebtSnapshotRow.fromJson(Map<String, dynamic> json) {
    return _DebtSnapshotRow(
      accountNumber: json['accountNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      debit: _asDouble(json['debit']),
      credit: _asDouble(json['credit']),
      totalCollected: _asDouble(json['totalCollected']),
      currentBalance: _asDouble(json['currentBalance']),
    );
  }
}

class _DebtCustomer {
  _DebtCustomer({
    required this.accountNumber,
    required this.customerName,
    required this.currentBalance,
  });

  final String accountNumber;
  final String customerName;
  final double currentBalance;

  String get displayName => '$customerName ($accountNumber)';

  factory _DebtCustomer.fromJson(Map<String, dynamic> json) {
    return _DebtCustomer(
      accountNumber: json['accountNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      currentBalance: _asDouble(json['currentBalance']),
    );
  }
}

class _DebtCollection {
  _DebtCollection({
    required this.id,
    required this.customerAccountNumber,
    required this.customerName,
    required this.amount,
    required this.paymentMethod,
    required this.collectorName,
    required this.remainingAfter,
    required this.createdAt,
  });

  final String id;
  final String customerAccountNumber;
  final String customerName;
  final double amount;
  final String paymentMethod;
  final String collectorName;
  final double remainingAfter;
  final DateTime createdAt;

  factory _DebtCollection.fromJson(Map<String, dynamic> json) {
    return _DebtCollection(
      id: json['id']?.toString() ?? '',
      customerAccountNumber: json['customerAccountNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      collectorName: json['collectorName']?.toString() ?? '',
      remainingAfter: _asDouble(json['remainingAfter']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _BankAccount {
  _BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;

  String get displayName => '$bankName - $accountName';

  factory _BankAccount.fromJson(Map<String, dynamic> json) {
    return _BankAccount(
      id: json['id']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
    );
  }
}

class _DepositRequest {
  _DepositRequest({
    required this.id,
    required this.collectorName,
    required this.amount,
    required this.bankName,
    required this.accountName,
  });

  final String id;
  final String collectorName;
  final double amount;
  final String bankName;
  final String accountName;

  factory _DepositRequest.fromJson(Map<String, dynamic> json) {
    return _DepositRequest(
      id: json['id']?.toString() ?? '',
      collectorName: json['collectorName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      bankName: json['bankName']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
    );
  }
}

class _SettlementRequest {
  _SettlementRequest({
    required this.id,
    required this.collectorName,
    required this.amount,
    required this.notes,
  });

  final String id;
  final String collectorName;
  final double amount;
  final String notes;

  factory _SettlementRequest.fromJson(Map<String, dynamic> json) {
    return _SettlementRequest(
      id: json['id']?.toString() ?? '',
      collectorName: json['collectorName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class _FinanceDashboard {
  _FinanceDashboard({
    required this.total,
    required this.cash,
    required this.card,
    required this.bankTransfer,
    required this.pendingDeposits,
    required this.pendingSettlements,
    required this.customers,
    required this.collectorCashStatus,
  });

  final double total;
  final double cash;
  final double card;
  final double bankTransfer;
  final int pendingDeposits;
  final int pendingSettlements;
  final List<_FinanceCustomerTotal> customers;
  final List<_CollectorCashStatus> collectorCashStatus;

  factory _FinanceDashboard.fromJson(Map<String, dynamic> json) {
    final methodTotals = json['methodTotals'] is Map
        ? Map<String, dynamic>.from(json['methodTotals'] as Map)
        : <String, dynamic>{};
    return _FinanceDashboard(
      total: _asDouble(methodTotals['total']),
      cash: _asDouble(methodTotals['cash']),
      card: _asDouble(methodTotals['card']),
      bankTransfer: _asDouble(methodTotals['bankTransfer']),
      pendingDeposits: _asInt(json['pendingDeposits']),
      pendingSettlements: _asInt(json['pendingSettlements']),
      customers: (json['customers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => _FinanceCustomerTotal.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      collectorCashStatus: (json['collectorCashStatus'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => _CollectorCashStatus.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class _FinanceCustomerTotal {
  _FinanceCustomerTotal({
    required this.customerAccountNumber,
    required this.customerName,
    required this.amount,
  });

  final String customerAccountNumber;
  final String customerName;
  final double amount;

  factory _FinanceCustomerTotal.fromJson(Map<String, dynamic> json) {
    return _FinanceCustomerTotal(
      customerAccountNumber: json['customerAccountNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
    );
  }
}

class _CollectorCashStatus {
  _CollectorCashStatus({
    required this.collectorName,
    required this.collected,
    required this.deposited,
    required this.settled,
    required this.outstanding,
  });

  final String collectorName;
  final double collected;
  final double deposited;
  final double settled;
  final double outstanding;

  factory _CollectorCashStatus.fromJson(Map<String, dynamic> json) {
    return _CollectorCashStatus(
      collectorName: json['collectorName']?.toString() ?? '',
      collected: _asDouble(json['collected']),
      deposited: _asDouble(json['deposited']),
      settled: _asDouble(json['settled']),
      outstanding: _asDouble(json['outstanding']),
    );
  }
}

class _CollectionTotals {
  _CollectionTotals({
    required this.total,
    required this.cash,
    required this.card,
    required this.bankTransfer,
  });

  final double total;
  final double cash;
  final double card;
  final double bankTransfer;

  factory _CollectionTotals.zero() => _CollectionTotals(
        total: 0,
        cash: 0,
        card: 0,
        bankTransfer: 0,
      );

  _CollectionTotals add(_DebtCollection item) {
    return _CollectionTotals(
      total: total + item.amount,
      cash: cash + (item.paymentMethod == 'cash' ? item.amount : 0),
      card: card + (item.paymentMethod == 'card' ? item.amount : 0),
      bankTransfer: bankTransfer +
          (item.paymentMethod == 'bank_transfer' ? item.amount : 0),
    );
  }
}

enum _SnapshotBalanceFilter { all, outstanding, collected, settled }

class _SnapshotTableTotals {
  _SnapshotTableTotals({
    required this.totalDebit,
    required this.totalCredit,
    required this.totalCollected,
    required this.totalCurrentBalance,
  });

  final double totalDebit;
  final double totalCredit;
  final double totalCollected;
  final double totalCurrentBalance;

  factory _SnapshotTableTotals.zero() => _SnapshotTableTotals(
        totalDebit: 0,
        totalCredit: 0,
        totalCollected: 0,
        totalCurrentBalance: 0,
      );

  _SnapshotTableTotals add(_DebtSnapshotRow row) {
    return _SnapshotTableTotals(
      totalDebit: totalDebit + row.debit,
      totalCredit: totalCredit + row.credit,
      totalCollected: totalCollected + row.totalCollected,
      totalCurrentBalance: totalCurrentBalance + row.currentBalance,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
