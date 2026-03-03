import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/custody_document_model.dart';
import 'package:order_tracker/providers/custody_document_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:provider/provider.dart';

class CustodyDashboardScreen extends StatefulWidget {
  const CustodyDashboardScreen({super.key});

  @override
  State<CustodyDashboardScreen> createState() =>
      _CustodyDashboardScreenState();
}

class _CustodyDashboardScreenState extends State<CustodyDashboardScreen> {
  String? _selectedMonthKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustodyDocumentProvider>().refreshDocuments();
    });
  }

  String _monthKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    return DateFormat('MMMM yyyy', 'ar').format(DateTime(year, month));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustodyDocumentProvider>();
    final documents = provider.documents;
    final currency = NumberFormat.currency(
      locale: 'ar',
      symbol: 'ر.س',
      decimalDigits: 2,
    );

    final totalAll = documents.fold<double>(
      0,
      (sum, doc) => sum + doc.amount,
    );
    final totalApproved = documents
        .where((doc) => doc.status == CustodyDocumentStatus.approved)
        .fold<double>(0, (sum, doc) => sum + doc.amount);
    final totalReturnedApproved = documents
        .where((doc) => doc.returnStatus == CustodyReturnStatus.approved)
        .fold<double>(0, (sum, doc) => sum + doc.returnAmount);
    final balance = totalApproved - totalReturnedApproved;

    final Map<String, List<CustodyDocument>> monthGroups = {};
    for (final doc in documents) {
      final key = _monthKey(doc.documentDate);
      monthGroups.putIfAbsent(key, () => []).add(doc);
    }
    final monthKeys = monthGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final selectedKey = _selectedMonthKey;
    final filteredDocuments = selectedKey == null
        ? documents
        : (monthGroups[selectedKey] ?? []);

    final selectedTotal = filteredDocuments.fold<double>(
      0,
      (sum, doc) => sum + doc.amount,
    );
    final selectedReturned = filteredDocuments
        .where((doc) => doc.returnStatus == CustodyReturnStatus.approved)
        .fold<double>(0, (sum, doc) => sum + doc.returnAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة سندات العهدة',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.custodyDocuments),
            icon: const Icon(Icons.list_alt),
            tooltip: 'قائمة السندات',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F5F2), Color(0xFFE9EEF5)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () => provider.refreshDocuments(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'إجمالي المبالغ',
                        value: currency.format(totalAll),
                        color: const Color(0xFF1B4D3E),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      _StatCard(
                        title: 'المعتمد',
                        value: currency.format(totalApproved),
                        color: const Color(0xFF0F5E9C),
                        icon: Icons.verified_outlined,
                      ),
                      _StatCard(
                        title: 'المردود المعتمد',
                        value: currency.format(totalReturnedApproved),
                        color: const Color(0xFF7A4E2D),
                        icon: Icons.undo,
                      ),
                      _StatCard(
                        title: 'الرصيد المتبقي',
                        value: currency.format(balance),
                        color: const Color(0xFF9C2C2C),
                        icon: Icons.summarize_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تصفية حسب الشهر',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: selectedKey,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('الكل'),
                              ),
                              ...monthKeys.map(
                                (key) => DropdownMenuItem(
                                  value: key,
                                  child: Text(_monthLabel(key)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedMonthKey = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStat(
                                  label: 'إجمالي الشهر',
                                  value: currency.format(selectedTotal),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniStat(
                                  label: 'مردود الشهر',
                                  value: currency.format(selectedReturned),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'إجماليات الشهور',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (monthKeys.isEmpty)
                            const Text('لا توجد بيانات بعد')
                          else
                            ...monthKeys.map((key) {
                              final items = monthGroups[key] ?? [];
                              final monthTotal = items.fold<double>(
                                0,
                                (sum, doc) => sum + doc.amount,
                              );
                              final monthReturned = items
                                  .where((doc) =>
                                      doc.returnStatus ==
                                      CustodyReturnStatus.approved)
                                  .fold<double>(
                                    0,
                                    (sum, doc) => sum + doc.returnAmount,
                                  );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_monthLabel(key)),
                                subtitle: Text('عدد السندات: ${items.length}'),
                                trailing: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      currency.format(monthTotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (monthReturned > 0)
                                      Text(
                                        'مردود: ${currency.format(monthReturned)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تنقل سريع',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.custodyDocuments,
                                ),
                                icon: const Icon(Icons.list_alt),
                                label: const Text('قائمة السندات'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.custodyDocumentForm,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('إنشاء سند جديد'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.custodyReturn,
                                ),
                                icon: const Icon(Icons.undo),
                                label: const Text('عمل مردود عهدة'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
