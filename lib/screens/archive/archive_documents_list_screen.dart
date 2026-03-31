import 'package:flutter/material.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/archive/archive_document_form_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';

class ArchiveDocumentsListScreen extends StatefulWidget {
  final String? initialDocumentType;
  final String? initialDepartmentName;
  final String? initialArchiveKey;
  final String? initialDossierKey;

  const ArchiveDocumentsListScreen({
    super.key,
    this.initialDocumentType,
    this.initialDepartmentName,
    this.initialArchiveKey,
    this.initialDossierKey,
  });

  @override
  State<ArchiveDocumentsListScreen> createState() =>
      _ArchiveDocumentsListScreenState();
}

class _ArchiveDocumentsListScreenState extends State<ArchiveDocumentsListScreen> {
  final _searchController = TextEditingController();
  bool _loading = false;
  String? _documentType;
  String? _transactionClass;
  String? _status;
  String? _departmentName;
  String? _archiveKey;
  String? _dossierKey;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _metadata = const {};

  @override
  void initState() {
    super.initState();
    _documentType = widget.initialDocumentType;
    _departmentName = widget.initialDepartmentName;
    _archiveKey = widget.initialArchiveKey;
    _dossierKey = widget.initialDossierKey;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _departments =>
      ((_metadata['departments'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();

  List<Map<String, dynamic>> get _archives =>
      ((_metadata['archives'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  List<Map<String, dynamic>> get _dossiers =>
      ((_metadata['dossiers'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) {
            if (_archiveKey != null &&
                item['archiveKey']?.toString() != _archiveKey) {
              return false;
            }
            if (_departmentName != null &&
                item['departmentName']?.toString() != _departmentName) {
              return false;
            }
            return true;
          })
          .toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ArchiveDocumentsRepository.list(
        search: _searchController.text,
        limit: 300,
        documentType: _documentType,
        transactionClass: _documentType == 'transaction' ? _transactionClass : null,
        status: _status,
        departmentName: _departmentName,
        archiveKey: _archiveKey,
        dossierKey: _dossierKey,
      );
      final metadata = await ArchiveDocumentsRepository.metadata(
        departmentName: _departmentName,
        archiveKey: _archiveKey,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _metadata = metadata;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل السجلات: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentFormScreen(
          initialType: _documentType ?? 'incoming',
          initialDepartmentName: _departmentName,
        ),
      ),
    ).then((_) => _load());
  }

  void _openDetails(Map<String, dynamic> document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveDocumentDetailsScreen(
          documentId: '${document['_id']}',
          initialDocument: document,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final pagePadding = ArchiveDocsLayout.pagePadding(context);
    final maxWidth = ArchiveDocsLayout.maxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('سجلات الأرشفة'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding,
          children: [
            _buildFiltersCard(),
            const SizedBox(height: 12),
            if (_loading && _items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد سجلات مطابقة للفلاتر الحالية'),
                ),
              )
            else
              ..._items.map(_buildResponsiveItemCard),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(ArchiveDocsLayout.isPhone(context) ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: ArchiveDocsLayout.inputDecoration(
                context,
                label: 'البحث',
                hintText: 'بحث برقم المعاملة أو الموضوع أو القسم أو الدوسيه',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _documentType,
                    decoration: const InputDecoration(
                      labelText: 'نوع العملية',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ...ArchiveDocsUi.documentTypeOptions.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item['value'],
                          child: Text(item['label']!),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _documentType = value;
                        if (_documentType != 'transaction') {
                          _transactionClass = null;
                        }
                      });
                    },
                  ),
                ),
                if (_documentType == 'transaction')
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _transactionClass,
                      decoration: const InputDecoration(
                        labelText: 'تصنيف المعاملة',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...ArchiveDocsUi.transactionClassOptions.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item['value'],
                            child: Text(item['label']!),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _transactionClass = value),
                    ),
                  ),
                SizedBox(
                  width: 220,
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
                        (item) => DropdownMenuItem<String?>(
                          value: item['value'],
                          child: Text(item['label']!),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _departmentName,
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ..._departments.map(
                        (department) => DropdownMenuItem<String?>(
                          value: department,
                          child: Text(department),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _departmentName = value;
                        _archiveKey = null;
                        _dossierKey = null;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _archiveKey,
                    decoration: const InputDecoration(
                      labelText: 'الأرشيف',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ..._archives.map(
                        (archive) => DropdownMenuItem<String?>(
                          value: archive['archiveKey']?.toString(),
                          child: Text(archive['archiveName']?.toString() ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _archiveKey = value;
                        _dossierKey = null;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _dossierKey,
                    decoration: const InputDecoration(
                      labelText: 'الدوسيه',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ..._dossiers.map(
                        (dossier) => DropdownMenuItem<String?>(
                          value: dossier['dossierKey']?.toString(),
                          child: Text(dossier['dossierLabel']?.toString() ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _dossierKey = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('تطبيق'),
                ),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _searchController.clear();
                            _documentType = null;
                            _transactionClass = null;
                            _status = null;
                            _departmentName = null;
                            _archiveKey = null;
                            _dossierKey = null;
                          });
                          _load();
                        },
                  icon: const Icon(Icons.clear_all_outlined),
                  label: const Text('مسح'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> document) {
    final attachments = (document['attachments'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final imageAttachment = attachments.cast<Map<String, dynamic>?>().firstWhere(
      (attachment) => attachment != null && ArchiveDocsUi.isImageAttachment(attachment),
      orElse: () => null,
    );
    final imageUrl = imageAttachment == null
        ? null
        : ArchiveDocsUi.attachmentUrl(imageAttachment);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(document),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(ArchiveDocsUi.typeWithClassLabel(document)),
                        ),
                        Chip(
                          label: Text(
                            document['statusLabel']?.toString() ??
                                ArchiveDocsUi.statusLabel(
                                  document['status']?.toString(),
                                ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${document['documentNumber'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      document['subject']?.toString().isNotEmpty == true
                          ? document['subject'].toString()
                          : 'بدون موضوع',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'القسم: ${document['departmentName'] ?? '-'} | الأرشيف: ${document['archiveName'] ?? '-'}',
                    ),
                    Text(
                      'الدوسيه: ${ArchiveDocsUi.dossierLabel(document)} | الرف: ${document['shelfNumber'] ?? document['archiveShelf'] ?? '-'}',
                    ),
                    Text(
                      'المكتب: ${document['officeName'] ?? '-'} | مع: ${document['currentHolderName'] ?? '-'}',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openDetails(document),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('التفاصيل'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => ArchiveStickerPrinter.printDocument(document),
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

  Widget _buildResponsiveItemCard(Map<String, dynamic> document) {
    final attachments = (document['attachments'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final imageAttachment = attachments.cast<Map<String, dynamic>?>().firstWhere(
      (attachment) =>
          attachment != null && ArchiveDocsUi.isImageAttachment(attachment),
      orElse: () => null,
    );
    final imageUrl = imageAttachment == null
        ? null
        : ArchiveDocsUi.attachmentUrl(imageAttachment);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: InkWell(
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        onTap: () => _openDetails(document),
        child: Padding(
          padding: EdgeInsets.all(ArchiveDocsLayout.isPhone(context) ? 14 : 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderThumb(),
                            ),
                          )
                        else
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: _placeholderThumb(),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      ArchiveDocsUi.typeWithClassLabel(document),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      document['statusLabel']?.toString() ??
                                          ArchiveDocsUi.statusLabel(
                                            document['status']?.toString(),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${document['documentNumber'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                document['subject']?.toString().isNotEmpty == true
                                    ? document['subject'].toString()
                                    : 'بدون موضوع',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetaLine(
                      'القسم',
                      '${document['departmentName'] ?? '-'}',
                    ),
                    _buildMetaLine(
                      'الأرشيف',
                      '${document['archiveName'] ?? '-'}',
                    ),
                    _buildMetaLine(
                      'الدوسيه',
                      ArchiveDocsUi.dossierLabel(document),
                    ),
                    _buildMetaLine(
                      'المكتب',
                      '${document['officeName'] ?? '-'}',
                    ),
                    _buildMetaLine(
                      'المستلم',
                      '${document['currentHolderName'] ?? '-'}',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth,
                          child: OutlinedButton.icon(
                            onPressed: () => _openDetails(document),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('التفاصيل'),
                          ),
                        ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                ArchiveStickerPrinter.printDocument(document),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('طباعة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderThumb(),
                      ),
                    )
                  else
                    _placeholderThumb(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                ArchiveDocsUi.typeWithClassLabel(document),
                              ),
                            ),
                            Chip(
                              label: Text(
                                document['statusLabel']?.toString() ??
                                    ArchiveDocsUi.statusLabel(
                                      document['status']?.toString(),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${document['documentNumber'] ?? '-'}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          document['subject']?.toString().isNotEmpty == true
                              ? document['subject'].toString()
                              : 'بدون موضوع',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'القسم: ${document['departmentName'] ?? '-'} | الأرشيف: ${document['archiveName'] ?? '-'}',
                        ),
                        Text(
                          'الدوسيه: ${ArchiveDocsUi.dossierLabel(document)} | الرف: ${document['shelfNumber'] ?? document['archiveShelf'] ?? '-'}',
                        ),
                        Text(
                          'المكتب: ${document['officeName'] ?? '-'} | مع: ${document['currentHolderName'] ?? '-'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openDetails(document),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('التفاصيل'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ArchiveStickerPrinter.printDocument(document),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('طباعة'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetaLine(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _placeholderThumb() => Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(Icons.insert_drive_file_outlined),
      );
}
