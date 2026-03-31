import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/screens/archive/archive_document_details_screen.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:path/path.dart' as p;

class ArchiveDocumentFormScreen extends StatefulWidget {
  final String initialType;
  final String? initialDepartmentName;

  const ArchiveDocumentFormScreen({
    super.key,
    this.initialType = 'incoming',
    this.initialDepartmentName,
  });

  @override
  State<ArchiveDocumentFormScreen> createState() =>
      _ArchiveDocumentFormScreenState();
}

class _ArchiveDocumentFormScreenState extends State<ArchiveDocumentFormScreen> {
  final _imagePicker = ImagePicker();
  final _controllers = <String, TextEditingController>{
    'subject': TextEditingController(),
    'department': TextEditingController(),
    'archive': TextEditingController(),
    'dossierName': TextEditingController(),
    'office': TextEditingController(),
    'shelf': TextEditingController(),
    'holderName': TextEditingController(),
    'locationNote': TextEditingController(),
    'notes': TextEditingController(),
  };

  late String _documentType = widget.initialType;
  String _transactionClass = 'internal';
  String _holderType = 'department';
  bool _createNewDossier = true;
  bool _saving = false;
  bool _loadingLookups = false;
  bool _autoPrint = true;
  ArchiveDraftFile? _file;
  Map<String, dynamic> _metadata = const {};
  List<User> _users = const [];
  User? _selectedHolderUser;
  String? _selectedDossierKey;

  @override
  void initState() {
    super.initState();
    _controllers['department']!.text = widget.initialDepartmentName ?? '';
    _loadLookups();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
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

  String? get _selectedArchiveKey {
    final archiveName = _controllers['archive']!.text.trim();
    if (archiveName.isEmpty) return null;
    for (final archive in _archives) {
      if ((archive['archiveName'] ?? '').toString() == archiveName) {
        return archive['archiveKey']?.toString();
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _availableDossiers =>
      ((_metadata['dossiers'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) {
            if (_selectedArchiveKey != null &&
                item['archiveKey']?.toString() != _selectedArchiveKey) {
              return false;
            }
            final department = _controllers['department']!.text.trim();
            if (department.isNotEmpty &&
                item['departmentName']?.toString() != department) {
              return false;
            }
            return true;
          })
          .toList();

  Future<void> _loadLookups() async {
    setState(() => _loadingLookups = true);
    try {
      final metadata = await ArchiveDocumentsRepository.metadata();
      final users = await ArchiveDocumentsRepository.fetchUsers();
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _users = users;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل بيانات الأقسام والمستخدمين: $error')),
      );
    } finally {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    setState(() {
      _file = ArchiveDraftFile(
        name: picked.name,
        path: picked.path,
        bytes: picked.bytes,
      );
    });
  }

  Future<void> _pickCamera() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = ArchiveDraftFile(
          name: p.basename(picked.path),
          path: picked.path,
          bytes: bytes,
        );
      });
    } catch (_) {
      _snack('الكاميرا غير متاحة هنا، استخدم إرفاق ملف');
    }
  }

  Future<void> _pickHolderUser() async {
    if (_users.isEmpty) {
      _snack('لا توجد قائمة مستخدمين متاحة حاليًا');
      return;
    }

    final selected = await showDialog<User>(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        var filteredUsers = List<User>.from(_users);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyFilter(String value) {
              final query = value.trim().toLowerCase();
              setDialogState(() {
                filteredUsers = _users.where((user) {
                  final haystack =
                      '${user.name} ${user.email} ${user.username} ${user.role}'
                          .toLowerCase();
                  return haystack.contains(query);
                }).toList();
              });
            }

            return AlertDialog(
              title: const Text('اختيار الموظف'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: applyFilter,
                      decoration: ArchiveDocsLayout.inputDecoration(
                        context,
                        label: 'بحث',
                        hint: 'بحث بالاسم أو البريد أو الدور',
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return ListTile(
                            title: Text(user.name),
                            subtitle: Text('${user.email} • ${user.role}'),
                            onTap: () => Navigator.pop(context, user),
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
                  child: const Text('إغلاق'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _selectedHolderUser = selected;
      _controllers['holderName']!.text = selected.name;
    });
  }

  Future<void> _save() async {
    final departmentName = _controllers['department']!.text.trim();
    final archiveName = _controllers['archive']!.text.trim();
    final officeName = _controllers['office']!.text.trim();
    final shelfNumber = _controllers['shelf']!.text.trim();

    if (_file == null) {
      _snack('أرفق ملف المعاملة أولًا');
      return;
    }
    if (departmentName.isEmpty) {
      _snack('القسم مطلوب');
      return;
    }
    if (archiveName.isEmpty) {
      _snack('اسم الأرشيف مطلوب');
      return;
    }
    if (officeName.isEmpty) {
      _snack('اسم المكتب مطلوب');
      return;
    }
    if (shelfNumber.isEmpty) {
      _snack('رقم الرف مطلوب');
      return;
    }
    if (_documentType == 'transaction' && _transactionClass.isEmpty) {
      _snack('حدد ما إذا كانت المعاملة داخلية أو خارجية');
      return;
    }
    if (_holderType == 'employee' && _selectedHolderUser == null) {
      _snack('اختر الموظف المستلم الحالي');
      return;
    }
    if (!_createNewDossier &&
        (_selectedDossierKey == null || _selectedDossierKey!.isEmpty)) {
      _snack('اختر الدوسيه الحالي أو فعّل إنشاء دوسيه جديد');
      return;
    }

    final fields = <String, String>{
      'documentType': _documentType,
      'departmentName': departmentName,
      'archiveName': archiveName,
      'officeName': officeName,
      'shelfNumber': shelfNumber,
      'currentHolderType': _holderType,
      if (_documentType == 'transaction') 'transactionClass': _transactionClass,
      if (_controllers['subject']!.text.trim().isNotEmpty)
        'subject': _controllers['subject']!.text.trim(),
      if (_controllers['locationNote']!.text.trim().isNotEmpty)
        'locationNote': _controllers['locationNote']!.text.trim(),
      if (_controllers['notes']!.text.trim().isNotEmpty)
        'notes': _controllers['notes']!.text.trim(),
      if (_holderType == 'employee' && _selectedHolderUser != null) ...{
        'currentHolderUserId': _selectedHolderUser!.id,
        'currentHolderName': _selectedHolderUser!.name,
      } else if (_controllers['holderName']!.text.trim().isNotEmpty) ...{
        'currentHolderName': _controllers['holderName']!.text.trim(),
      },
      if (_createNewDossier) 'createNewDossier': 'true',
      if (_createNewDossier &&
          _controllers['dossierName']!.text.trim().isNotEmpty)
        'dossierName': _controllers['dossierName']!.text.trim(),
      if (!_createNewDossier && _selectedDossierKey != null) ...{
        'createNewDossier': 'false',
        'dossierKey': _selectedDossierKey!,
      },
    };

    setState(() => _saving = true);
    try {
      final document = await ArchiveDocumentsRepository.create(
        file: _file!,
        fields: fields,
      );
      if (_autoPrint) {
        await ArchiveStickerPrinter.printDocument(document);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ArchiveDocumentDetailsScreen(
            documentId: '${document['_id']}',
            initialDocument: document,
          ),
        ),
      );
    } catch (error) {
      _snack('تعذر إنشاء سجل الأرشفة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    int maxLines = 1,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: _controllers[key],
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: ArchiveDocsLayout.inputDecoration(
        context,
        label: label,
        hint: hint,
      ),
    );
  }

  Widget _buildSuggestionChips({
    required List<String> items,
    required TextEditingController controller,
  }) {
    final query = controller.text.trim().toLowerCase();
    final suggestions = items
        .where((item) {
          if (query.isEmpty) return true;
          return item.toLowerCase().contains(query);
        })
        .take(6)
        .toList();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions
          .map(
            (item) => ActionChip(
              label: Text(item),
              onPressed: () => setState(() => controller.text = item),
            ),
          )
          .toList(),
      );
  }

  Widget _buildFormHero() {
    final isPhone = ArchiveDocsLayout.isPhone(context);
    final typeLabel = ArchiveDocsUi.documentTypeOptions.firstWhere(
      (item) => item['value'] == _documentType,
      orElse: () => ArchiveDocsUi.documentTypeOptions.first,
    )['label']!;

    return Container(
      padding: EdgeInsets.all(isPhone ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.appBarGradient,
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        boxShadow: [
          BoxShadow(
            color: AppColors.appBarWaterDeep.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء سجل أرشفة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isPhone ? 20 : 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'نوع العملية الحالية: $typeLabel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isPhone ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'املأ الحقول الأساسية ثم أرفق الملف واختر الدوسيه أو أنشئ واحداً جديداً.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    height: 1.5,
                    fontSize: isPhone ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isPhone) ...[
            const SizedBox(width: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagePadding = ArchiveDocsLayout.pagePadding(context);
    final maxWidth = ArchiveDocsLayout.maxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(title: const Text('إنشاء سجل أرشفة')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePadding,
            children: [
              if (_loadingLookups) const LinearProgressIndicator(),
              _buildFormHero(),
              const SizedBox(height: 16),
              Card(
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _documentType,
                          decoration: ArchiveDocsLayout.inputDecoration(
                            context,
                            label: 'نوع العملية',
                          ),
                          items: ArchiveDocsUi.documentTypeOptions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item['value'],
                                  child: Text(item['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _documentType = value);
                          },
                        ),
                      ),
                      if (_documentType == 'transaction')
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            initialValue: _transactionClass,
                            decoration: ArchiveDocsLayout.inputDecoration(
                              context,
                              label: 'تصنيف المعاملة',
                            ),
                            items: ArchiveDocsUi.transactionClassOptions
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item['value'],
                                    child: Text(item['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _transactionClass = value);
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field('subject', 'موضوع المعاملة'),
                  const SizedBox(height: 12),
                  _field(
                    'department',
                    'القسم المعني',
                    hint: 'اكتب اسم القسم أو اختر من الشريط',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionChips(
                    items: _departments,
                    controller: _controllers['department']!,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    'archive',
                    'اسم الأرشيف',
                    hint: 'مثال: أرشيف الإدارة العامة',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionChips(
                    items: _archives
                        .map((archive) => archive['archiveName']?.toString() ?? '')
                        .where((name) => name.trim().isNotEmpty)
                        .toList(),
                    controller: _controllers['archive']!,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 260,
                        child: _field('office', 'المكتب الموجود به'),
                      ),
                      SizedBox(
                        width: 220,
                        child: _field('shelf', 'رقم الرف'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _createNewDossier,
                    onChanged: (value) {
                      setState(() {
                        _createNewDossier = value;
                        if (value) {
                          _selectedDossierKey = null;
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إنشاء دوسيه جديد'),
                    subtitle: const Text(
                      'عند التعطيل يمكنك ربط المعاملة بدوسيه موجود داخل الأرشيف نفسه',
                    ),
                  ),
                  if (_createNewDossier)
                    _field(
                      'dossierName',
                      'اسم الدوسيه الجديد',
                      hint: 'اختياري، سيولد الرقم تلقائيًا',
                    )
                  else if (_availableDossiers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'لا توجد دوسيهات متاحة لهذا الأرشيف والقسم حاليًا',
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDossierKey,
                      decoration: ArchiveDocsLayout.inputDecoration(
                        context,
                        label: 'الدوسيه الحالي',
                      ),
                      items: _availableDossiers
                          .map(
                            (dossier) => DropdownMenuItem(
                              value: dossier['dossierKey']?.toString(),
                              child: Text(
                                dossier['dossierLabel']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedDossierKey = value),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _holderType,
                    decoration: ArchiveDocsLayout.inputDecoration(
                      context,
                      label: 'المستلم الحالي',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'department',
                        child: Text('قسم'),
                      ),
                      DropdownMenuItem(
                        value: 'employee',
                        child: Text('موظف'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('أخرى'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _holderType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_holderType == 'employee') ...[
                    OutlinedButton.icon(
                      onPressed: _pickHolderUser,
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('اختيار الموظف'),
                    ),
                    if (_selectedHolderUser != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedHolderUser!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_selectedHolderUser!.email} • ${_selectedHolderUser!.role}',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedHolderUser = null;
                                  _controllers['holderName']!.clear();
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else
                    _field('holderName', 'اسم الجهة أو المستلم الحالي'),
                  const SizedBox(height: 12),
                  _field('locationNote', 'ملاحظات الموقع', maxLines: 2),
                  const SizedBox(height: 12),
                  _field('notes', 'ملاحظات إضافية', maxLines: 2),
                  const SizedBox(height: 16),
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
                    ],
                  ),
                  if (_file != null) ...[
                    const SizedBox(height: 10),
                    Chip(
                      label: Text(_file!.name),
                      onDeleted: _saving ? null : () => setState(() => _file = null),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _autoPrint,
                    onChanged: (value) => setState(() => _autoPrint = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('طباعة الاستيكر تلقائيًا'),
                    subtitle: const Text('بعد إنشاء المعاملة مباشرة'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'جارٍ الحفظ...' : 'إنشاء سجل الأرشفة',
                    ),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    ),
    );
  }
}
