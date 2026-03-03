import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/customer_model.dart';
import 'package:order_tracker/providers/customer_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';

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
  final _contactPersonController = TextEditingController();
  final _contactPersonPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showDocumentSection = false;
  final Map<String, PlatformFile?> _documentFiles =
      Map.fromEntries(_customerDocumentTypeLabels.keys.map((key) => MapEntry(key, null)));

  @override
  void initState() {
    super.initState();
    if (widget.customerToEdit != null) {
      _initializeFormWithCustomer();
    }
  }

  void _initializeFormWithCustomer() {
    final customer = widget.customerToEdit!;
    _nameController.text = customer.name;
    _codeController.text = customer.code;
    _phoneController.text = customer.phone ?? '';
    _emailController.text = customer.email ?? '';
    _addressController.text = customer.address ?? '';
    _contactPersonController.text = customer.contactPerson ?? '';
    _contactPersonPhoneController.text = customer.contactPersonPhone ?? '';
    _notesController.text = customer.notes ?? '';
  }

  int get _documentAttachmentCount =>
      _documentFiles.values.where((file) => file != null).length;

  Future<void> _pickCustomerDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;

    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }

    final displayValue = size < 10 ? size.toStringAsFixed(1) : size.toStringAsFixed(0);
    return '$displayValue ${suffixes[index]}';
  }

  List<CustomerDocumentUpload> _prepareDocumentUploads() {
    final uploads = <CustomerDocumentUpload>[];

    _documentFiles.forEach((docType, file) {
      if (file == null || file.path == null) return;
      uploads.add(CustomerDocumentUpload(
        docType: docType,
        fileName: file.name,
        file: File(file.path!),
      ));
    });

    return uploads;
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<CustomerProvider>(context, listen: false);

    final data = {
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

    if (success && mounted) {
      final String customerId =
          widget.customerToEdit?.id ?? createdCustomer!.id;

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
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final isEditing = widget.customerToEdit != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final bool isMobile = width < 600;
        final bool isTablet = width >= 600 && width < 1024;
        final bool isDesktop = width >= 1024;

        final double maxWidth = isDesktop ? 900 : double.infinity;
        final int gridCols = isDesktop ? 2 : 1;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isEditing ? 'تعديل العميل' : 'عميل جديد',
              style: TextStyle(color: Colors.white),
            ),
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
                        /// ======================
                        /// المعلومات الأساسية
                        /// ======================
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
                                  validator: (v) => v == null || v.isEmpty
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

                        /// ======================
                        /// معلومات الاتصال
                        /// ======================
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

                        /// ======================
                        /// العنوان والملاحظات
                        /// ======================
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'العنوان والملاحظات',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),

                                CustomTextField(
                                  controller: _addressController,
                                  labelText: 'العنوان',
                                  prefixIcon: Icons.location_on,
                                  maxLines: 3,
                                ),
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
                                    'إنشاء ملف للعميل',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: const Text('جميع مستندات العميل'),
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
                                  const SizedBox(height: 12),
                                  for (final entry in _customerDocumentTypeLabels.entries)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildDocumentPicker(
                                        entry.key,
                                        entry.value,
                                      ),
                                    ),
                                  Text(
                                    'عدد المرفقات: $_documentAttachmentCount',
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

                        /// ======================
                        /// زر الحفظ
                        /// ======================
                        GradientButton(
                          onPressed: provider.isLoading ? null : _submitForm,
                          text: provider.isLoading
                              ? 'جاري الحفظ...'
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
