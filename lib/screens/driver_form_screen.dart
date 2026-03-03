import 'package:flutter/material.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/driver_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class DriverFormScreen extends StatefulWidget {
  final Driver? driverToEdit;

  const DriverFormScreen({super.key, this.driverToEdit});

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Driver? _driverToEdit;
  bool _didLoadArgs = false;

  String _vehicleType = 'شاحنة كبيرة';
  String _status = 'نشط';
  DateTime? _licenseExpiryDate;

  final List<String> _vehicleTypes = [
    'سيارة صغيرة',
    'شاحنة صغيرة',
    'شاحنة كبيرة',
    'تانكر',
    'أخرى',
  ];

  final List<String> _statuses = ['نشط', 'غير نشط', 'في إجازة', 'معلق'];

  @override
  void initState() {
    super.initState();
    _driverToEdit = widget.driverToEdit;
    if (_driverToEdit != null) {
      _initializeFormWithDriver(_driverToEdit!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadArgs) return;
    _didLoadArgs = true;

    if (_driverToEdit != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Driver) {
      _driverToEdit = args;
      _initializeFormWithDriver(args);
    }
  }

  void _initializeFormWithDriver(Driver driver) {
    _nameController.text = driver.name;
    _licenseNumberController.text = driver.licenseNumber;
    _phoneController.text = driver.phone;
    _emailController.text = driver.email ?? '';
    _addressController.text = driver.address ?? '';
    _vehicleNumberController.text = driver.vehicleNumber ?? '';
    _notesController.text = driver.notes ?? '';

    _vehicleType = driver.vehicleType;
    _status = driver.status;
    _licenseExpiryDate = driver.licenseExpiryDate;
  }

  Future<void> _pickLicenseExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
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
        _licenseExpiryDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final driverProvider = Provider.of<DriverProvider>(context, listen: false);

    final driverData = {
      'name': _nameController.text.trim(),
      'licenseNumber': _licenseNumberController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      'address': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      'vehicleType': _vehicleType,
      'vehicleNumber': _vehicleNumberController.text.trim().isNotEmpty
          ? _vehicleNumberController.text.trim()
          : null,
      'licenseExpiryDate': _licenseExpiryDate?.toIso8601String(),
      'status': _status,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    bool success;
    if (_driverToEdit != null) {
      success = await driverProvider.updateDriver(
        _driverToEdit!.id,
        driverData,
      );
    } else {
      success = await driverProvider.createDriver(driverData);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _driverToEdit != null
                ? 'تم تحديث بيانات السائق بنجاح'
                : 'تم إنشاء السائق بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(
        context,
        _driverToEdit != null ? _driverToEdit : Driver.fromJson(driverData),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(driverProvider.error ?? 'حدث خطأ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  // تحديد إذا كان العرض واسع (ويب/كمبيوتر)
  bool get _isWideScreen {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width > 768;
  }

  // تحديد إذا كان العرض كبير جداً (شاشات واسعة)
  bool get _isExtraWideScreen {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width > 1200;
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = Provider.of<DriverProvider>(context);
    final isEditing = _driverToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل السائق' : 'سائق جديد',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: !_isWideScreen,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _isExtraWideScreen
                  ? 1000
                  : _isWideScreen
                  ? 800
                  : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: _isWideScreen ? 24 : 16,
                vertical: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isWideScreen)
                      _buildWideLayout(driverProvider, isEditing)
                    else
                      _buildMobileLayout(driverProvider, isEditing),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: _isWideScreen ? 400 : double.infinity,
                      child: GradientButton(
                        onPressed: driverProvider.isLoading
                            ? null
                            : _submitForm,
                        text: driverProvider.isLoading
                            ? 'جاري الحفظ...'
                            : (isEditing ? 'تحديث السائق' : 'إنشاء السائق'),
                        gradient: AppColors.accentGradient,
                        isLoading: driverProvider.isLoading,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(DriverProvider driverProvider, bool isEditing) {
    return Column(
      children: [
        // Basic Information Card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المعلومات الأساسية',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _nameController,
                  labelText: 'اسم السائق *',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'اسم السائق مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _licenseNumberController,
                  labelText: 'رقم الرخصة *',
                  prefixIcon: Icons.card_membership,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'رقم الرخصة مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'رقم الهاتف *',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'رقم الهاتف مطلوب';
                    }
                    if (!RegExp(r'^[0-9]{10,}$').hasMatch(value)) {
                      return 'رقم هاتف غير صالح';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Vehicle Information Card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات المركبة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  label: 'نوع المركبة',
                  value: _vehicleType,
                  items: _vehicleTypes,
                  onChanged: (value) {
                    setState(() {
                      _vehicleType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _vehicleNumberController,
                  labelText: 'رقم المركبة',
                  prefixIcon: Icons.directions_car,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  label: 'تاريخ انتهاء الرخصة',
                  date: _licenseExpiryDate,
                  onTap: _pickLicenseExpiryDate,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status & Contact Card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحالة ومعلومات الاتصال',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDropdownField(
                  label: 'حالة السائق',
                  value: _status,
                  items: _statuses,
                  onChanged: (value) {
                    setState(() {
                      _status = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _addressController,
                  labelText: 'العنوان',
                  prefixIcon: Icons.location_on,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Notes Card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملاحظات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _notesController,
                  labelText: 'ملاحظات إضافية',
                  prefixIcon: Icons.note,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(DriverProvider driverProvider, bool isEditing) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                        labelText: 'اسم السائق *',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'اسم السائق مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _licenseNumberController,
                              labelText: 'رقم الرخصة *',
                              prefixIcon: Icons.card_membership,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'رقم الرخصة مطلوب';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _phoneController,
                              labelText: 'رقم الهاتف *',
                              prefixIcon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'رقم الهاتف مطلوب';
                                }
                                if (!RegExp(r'^[0-9]{10,}$').hasMatch(value)) {
                                  return 'رقم هاتف غير صالح';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات المركبة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownField(
                        label: 'نوع المركبة',
                        value: _vehicleType,
                        items: _vehicleTypes,
                        onChanged: (value) {
                          setState(() {
                            _vehicleType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _vehicleNumberController,
                        labelText: 'رقم المركبة',
                        prefixIcon: Icons.directions_car,
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        label: 'تاريخ انتهاء الرخصة',
                        date: _licenseExpiryDate,
                        onTap: _pickLicenseExpiryDate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الحالة ومعلومات الاتصال',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownField(
                        label: 'حالة السائق',
                        value: _status,
                        items: _statuses,
                        onChanged: (value) {
                          setState(() {
                            _status = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _emailController,
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _addressController,
                        labelText: 'العنوان',
                        prefixIcon: Icons.location_on,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظات',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _notesController,
                        labelText: 'ملاحظات إضافية',
                        prefixIcon: Icons.note,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mediumGray,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGray),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mediumGray,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? DateFormat('yyyy/MM/dd').format(date)
                      : 'اختر التاريخ',
                  style: TextStyle(
                    color: date != null
                        ? AppColors.darkGray
                        : AppColors.mediumGray,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
