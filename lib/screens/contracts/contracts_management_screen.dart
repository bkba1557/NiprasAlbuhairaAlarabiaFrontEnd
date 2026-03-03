import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';

class _ContractTypeInfo {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _ContractTypeInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_ContractTypeInfo> _contractTypes = [
  _ContractTypeInfo(
    key: 'station',
    label: 'عقود المحطات',
    icon: Icons.local_gas_station,
    color: AppColors.primaryBlue,
  ),
  _ContractTypeInfo(
    key: 'rental',
    label: 'عقود الإيجارات',
    icon: Icons.home_work_outlined,
    color: AppColors.warningOrange,
  ),
  _ContractTypeInfo(
    key: 'vehicle',
    label: 'عقود السيارات',
    icon: Icons.directions_car_filled_outlined,
    color: AppColors.successGreen,
  ),
  _ContractTypeInfo(
    key: 'work',
    label: 'عقود العمل',
    icon: Icons.work_outline,
    color: AppColors.secondaryTeal,
  ),
];

class ContractsManagementScreen extends StatefulWidget {
  const ContractsManagementScreen({super.key});

  @override
  State<ContractsManagementScreen> createState() =>
      _ContractsManagementScreenState();
}

class _ContractsManagementScreenState
    extends State<ContractsManagementScreen> {
  bool _loading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _byType = {};
  List<Map<String, dynamic>> _all = [];
  Map<String, int> _statusCounts = {};
  Map<String, int> _companyCounts = {};
  double _totalValue = 0;
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
        _contractTypes.map((t) => _ContractsApi.list(t.key)),
      );

      final Map<String, List<Map<String, dynamic>>> byType = {};
      final List<Map<String, dynamic>> all = [];

      for (var i = 0; i < _contractTypes.length; i++) {
        final type = _contractTypes[i];
        final data = results[i];
        final items = (data['contracts'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        byType[type.key] = items;
        for (final item in items) {
          item['_type'] = type.key;
        }
        all.addAll(items);
      }

      final statusCounts = {
        'draft': 0,
        'active': 0,
        'expired': 0,
        'terminated': 0,
        'archived': 0,
      };
      for (final c in all) {
        final s = c['status']?.toString();
        if (s == null) continue;
        if (statusCounts.containsKey(s)) {
          statusCounts[s] = (statusCounts[s] ?? 0) + 1;
        }
      }

      final companyCounts = <String, int>{};
      for (final c in all) {
        final name = (c['counterpartyName'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        companyCounts[name] = (companyCounts[name] ?? 0) + 1;
      }

      final totalValue = all.fold<double>(
        0,
        (sum, c) =>
            sum +
            ((c['value'] is num)
                ? (c['value'] as num).toDouble()
                : double.tryParse('${c['value']}') ?? 0),
      );

      final recent = List<Map<String, dynamic>>.from(all);
      recent.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));

      if (!mounted) return;
      setState(() {
        _byType = byType;
        _all = all;
        _statusCounts = statusCounts;
        _companyCounts = companyCounts;
        _totalValue = totalValue;
        _recent = recent.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openTypeList(_ContractTypeInfo type) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ContractsTypeListScreen(
          contractType: type.key,
          title: type.label,
        ),
      ),
    );
  }

  Future<void> _openDetails(String id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _ContractDetailsScreen(contractId: id)),
    );
    if (changed == true) _load();
  }

  int _countForType(String key) => _byType[key]?.length ?? 0;

  DateTime _sortDate(Map<String, dynamic> c) {
    return _date(c['updatedAt']) ??
        _date(c['createdAt']) ??
        _date(c['startDate']) ??
        _date(c['endDate']) ??
        DateTime(1970);
  }

  _ContractTypeInfo _typeInfo(String? key) {
    for (final t in _contractTypes) {
      if (t.key == key) return t;
    }
    return const _ContractTypeInfo(
      key: 'other',
      label: 'العقود',
      icon: Icons.description_outlined,
      color: AppColors.primaryBlue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العقود'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'تعذر تحميل البيانات\n$_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildOverviewCard(context),
                      const SizedBox(height: 16),
                      _sectionTitle('إحصائيات العقود'),
                      const SizedBox(height: 10),
                      _buildStatsGrid(context),
                      const SizedBox(height: 16),
                      _sectionTitle('إحصائيات الشركات المتعاقدة'),
                      const SizedBox(height: 10),
                      _buildCompaniesCard(context),
                      const SizedBox(height: 16),
                      _sectionTitle('إجراءات العقود'),
                      const SizedBox(height: 10),
                      _buildActionsGrid(context),
                      const SizedBox(height: 16),
                      _sectionTitle('سجل العقود'),
                      const SizedBox(height: 10),
                      _buildRecentContracts(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: Colors.white, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'لوحة العقود',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'إجمالي العقود: ${_all.length} • إجمالي القيمة: ${_money(_totalValue, 'SAR')}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الشركات: ${_companyCounts.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final stats = [
      _StatCardData(
        label: 'إجمالي العقود',
        value: _all.length.toString(),
        icon: Icons.assignment_outlined,
        color: AppColors.primaryBlue,
      ),
      _StatCardData(
        label: 'عقود نشطة',
        value: (_statusCounts['active'] ?? 0).toString(),
        icon: Icons.play_circle_outline,
        color: AppColors.successGreen,
      ),
      _StatCardData(
        label: 'عقود منتهية',
        value: (_statusCounts['expired'] ?? 0).toString(),
        icon: Icons.event_busy,
        color: AppColors.warningOrange,
      ),
      _StatCardData(
        label: 'مسودات',
        value: (_statusCounts['draft'] ?? 0).toString(),
        icon: Icons.edit_note,
        color: AppColors.mediumGray,
      ),
      _StatCardData(
        label: 'الشركات المتعاقدة',
        value: _companyCounts.length.toString(),
        icon: Icons.apartment,
        color: AppColors.secondaryTeal,
      ),
      _StatCardData(
        label: 'إجمالي القيمة',
        value: _money(_totalValue, 'SAR'),
        icon: Icons.payments_outlined,
        color: AppColors.infoBlue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000 ? 3 : (width >= 620 ? 2 : 1);
        final itemWidth = (width - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map((s) => SizedBox(
                    width: itemWidth,
                    child: _statCard(s),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(_StatCardData data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: data.color,
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

  Widget _buildCompaniesCard(BuildContext context) {
    final entries = _companyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الشركات المتعاقدة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'العدد: ${_companyCounts.length}',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (top.isEmpty)
              const Text('لا توجد شركات متعاقدة بعد')
            else
              ...top.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.business_center_outlined),
                  title: Text(e.key),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${e.value} عقد',
                      style: const TextStyle(
                        color: AppColors.secondaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 2 : 1;
        final itemWidth = (width - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _contractTypes
              .map(
                (type) => SizedBox(
                  width: itemWidth,
                  child: _actionCard(type),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _actionCard(_ContractTypeInfo type) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, color: type.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عدد العقود: ${_countForType(type.key)}',
                    style: const TextStyle(color: AppColors.mediumGray),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _openTypeList(type),
              style: ElevatedButton.styleFrom(
                backgroundColor: type.color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('عرض'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentContracts(BuildContext context) {
    if (_recent.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد عقود بعد'),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recent.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = _recent[i];
          final type = _typeInfo(c['_type']?.toString() ?? c['contractType']);

          return ListTile(
            onTap: () => _openDetails(c['_id'].toString()),
            leading: CircleAvatar(
              backgroundColor: type.color.withOpacity(0.12),
              child: Icon(type.icon, color: type.color),
            ),
            title: Text(c['title']?.toString() ?? type.label),
            subtitle: Text(
              'رقم: ${c['contractNumber'] ?? '-'} | الطرف: ${c['counterpartyName'] ?? '-'}',
            ),
            trailing: _statusChip(c['status']),
          );
        },
      ),
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

Widget _statusChip(dynamic status) {
  final label = _statusLabel(status);
  Color color;
  switch ('$status') {
    case 'active':
      color = AppColors.successGreen;
      break;
    case 'expired':
      color = AppColors.warningOrange;
      break;
    case 'terminated':
      color = AppColors.errorRed;
      break;
    case 'archived':
      color = AppColors.mediumGray;
      break;
    case 'draft':
    default:
      color = AppColors.infoBlue;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _ContractsTypeListScreen extends StatefulWidget {
  final String contractType;
  final String title;
  const _ContractsTypeListScreen({
    required this.contractType,
    required this.title,
  });

  @override
  State<_ContractsTypeListScreen> createState() => _ContractsTypeListScreenState();
}

class _ContractsTypeListScreenState extends State<_ContractsTypeListScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ContractsApi.list(widget.contractType, q: _search.text.trim());
      final items = (data['contracts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? contract]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ContractEditorScreen(
          contractType: widget.contractType,
          categoryTitle: widget.title,
          contract: contract,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetails(String id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _ContractDetailsScreen(contractId: id)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العقد'),
        content: Text('تأكيد حذف العقد ${item['contractNumber'] ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ContractsApi.delete(item['_id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العقد')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  Future<void> _print(String id) async {
    try {
      await _ContractsApi.print(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز الطباعة')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الطباعة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => _openEditor(), icon: const Icon(Icons.add)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('عقد جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'بحث',
                      hintText: 'رقم العقد / الطرف المتعاقد',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _load, child: const Text('بحث')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('تعذر تحميل العقود\n$_error'))
                    : _items.isEmpty
                        ? const Center(child: Text('لا توجد عقود'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final c = _items[i];
                                return Card(
                                  child: ListTile(
                                    onTap: () => _openDetails(c['_id'].toString()),
                                    title: Text('${c['title'] ?? ''}'),
                                    subtitle: Text(
                                      'رقم: ${c['contractNumber'] ?? '-'} | الطرف: ${c['counterpartyName'] ?? '-'}\n'
                                      'الحالة: ${_statusLabel(c['status'])} | القيمة: ${_money(c['value'], c['currency'])}',
                                    ),
                                    isThreeLine: true,
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _openEditor(c);
                                        if (v == 'delete') _delete(c);
                                        if (v == 'print') _print(c['_id'].toString());
                                        if (v == 'details') _openDetails(c['_id'].toString());
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'details', child: Text('التفاصيل')),
                                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                        PopupMenuItem(value: 'print', child: Text('طباعة')),
                                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ContractEditorScreen extends StatefulWidget {
  final String contractType;
  final String categoryTitle;
  final Map<String, dynamic>? contract;
  const _ContractEditorScreen({
    required this.contractType,
    required this.categoryTitle,
    this.contract,
  });

  @override
  State<_ContractEditorScreen> createState() => _ContractEditorScreenState();
}

class _ContractEditorScreenState extends State<_ContractEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _title;
  late final TextEditingController _party;
  late final TextEditingController _contact;
  late final TextEditingController _value;
  late final TextEditingController _paymentTerms;
  late final TextEditingController _description;
  String _status = 'draft';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  bool get _isEdit => widget.contract != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _number = TextEditingController(text: c?['contractNumber']?.toString() ?? '');
    _title = TextEditingController(text: c?['title']?.toString() ?? '');
    _party = TextEditingController(text: c?['counterpartyName']?.toString() ?? '');
    _contact = TextEditingController(text: c?['counterpartyContact']?.toString() ?? '');
    _value = TextEditingController(text: c?['value']?.toString() ?? '');
    _paymentTerms = TextEditingController(text: c?['paymentTerms']?.toString() ?? '');
    _description = TextEditingController(text: c?['description']?.toString() ?? '');
    _status = c?['status']?.toString() ?? 'draft';
    _startDate = _date(c?['startDate']);
    _endDate = _date(c?['endDate']);
  }

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _party.dispose();
    _contact.dispose();
    _value.dispose();
    _paymentTerms.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => start ? _startDate = picked : _endDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'contractType': widget.contractType,
      'contractNumber': _number.text.trim(),
      'title': _title.text.trim(),
      'counterpartyName': _party.text.trim(),
      'counterpartyContact': _contact.text.trim(),
      'status': _status,
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'value': double.tryParse(_value.text.trim()) ?? 0,
      'currency': 'SAR',
      'paymentTerms': _paymentTerms.text.trim(),
      'description': _description.text.trim(),
    };
    try {
      if (_isEdit) {
        await _ContractsApi.update(widget.contract!['_id'].toString(), body);
      } else {
        await _ContractsApi.create(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل عقد' : 'إنشاء عقد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('النوع: ${widget.categoryTitle}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _field(_number, 'رقم العقد', required: true),
            const SizedBox(height: 10),
            _field(_title, 'عنوان العقد', required: true),
            const SizedBox(height: 10),
            _field(_party, 'الطرف المتعاقد', required: true),
            const SizedBox(height: 10),
            _field(_contact, 'بيانات التواصل'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                DropdownMenuItem(value: 'active', child: Text('نشط')),
                DropdownMenuItem(value: 'expired', child: Text('منتهي')),
                DropdownMenuItem(value: 'terminated', child: Text('مفسوخ')),
                DropdownMenuItem(value: 'archived', child: Text('مؤرشف')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'draft'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dateTile('بداية العقد', _startDate, () => _pickDate(true))),
                const SizedBox(width: 10),
                Expanded(child: _dateTile('نهاية العقد', _endDate, () => _pickDate(false))),
              ],
            ),
            const SizedBox(height: 10),
            _field(_value, 'قيمة العقد', keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _field(_paymentTerms, 'شروط الدفع', maxLines: 2),
            const SizedBox(height: 10),
            _field(_description, 'التفاصيل', maxLines: 4),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'حفظ التعديل' : 'إنشاء العقد'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _dateTile(String label, DateTime? d, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(d == null ? '-' : _dateText(d)),
      ),
    );
  }
}

class _ContractDetailsScreen extends StatefulWidget {
  final String contractId;
  const _ContractDetailsScreen({required this.contractId});

  @override
  State<_ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<_ContractDetailsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _contract;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ContractsApi.get(widget.contractId);
      if (!mounted) return;
      setState(() {
        _contract = Map<String, dynamic>.from(data['contract'] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _print() async {
    try {
      await _ContractsApi.print(widget.contractId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الطباعة')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الطباعة: $e')));
    }
  }

  Future<void> _edit() async {
    if (_contract == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ContractEditorScreen(
          contractType: _contract!['contractType']?.toString() ?? 'work',
          categoryTitle: _typeLabel(_contract!['contractType']),
          contract: _contract,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteContract() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العقد'),
        content: const Text('تأكيد حذف العقد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ContractsApi.delete(widget.contractId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  Future<void> _saveVoucher({Map<String, dynamic>? voucher}) async {
    final data = await _voucherDialog(voucher: voucher);
    if (data == null) return;
    try {
      if (voucher == null) {
        await _ContractsApi.addVoucher(widget.contractId, data);
      } else {
        await _ContractsApi.updateVoucher(widget.contractId, voucher['_id'].toString(), data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voucher == null ? 'تم إضافة سند أمر' : 'تم تحديث سند الأمر')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل العملية: $e')));
    }
  }

  Future<void> _deleteVoucher(Map<String, dynamic> voucher) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف سند أمر'),
        content: const Text('تأكيد حذف سند الأمر؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ContractsApi.deleteVoucher(widget.contractId, voucher['_id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف سند الأمر')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  Future<Map<String, dynamic>?> _voucherDialog({Map<String, dynamic>? voucher}) async {
    final formKey = GlobalKey<FormState>();
    final number = TextEditingController(text: voucher?['voucherNumber']?.toString() ?? '');
    final title = TextEditingController(text: voucher?['title']?.toString() ?? '');
    final amount = TextEditingController(text: voucher?['amount']?.toString() ?? '');
    final notes = TextEditingController(text: voucher?['notes']?.toString() ?? '');
    var status = voucher?['status']?.toString() ?? 'draft';
    DateTime date = _date(voucher?['issueDate']) ?? DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(voucher == null ? 'إضافة سند أمر' : 'تعديل سند أمر'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: number, decoration: const InputDecoration(labelText: 'رقم السند')),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                    ),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                        DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                        DropdownMenuItem(value: 'issued', child: Text('صادر')),
                        DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
                      ],
                      onChanged: (v) => setStateDialog(() => status = v ?? 'draft'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ السند'),
                      subtitle: Text(_dateText(date)),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setStateDialog(() => date = picked);
                      },
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, {
                  'voucherNumber': number.text.trim(),
                  'title': title.text.trim(),
                  'amount': double.tryParse(amount.text.trim()) ?? 0,
                  'status': status,
                  'issueDate': date.toIso8601String(),
                  'notes': notes.text.trim(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    number.dispose();
    title.dispose();
    amount.dispose();
    notes.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _contract == null) {
      return Scaffold(appBar: AppBar(title: const Text('تفاصيل العقد')), body: Center(child: Text('تعذر التحميل\n$_error')));
    }
    final c = _contract!;
    final vouchers = (c['orderVouchers'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(c['title']?.toString() ?? 'تفاصيل العقد'),
        actions: [
          IconButton(onPressed: _print, icon: const Icon(Icons.print_outlined)),
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: _deleteContract, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveVoucher(),
        icon: const Icon(Icons.assignment_add),
        label: const Text('سند أمر'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _infoCard('بيانات العقد', [
              _row('نوع العقد', _typeLabel(c['contractType'])),
              _row('رقم العقد', '${c['contractNumber'] ?? '-'}'),
              _row('الحالة', _statusLabel(c['status'])),
              _row('الطرف المتعاقد', '${c['counterpartyName'] ?? '-'}'),
              _row('التواصل', '${c['counterpartyContact'] ?? '-'}'),
              _row('القيمة', _money(c['value'], c['currency'])),
              _row('بداية العقد', _dateText(_date(c['startDate']))),
              _row('نهاية العقد', _dateText(_date(c['endDate']))),
              _row('بواسطة (إنشاء)', '${c['createdByName'] ?? '-'}'),
              _row('بواسطة (آخر تعديل)', '${c['updatedByName'] ?? '-'}'),
              _row('عدد مرات الطباعة', '${c['printCount'] ?? 0}'),
            ]),
            const SizedBox(height: 10),
            _infoCard('التفاصيل', [
              Text('شروط الدفع: ${c['paymentTerms'] ?? '-'}'),
              const SizedBox(height: 6),
              Text('الوصف: ${c['description'] ?? '-'}'),
            ]),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('سندات الأمر', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton.icon(
                          onPressed: () => _saveVoucher(),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة'),
                        ),
                      ],
                    ),
                    if (vouchers.isEmpty) const Text('لا توجد سندات أمر'),
                    ...vouchers.map(
                      (v) => Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: ListTile(
                          title: Text('${v['title'] ?? ''}'),
                          subtitle: Text(
                            'رقم السند: ${v['voucherNumber'] ?? '-'} | الحالة: ${_voucherStatus(v['status'])}\n'
                            'المبلغ: ${_money(v['amount'], c['currency'])} | التاريخ: ${_dateText(_date(v['issueDate']))}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (x) {
                              if (x == 'edit') _saveVoucher(voucher: v);
                              if (x == 'delete') _deleteVoucher(v);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                          ),
                        ),
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

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _ContractsApi {
  static Future<Map<String, dynamic>> list(String type, {String? q}) async {
    final qp = {'type': type, 'limit': '200', if ((q ?? '').isNotEmpty) 'q': q!};
    final r = await ApiService.get('/contracts?${Uri(queryParameters: qp).query}');
    return _json(r.bodyBytes);
  }

  static Future<Map<String, dynamic>> get(String id) async => _json((await ApiService.get('/contracts/$id')).bodyBytes);
  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async => _json((await ApiService.post('/contracts', body)).bodyBytes);
  static Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async => _json((await ApiService.put('/contracts/$id', body)).bodyBytes);
  static Future<Map<String, dynamic>> delete(String id) async => _json((await ApiService.delete('/contracts/$id')).bodyBytes);
  static Future<Map<String, dynamic>> print(String id) async => _json((await ApiService.post('/contracts/$id/print', {})).bodyBytes);
  static Future<Map<String, dynamic>> addVoucher(String id, Map<String, dynamic> body) async => _json((await ApiService.post('/contracts/$id/order-vouchers', body)).bodyBytes);
  static Future<Map<String, dynamic>> updateVoucher(String id, String voucherId, Map<String, dynamic> body) async => _json((await ApiService.put('/contracts/$id/order-vouchers/$voucherId', body)).bodyBytes);
  static Future<Map<String, dynamic>> deleteVoucher(String id, String voucherId) async => _json((await ApiService.delete('/contracts/$id/order-vouchers/$voucherId')).bodyBytes);

  static Map<String, dynamic> _json(List<int> bytes) => Map<String, dynamic>.from(json.decode(utf8.decode(bytes)) as Map);
}

String _typeLabel(dynamic type) {
  switch ('$type') {
    case 'work':
      return 'عقود العمل';
    case 'station':
      return 'عقود المحطات';
    case 'rental':
      return 'عقود الإيجارات';
    case 'vehicle':
      return 'عقود السيارات';
    default:
      return '$type';
  }
}

String _statusLabel(dynamic s) {
  switch ('$s') {
    case 'draft':
      return 'مسودة';
    case 'active':
      return 'نشط';
    case 'expired':
      return 'منتهي';
    case 'terminated':
      return 'مفسوخ';
    case 'archived':
      return 'مؤرشف';
    default:
      return '$s';
  }
}

String _voucherStatus(dynamic s) {
  switch ('$s') {
    case 'draft':
      return 'مسودة';
    case 'approved':
      return 'معتمد';
    case 'issued':
      return 'صادر';
    case 'cancelled':
      return 'ملغي';
    default:
      return '$s';
  }
}

DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());

String _dateText(DateTime? d) {
  if (d == null) return '-';
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _money(dynamic v, dynamic c) {
  final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  final code = (c == null || '$c'.trim().isEmpty) ? 'SAR' : '$c';
  return '${n.toStringAsFixed(2)} $code';
}
