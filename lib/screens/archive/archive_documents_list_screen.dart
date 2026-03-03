import 'package:flutter/material.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/archive/archive_document_form_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';

class ArchiveDocumentsListScreen extends StatefulWidget {
  const ArchiveDocumentsListScreen({super.key});

  @override
  State<ArchiveDocumentsListScreen> createState() => _ArchiveDocumentsListScreenState();
}

class _ArchiveDocumentsListScreenState extends State<ArchiveDocumentsListScreen> {
  final _search = TextEditingController();
  String? _type;
  String? _status;
  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];

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
    setState(() => _loading = true);
    try {
      final docs = await ArchiveDocumentsRepository.list(
        search: _search.text,
        documentType: _type,
        status: _status,
        limit: 100,
      );
      if (!mounted) return;
      setState(() => _items = docs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر تحميل السجلات: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كل سجلات الأرشفة'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchiveDocumentFormScreen()),
              ).then((_) => _load());
            },
            icon: const Icon(Icons.add),
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      decoration: const InputDecoration(
                        hintText: 'بحث برقم المستند / السريال / الموضوع',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _type,
                            decoration: const InputDecoration(
                              labelText: 'نوع المستند',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem<String?>(value: null, child: Text('الكل')),
                              DropdownMenuItem<String?>(value: 'incoming', child: Text('وارد')),
                              DropdownMenuItem<String?>(value: 'outgoing', child: Text('صادر')),
                            ],
                            onChanged: (v) => setState(() => _type = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'الحالة',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('الكل'),
                              ),
                              ...ArchiveDocsUi.statusOptions.map(
                                (e) => DropdownMenuItem<String?>(
                                  value: e['value'],
                                  child: Text(e['label']!),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _status = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _load,
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('تطبيق'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد سجلات أرشفة')))
            else
              ..._items.map(_buildItemCard),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> d) {
    final attachments = (d['attachments'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final imageAtt = attachments.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a != null && ArchiveDocsUi.isImageAttachment(a),
          orElse: () => null,
        );
    final imageUrl = imageAtt == null ? null : ArchiveDocsUi.attachmentUrl(imageAtt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArchiveDocumentDetailsScreen(
                documentId: '${d['_id']}',
                initialDocument: d,
              ),
            ),
          ).then((_) => _load());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderThumb(),
                  ),
                )
              else
                _placeholderThumb(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(
                          label: Text(
                            d['documentTypeLabel']?.toString() ??
                                ArchiveDocsUi.typeLabel(d['documentType']?.toString()),
                          ),
                        ),
                        Chip(
                          label: Text(
                            d['statusLabel']?.toString() ??
                                ArchiveDocsUi.statusLabel(d['status']?.toString()),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'رقم المستند: ${d['documentNumber'] ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('السريال: ${d['serialNumber'] ?? '-'}'),
                    Text('الموضوع: ${d['subject'] ?? '-'}'),
                    Text(
                      'مع من: ${d['currentHolderName'] ?? '-'} | الأرشيف: ${d['archiveName'] ?? '-'} | الفايل: ${d['archiveFile'] ?? '-'}',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArchiveDocumentDetailsScreen(
                                  documentId: '${d['_id']}',
                                  initialDocument: d,
                                ),
                              ),
                            ).then((_) => _load());
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('التفاصيل'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => ArchiveStickerPrinter.printDocument(d),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('طباعة'),
                        ),
                      ],
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

  Widget _placeholderThumb() => Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(Icons.insert_drive_file_outlined),
      );
}
