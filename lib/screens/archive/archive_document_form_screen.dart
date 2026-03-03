import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';
import 'package:path/path.dart' as p;

class ArchiveDocumentFormScreen extends StatefulWidget {
  final String initialType;
  const ArchiveDocumentFormScreen({
    super.key,
    this.initialType = 'incoming',
  });

  @override
  State<ArchiveDocumentFormScreen> createState() => _ArchiveDocumentFormScreenState();
}

class _ArchiveDocumentFormScreenState extends State<ArchiveDocumentFormScreen> {
  final _img = ImagePicker();
  final _c = <String, TextEditingController>{
    'subject': TextEditingController(),
    'holder': TextEditingController(),
    'dept': TextEditingController(),
    'employee': TextEditingController(),
    'archive': TextEditingController(),
    'file': TextEditingController(),
    'shelf': TextEditingController(),
    'notes': TextEditingController(),
  };

  late String _type = widget.initialType;
  String _status = 'new';
  String _holderType = 'department';
  bool _saving = false;
  bool _autoPrint = true;
  ArchiveDraftFile? _file;

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    setState(() {
      _file = ArchiveDraftFile(name: f.name, path: f.path, bytes: f.bytes);
    });
  }

  Future<void> _pickCamera() async {
    try {
      final x = await _img.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = ArchiveDraftFile(name: p.basename(x.name), path: x.path, bytes: bytes);
      });
    } catch (_) {
      _snack('الكاميرا غير متاحة هنا. استخدم إرفاق ملف.');
    }
  }

  void _scanHint() => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('اسكانر الطابعة'),
          content: const Text(
            'المسح المباشر من الاسكانر يحتاج تكامل محلي. يمكنك الآن استخدام إرفاق ملف أو تصوير المستند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );

  Future<void> _save() async {
    if (_file == null) {
      _snack('أرفق المستند أولًا');
      return;
    }
    setState(() => _saving = true);
    try {
      final doc = await ArchiveDocumentsRepository.create(
        documentType: _type,
        status: _status,
        currentHolderType: _holderType,
        file: _file!,
        subject: _c['subject']!.text,
        currentHolderName: _c['holder']!.text,
        currentDepartment: _c['dept']!.text,
        currentEmployeeName: _c['employee']!.text,
        archiveName: _c['archive']!.text,
        archiveFile: _c['file']!.text,
        archiveShelf: _c['shelf']!.text,
        notes: _c['notes']!.text,
      );

      if (_autoPrint) {
        await ArchiveStickerPrinter.printDocument(doc);
      }
      if (!mounted) return;
      _snack('تم إنشاء السجل: ${doc['documentNumber']}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ArchiveDocumentDetailsScreen(
            documentId: '${doc['_id']}',
            initialDocument: doc,
          ),
        ),
      );
    } catch (e) {
      _snack('تعذر إنشاء سجل الأرشفة: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label, {int maxLines = 1}) => TextField(
        controller: _c[key],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء سجل أرشفة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'نوع المستند',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'incoming', child: Text('وارد')),
                            DropdownMenuItem(value: 'outgoing', child: Text('صادر')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'incoming'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                            border: OutlineInputBorder(),
                          ),
                          items: ArchiveDocsUi.statusOptions
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['value'],
                                  child: Text(e['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _status = v ?? 'new'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field('subject', 'موضوع المستند (اختياري)'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _holderType,
                          decoration: const InputDecoration(
                            labelText: 'نوع الجهة الحالية',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'department', child: Text('قسم')),
                            DropdownMenuItem(value: 'employee', child: Text('موظف')),
                            DropdownMenuItem(value: 'other', child: Text('أخرى')),
                          ],
                          onChanged: (v) =>
                              setState(() => _holderType = v ?? 'department'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field('holder', 'مع من / المستلم الحالي')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field('dept', 'القسم')),
                      const SizedBox(width: 12),
                      Expanded(child: _field('employee', 'الموظف')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field('archive', 'الأرشيف')),
                      const SizedBox(width: 12),
                      Expanded(child: _field('file', 'الفايل')),
                      const SizedBox(width: 12),
                      Expanded(child: _field('shelf', 'الرف/الموقع')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field('notes', 'ملاحظات', maxLines: 2),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('إرفاق ملف'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickCamera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('تصوير/اسكان'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _scanHint,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('اسكانر الطابعة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_file != null)
                    Chip(
                      label: Text(_file!.name),
                      onDeleted:
                          _saving ? null : () => setState(() => _file = null),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoPrint,
                    onChanged: (v) => setState(() => _autoPrint = v),
                    title: const Text('طباعة الاستيكر تلقائيًا'),
                    subtitle: const Text('مقاس 7 × 5 سم'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'جاري الإنشاء...' : 'إنشاء سجل الأرشفة'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
