import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/services/whatsapp_service.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/attachment_item.dart';

class WhatsAppComposeDialog extends StatefulWidget {
  final List<WhatsAppContact> initialContacts;
  final String? initialPhone;
  final String? initialMessage;
  final String? folderKey;
  final String title;

  const WhatsAppComposeDialog({
    super.key,
    this.initialContacts = const <WhatsAppContact>[],
    this.initialPhone,
    this.initialMessage,
    this.folderKey,
    this.title = 'مراسلة واتساب',
  });

  static Future<void> show(
    BuildContext context, {
    List<WhatsAppContact> initialContacts = const <WhatsAppContact>[],
    String? initialPhone,
    String? initialMessage,
    String? folderKey,
    String title = 'مراسلة واتساب',
  }) {
    final navigatorContext = appNavigatorKey.currentContext ?? context;
    return showDialog<void>(
      context: navigatorContext,
      useRootNavigator: true,
      builder: (_) => WhatsAppComposeDialog(
        initialContacts: initialContacts,
        initialPhone: initialPhone,
        initialMessage: initialMessage,
        folderKey: folderKey,
        title: title,
      ),
    );
  }

  @override
  State<WhatsAppComposeDialog> createState() => _WhatsAppComposeDialogState();
}

class _WhatsAppComposeDialogState extends State<WhatsAppComposeDialog> {
  late final Future<List<WhatsAppContact>> _contactsFuture;
  late final TextEditingController _searchController;
  late final TextEditingController _messageController;

  final List<PlatformFile> _attachments = <PlatformFile>[];
  final Set<String> _selectedRecipientIds = <String>{};

  bool _sending = false;
  bool _seededInitialSelection = false;

  @override
  void initState() {
    super.initState();
    _contactsFuture = WhatsAppService.fetchAvailableContacts();
    _searchController = TextEditingController();
    _messageController = TextEditingController(
      text: widget.initialMessage?.trim().isNotEmpty == true
          ? widget.initialMessage!.trim()
          : '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  List<WhatsAppContact> _mergeContacts(List<WhatsAppContact> remoteContacts) {
    final merged = <WhatsAppContact>[];
    final seenPhones = <String>{};

    void addContact(WhatsAppContact contact) {
      final normalizedPhone = WhatsAppService.normalizePhone(contact.phone);
      if (normalizedPhone == null || !seenPhones.add(normalizedPhone)) return;
      merged.add(contact);
    }

    for (final contact in widget.initialContacts) {
      addContact(contact);
    }
    for (final contact in remoteContacts) {
      addContact(contact);
    }

    return merged;
  }

  WhatsAppContact? _findInitialContact(List<WhatsAppContact> contacts) {
    final normalizedInitial = WhatsAppService.normalizePhone(widget.initialPhone);
    if (normalizedInitial == null) return null;

    for (final contact in contacts) {
      if (WhatsAppService.normalizePhone(contact.phone) == normalizedInitial) {
        return contact;
      }
    }

    return null;
  }

  void _seedSelectionIfNeeded(List<WhatsAppContact> contacts) {
    if (_seededInitialSelection) return;
    _seededInitialSelection = true;

    final initialContact = _findInitialContact(contacts);
    if (initialContact != null) {
      _selectedRecipientIds.add(initialContact.id);
      return;
    }

    if (widget.initialContacts.length == 1) {
      _selectedRecipientIds.add(widget.initialContacts.first.id);
    }
  }

  List<WhatsAppContact> _selectedRecipients(List<WhatsAppContact> contacts) {
    return contacts
        .where((contact) => _selectedRecipientIds.contains(contact.id))
        .toList();
  }

  void _toggleRecipient(WhatsAppContact contact, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecipientIds.add(contact.id);
      } else {
        _selectedRecipientIds.remove(contact.id);
      }
    });
  }

  void _selectVisibleRecipients(List<WhatsAppContact> contacts) {
    setState(() {
      _selectedRecipientIds.addAll(contacts.map((contact) => contact.id));
    });
  }

  void _clearSelection() {
    setState(_selectedRecipientIds.clear);
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = <String>['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;

    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }

    final displayValue = size < 10
        ? size.toStringAsFixed(1)
        : size.toStringAsFixed(0);
    return '$displayValue ${suffixes[index]}';
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() {
      _attachments.addAll(result.files);
    });
  }

  Future<void> _sendMessage(List<WhatsAppContact> contacts) async {
    final selectedRecipients = _selectedRecipients(contacts);
    if (selectedRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مستلماً واحداً على الأقل')),
      );
      return;
    }

    final body = _messageController.text.trim();
    if (body.isEmpty && _attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل نص الرسالة أو أرفق ملفاً واحداً على الأقل'),
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(
      appNavigatorKey.currentContext ?? context,
    );

    try {
      final resolvedFolderKey =
          widget.folderKey?.trim().isNotEmpty == true
          ? widget.folderKey!.trim()
          : 'whatsapp-${DateTime.now().millisecondsSinceEpoch}';

      final uploadedAttachments = _attachments.isEmpty
          ? const <WhatsAppAttachmentShare>[]
          : await WhatsAppService.uploadAttachments(
              folderKey: resolvedFolderKey,
              files: _attachments,
            );
      final response = await WhatsAppService.sendDirectMessages(
        messages: selectedRecipients
            .map(
              (recipient) => WhatsAppOutboundMessage(
                phone: recipient.phone,
                recipientName: recipient.name,
                text: WhatsAppService.buildBrandedMessage(
                  recipientName: recipient.name,
                  body: body,
                  attachments: uploadedAttachments,
                ),
              ),
            )
            .toList(),
      );

      final summary = response['summary'];
      final sentCount = summary is Map<String, dynamic>
          ? (summary['sent'] is int
                ? summary['sent'] as int
                : int.tryParse(summary['sent']?.toString() ?? '') ?? 0)
          : selectedRecipients.length;
      final failedCount = summary is Map<String, dynamic>
          ? (summary['failed'] is int
                ? summary['failed'] as int
                : int.tryParse(summary['failed']?.toString() ?? '') ?? 0)
          : 0;

      if (!mounted) return;

      Navigator.of(context).pop();

      final successMessage = selectedRecipients.length == 1
          ? 'تم إرسال الرسالة عبر واتساب بنجاح'
          : 'تم إرسال الرسالة إلى $sentCount من ${selectedRecipients.length} مستلمين';

      final partialFailureMessage = failedCount == 0
          ? successMessage
          : '$successMessage، وتعذر إرسال $failedCount مستلمين.';

      Future<void>.delayed(Duration.zero, () {
        messenger?.showSnackBar(SnackBar(content: Text(partialFailureMessage)));
      });
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('تعذر تجهيز الرسالة: $error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WhatsAppContact>>(
      future: _contactsFuture,
      builder: (context, snapshot) {
        final mergedContacts = _mergeContacts(
          snapshot.data ?? const <WhatsAppContact>[],
        );
        _seedSelectionIfNeeded(mergedContacts);

        final searchQuery = _searchController.text.trim().toLowerCase();
        final visibleContacts = searchQuery.isEmpty
            ? mergedContacts
            : mergedContacts.where((contact) {
                final name = contact.name.toLowerCase();
                final phone = contact.phone.toLowerCase();
                final subtitle = (contact.subtitle ?? '').toLowerCase();
                final source = contact.sourceLabel.toLowerCase();
                return name.contains(searchQuery) ||
                    phone.contains(searchQuery) ||
                    subtitle.contains(searchQuery) ||
                    source.contains(searchQuery);
              }).toList();
        final selectedCount = _selectedRecipients(mergedContacts).length;

        return AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'ابحث بالاسم أو رقم الجوال',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedCount == 0
                              ? 'لم يتم تحديد أي مستلم'
                              : 'تم تحديد $selectedCount مستلمين',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _sending || visibleContacts.isEmpty
                            ? null
                            : () => _selectVisibleRecipients(visibleContacts),
                        child: const Text('تحديد النتائج'),
                      ),
                      TextButton(
                        onPressed: _sending || _selectedRecipientIds.isEmpty
                            ? null
                            : _clearSelection,
                        child: const Text('إلغاء التحديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: visibleContacts.isEmpty
                        ? const Center(
                            child: Text('لا توجد أرقام جوال متاحة حالياً'),
                          )
                        : ListView.separated(
                            itemCount: visibleContacts.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final contact = visibleContacts[index];
                              final isSelected = _selectedRecipientIds.contains(
                                contact.id,
                              );

                              return CheckboxListTile(
                                value: isSelected,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: _sending
                                    ? null
                                    : (value) => _toggleRecipient(
                                          contact,
                                          value ?? false,
                                        ),
                                title: Text(contact.name),
                                subtitle: Text(
                                  '${contact.phone} • ${contact.sourceLabel}'
                                  '${contact.subtitle != null ? ' • ${contact.subtitle}' : ''}',
                                ),
                                dense: true,
                                activeColor: AppColors.primaryBlue,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'نص الرسالة',
                      alignLabelWithHint: true,
                      helperText:
                          'سيتم تجهيز نفس الرسالة لكل المستلمين باسم ${AppStrings.appName}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sending ? null : _pickAttachments,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('إرفاق ملفات'),
                      ),
                      if (_attachments.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.link, size: 18),
                          label: Text('${_attachments.length} مرفق'),
                        ),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._attachments.map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AttachmentItem(
                          fileName: file.name,
                          fileSize: _formatFileSize(file.size),
                          onDelete: () {
                            setState(() {
                              _attachments.remove(file);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'المرفقات سترفع إلى Firebase ويُرسل رابطها داخل رسالة واتساب.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: _sending ? null : () => _sendMessage(mergedContacts),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال واتساب'),
            ),
          ],
        );
      },
    );
  }
}
