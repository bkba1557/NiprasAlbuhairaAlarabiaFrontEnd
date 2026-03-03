import 'package:flutter/material.dart';
import 'package:order_tracker/models/supplier_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/supplier_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplierToEdit;

  const SupplierFormScreen({super.key, this.supplierToEdit});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _secondaryPhoneController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _commercialNumberController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankAccountNumberController =
      TextEditingController();
  final TextEditingController _bankAccountNameController =
      TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _supplierType = 'وقود';
  double _rating = 3.0;
  bool _isActive = true;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  List<String> _newDocumentPaths = [];

  final List<String> _supplierTypes = [
    'وقود',
    'صيانة',
    'خدمات لوجستية',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.supplierToEdit != null) {
      _initializeFormWithSupplier();
    } else {
      _countryController.text = 'السعودية';
    }
  }

  void _initializeFormWithSupplier() {
    final supplier = widget.supplierToEdit!;

    _nameController.text = supplier.name;
    _companyController.text = supplier.company;
    _contactPersonController.text = supplier.contactPerson;
    _emailController.text = supplier.email ?? '';
    _phoneController.text = supplier.phone;
    _secondaryPhoneController.text = supplier.secondaryPhone ?? '';
    _addressController.text = supplier.address ?? '';
    _cityController.text = supplier.city ?? '';
    _countryController.text = supplier.country ?? 'السعودية';
    _taxNumberController.text = supplier.taxNumber ?? '';
    _commercialNumberController.text = supplier.commercialNumber ?? '';
    _bankNameController.text = supplier.bankName ?? '';
    _bankAccountNumberController.text = supplier.bankAccountNumber ?? '';
    _bankAccountNameController.text = supplier.bankAccountName ?? '';
    _ibanController.text = supplier.iban ?? '';
    _notesController.text = supplier.notes ?? '';

    _supplierType = supplier.supplierType;
    _rating = supplier.rating;
    _isActive = supplier.isActive;
    _contractStartDate = supplier.contractStartDate;
    _contractEndDate = supplier.contractEndDate;
  }

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _contractStartDate = picked;
        } else {
          _contractEndDate = picked;
        }
      });
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
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

    if (result != null) {
      setState(() {
        _newDocumentPaths.addAll(result.paths.whereType<String>());
      });
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _newDocumentPaths.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final supplierProvider = Provider.of<SupplierProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final supplier = Supplier(
      id: widget.supplierToEdit?.id ?? '',
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      contactPerson: _contactPersonController.text.trim(),
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      phone: _phoneController.text.trim(),
      secondaryPhone: _secondaryPhoneController.text.trim().isNotEmpty
          ? _secondaryPhoneController.text.trim()
          : null,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      city: _cityController.text.trim().isNotEmpty
          ? _cityController.text.trim()
          : null,
      country: _countryController.text.trim(),
      taxNumber: _taxNumberController.text.trim().isNotEmpty
          ? _taxNumberController.text.trim()
          : null,
      commercialNumber: _commercialNumberController.text.trim().isNotEmpty
          ? _commercialNumberController.text.trim()
          : null,
      bankName: _bankNameController.text.trim().isNotEmpty
          ? _bankNameController.text.trim()
          : null,
      bankAccountNumber: _bankAccountNumberController.text.trim().isNotEmpty
          ? _bankAccountNumberController.text.trim()
          : null,
      bankAccountName: _bankAccountNameController.text.trim().isNotEmpty
          ? _bankAccountNameController.text.trim()
          : null,
      iban: _ibanController.text.trim().isNotEmpty
          ? _ibanController.text.trim()
          : null,
      supplierType: _supplierType,
      rating: _rating,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      isActive: _isActive,
      contractStartDate: _contractStartDate,
      contractEndDate: _contractEndDate,
      documents: [], // Will be handled by provider
      createdById: authProvider.user?.id ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool success;
    if (widget.supplierToEdit != null) {
      success = await supplierProvider.updateSupplier(
        widget.supplierToEdit!.id,
        supplier,
        _newDocumentPaths,
      );
    } else {
      success = await supplierProvider.createSupplier(
        supplier,
        _newDocumentPaths,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.supplierToEdit != null
                ? 'تم تحديث بيانات المورد بنجاح'
                : 'تم إنشاء المورد بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(supplierProvider.error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildFieldWithIcon({
    required String label,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final isEditing = widget.supplierToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل مورد' : 'مورد جديد', style: TextStyle(color: Colors.white)),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: () {
                _showDeleteDialog(context);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Card
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
                      const SizedBox(height: 16),
                      // Name
                      _buildFieldWithIcon(
                        label: 'اسم المورد',
                        icon: Icons.business,
                        color: AppColors.primaryBlue,
                        child: CustomTextField(
                          controller: _nameController,
                          labelText: '',
                          prefixIcon: null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال اسم المورد';
                            }
                            return null;
                          },
                          fieldColor: AppColors.primaryBlue.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Company
                      _buildFieldWithIcon(
                        label: 'الشركة',
                        icon: Icons.apartment,
                        color: AppColors.primaryBlue,
                        child: CustomTextField(
                          controller: _companyController,
                          labelText: '',
                          prefixIcon: null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال اسم الشركة';
                            }
                            return null;
                          },
                          fieldColor: AppColors.primaryBlue.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'جهة الاتصال',
                              icon: Icons.person,
                              color: AppColors.infoBlue,
                              child: CustomTextField(
                                controller: _contactPersonController,
                                labelText: '',
                                prefixIcon: null,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'يرجى إدخال اسم جهة الاتصال';
                                  }
                                  return null;
                                },
                                fieldColor: AppColors.infoBlue.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'نوع المورد',
                              icon: Icons.category,
                              color: AppColors.secondaryTeal,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryTeal.withOpacity(
                                    0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.lightGray,
                                  ),
                                ),
                                child: DropdownButton<String>(
                                  value: _supplierType,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: _supplierTypes.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _supplierType = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Rating
                      _buildFieldWithIcon(
                        label: 'التقييم',
                        icon: Icons.star,
                        color: AppColors.warningOrange,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _rating = index + 1.0;
                                    });
                                  },
                                  icon: Icon(
                                    index < _rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: AppColors.warningOrange,
                                    size: 30,
                                  ),
                                );
                              }),
                            ),
                            Text(
                              '${_rating.toStringAsFixed(1)} / 5.0',
                              style: TextStyle(
                                color: AppColors.warningOrange,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status
                      _buildFieldWithIcon(
                        label: 'حالة المورد',
                        icon: Icons.stairs,
                        color: _isActive
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                        child: SwitchListTile.adaptive(
                          title: Text(
                            _isActive ? 'نشط' : 'غير نشط',
                            style: TextStyle(
                              color: _isActive
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text('تفعيل أو تعطيل المورد'),
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                          activeColor: AppColors.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Contact Information Card
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'البريد الإلكتروني',
                              icon: Icons.email,
                              color: AppColors.infoBlue,
                              child: CustomTextField(
                                controller: _emailController,
                                labelText: '',
                                prefixIcon: null,
                                keyboardType: TextInputType.emailAddress,
                                fieldColor: AppColors.infoBlue.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'الهاتف',
                              icon: Icons.phone,
                              color: AppColors.infoBlue,
                              child: CustomTextField(
                                controller: _phoneController,
                                labelText: '',
                                prefixIcon: null,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'يرجى إدخال رقم الهاتف';
                                  }
                                  return null;
                                },
                                fieldColor: AppColors.infoBlue.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFieldWithIcon(
                        label: 'هاتف احتياطي',
                        icon: Icons.phone_android,
                        color: AppColors.infoBlue,
                        child: CustomTextField(
                          controller: _secondaryPhoneController,
                          labelText: '',
                          prefixIcon: null,
                          keyboardType: TextInputType.phone,
                          fieldColor: AppColors.infoBlue.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldWithIcon(
                        label: 'العنوان',
                        icon: Icons.location_on,
                        color: AppColors.infoBlue,
                        child: CustomTextField(
                          controller: _addressController,
                          labelText: '',
                          prefixIcon: null,
                          maxLines: 2,
                          fieldColor: AppColors.infoBlue.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'المدينة',
                              icon: Icons.location_city,
                              color: AppColors.infoBlue,
                              child: CustomTextField(
                                controller: _cityController,
                                labelText: '',
                                prefixIcon: null,
                                fieldColor: AppColors.infoBlue.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'البلد',
                              icon: Icons.flag,
                              color: AppColors.infoBlue,
                              child: CustomTextField(
                                controller: _countryController,
                                labelText: '',
                                prefixIcon: null,
                                fieldColor: AppColors.infoBlue.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Contract Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات العقد',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'بداية العقد',
                              icon: Icons.calendar_today,
                              color: AppColors.successGreen,
                              child: InkWell(
                                onTap: () => _pickDate(context, true),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen.withOpacity(
                                      0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.lightGray,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _contractStartDate != null
                                            ? DateFormat(
                                                'yyyy/MM/dd',
                                              ).format(_contractStartDate!)
                                            : 'اختر تاريخ',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'نهاية العقد',
                              icon: Icons.date_range,
                              color: AppColors.warningOrange,
                              child: InkWell(
                                onTap: () => _pickDate(context, false),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningOrange.withOpacity(
                                      0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.lightGray,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _contractEndDate != null
                                            ? DateFormat(
                                                'yyyy/MM/dd',
                                              ).format(_contractEndDate!)
                                            : 'اختر تاريخ',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Financial Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المعلومات المالية',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'الرقم الضريبي',
                              icon: Icons.receipt,
                              color: AppColors.secondaryTeal,
                              child: CustomTextField(
                                controller: _taxNumberController,
                                labelText: '',
                                prefixIcon: null,
                                fieldColor: AppColors.secondaryTeal.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'رقم السجل التجاري',
                              icon: Icons.business_center,
                              color: AppColors.secondaryTeal,
                              child: CustomTextField(
                                controller: _commercialNumberController,
                                labelText: '',
                                prefixIcon: null,
                                fieldColor: AppColors.secondaryTeal.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFieldWithIcon(
                        label: 'اسم البنك',
                        icon: Icons.account_balance,
                        color: AppColors.secondaryTeal,
                        child: CustomTextField(
                          controller: _bankNameController,
                          labelText: '',
                          prefixIcon: null,
                          fieldColor: AppColors.secondaryTeal.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'رقم الحساب',
                              icon: Icons.numbers,
                              color: AppColors.secondaryTeal,
                              child: CustomTextField(
                                controller: _bankAccountNumberController,
                                labelText: '',
                                prefixIcon: null,
                                fieldColor: AppColors.secondaryTeal.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFieldWithIcon(
                              label: 'اسم الحساب',
                              icon: Icons.person,
                              color: AppColors.secondaryTeal,
                              child: CustomTextField(
                                controller: _bankAccountNameController,
                                labelText: '',
                                prefixIcon: null,
                                fieldColor: AppColors.secondaryTeal.withOpacity(
                                  0.05,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFieldWithIcon(
                        label: 'رقم الآيبان',
                        icon: Icons.credit_card,
                        color: AppColors.secondaryTeal,
                        child: CustomTextField(
                          controller: _ibanController,
                          labelText: '',
                          prefixIcon: null,
                          fieldColor: AppColors.secondaryTeal.withOpacity(0.05),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Documents Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المستندات',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickDocuments,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('إضافة مستندات'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_newDocumentPaths.isEmpty &&
                          (widget.supplierToEdit?.documents.isEmpty ?? true))
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.lightGray,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 48,
                                color: AppColors.mediumGray,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مستندات',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'انقر على زر "إضافة مستندات" لرفع الملفات',
                                style: TextStyle(
                                  color: AppColors.lightGray,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      if (_newDocumentPaths.isNotEmpty ||
                          (widget.supplierToEdit?.documents.isNotEmpty ??
                              false))
                        Column(
                          children: [
                            // Existing documents from editing
                            if (widget.supplierToEdit != null)
                              ...widget.supplierToEdit!.documents.map(
                                (document) => AttachmentItem(
                                  fileName: document.filename,
                                  fileSize: 'موجود على السيرفر',
                                  onDelete: () {
                                    // TODO: Implement delete existing document
                                  },
                                  canDelete: false,
                                ),
                              ),
                            // New documents
                            ..._newDocumentPaths.asMap().entries.map(
                              (entry) => AttachmentItem(
                                fileName: entry.value.split('/').last,
                                fileSize: _formatFileSize(entry.value),
                                onDelete: () => _removeDocument(entry.key),
                                canDelete: true,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Notes Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldWithIcon(
                        label: 'ملاحظات إضافية',
                        icon: Icons.note,
                        color: AppColors.mediumGray,
                        child: CustomTextField(
                          controller: _notesController,
                          labelText: '',
                          prefixIcon: null,
                          maxLines: 4,
                          fieldColor: AppColors.backgroundGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Submit Button
              GradientButton(
                onPressed: supplierProvider.isLoading ? null : _submitForm,
                text: supplierProvider.isLoading
                    ? 'جاري الحفظ...'
                    : (isEditing ? 'تحديث المورد' : 'إنشاء المورد'),
                gradient: AppColors.accentGradient,
                isLoading: supplierProvider.isLoading,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(String path) {
    final file = File(path);
    final size = file.lengthSync();
    if (size < 1024) {
      return '${size} B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المورد'),
        content: const Text(
          'هل أنت متأكد من حذف هذا المورد؟ هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final supplierProvider = Provider.of<SupplierProvider>(
                context,
                listen: false,
              );
              final success = await supplierProvider.deleteSupplier(
                widget.supplierToEdit!.id,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف المورد بنجاح'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
