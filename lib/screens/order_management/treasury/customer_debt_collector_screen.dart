import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

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
    final decoded = await _getJson(
      '/customer-debts/collections${_dateQuery()}',
    );
    final list = decoded['collections'] as List<dynamic>? ?? const [];
    _collections = list
        .whereType<Map>()
        .map(
          (item) => _DebtCollection.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
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
    final amount = double.tryParse(_collectionAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغ تحصيل صحيح');
      return;
    }

    await ApiService.post('/customer-debts/collections', {
      'customerAccountNumber': _selectedCustomer!.accountNumber,
      'amount': amount,
      'paymentMethod': _paymentMethod,
      'bankAccountId': _paymentMethod == 'bank_transfer'
          ? _selectedBank?.id
          : null,
      'bankName': _paymentMethod == 'bank_transfer'
          ? _selectedBank?.bankName
          : '',
      'referenceName': _collectionReferenceController.text.trim(),
      'notes': _collectionNotesController.text.trim(),
    });

    _collectionAmountController.clear();
    _collectionReferenceController.clear();
    _collectionNotesController.clear();
    await _loadAll();
  }

  Future<void> _pickDepositAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _depositAttachment = result.files.single);
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
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.14,
                            ),
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
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        20,
        horizontalPadding,
        24,
      ),
      children: children,
    );
  }

  Widget _buildCustomerPickerField({
    required String label,
    required _DebtCustomer? customer,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
    final amount =
        double.tryParse(_collectionAmountController.text.trim()) ?? 0;
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
                controller: _collectionAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'مبلغ التحصيل',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: InputDecoration(
                  labelText: 'طريقة التحصيل',
                  prefixIcon: const Icon(Icons.tune_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<_BankAccount>(
                  initialValue: _selectedBank,
                  decoration: InputDecoration(
                    labelText: 'الحساب البنكي',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _collectionReferenceController,
                  decoration: InputDecoration(
                    labelText: 'اسم المرجع / اسم المحول',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _collectionNotesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظات',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
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
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.customerName),
                          subtitle: Text(
                            '${_paymentMethodLabel(item.paymentMethod)} • ${_dateTimeFormat.format(item.createdAt.toLocal())}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _MoneyValue(text: _formatMoney(item.amount)),
                              Text(
                                'متبقي ${_formatMoney(item.remainingAfter)}',
                              ),
                            ],
                          ),
                        ),
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
                    trailing: _MoneyValue(text: _formatMoney(item.amount)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
    required this.customerName,
    required this.amount,
    required this.paymentMethod,
    required this.collectorName,
    required this.remainingAfter,
    required this.createdAt,
  });

  final String customerName;
  final double amount;
  final String paymentMethod;
  final String collectorName;
  final double remainingAfter;
  final DateTime createdAt;

  factory _DebtCollection.fromJson(Map<String, dynamic> json) {
    return _DebtCollection(
      customerName: json['customerName']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      collectorName: json['collectorName']?.toString() ?? '',
      remainingAfter: _asDouble(json['remainingAfter']),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
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
