import 'package:flutter/material.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/archive/archive_document_form_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_list_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';

class ArchiveDocumentsScreen extends StatefulWidget {
  const ArchiveDocumentsScreen({super.key});

  @override
  State<ArchiveDocumentsScreen> createState() => _ArchiveDocumentsScreenState();
}

class _ArchiveDocumentsScreenState extends State<ArchiveDocumentsScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await ArchiveDocumentsRepository.list(limit: 20);
      if (!mounted) return;
      setState(() => _recent = docs);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل بيانات الأرشفة')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _countByType(String type) =>
      _recent.where((e) => '${e['documentType']}' == type).length;
  int _countByStatus(String status) =>
      _recent.where((e) => '${e['status']}' == status).length;

  void _openCreate([String type = 'incoming']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentFormScreen(initialType: type),
      ),
    ).then((_) => _load());
  }

  void _openList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArchiveDocumentsListScreen()),
    ).then((_) => _load());
  }

  void _openDetails(Map<String, dynamic> d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentDetailsScreen(
          documentId: '${d['_id']}',
          initialDocument: d,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _countByType('incoming');
    final outgoing = _countByType('outgoing');
    final archived = _countByStatus('archived');
    final pending = _countByStatus('new') + _countByStatus('in_progress');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرشفة (وارد / صادر)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'داشبورد الأرشفة',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statCard('الوارد', incoming, Icons.move_to_inbox_outlined),
                        _statCard('الصادر', outgoing, Icons.outbox_outlined),
                        _statCard('مؤرشف', archived, Icons.archive_outlined),
                        _statCard('قيد الإجراء', pending, Icons.pending_actions),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _openCreate('incoming'),
                          icon: const Icon(Icons.add_to_drive_outlined),
                          label: const Text('إضافة وارد'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openCreate('outgoing'),
                          icon: const Icon(Icons.outbox_outlined),
                          label: const Text('إضافة صادر'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openList,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('كل الأرشيف'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'آخر السجلات',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openList,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_recent.isEmpty)
                      const Text('لا توجد سجلات أرشفة حتى الآن')
                    else
                      ..._recent.take(8).map(
                            (d) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor:
                                    ('${d['documentType']}' == 'outgoing')
                                        ? Colors.orange.shade100
                                        : Colors.blue.shade100,
                                child: Icon(
                                  ('${d['documentType']}' == 'outgoing')
                                      ? Icons.outbox_outlined
                                      : Icons.move_to_inbox_outlined,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              title: Text(
                                '${d['documentNumber'] ?? '-'} - ${d['subject'] ?? 'بدون موضوع'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'الحالة: ${d['statusLabel'] ?? ArchiveDocsUi.statusLabel('${d['status']}')} | السريال: ${d['serialNumber'] ?? '-'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'التفاصيل',
                                    onPressed: () => _openDetails(d),
                                    icon: const Icon(Icons.visibility_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'طباعة الاستيكر',
                                    onPressed: () =>
                                        ArchiveStickerPrinter.printDocument(d),
                                    icon: const Icon(Icons.print_outlined),
                                  ),
                                ],
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

  Widget _statCard(String title, int value, IconData icon) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
