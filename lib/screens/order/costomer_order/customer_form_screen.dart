import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/screens/tasks/task_location_picker_screen.dart';
import 'package:order_tracker/services/whatsapp_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:order_tracker/widgets/whatsapp_brand_icon.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const Map<String, String> _customerDocumentTypeLabels = {
  'commercialRecord': 'السجل التجاري',
  'energyCertificate': 'شهادة الطاقة',
  'taxCertificate': 'شهادة الضريبة',
  'safetyCertificate': 'شهادة السلامة',
  'municipalLicense': 'رخصة بلدي',
  'additionalDocument': 'مرفق إضافي',
};

class CustomerFormScreen extends StatefulWidget {
  final Customer? customerToEdit;

  const CustomerFormScreen({super.key, this.customerToEdit});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _streetController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPersonPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  bool _showDocumentSection = false;
  double? _selectedLatitude;
  double? _selectedLongitude;

  final Map<String, PlatformFile?> _documentFiles = Map.fromEntries(
    _customerDocumentTypeLabels.keys.map((key) => MapEntry(key, null)),
  );
  final List<CustomerDocument> _currentDocuments = <CustomerDocument>[];
  final Set<String> _documentIdsInProgress = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.customerToEdit != null) {
      _initializeFormWithCustomer();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    _contactPersonController.dispose();
    _contactPersonPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeFormWithCustomer() {
    final customer = widget.customerToEdit!;
    _nameController.text = customer.name;
    _codeController.text = customer.code;
    _phoneController.text = customer.phone ?? '';
    _emailController.text = customer.email ?? '';
    _addressController.text = customer.address ?? '';
    _cityController.text = customer.city ?? '';
    _areaController.text = customer.area ?? '';
    _streetController.text = customer.street ?? '';
    _postalCodeController.text = customer.postalCode ?? '';
    _contactPersonController.text = customer.contactPerson ?? '';
    _contactPersonPhoneController.text = customer.contactPersonPhone ?? '';
    _notesController.text = customer.notes ?? '';
    _selectedLatitude = customer.latitude;
    _selectedLongitude = customer.longitude;
    _showDocumentSection = customer.documents.isNotEmpty;
    _currentDocuments
      ..clear()
      ..addAll(customer.documents);
  }

  bool get _hasSelectedLocation =>
      _selectedLatitude != null && _selectedLongitude != null;

  int get _documentAttachmentCount =>
      _documentFiles.values.where((file) => file != null).length;

  bool _canUseWhatsAppTools() {
    final auth = context.read<AuthProvider>();
    return WhatsAppService.canAccessForRole(auth.user?.role);
  }

  bool _canManageExistingDocuments() {
    final auth = context.read<AuthProvider>();
    return auth.user?.role == 'owner';
  }

  bool _isDocumentActionInProgress(String documentId) {
    return _documentIdsInProgress.contains(documentId);
  }

  void _setDocumentActionInProgress(String documentId, bool inProgress) {
    setState(() {
      if (inProgress) {
        _documentIdsInProgress.add(documentId);
      } else {
        _documentIdsInProgress.remove(documentId);
      }
    });
  }

  Future<void> _pickCustomerDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _documentFiles[docType] = result.files.first;
    });
  }

  void _removeCustomerDocument(String docType) {
    setState(() {
      _documentFiles[docType] = null;
    });
  }

  void _clearDocumentSelections() {
    setState(() {
      for (final key in _documentFiles.keys) {
        _documentFiles[key] = null;
      }
    });
  }

  Future<void> _pickLocationFromMap() async {
    final result = await Navigator.of(context).push<TaskLocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => TaskLocationPickerScreen(
          initialLat: _selectedLatitude,
          initialLng: _selectedLongitude,
          initialAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      if ((result.address ?? '').trim().isNotEmpty) {
        _addressController.text = result.address!.trim();
      }
      if ((result.city ?? '').trim().isNotEmpty) {
        _cityController.text = result.city!.trim();
      }
      if ((result.district ?? '').trim().isNotEmpty) {
        _areaController.text = result.district!.trim();
      }
      if ((result.street ?? '').trim().isNotEmpty) {
        _streetController.text = result.street!.trim();
      }
      if ((result.postalCode ?? '').trim().isNotEmpty) {
        _postalCodeController.text = result.postalCode!.trim();
      }
    });
  }

  String? _mapUrl({bool directions = false}) {
    if (!_hasSelectedLocation) return null;
    final lat = _selectedLatitude!;
    final lng = _selectedLongitude!;
    return directions
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
        : 'https://www.google.com/maps?q=$lat,$lng';
  }

  Future<void> _openMap({bool directions = false}) async {
    final url = _mapUrl(directions: directions);
    if (url == null) return;

    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الخرائط')),
      );
    }
  }

  Future<void> _openDocument(CustomerDocument document) async {
    final url = document.url.trim();
    if (url.isEmpty) return;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المستند')),
      );
    }
  }

  Future<PlatformFile?> _pickReplacementDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<void> _replaceExistingDocument(CustomerDocument document) async {
    if (!_canManageExistingDocuments()) return;
    final customer = widget.customerToEdit;
    if (customer == null || document.id.isEmpty) return;

    final replacementFile = await _pickReplacementDocument();
    if (replacementFile == null || !mounted) return;

    final provider = context.read<CustomerProvider>();
    _setDocumentActionInProgress(document.id, true);

    try {
      final updatedCustomer = await provider.replaceCustomerDocument(
        customerId: customer.id,
        document: document,
        file: replacementFile,
      );

      if (!mounted) return;
      if (updatedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'تعذر استبدال المستند'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      setState(() {
        _currentDocuments
          ..clear()
          ..addAll(updatedCustomer.documents);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استبدال المستند بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } finally {
      if (mounted) {
        _setDocumentActionInProgress(document.id, false);
      }
    }
  }

  Future<void> _deleteExistingDocument(CustomerDocument document) async {
    if (!_canManageExistingDocuments()) return;
    final customer = widget.customerToEdit;
    if (customer == null || document.id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: Text(
          'هل تريد حذف "${document.label?.trim().isNotEmpty == true ? document.label : document.filename}" نهائياً؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<CustomerProvider>();
    _setDocumentActionInProgress(document.id, true);

    try {
      final updatedCustomer = await provider.deleteCustomerDocument(
        customerId: customer.id,
        documentId: document.id,
      );

      if (!mounted) return;
      if (updatedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'تعذر حذف المستند'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      setState(() {
        _currentDocuments
          ..clear()
          ..addAll(updatedCustomer.documents);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المستند بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } finally {
      if (mounted) {
        _setDocumentActionInProgress(document.id, false);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
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

  List<CustomerDocumentUpload> _prepareDocumentUploads() {
    final uploads = <CustomerDocumentUpload>[];

    _documentFiles.forEach((docType, file) {
      if (file == null) return;
      uploads.add(
        CustomerDocumentUpload(
          docType: docType,
          fileName: file.name,
          file: file,
        ),
      );
    });

    return uploads;
  }

  List<WhatsAppContact> _buildFormWhatsAppContacts() {
    final contacts = <WhatsAppContact>[];
    final seen = <String>{};

    void addContact({
      required String name,
      required String phone,
      required String subtitle,
    }) {
      final normalizedPhone = WhatsAppService.normalizePhone(phone);
      if (normalizedPhone == null) return;
      if (!seen.add(normalizedPhone)) return;
      contacts.add(
        WhatsAppContact(
          id: 'form-$normalizedPhone',
          name: name.trim(),
          phone: phone.trim(),
          source: 'form',
          subtitle: subtitle,
        ),
      );
    }

    final customerName = _nameController.text.trim();
    if (_phoneController.text.trim().isNotEmpty) {
      addContact(
        name: customerName.isEmpty ? 'العميل الحالي' : customerName,
        phone: _phoneController.text.trim(),
        subtitle: 'هاتف العميل',
      );
    }
    if (_contactPersonPhoneController.text.trim().isNotEmpty) {
      addContact(
        name: _contactPersonController.text.trim().isEmpty
            ? (customerName.isEmpty ? 'مسؤول العميل' : customerName)
            : _contactPersonController.text.trim(),
        phone: _contactPersonPhoneController.text.trim(),
        subtitle: 'هاتف المسؤول',
      );
    }

    return contacts;
  }

  List<WhatsAppContact> _mergeWhatsAppContacts(
    List<WhatsAppContact> localContacts,
    List<WhatsAppContact> remoteContacts,
  ) {
    final merged = <WhatsAppContact>[];
    final seen = <String>{};

    void add(WhatsAppContact contact) {
      final normalizedPhone = WhatsAppService.normalizePhone(contact.phone);
      if (normalizedPhone == null || !seen.add(normalizedPhone)) return;
      merged.add(contact);
    }

    for (final contact in localContacts) {
      add(contact);
    }
    for (final contact in remoteContacts) {
      add(contact);
    }
    return merged;
  }

  WhatsAppContact? _findInitialContact(
    List<WhatsAppContact> contacts, {
    String? initialPhone,
  }) {
    final normalizedInitial = WhatsAppService.normalizePhone(initialPhone);
    if (normalizedInitial == null) return null;
    for (final contact in contacts) {
      if (WhatsAppService.normalizePhone(contact.phone) == normalizedInitial) {
        return contact;
      }
    }
    return null;
  }

  Future<void> _openWhatsAppComposer({
    String? initialPhone,
    String? initialMessage,
  }) async {
    final rootContext = context;
    final localContacts = _buildFormWhatsAppContacts();
    final contactsFuture = WhatsAppService.fetchAvailableContacts();
    final searchController = TextEditingController();
    final messageController = TextEditingController(
      text: initialMessage?.trim().isNotEmpty == true
          ? initialMessage!.trim()
          : '',
    );
    final attachments = <PlatformFile>[];
    WhatsAppContact? selectedRecipient;
    var sending = false;

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return FutureBuilder<List<WhatsAppContact>>(
              future: contactsFuture,
              builder: (context, snapshot) {
                final mergedContacts = _mergeWhatsAppContacts(
                  localContacts,
                  snapshot.data ?? const <WhatsAppContact>[],
                );
                selectedRecipient ??= _findInitialContact(
                      mergedContacts,
                      initialPhone: initialPhone,
                    ) ??
                    (mergedContacts.isNotEmpty ? mergedContacts.first : null);

                final searchQuery = searchController.text.trim().toLowerCase();
                final visibleContacts = searchQuery.isEmpty
                    ? mergedContacts
                    : mergedContacts.where((contact) {
                        final name = contact.name.toLowerCase();
                        final phone = contact.phone.toLowerCase();
                        final subtitle =
                            (contact.subtitle ?? '').toLowerCase();
                        final source = contact.sourceLabel.toLowerCase();
                        return name.contains(searchQuery) ||
                            phone.contains(searchQuery) ||
                            subtitle.contains(searchQuery) ||
                            source.contains(searchQuery);
                      }).toList();

                return AlertDialog(
                  title: const Text('مراسلة واتساب'),
                  content: SizedBox(
                    width: 680,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) ...[
                            const LinearProgressIndicator(),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: searchController,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'ابحث باسم أو رقم الجوال',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: visibleContacts.isEmpty
                                ? const Center(
                                    child: Text(
                                      'لا توجد أرقام جوال متاحة حالياً',
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: visibleContacts.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final contact = visibleContacts[index];
                                      return ListTile(
                                        leading: Radio<WhatsAppContact>(
                                          value: contact,
                                          groupValue: selectedRecipient,
                                          onChanged: sending
                                              ? null
                                              : (value) {
                                                  setDialogState(() {
                                                    selectedRecipient = value;
                                                  });
                                                },
                                        ),
                                        title: Text(contact.name),
                                        subtitle: Text(
                                          '${contact.phone} • ${contact.sourceLabel}'
                                          '${contact.subtitle != null ? ' • ${contact.subtitle}' : ''}',
                                        ),
                                        selected: selectedRecipient?.id ==
                                            contact.id,
                                        onTap: sending
                                            ? null
                                            : () {
                                                setDialogState(() {
                                                  selectedRecipient = contact;
                                                });
                                              },
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: messageController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: InputDecoration(
                              labelText: 'نص الرسالة',
                              alignLabelWithHint: true,
                              helperText:
                                  'سيتم إرسال الرسالة باسم ${WhatsAppService.companyName}',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: sending
                                    ? null
                                    : () async {
                                        final result = await FilePicker.platform
                                            .pickFiles(
                                              allowMultiple: true,
                                              withData: true,
                                              type: FileType.custom,
                                              allowedExtensions: const [
                                                'jpg',
                                                'jpeg',
                                                'png',
                                                'pdf',
                                                'doc',
                                                'docx',
                                                'xls',
                                                'xlsx',
                                              ],
                                            );
                                        if (result == null ||
                                            result.files.isEmpty) {
                                          return;
                                        }
                                        setDialogState(() {
                                          attachments.addAll(result.files);
                                        });
                                      },
                                icon: const Icon(Icons.attach_file),
                                label: const Text('إرفاق مستندات وصور'),
                              ),
                              if (attachments.isNotEmpty)
                                Chip(
                                  avatar: const Icon(Icons.link, size: 18),
                                  label: Text('${attachments.length} مرفق'),
                                ),
                            ],
                          ),
                          if (attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ...attachments.map(
                              (file) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AttachmentItem(
                                  fileName: file.name,
                                  fileSize: _formatFileSize(file.size),
                                  onDelete: () {
                                    setDialogState(() {
                                      attachments.remove(file);
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
                      onPressed: sending
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final recipient = selectedRecipient;
                              if (recipient == null) {
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('اختر رقماً لإرسال الرسالة'),
                                  ),
                                );
                                return;
                              }

                              final body = messageController.text.trim();
                              if (body.isEmpty && attachments.isEmpty) {
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'أدخل نص الرسالة أو أرفق ملفاً واحداً على الأقل',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                sending = true;
                              });

                              try {
                                final uploadedAttachments =
                                    attachments.isEmpty
                                    ? const <WhatsAppAttachmentShare>[]
                                    : await WhatsAppService.uploadAttachments(
                                        folderKey:
                                            widget.customerToEdit?.id.isNotEmpty ==
                                                    true
                                                ? widget.customerToEdit!.id
                                                : 'customer-${DateTime.now().millisecondsSinceEpoch}',
                                        files: attachments,
                                      );

                                final message =
                                    WhatsAppService.buildBrandedMessage(
                                      recipientName: recipient.name,
                                      body: body,
                                      attachments: uploadedAttachments,
                                    );
                                await WhatsAppService.sendDirectMessage(
                                  phone: recipient.phone,
                                  message: message,
                                  recipientName: recipient.name,
                                );
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  SnackBar(
                                    content: Text('تعذر تجهيز الرسالة: $e'),
                                    backgroundColor: AppColors.errorRed,
                                  ),
                                );
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() {
                                    sending = false;
                                  });
                                }
                              }
                            },
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(sending ? 'جارٍ الإرسال...' : 'إرسال واتساب'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    searchController.dispose();
    messageController.dispose();
  }

  Future<void> _promptWelcomeMessage(Customer customer) async {
    if (!_canUseWhatsAppTools()) return;

    final phone = (customer.phone ?? '').trim().isNotEmpty
        ? customer.phone!.trim()
        : (customer.contactPersonPhone ?? '').trim().isNotEmpty
        ? customer.contactPersonPhone!.trim()
        : null;
    if (phone == null) return;

    final recipientName = (customer.contactPerson ?? '').trim().isNotEmpty
        ? customer.contactPerson!.trim()
        : customer.name;

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رسالة ترحيب واتساب'),
        content: Text(
          'تم إنشاء العميل بنجاح. هل تريد تجهيز رسالة ترحيب مباشرة إلى $recipientName؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );

    if (shouldSend == true && mounted) {
      await _openWhatsAppComposer(
        initialPhone: phone,
        initialMessage: WhatsAppService.buildWelcomeMessage(
          customerName: recipientName,
        ),
      );
    }
  }

  Widget _buildDocumentPicker(String docType, String label) {
    final file = _documentFiles[docType];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickCustomerDocument(docType),
              icon: const Icon(Icons.attach_file),
              label: const Text('إرفاق'),
            ),
          ],
        ),
        if (file != null) ...[
          const SizedBox(height: 6),
          AttachmentItem(
            fileName: file.name,
            fileSize: _formatFileSize(file.size),
            onDelete: () => _removeCustomerDocument(docType),
          ),
        ],
      ],
    );
  }

  Widget _buildExistingDocumentTile(CustomerDocument document) {
    final canManage =
        _canManageExistingDocuments() && widget.customerToEdit != null &&
        document.id.isNotEmpty;
    final busy = _isDocumentActionInProgress(document.id);
    final title = document.label?.trim().isNotEmpty == true
        ? '${document.label} - ${document.filename}'
        : document.filename;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: busy ? null : () => _openDocument(document),
            child: AttachmentItem(
              fileName: title,
              fileSize: busy ? 'جارٍ التنفيذ...' : 'مرفوع',
              canDelete: false,
              onDelete: () {},
            ),
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _replaceExistingDocument(document),
                    icon: const Icon(Icons.sync_alt_outlined),
                    label: const Text('استبدال'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _deleteExistingDocument(document),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _pickLocationFromMap,
          icon: const Icon(Icons.map_outlined),
          label: Text(_hasSelectedLocation ? 'تعديل الموقع' : 'اختيار من الخريطة'),
        ),
        if (_hasSelectedLocation)
          OutlinedButton.icon(
            onPressed: () => _openMap(),
            icon: const Icon(Icons.place_outlined),
            label: const Text('فتح الموقع'),
          ),
        if (_hasSelectedLocation)
          ElevatedButton.icon(
            onPressed: () => _openMap(directions: true),
            icon: const Icon(Icons.directions),
            label: const Text('الذهاب للموقع'),
          ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CustomerProvider>();

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      'email': _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      'address': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      'city': _cityController.text.trim().isNotEmpty
          ? _cityController.text.trim()
          : null,
      'area': _areaController.text.trim().isNotEmpty
          ? _areaController.text.trim()
          : null,
      'street': _streetController.text.trim().isNotEmpty
          ? _streetController.text.trim()
          : null,
      'postalCode': _postalCodeController.text.trim().isNotEmpty
          ? _postalCodeController.text.trim()
          : null,
      'latitude': _selectedLatitude,
      'longitude': _selectedLongitude,
      'contactPerson': _contactPersonController.text.trim().isNotEmpty
          ? _contactPersonController.text.trim()
          : null,
      'contactPersonPhone': _contactPersonPhoneController.text.trim().isNotEmpty
          ? _contactPersonPhoneController.text.trim()
          : null,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    if (widget.customerToEdit != null) {
      data['code'] = _codeController.text.trim();
    }

    final documentUploads = _prepareDocumentUploads();

    bool success;
    Customer? createdCustomer;
    if (widget.customerToEdit != null) {
      success = await provider.updateCustomer(widget.customerToEdit!.id, data);
    } else {
      createdCustomer = await provider.createCustomer(data);
      success = createdCustomer != null;
    }

    if (!success || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final customerId = widget.customerToEdit?.id ?? createdCustomer!.id;
    if (documentUploads.isNotEmpty) {
      final docsUploaded = await provider.uploadCustomerDocuments(
        customerId,
        documentUploads,
      );
      if (!docsUploaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'حدث خطأ أثناء رفع المستندات'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.customerToEdit != null
              ? 'تم تحديث بيانات العميل بنجاح'
              : 'تم إنشاء العميل بنجاح',
        ),
        backgroundColor: AppColors.successGreen,
      ),
    );

    if (createdCustomer != null && mounted) {
      await _promptWelcomeMessage(createdCustomer);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final isEditing = widget.customerToEdit != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final maxWidth = isDesktop ? 980.0 : double.infinity;
        final gridCols = isDesktop ? 2 : 1;
        final existingDocuments = List<CustomerDocument>.unmodifiable(
          _currentDocuments,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isEditing ? 'تعديل العميل' : 'عميل جديد',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              if (_canUseWhatsAppTools())
                IconButton(
                  tooltip: 'مراسلة واتساب',
                  onPressed: () => _openWhatsAppComposer(),
                  icon: const WhatsAppBrandIcon(size: 26),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المعلومات الأساسية',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),
                                CustomTextField(
                                  controller: _nameController,
                                  labelText: 'اسم العميل *',
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) => value == null ||
                                          value.trim().isEmpty
                                      ? 'اسم العميل مطلوب'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                if (isEditing) ...[
                                  CustomTextField(
                                    controller: _codeController,
                                    labelText: 'كود العميل',
                                    prefixIcon: Icons.code,
                                    enabled: false,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: gridCols,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 3.5,
                                  children: [
                                    CustomTextField(
                                      controller: _phoneController,
                                      labelText: 'رقم الهاتف',
                                      prefixIcon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    CustomTextField(
                                      controller: _emailController,
                                      labelText: 'البريد الإلكتروني',
                                      prefixIcon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'معلومات الاتصال',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: gridCols,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 3.5,
                                  children: [
                                    CustomTextField(
                                      controller: _contactPersonController,
                                      labelText: 'اسم الشخص المسؤول',
                                      prefixIcon: Icons.contact_page,
                                    ),
                                    CustomTextField(
                                      controller: _contactPersonPhoneController,
                                      labelText: 'هاتف الشخص المسؤول',
                                      prefixIcon: Icons.phone_android,
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'العنوان والموقع',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),
                                CustomTextField(
                                  controller: _addressController,
                                  labelText: 'العنوان التفصيلي',
                                  prefixIcon: Icons.location_on,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: gridCols,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 3.5,
                                  children: [
                                    CustomTextField(
                                      controller: _cityController,
                                      labelText: 'المدينة',
                                      prefixIcon: Icons.location_city,
                                    ),
                                    CustomTextField(
                                      controller: _areaController,
                                      labelText: 'الحي / المنطقة',
                                      prefixIcon: Icons.map_outlined,
                                    ),
                                    CustomTextField(
                                      controller: _streetController,
                                      labelText: 'الشارع',
                                      prefixIcon: Icons.route_outlined,
                                    ),
                                    CustomTextField(
                                      controller: _postalCodeController,
                                      labelText: 'الرمز البريدي',
                                      prefixIcon: Icons.markunread_mailbox_outlined,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildLocationActions(),
                                if (_hasSelectedLocation) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundGray,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'الإحداثيات: '
                                      '${_selectedLatitude!.toStringAsFixed(6)}, '
                                      '${_selectedLongitude!.toStringAsFixed(6)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _notesController,
                                  labelText: 'ملاحظات',
                                  prefixIcon: Icons.note,
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'ملف العميل والمرفقات',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: const Text(
                                    'رفع المستندات إلى Firebase ثم حفظ روابطها في النظام',
                                  ),
                                  value: _showDocumentSection,
                                  onChanged: (value) {
                                    setState(() {
                                      _showDocumentSection = value;
                                      if (!value) {
                                        _clearDocumentSelections();
                                      }
                                    });
                                  },
                                ),
                                if (_showDocumentSection) ...[
                                  if (existingDocuments.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'المستندات الحالية',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        _canManageExistingDocuments()
                                            ? 'يمكن للمالك فقط استبدال أو حذف المرفقات الحالية.'
                                            : 'الحذف والاستبدال متاحان للمالك فقط.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.mediumGray,
                                            ),
                                      ),
                                    ),
                                    ...existingDocuments.map(
                                      _buildExistingDocumentTile,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  for (final entry
                                      in _customerDocumentTypeLabels.entries)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _buildDocumentPicker(
                                        entry.key,
                                        entry.value,
                                      ),
                                    ),
                                  Text(
                                    'عدد المرفقات الجديدة: $_documentAttachmentCount',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        GradientButton(
                          onPressed: provider.isLoading ? null : _submitForm,
                          text: provider.isLoading
                              ? 'جارٍ الحفظ...'
                              : (isEditing ? 'تحديث العميل' : 'إنشاء العميل'),
                          gradient: AppColors.accentGradient,
                          isLoading: provider.isLoading,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
