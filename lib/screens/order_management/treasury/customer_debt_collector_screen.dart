import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/file_saver.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerDebtCollectorScreen extends StatefulWidget {
  const CustomerDebtCollectorScreen({super.key});

  @override
  State<CustomerDebtCollectorScreen> createState() =>
      _CustomerDebtCollectorScreenState();
}

class _CustomerDebtCollectorScreenState
    extends State<CustomerDebtCollectorScreen> {
  final NumberFormat _money = NumberFormat.currency(
    locale: 'ar',
    symbol: '',
    decimalDigits: 2,
  );
  final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd hh:mm a', 'ar');

  List<_DebtCustomer> _customers = const [];
  List<_BankAccount> _bankAccounts = const [];
  List<_DebtCollection> _collections = const [];
  List<_DepositRequest> _deposits = const [];
  List<_SettlementRequest> _settlements = const [];
  _CollectorDashboard? _dashboard;
  _CustomerLedger? _ledger;

  _DebtCustomer? _selectedCustomer;
  String _paymentMethod = 'cash';
  _BankAccount? _selectedBank;
  bool _loading = false;
  String? _error;
  DateTime? _selectedDate;
  PlatformFile? _depositAttachment;
  PlatformFile? _collectionReceiptAttachment;

  static const String _collectionsCacheKey =
      'customer_debt_collections_cache_v1';

  final TextEditingController _collectionAmountController =
      TextEditingController();
  final TextEditingController _collectionReferenceController =
      TextEditingController();
  final TextEditingController _collectionNotesController =
      TextEditingController();
  final TextEditingController _depositAmountController =
      TextEditingController();
  final TextEditingController _depositNotesController = TextEditingController();
  final TextEditingController _settlementAmountController =
      TextEditingController();
  final TextEditingController _settlementNotesController =
      TextEditingController();
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  final TextEditingController _bankAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _collectionAmountController.dispose();
    _collectionReferenceController.dispose();
    _collectionNotesController.dispose();
    _depositAmountController.dispose();
    _depositNotesController.dispose();
    _settlementAmountController.dispose();
    _settlementNotesController.dispose();
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _bankAmountController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getJson(String endpoint) async {
    final response = await ApiService.get(endpoint);
    return ApiService.decodeJsonMap(response);
  }

  String _dateQuery() => _selectedDate == null
      ? ''
      : '?date=${DateFormat('yyyy-MM-dd').format(_selectedDate!)}';

  Future<void> _loadAll() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _loadCustomers(),
        _loadBankAccounts(),
        _loadDashboard(),
        _loadCollections(),
        _loadDeposits(),
        _loadSettlements(),
      ]);
      if (_selectedCustomer == null && _customers.isNotEmpty) {
        _selectedCustomer = _customers.first;
      }
      if (_selectedCustomer != null) {
        await _loadLedger(_selectedCustomer!.accountNumber);
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _loadBankAccounts() async {
    final decoded = await _getJson('/customer-debts/bank-accounts');
    final list = decoded['bankAccounts'] as List<dynamic>? ?? const [];
    _bankAccounts = list
        .whereType<Map>()
        .map((item) => _BankAccount.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    _selectedBank ??= _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
  }

  Future<void> _loadDashboard() async {
    final decoded = await _getJson('/customer-debts/collector/dashboard');
    final raw = decoded['dashboard'];
    if (raw is Map<String, dynamic>) {
      _dashboard = _CollectorDashboard.fromJson(raw);
    } else if (raw is Map) {
      _dashboard = _CollectorDashboard.fromJson(Map<String, dynamic>.from(raw));
    }
  }

  Future<void> _loadCollections() async {
    // Always fetch without date filter to keep older collection records visible
    // even after finance uploads a new statement/snapshot.
    final decoded = await _getJson('/customer-debts/collections');
    final list = decoded['collections'] as List<dynamic>? ?? const [];

    final fetched = list
        .whereType<Map>()
        .map(
          (item) => _DebtCollection.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    final merged = await _mergeCollectionsCache(fetched);
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_selectedDate == null) {
      _collections = merged;
      return;
    }

    final filterDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );

    _collections = merged.where((item) {
      final local = item.createdAt.toLocal();
      final itemDate = DateTime(local.year, local.month, local.day);
      return itemDate == filterDate;
    }).toList();
  }

  Future<List<_DebtCollection>> _mergeCollectionsCache(
    List<_DebtCollection> fetched,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_collectionsCacheKey) ?? '';

    final cached = <_DebtCollection>[];
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              cached.add(_DebtCollection.fromJson(item));
            } else if (item is Map) {
              cached.add(
                _DebtCollection.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      } catch (_) {
        // Ignore corrupted cache.
      }
    }

    final mergedByKey = <String, _DebtCollection>{};
    for (final item in [...cached, ...fetched]) {
      mergedByKey[item.cacheKey] = item;
    }

    final merged = mergedByKey.values.toList();

    // Keep cache reasonably small.
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = merged.length > 500 ? merged.take(500).toList() : merged;

    await prefs.setString(
      _collectionsCacheKey,
      json.encode(trimmed.map((e) => e.toJson()).toList()),
    );

    return trimmed;
  }

  Future<void> _loadDeposits() async {
    final decoded = await _getJson('/customer-debts/deposits');
    final list = decoded['deposits'] as List<dynamic>? ?? const [];
    _deposits = list
        .whereType<Map>()
        .map(
          (item) => _DepositRequest.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> _loadSettlements() async {
    final decoded = await _getJson('/customer-debts/settlements');
    final list = decoded['settlements'] as List<dynamic>? ?? const [];
    _settlements = list
        .whereType<Map>()
        .map(
          (item) =>
              _SettlementRequest.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> _loadLedger(String accountNumber) async {
    final decoded = await _getJson(
      '/customer-debts/customers/$accountNumber/ledger',
    );
    final raw = decoded['ledger'];
    if (raw is Map<String, dynamic>) {
      setState(() => _ledger = _CustomerLedger.fromJson(raw));
    } else if (raw is Map) {
      setState(
        () =>
            _ledger = _CustomerLedger.fromJson(Map<String, dynamic>.from(raw)),
      );
    }
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
    await _loadCollections();
  }

  Future<void> _selectCustomer(_DebtCustomer customer) async {
    setState(() => _selectedCustomer = customer);
    await _loadLedger(customer.accountNumber);
  }

  Future<void> _showCustomerPicker() async {
    final picked = await showModalBottomSheet<_DebtCustomer>(
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
            final filteredCustomers = _customers.where((customer) {
              final haystack =
                  '${customer.customerName} ${customer.accountNumber}'
                      .toLowerCase();
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
                      'اختيار العميل',
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
                        hintText: 'ابحث باسم العميل أو رقم الحساب',
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
                    Flexible(
                      child: filteredCustomers.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('لا يوجد عميل مطابق للبحث'),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredCustomers.length,
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = filteredCustomers[index];
                                final selected =
                                    customer.accountNumber ==
                                    _selectedCustomer?.accountNumber;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryBlue
                                        .withValues(alpha: 0.10),
                                    child: const Icon(
                                      Icons.person_search_rounded,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  title: Text(
                                    customer.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(customer.accountNumber),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.successGreen,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(context, customer),
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
      await _selectCustomer(picked);
    }
  }

Future<void> _submitCollection() async {
  if (_selectedCustomer == null) return;

  final cashAmount = _parseAmount(_cashAmountController.text);
  final cardAmount = _parseAmount(_cardAmountController.text);
  final bankAmount = _parseAmount(_bankAmountController.text);

  if (cashAmount < 0 || cardAmount < 0 || bankAmount < 0) {
    setState(() => _error = 'لا يمكن إدخال مبلغ بالسالب');
    return;
  }

  final totalAmount = cashAmount + cardAmount + bankAmount;

  if (totalAmount <= 0) {
    setState(() => _error = 'أدخل مبلغ تحصيل واحد على الأقل');
    return;
  }

  if (bankAmount > 0 && _collectionReferenceController.text.trim().isEmpty) {
   setState(
     () => _error = 'ادخل اسم المحول / المرجع للتحويل',
   );
   return;
 }

  final payload = <String, dynamic>{
    'customerAccountNumber': _selectedCustomer!.accountNumber,
    'cashAmount': cashAmount,
    'cardAmount': cardAmount,
    'bankTransferAmount': bankAmount,
    'bankAccountId': bankAmount > 0 ? _selectedBank?.id : null,
    'bankName': bankAmount > 0 ? _selectedBank?.bankName : '',
    'referenceName': _collectionReferenceController.text.trim(),
    'notes': _collectionNotesController.text.trim(),
  };

  if (_collectionReceiptAttachment == null) {
    await ApiService.post('/customer-debts/collections/split', payload);
  } else {
    await ApiService.loadToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiEndpoints.baseUrl}/customer-debts/collections/split'),
    );
    final authorization = ApiService.headers['Authorization'];
    if (authorization != null && authorization.isNotEmpty) {
      request.headers['Authorization'] = authorization;
    }
    payload.forEach((key, value) {
      if (value == null) return;
      request.fields[key] = value.toString();
    });
    request.files.add(
      http.MultipartFile.fromBytes(
        'receipt',
        _collectionReceiptAttachment!.bytes!,
        filename: _collectionReceiptAttachment!.name,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل تسجيل التحصيل');
    }
  }

  _cashAmountController.clear();
  _cardAmountController.clear();
  _bankAmountController.clear();
  _collectionReferenceController.clear();
  _collectionNotesController.clear();
  _collectionReceiptAttachment = null;

  await _loadAll();
}

double _parseAmount(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  return double.tryParse(normalized) ?? 0;
}

    Future<void> _exportCollections({required String format}) async {
    try {
      final date = _selectedDate ?? DateTime.now();
      final dateOnly = DateFormat('yyyy-MM-dd').format(date);

      final query =
          'reportType=customer_debt_collections&startDate=$dateOnly&endDate=$dateOnly';
      final endpoint = format == 'pdf'
          ? '/reports/export/pdf?$query'
          : '/reports/export/excel?$query';

      final response = await ApiService.download(endpoint);
      final fileStamp = DateTime.now().millisecondsSinceEpoch;
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      await saveAndLaunchFile(
        response.bodyBytes,
        'collections_${dateOnly}_$fileStamp.$ext',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير الملف')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _exportCustomerLedger({required String format}) async {
    try {
      final customer = _selectedCustomer;
      if (customer == null) return;

      final query =
          'reportType=customer_debt_ledger&customerAccountNumber=${Uri.encodeComponent(customer.accountNumber)}';
      final endpoint = format == 'pdf'
          ? '/reports/export/pdf?$query'
          : '/reports/export/excel?$query';

      final response = await ApiService.download(endpoint);
      final fileStamp = DateTime.now().millisecondsSinceEpoch;
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      await saveAndLaunchFile(
        response.bodyBytes,
        'ledger_${customer.accountNumber}_$fileStamp.$ext',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير الملف')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
  Future<void> _pickDepositAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _depositAttachment = result.files.single);
  }

  Future<void> _pickCollectionReceiptAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) return;
    setState(() => _collectionReceiptAttachment = file);
  }

  Future<void> _previewCollectionReceiptAttachment() async {
    final file = _collectionReceiptAttachment;
    if (file?.bytes == null || file!.bytes!.isEmpty) return;
    await saveAndLaunchFile(
      file.bytes!,
      file.name.isNotEmpty ? file.name : 'receipt_attachment',
    );
  }

  Future<void> _submitDeposit() async {
    final amount = double.tryParse(_depositAmountController.text.trim());
    if (amount == null || amount <= 0 || _selectedBank == null) {
      setState(() => _error = 'بيانات الإيداع غير مكتملة');
      return;
    }

    await ApiService.loadToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiEndpoints.baseUrl}/customer-debts/deposits'),
    );
    final authorization = ApiService.headers['Authorization'];
    if (authorization != null && authorization.isNotEmpty) {
      request.headers['Authorization'] = authorization;
    }
    request.fields['amount'] = amount.toString();
    request.fields['bankAccountId'] = _selectedBank!.id;
    request.fields['notes'] = _depositNotesController.text.trim();

    if (_depositAttachment?.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          _depositAttachment!.bytes!,
          filename: _depositAttachment!.name,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل إرسال طلب الإيداع');
    }

    _depositAmountController.clear();
    _depositNotesController.clear();
    _depositAttachment = null;
    await _loadAll();
  }

  Future<void> _submitSettlement() async {
    final amount = double.tryParse(_settlementAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'مبلغ التصفية غير صالح');
      return;
    }

    await ApiService.post('/customer-debts/settlements', {
      'amount': amount,
      'notes': _settlementNotesController.text.trim(),
    });

    _settlementAmountController.clear();
    _settlementNotesController.clear();
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideScreen = width >= 1100;
    final contentMaxWidth = width >= 1600 ? 1500.0 : 1280.0;
    final horizontalPadding = width >= 1400
        ? 24.0
        : width >= 900
        ? 20.0
        : 16.0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
      appBar: AppBar(
  centerTitle: true,
  elevation: 0,
  scrolledUnderElevation: 0,
  backgroundColor: AppColors.primaryBlue,
  foregroundColor: Colors.white,
  toolbarHeight: isWideScreen ? 62 : 54,

  title: Text(
    'التحصيل',
    style: TextStyle(
      fontSize: isWideScreen ? 24 : 19,
      fontWeight: FontWeight.w900,
    ),
  ),

  // ✅ زر تسجيل الخروج
  actions: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          if (value == 'logout') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('تسجيل الخروج'),
                content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              // 👇 استدعاء اللوج أوت الحقيقي من AuthProvider
              final auth = context.read<AuthProvider>();
              await auth.logout();

              if (!context.mounted) return;

              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('تسجيل الخروج'),
              ],
            ),
          ),
        ],
      ),
    ),
  ],

  bottom: PreferredSize(
    preferredSize: Size.fromHeight(isWideScreen ? 108 : 96),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        8,
        horizontalPadding,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildToolbarAction(
                icon: Icons.refresh_rounded,
                label: 'تحديث',
                onTap: _loading ? null : _loadAll,
              ),
              _buildToolbarAction(
                icon: Icons.calendar_month_rounded,
                label: 'تاريخ السجلات',
                onTap: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: isWideScreen ? 50 : 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.10),
              ),
            ),
            child: TabBar(
              isScrollable: false,
              indicatorSize: TabBarIndicatorSize.tab,
              splashBorderRadius: BorderRadius.circular(15),
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              tabs: const [
                Tab(
                  height: 38,
                  iconMargin: EdgeInsets.only(bottom: 1),
                  icon: Icon(Icons.payments_outlined, size: 17),
                  text: 'تحصيل',
                ),
                Tab(
                  height: 38,
                  iconMargin: EdgeInsets.only(bottom: 1),
                  icon: Icon(Icons.receipt_long_outlined, size: 17),
                  text: 'السجلات',
                ),
                Tab(
                  height: 38,
                  iconMargin: EdgeInsets.only(bottom: 1),
                  icon: Icon(Icons.manage_search_rounded, size: 17),
                  text: 'استعلام',
                ),
                Tab(
                  height: 38,
                  iconMargin: EdgeInsets.only(bottom: 1),
                  icon: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 17,
                  ),
                  text: 'الإيداع',
                ),
              ],
            ),
          ),
        ],
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
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            16,
                            horizontalPadding,
                            0,
                          ),
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
                            _buildCollectTab(horizontalPadding),
                            _buildRecordsTab(horizontalPadding),
                            _buildInquiryTab(horizontalPadding),
                            _buildCashTab(horizontalPadding),
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
  }) {
    return Material(
      color: AppColors.primaryBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 1100 ? 980.0 : double.infinity;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                20,
              ),
              children: children,
            ),
          ),
        );
      },
    );
  }

  InputDecoration _tightInputDecoration({
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildCustomerPickerField({
    required String label,
    required _DebtCustomer? customer,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customer?.displayName ?? 'اختر العميل',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: customer == null ? Colors.black45 : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectTab(double horizontalPadding) {
    final currentCustomer = _selectedCustomer;
    final currentBalance = currentCustomer?.currentBalance ?? 0;
    final cashAmount = double.tryParse(_cashAmountController.text.trim()) ?? 0;
    final cardAmount = double.tryParse(_cardAmountController.text.trim()) ?? 0;
    final bankAmount = double.tryParse(_bankAmountController.text.trim()) ?? 0;
    final amount = cashAmount + cardAmount + bankAmount;
    final remaining = currentBalance - amount;

    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerPickerField(
                label: 'اختر العميل',
                customer: currentCustomer,
                onTap: _customers.isEmpty ? () {} : _showCustomerPicker,
              ),
              const SizedBox(height: 16),
              _featuredBalanceCard(
                title: 'مديونية العميل الحالية',
                value: _formatMoney(currentBalance),
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cashAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: _tightInputDecoration(
                  labelText: 'مبلغ الكاش',
                  prefixIcon: Icons.money_outlined,
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _cardAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: _tightInputDecoration(
                  labelText: 'مبلغ الشبكة',
                  prefixIcon: Icons.credit_card_outlined,
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _bankAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: _tightInputDecoration(
                  labelText: 'مبلغ التحويل البنكي',
                  prefixIcon: Icons.account_balance_outlined,
                ),
                onChanged: (_) => setState(() {}),
              ),

              if ((double.tryParse(_bankAmountController.text.trim()) ?? 0) >
                  0) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<_BankAccount>(
                  initialValue: _selectedBank,
                  decoration: _tightInputDecoration(
                    labelText: 'الحساب البنكي',
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  items: _bankAccounts
                      .map(
                        (item) => DropdownMenuItem<_BankAccount>(
                          value: item,
                          child: Text(item.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBank = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _collectionReferenceController,
                  decoration: _tightInputDecoration(
                    labelText: 'اسم المرجع / اسم المحول',
                    prefixIcon: Icons.badge_outlined,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: _tightInputDecoration(
                  labelText: 'طريقة التحصيل',
                  prefixIcon: Icons.tune_rounded,
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('كاش')),
                  DropdownMenuItem(value: 'card', child: Text('شبكة')),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('تحويل بنكي'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _paymentMethod = value ?? 'cash');
                },
              ),
              if (_paymentMethod == 'bank_transfer') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<_BankAccount>(
                  initialValue: _selectedBank,
                  decoration: _tightInputDecoration(
                    labelText: 'الحساب البنكي',
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  items: _bankAccounts
                      .map(
                        (item) => DropdownMenuItem<_BankAccount>(
                          value: item,
                          child: Text(item.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBank = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _collectionReferenceController,
                  decoration: _tightInputDecoration(
                    labelText: 'اسم المرجع / اسم المحول',
                    prefixIcon: Icons.badge_outlined,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _collectionNotesController,
                maxLines: 2,
                decoration: _tightInputDecoration(
                  labelText: 'ملاحظات',
                ).copyWith(alignLabelWithHint: true),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickCollectionReceiptAttachment,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'إرفاق سند القبض',
                    prefixIcon: const Icon(Icons.attach_file),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    suffixIcon: _collectionReceiptAttachment == null
                        ? const Icon(Icons.add_circle_outline)
                        : IconButton(
                            tooltip: 'إزالة المرفق',
                            onPressed: () =>
                                setState(() => _collectionReceiptAttachment = null),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  child: Text(
                    _collectionReceiptAttachment?.name ?? 'اختياري (PDF / صورة)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_collectionReceiptAttachment != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _previewCollectionReceiptAttachment,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('عرض السند'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _summaryCard('تم الخصم', _formatMoney(amount)),
                  _summaryCard('المتبقي', _formatMoney(remaining)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: currentCustomer == null ? null : _submitCollection,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسجيل التحصيل'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsTab(double horizontalPadding) {
    final totals = _collections.fold<_CollectionTotals>(
      _CollectionTotals.zero(),
      (acc, item) => acc.add(item),
    );
    final balanceByAccount = <String, double>{
      for (final customer in _customers)
        customer.accountNumber: customer.currentBalance,
    };

    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryCard('إجمالي التحصيل', _formatMoney(totals.total)),
            _summaryCard('نقدي', _formatMoney(totals.cash)),
            _summaryCard('شبكة', _formatMoney(totals.card)),
            _summaryCard('تحويل بنكي', _formatMoney(totals.bankTransfer)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _exportCollections(format: 'pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('تصدير PDF'),
            ),
            FilledButton.icon(
              onPressed: () => _exportCollections(format: 'excel'),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('تصدير Excel'),
            ),
            if (_selectedCustomer != null)
              OutlinedButton.icon(
                onPressed: () => _exportCustomerLedger(format: 'pdf'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('حركة العميل PDF'),
              ),
            if (_selectedCustomer != null)
              OutlinedButton.icon(
                onPressed: () => _exportCustomerLedger(format: 'excel'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('حركة العميل Excel'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: _collections.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا توجد سجلات'),
                    ),
                  ]
                : _collections
                      .map(
                        (item) {
                          final currentBalance =
                              balanceByAccount[item.customerAccountNumber];
                          final remainingDue = (currentBalance ?? item.remainingAfter) > 0
                              ? (currentBalance ?? item.remainingAfter)
                              : 0.0;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.customerName),
                            isThreeLine:
                                item.customerAccountNumber.isNotEmpty &&
                                balanceByAccount.containsKey(
                                  item.customerAccountNumber,
                                ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_paymentMethodLabel(item.paymentMethod)} \u2022 ${_dateTimeFormat.format(item.createdAt.toLocal())}',
                                ),
                                if (item.customerAccountNumber.isNotEmpty &&
                                    balanceByAccount.containsKey(
                                      item.customerAccountNumber,
                                    ))
                                  Text(
                                    '${'\u0627\u0644\u0631\u0635\u064a\u062f \u0627\u0644\u062d\u0627\u0644\u064a'} ${_formatMoney(currentBalance ?? 0)}',
                                    style: TextStyle(
                                      color: Colors.black.withValues(alpha: 0.58),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.hasReceiptAttachment)
                                  IconButton(
                                    tooltip: 'عرض سند القبض',
                                    onPressed: () => _openReceiptAttachment(item),
                                    icon: const Icon(Icons.attach_file),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _MoneyValue(text: _formatMoney(item.amount)),
                                    Text(
                                      '${'\u0645\u062a\u0628\u0642\u064a'} ${_formatMoney(remainingDue)}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )
                      .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInquiryTab(double horizontalPadding) {
    final ledger = _ledger;
    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerPickerField(
                label: 'اختيار العميل',
                customer: _selectedCustomer,
                onTap: _customers.isEmpty ? () {} : _showCustomerPicker,
              ),
              const SizedBox(height: 16),
              if (ledger != null) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summaryCard(
                      'الرصيد الافتتاحي',
                      _formatMoney(ledger.openingBalance),
                    ),
                    _summaryCard('المحصل', _formatMoney(ledger.totalCollected)),
                    _summaryCard(
                      'الرصيد الحالي',
                      _formatMoney(ledger.currentBalance),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...ledger.collections.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.customerName),
                    subtitle: Text(
                      '${_paymentMethodLabel(item.paymentMethod)} • ${item.collectorName} • ${_dateTimeFormat.format(item.createdAt.toLocal())}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.hasReceiptAttachment)
                          IconButton(
                            tooltip: 'عرض سند القبض',
                            onPressed: () => _openReceiptAttachment(item),
                            icon: const Icon(Icons.attach_file),
                          ),
                        _MoneyValue(text: _formatMoney(item.amount)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _resolveFileUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/uploads')) {
      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/+$'), '');
      return '$base$path';
    }
    return '${ApiEndpoints.baseUrl}$path';
  }

  Future<void> _openReceiptAttachment(_DebtCollection item) async {
    final receiptPath = item.receiptAttachmentPath.trim();
    if (receiptPath.isEmpty) return;
    final uri = Uri.tryParse(_resolveFileUrl(receiptPath));
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المرفق')),
      );
    }
  }

  Widget _buildCashTab(double horizontalPadding) {
    final cashBox = _dashboard?.cashBox ?? _CashBox.zero();
    return _buildResponsiveListView(
      horizontalPadding: horizontalPadding,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryCard('المحصل نقداً', _formatMoney(cashBox.collected)),
            _summaryCard('تم إيداعه', _formatMoney(cashBox.deposited)),
            _summaryCard('تمت تصفيته', _formatMoney(cashBox.settled)),
            _summaryCard('المتبقي عليك', _formatMoney(cashBox.outstanding)),
          ],
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إيداع نقدي',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<_BankAccount>(
                initialValue: _selectedBank,
                decoration: const InputDecoration(labelText: 'الحساب البنكي'),
                items: _bankAccounts
                    .map(
                      (item) => DropdownMenuItem<_BankAccount>(
                        value: item,
                        child: Text(item.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedBank = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _depositAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مبلغ الإيداع'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _depositNotesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDepositAttachment,
                icon: const Icon(Icons.attach_file_outlined),
                label: Text(
                  _depositAttachment == null
                      ? 'إرفاق صورة'
                      : _depositAttachment!.name,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitDeposit,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('إرسال طلب الإيداع'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'طلب تصفية يومية',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _settlementAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مبلغ التصفية'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _settlementNotesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitSettlement,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('إرسال طلب التصفية'),
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
                'سجلات الإيداع والتصفية',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              ..._deposits.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('إيداع ${item.bankName}'),
                  subtitle: Text(item.statusLabel),
                  trailing: _MoneyValue(text: _formatMoney(item.amount)),
                ),
              ),
              ..._settlements.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تصفية يومية'),
                  subtitle: Text(item.statusLabel),
                  trailing: _MoneyValue(text: _formatMoney(item.amount)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 280),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _MoneyValue(text: value),
          ],
        ),
      ),
    );
  }

  Widget _featuredBalanceCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _MoneyValue(text: value, fontSize: 18),
              ],
            ),
          ),
        ],
      ),
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
  const _MoneyValue({required this.text, this.fontSize = 16});

  final String text;
  final double fontSize;

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
          ).copyWith(fontSize: fontSize),
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

class _BankAccount {
  _BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
  });

  final String id;
  final String bankName;
  final String accountName;

  String get displayName => '$bankName - $accountName';

  factory _BankAccount.fromJson(Map<String, dynamic> json) {
    return _BankAccount(
      id: json['id']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
    );
  }
}

class _DebtCollection {
  _DebtCollection({
    required this.customerAccountNumber,
    required this.customerName,
    required this.amount,
    required this.paymentMethod,
    required this.collectorName,
    required this.remainingAfter,
    required this.createdAt,
    required this.receiptAttachmentPath,
    required this.receiptAttachmentName,
  });

  final String customerAccountNumber;
  final String customerName;
  final double amount;
  final String paymentMethod;
  final String collectorName;
  final double remainingAfter;
  final DateTime createdAt;
  final String receiptAttachmentPath;
  final String receiptAttachmentName;

  bool get hasReceiptAttachment => receiptAttachmentPath.trim().isNotEmpty;

  String get cacheKey =>
      '$customerAccountNumber|$customerName|$amount|$paymentMethod|$collectorName|${createdAt.toIso8601String()}';

  factory _DebtCollection.fromJson(Map<String, dynamic> json) {
    final receiptAttachment = json['receiptAttachment'] is Map
        ? Map<String, dynamic>.from(json['receiptAttachment'])
        : const <String, dynamic>{};

    return _DebtCollection(
      customerAccountNumber:
          json['customerAccountNumber']?.toString() ??
          json['accountNumber']?.toString() ??
          '',
      customerName: json['customerName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      collectorName: json['collectorName']?.toString() ?? '',
      remainingAfter: _asDouble(json['remainingAfter']),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      receiptAttachmentPath: receiptAttachment['path']?.toString() ?? '',
      receiptAttachmentName: receiptAttachment['filename']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerAccountNumber': customerAccountNumber,
      'customerName': customerName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'collectorName': collectorName,
      'remainingAfter': remainingAfter,
      'createdAt': createdAt.toIso8601String(),
      'receiptAttachment': {
        'path': receiptAttachmentPath,
        'filename': receiptAttachmentName,
      },
    };
  }
}

class _DepositRequest {
  _DepositRequest({
    required this.amount,
    required this.bankName,
    required this.status,
  });

  final double amount;
  final String bankName;
  final String status;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'تم الاعتماد';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'تحت المراجعة';
    }
  }

  factory _DepositRequest.fromJson(Map<String, dynamic> json) {
    return _DepositRequest(
      amount: _asDouble(json['amount']),
      bankName: json['bankName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class _SettlementRequest {
  _SettlementRequest({required this.amount, required this.status});

  final double amount;
  final String status;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'تم الاعتماد';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'تحت المراجعة';
    }
  }

  factory _SettlementRequest.fromJson(Map<String, dynamic> json) {
    return _SettlementRequest(
      amount: _asDouble(json['amount']),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class _CollectorDashboard {
  _CollectorDashboard({required this.cashBox});

  final _CashBox cashBox;

  factory _CollectorDashboard.fromJson(Map<String, dynamic> json) {
    return _CollectorDashboard(
      cashBox: _CashBox.fromJson(
        json['cashBox'] is Map
            ? Map<String, dynamic>.from(json['cashBox'] as Map)
            : <String, dynamic>{},
      ),
    );
  }
}

class _CashBox {
  _CashBox({
    required this.collected,
    required this.deposited,
    required this.settled,
    required this.outstanding,
  });

  final double collected;
  final double deposited;
  final double settled;
  final double outstanding;

  factory _CashBox.zero() =>
      _CashBox(collected: 0, deposited: 0, settled: 0, outstanding: 0);

  factory _CashBox.fromJson(Map<String, dynamic> json) {
    return _CashBox(
      collected: _asDouble(json['collected']),
      deposited: _asDouble(json['deposited']),
      settled: _asDouble(json['settled']),
      outstanding: _asDouble(json['outstanding']),
    );
  }
}

class _CustomerLedger {
  _CustomerLedger({
    required this.openingBalance,
    required this.totalCollected,
    required this.currentBalance,
    required this.collections,
  });

  final double openingBalance;
  final double totalCollected;
  final double currentBalance;
  final List<_DebtCollection> collections;

  factory _CustomerLedger.fromJson(Map<String, dynamic> json) {
    return _CustomerLedger(
      openingBalance: _asDouble(json['openingBalance']),
      totalCollected: _asDouble(json['totalCollected']),
      currentBalance: _asDouble(json['currentBalance']),
      collections: (json['collections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => _DebtCollection.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
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

  factory _CollectionTotals.zero() =>
      _CollectionTotals(total: 0, cash: 0, card: 0, bankTransfer: 0);

  _CollectionTotals add(_DebtCollection item) {
    return _CollectionTotals(
      total: total + item.amount,
      cash: cash + (item.paymentMethod == 'cash' ? item.amount : 0),
      card: card + (item.paymentMethod == 'card' ? item.amount : 0),
      bankTransfer:
          bankTransfer +
          (item.paymentMethod == 'bank_transfer' ? item.amount : 0),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

