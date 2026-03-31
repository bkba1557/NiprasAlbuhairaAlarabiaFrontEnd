import 'package:flutter/material.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/screens/archive/archive_documents_shared.dart';
import 'package:provider/provider.dart';
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

class _ArchiveDocumentDetailsScreenState
    extends State<ArchiveDocumentDetailsScreen> {
  Map<String, dynamic>? _document;
  bool _loading = false;
  bool _savingStatus = false;
  bool _sendingHandover = false;
  bool _verifyingHandover = false;
  String? _status;
  final _handoverNoteController = TextEditingController();
  final _otpController = TextEditingController();
  List<User> _users = const [];
  User? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    _document = widget.initialDocument;
    _status = _document?['status']?.toString() ?? 'new';
    _load();
    _loadUsers();
  }

  @override
  void dispose() {
    _handoverNoteController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  User? get _currentUser => context.read<AuthProvider>().user;

  Map<String, dynamic>? get _pendingHandover =>
      _document?['pendingHandover'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(_document!['pendingHandover'] as Map)
          : _document?['pendingHandover'] is Map
              ? Map<String, dynamic>.from(_document!['pendingHandover'] as Map)
              : null;

  bool get _canRequestHandover {
    final currentUser = _currentUser;
    if (currentUser == null || _document == null) return false;
    final holderUserId = _document?['currentHolderUserId']?.toString() ?? '';
    return currentUser.hasPermission('archive_manage') ||
        holderUserId.isEmpty ||
        holderUserId == currentUser.id;
  }

  bool get _canVerifyHandover {
    final currentUser = _currentUser;
    final pending = _pendingHandover;
    if (currentUser == null || pending == null) return false;
    final recipientUserId = pending['toUserId']?.toString() ?? '';
    return currentUser.hasPermission('archive_manage') ||
        (recipientUserId.isNotEmpty && recipientUserId == currentUser.id);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final document = await ArchiveDocumentsRepository.getById(widget.documentId);
      if (!mounted) return;
      setState(() {
        _document = document;
        _status = document['status']?.toString() ?? 'new';
      });
    } catch (error) {
      if (mounted) {
        _snack('تعذر تحميل تفاصيل الأرشفة: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ArchiveDocumentsRepository.fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (_) {}
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveStatus() async {
    if (_status == null) return;
    setState(() => _savingStatus = true);
    try {
      final updated = await ArchiveDocumentsRepository.update(
        widget.documentId,
        {'status': _status},
      );
      if (!mounted) return;
      setState(() => _document = updated);
      _snack('تم تحديث الحالة');
    } catch (error) {
      if (mounted) _snack('تعذر تحديث الحالة: $error');
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _requestHandover() async {
    if (_selectedRecipient == null) {
      _snack('اختر الموظف المراد تحويل المعاملة إليه');
      return;
    }

    setState(() => _sendingHandover = true);
    try {
      final result = await ArchiveDocumentsRepository.requestHandover(
        widget.documentId,
        recipientUserId: _selectedRecipient!.id,
        note: _handoverNoteController.text,
      );
      if (!mounted) return;
      if (result['document'] is Map) {
        setState(() {
          _document = Map<String, dynamic>.from(result['document'] as Map);
        });
      } else {
        await _load();
      }
      _handoverNoteController.clear();
      _selectedRecipient = null;
      _snack(result['message']?.toString() ?? 'تم إرسال رمز الاستلام');
    } catch (error) {
      if (mounted) _snack('تعذر إرسال رمز الاستلام: $error');
    } finally {
      if (mounted) setState(() => _sendingHandover = false);
    }
  }

  Future<void> _verifyHandover() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _snack('أدخل رمز الاستلام أولًا');
      return;
    }

    setState(() => _verifyingHandover = true);
    try {
      final result = await ArchiveDocumentsRepository.verifyHandover(
        widget.documentId,
        otp: otp,
      );
      if (!mounted) return;
      if (result['document'] is Map) {
        setState(() {
          _document = Map<String, dynamic>.from(result['document'] as Map);
        });
      } else {
        await _load();
      }
      _otpController.clear();
      _snack(result['message']?.toString() ?? 'تم اعتماد الاستلام');
    } catch (error) {
      if (mounted) _snack('تعذر اعتماد الاستلام: $error');
    } finally {
      if (mounted) setState(() => _verifyingHandover = false);
    }
  }

  Future<void> _pickRecipient() async {
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
              title: const Text('اختيار الموظف المستلم'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: applyFilter,
                      decoration: const InputDecoration(
                        hintText: 'بحث بالاسم أو البريد أو الدور',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
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
    setState(() => _selectedRecipient = selected);
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final url = ArchiveDocsUi.attachmentUrl(attachment);
    if (url == null) return _snack('رابط المرفق غير متاح');
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
    );
    if (!launched) {
      _snack('تعذر فتح المرفق');
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value.toString());
    if (parsed == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)} ${two(parsed.hour)}:${two(parsed.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final attachments = (document?['attachments'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final pagePadding = ArchiveDocsLayout.pagePadding(context);
    final maxWidth = ArchiveDocsLayout.maxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('تفاصيل المعاملة'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && document == null
          ? const Center(child: CircularProgressIndicator())
          : document == null
              ? const Center(child: Text('لا توجد بيانات لهذه المعاملة'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: pagePadding,
                        children: [
                          _buildResponsiveHeaderCard(document),
                          const SizedBox(height: 12),
                          _buildHandoverSection(document),
                          const SizedBox(height: 12),
                          _buildMovementHistory(document),
                          const SizedBox(height: 12),
                          _buildAttachmentsSection(attachments),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildResponsiveHeaderCard(Map<String, dynamic> document) {
    final isPhone = ArchiveDocsLayout.isPhone(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: ArchiveDocsLayout.cardRadius(context),
        side: BorderSide(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(ArchiveDocsUi.typeWithClassLabel(document))),
                Chip(
                  label: Text(
                    document['statusLabel']?.toString() ??
                        ArchiveDocsUi.statusLabel(document['status']?.toString()),
                  ),
                ),
                Chip(label: Text('رقم: ${document['documentNumber'] ?? '-'}')),
                Chip(label: Text('سيريال: ${document['serialNumber'] ?? '-'}')),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              document['subject']?.toString().isNotEmpty == true
                  ? document['subject'].toString()
                  : 'بدون موضوع',
              style: TextStyle(
                fontSize: isPhone ? 18 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1100 ? 3 : width >= 700 ? 2 : 1;
                final itemWidth = columns == 1
                    ? width
                    : (width - (12 * (columns - 1))) / columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'القسم',
                        document['departmentName']?.toString() ?? '-',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'الأرشيف',
                        document['archiveName']?.toString() ?? '-',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'الدوسيه',
                        ArchiveDocsUi.dossierLabel(document),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'المكتب',
                        document['officeName']?.toString() ?? '-',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'الرف',
                        document['shelfNumber']?.toString() ??
                            document['archiveShelf']?.toString() ??
                            '-',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'المستلم الحالي',
                        document['currentHolderName']?.toString() ?? '-',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'البريد الحالي',
                        document['currentHolderEmail']?.toString().isNotEmpty == true
                            ? document['currentHolderEmail'].toString()
                            : '-',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'آخر استلام',
                        '${document['lastReceivedByName'] ?? '-'} • ${_formatDateTime(document['lastReceivedAt'])}',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildInfoTile(
                        'ملاحظات الموقع',
                        document['locationNote']?.toString().isNotEmpty == true
                            ? document['locationNote'].toString()
                            : '-',
                      ),
                    ),
                  ],
                );
              },
            ),
            if ((document['notes'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoTile('ملاحظات', document['notes'].toString()),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isPhone ? 280 : 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status ?? 'new',
                    decoration: ArchiveDocsLayout.inputDecoration(
                      context,
                      label: 'تحديث الحالة',
                    ),
                    items: ArchiveDocsUi.statusOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item['value']!,
                            child: Text(item['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _savingStatus ? null : _saveStatus,
                  icon: _savingStatus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ الحالة'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ArchiveStickerPrinter.printDocument(document),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة الاستيكر'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> document) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(ArchiveDocsUi.typeWithClassLabel(document))),
                Chip(
                  label: Text(
                    document['statusLabel']?.toString() ??
                        ArchiveDocsUi.statusLabel(
                          document['status']?.toString(),
                        ),
                  ),
                ),
                Chip(label: Text('رقم: ${document['documentNumber'] ?? '-'}')),
                Chip(label: Text('سيريال: ${document['serialNumber'] ?? '-'}')),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow('الموضوع', document['subject']?.toString() ?? '-'),
            _detailRow('القسم', document['departmentName']?.toString() ?? '-'),
            _detailRow('الأرشيف', document['archiveName']?.toString() ?? '-'),
            _detailRow('الدوسيه', ArchiveDocsUi.dossierLabel(document)),
            _detailRow('المكتب', document['officeName']?.toString() ?? '-'),
            _detailRow(
              'الرف',
              document['shelfNumber']?.toString() ??
                  document['archiveShelf']?.toString() ??
                  '-',
            ),
            _detailRow(
              'المستلم الحالي',
              document['currentHolderName']?.toString() ?? '-',
            ),
            _detailRow(
              'البريد الحالي',
              document['currentHolderEmail']?.toString().isNotEmpty == true
                  ? document['currentHolderEmail'].toString()
                  : '-',
            ),
            _detailRow(
              'آخر استلام',
              '${document['lastReceivedByName'] ?? '-'} • ${_formatDateTime(document['lastReceivedAt'])}',
            ),
            _detailRow(
              'ملاحظات الموقع',
              document['locationNote']?.toString().isNotEmpty == true
                  ? document['locationNote'].toString()
                  : '-',
            ),
            _detailRow(
              'ملاحظات',
              document['notes']?.toString().isNotEmpty == true
                  ? document['notes'].toString()
                  : '-',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status ?? 'new',
                    decoration: const InputDecoration(
                      labelText: 'تحديث الحالة',
                      border: OutlineInputBorder(),
                    ),
                    items: ArchiveDocsUi.statusOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item['value']!,
                            child: Text(item['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _savingStatus ? null : _saveStatus,
                  icon: _savingStatus
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ الحالة'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ArchiveStickerPrinter.printDocument(document),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة الاستيكر'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandoverSection(Map<String, dynamic> document) {
    final pending = _pendingHandover;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تحويل المعاملة بين الموظفين',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (pending != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'طلب تسليم معلق إلى ${pending['toName'] ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('من: ${pending['fromName'] ?? '-'}'),
                    Text('البريد: ${pending['maskedEmail'] ?? '-'}'),
                    Text('وقت الطلب: ${_formatDateTime(pending['requestedAt'])}'),
                    Text('ينتهي: ${_formatDateTime(pending['expiresAt'])}'),
                    if ((pending['note'] ?? '').toString().trim().isNotEmpty)
                      Text('ملاحظة: ${pending['note']}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_canRequestHandover) ...[
              OutlinedButton.icon(
                onPressed: _pickRecipient,
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('اختيار الموظف المستلم'),
              ),
              if (_selectedRecipient != null) ...[
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
                              _selectedRecipient!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_selectedRecipient!.email} • ${_selectedRecipient!.role}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _handoverNoteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة التسليم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _sendingHandover ? null : _requestHandover,
                icon: _sendingHandover
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_to_mobile_outlined),
                label: const Text('إرسال رمز الاستلام'),
              ),
            ],
            if (_canVerifyHandover) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق للاستلام',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _verifyingHandover ? null : _verifyHandover,
                icon: _verifyingHandover
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: const Text('اعتماد الاستلام'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMovementHistory(Map<String, dynamic> document) {
    final history = (document['movementHistory'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'سجل الحركة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (history.isEmpty)
              const Text('لا توجد حركات مسجلة بعد')
            else
              ...history.map((movement) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        movement['actionLabel']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('المنفذ: ${movement['performedByName'] ?? '-'}'),
                      if ((movement['fromName'] ?? '').toString().isNotEmpty)
                        Text('من: ${movement['fromName']}'),
                      if ((movement['toName'] ?? '').toString().isNotEmpty)
                        Text('إلى: ${movement['toName']}'),
                      if ((movement['note'] ?? '').toString().isNotEmpty)
                        Text('ملاحظة: ${movement['note']}'),
                      Text('الوقت: ${_formatDateTime(movement['happenedAt'])}'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(List<Map<String, dynamic>> attachments) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'المرفقات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (attachments.isEmpty)
              const Text('لا توجد مرفقات')
            else
              ...attachments.map((attachment) => _attachmentTile(attachment)),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(Map<String, dynamic> attachment) {
    final url = ArchiveDocsUi.attachmentUrl(attachment);
    final isImage = ArchiveDocsUi.isImageAttachment(attachment);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isImage && url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (isImage && url != null) const SizedBox(height: 10),
          Text(
            (attachment['originalName'] ?? attachment['filename'] ?? '-')
                .toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAttachment(attachment),
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
