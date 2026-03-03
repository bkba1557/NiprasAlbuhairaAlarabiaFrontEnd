import 'package:flutter/material.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';
import 'package:url_launcher/url_launcher.dart';

class ArchiveDocumentDetailsScreen extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic>? initialDocument;

  const ArchiveDocumentDetailsScreen({
    super.key,
    required this.documentId,
    this.initialDocument,
  });

  @override
  State<ArchiveDocumentDetailsScreen> createState() =>
      _ArchiveDocumentDetailsScreenState();
}

class _ArchiveDocumentDetailsScreenState extends State<ArchiveDocumentDetailsScreen> {
  Map<String, dynamic>? _doc;
  bool _loading = false;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _doc = widget.initialDocument;
    _status = _doc?['status']?.toString() ?? 'new';
    _load();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ArchiveDocumentsRepository.getById(widget.documentId);
      if (!mounted) return;
      setState(() {
        _doc = d;
        _status = d['status']?.toString() ?? _status ?? 'new';
      });
    } catch (e) {
      if (mounted) _snack('تعذر تحميل التفاصيل: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveStatus() async {
    if (_status == null) return;
    setState(() => _saving = true);
    try {
      final updated = await ArchiveDocumentsRepository.update(
        widget.documentId,
        {'status': _status},
      );
      if (!mounted) return;
      setState(() => _doc = updated);
      _snack('تم تحديث الحالة');
    } catch (e) {
      if (mounted) _snack('تعذر تحديث الحالة: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> att) async {
    final url = ArchiveDocsUi.attachmentUrl(att);
    if (url == null) return _snack('رابط المرفق غير متاح');
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    if (!ok) _snack('تعذر فتح المرفق');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final d = _doc;
    final attachments = (d?['attachments'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الأرشفة'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Center(child: Text('لا توجد بيانات'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1680),
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeaderAndDetailsCard(d, isWide: isWide),
                          const SizedBox(height: 12),
                          _buildAttachmentsCard(
                            attachments: attachments,
                            isWide: isWide,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderAndDetailsCard(Map<String, dynamic> d, {required bool isWide}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
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
                Chip(label: Text('رقم: ${d['documentNumber'] ?? '-'}')),
                Chip(label: Text('سريال: ${d['serialNumber'] ?? '-'}')),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailsGrid(d, isWide: isWide),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isWide ? 540 : double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status ?? 'new',
                    decoration: const InputDecoration(
                      labelText: 'تغيير الحالة',
                      border: OutlineInputBorder(),
                    ),
                    items: ArchiveDocsUi.statusOptions
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['value']!,
                            child: Text(e['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'new'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveStatus,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ArchiveStickerPrinter.printDocument(d),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة الاستيكر'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _status = 'archived');
                    _saveStatus();
                  },
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('أرشفة الآن'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(Map<String, dynamic> d, {required bool isWide}) {
    final items = <MapEntry<String, String>>[
      MapEntry('الموضوع', '${d['subject'] ?? '-'}'),
      MapEntry('مع من', '${d['currentHolderName'] ?? '-'}'),
      MapEntry('القسم', '${d['currentDepartment'] ?? '-'}'),
      MapEntry('الموظف', '${d['currentEmployeeName'] ?? '-'}'),
      MapEntry('الأرشيف', '${d['archiveName'] ?? '-'}'),
      MapEntry('الفايل', '${d['archiveFile'] ?? '-'}'),
      MapEntry('الرف/الموقع', '${d['archiveShelf'] ?? '-'}'),
      MapEntry('ملاحظات', '${d['notes'] ?? '-'}'),
    ];

    if (!isWide) {
      return Column(
        children: items.map((e) => _detailRow(e.key, e.value)).toList(),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items
          .map(
            (e) => SizedBox(
              width: 790,
              child: _detailRow(e.key, e.value),
            ),
          )
          .toList(),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$title:',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard({
    required List<Map<String, dynamic>> attachments,
    required bool isWide,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'المرفقات والصور',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (attachments.isEmpty)
              const Text('لا توجد مرفقات')
            else
              ...attachments.map((att) => _attachmentTile(att, isWide: isWide)),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(Map<String, dynamic> att, {required bool isWide}) {
    final url = ArchiveDocsUi.attachmentUrl(att);
    final isImage = ArchiveDocsUi.isImageAttachment(att);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isImage && url != null)
            InkWell(
              onTap: () => _showImage(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 120,
                    maxHeight: isWide ? 320 : 220,
                  ),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          if (isImage && url != null) const SizedBox(height: 8),
          Text(
            (att['originalName'] ?? att['filename'] ?? '-').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAttachment(att),
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح'),
              ),
              if (isImage && url != null)
                OutlinedButton.icon(
                  onPressed: () => _showImage(url),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('عرض الصورة'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 1200,
          height: 700,
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
