import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/vehicle_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/vehicle_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/driver_user_service.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';

class DriverFormScreen extends StatefulWidget {
  final Driver? driverToEdit;

  const DriverFormScreen({super.key, this.driverToEdit});

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _driverUsernameController =
      TextEditingController();
  final TextEditingController _driverPasswordController =
      TextEditingController();

  Driver? _driverToEdit;
  User? _linkedDriverUser;
  bool _didLoadArgs = false;
  bool _isLoadingLinkedUser = false;

  String? _selectedVehicleId;
  String _status = 'نشط';
  DateTime? _licenseExpiryDate;
  DateTime? _iqamaIssueDate;
  DateTime? _iqamaExpiryDate;
  DateTime? _insuranceExpiryDate;
  DateTime? _operationCardExpiryDate;

  final List<String> _statuses = [
    'نشط',
    'غير نشط',
    'في إجازة',
    'مرفوض',
    'معلق',
  ];

  @override
  void initState() {
    super.initState();
    _driverToEdit = widget.driverToEdit;
    if (_driverToEdit != null) {
      _initializeFormWithDriver(_driverToEdit!);
    }
    _setSuggestedDriverUsername(force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureVehiclesLoaded());
      unawaited(_loadLinkedDriverUser());
    });
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
      _setSuggestedDriverUsername(force: true);
      unawaited(_loadLinkedDriverUser());
    }
  }

  Vehicle? get _selectedVehicle {
    return context.read<VehicleProvider>().findById(_selectedVehicleId);
  }

  Future<void> _ensureVehiclesLoaded() async {
    final vehicleProvider = context.read<VehicleProvider>();
    if (vehicleProvider.vehicles.isEmpty && !vehicleProvider.isLoading) {
      await vehicleProvider.fetchVehicles();
    }
    if (!mounted) return;
    setState(() {});
  }

  void _initializeFormWithDriver(Driver driver) {
    _nameController.text = driver.name;
    _nationalIdController.text = driver.nationalId ?? '';
    _licenseNumberController.text = driver.licenseNumber;
    _phoneController.text = driver.phone;
    _emailController.text = driver.email ?? '';
    _addressController.text = driver.address ?? '';
    _notesController.text = driver.notes ?? '';
    _selectedVehicleId = driver.linkedVehicleId;
    _status = driver.status;
    _licenseExpiryDate = driver.licenseExpiryDate;
    _iqamaIssueDate = driver.iqamaIssueDate;
    _iqamaExpiryDate = driver.iqamaExpiryDate;
    _insuranceExpiryDate = driver.insuranceExpiryDate;
    _operationCardExpiryDate = driver.operationCardExpiryDate;
  }

  Future<void> _loadLinkedDriverUser() async {
    final driverId = _driverToEdit?.id;
    if (driverId == null || driverId.isEmpty) {
      _setSuggestedDriverUsername(force: true);
      return;
    }

    setState(() {
      _isLoadingLinkedUser = true;
    });

    try {
      final linkedUser = await findDriverUserByDriverId(driverId);
      if (!mounted) return;

      setState(() {
        _linkedDriverUser = linkedUser;
        if (linkedUser != null && linkedUser.username.trim().isNotEmpty) {
          _driverUsernameController.text = linkedUser.username.trim();
        }
        final linkedEmail = linkedUser?.email.trim() ?? '';
        if (linkedEmail.isNotEmpty &&
            (_emailController.text.trim().isEmpty ||
                _isLegacyGeneratedDriverEmail(_emailController.text))) {
          _emailController.text = linkedEmail;
        }
        if (linkedUser == null) {
          _setSuggestedDriverUsername(force: true);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _setSuggestedDriverUsername(force: true);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLinkedUser = false;
        });
      }
    }
  }

  String _usernameVehicleNumber() {
    final vehicle = _selectedVehicle;
    if (vehicle != null && vehicle.plateNumber.trim().isNotEmpty) {
      return vehicle.plateNumber.trim();
    }
    return _driverToEdit?.linkedVehiclePlateNumber?.trim() ?? '';
  }

  void _setSuggestedDriverUsername({bool force = false}) {
    if (!force && _driverUsernameController.text.trim().isNotEmpty) {
      return;
    }

    _driverUsernameController.text = suggestedDriverTruckUsername(
      vehicleNumber: _usernameVehicleNumber(),
      licenseNumber: _licenseNumberController.text,
      phone: _phoneController.text,
    );
  }

  bool _isLegacyGeneratedDriverEmail(String value) {
    return value.trim().toLowerCase().endsWith('@driver-truck.local');
  }

  String? _validateDriverAccountEmail(String? value) {
    final rawValue = (value ?? '').trim();
    if (rawValue.isEmpty) {
      return 'بريد حساب السائق مطلوب';
    }
    if (_isLegacyGeneratedDriverEmail(rawValue)) {
      return 'أدخل بريدًا حقيقيًا ليستقبل السائق رمز التحقق';
    }
    if (!isValidDriverAccountEmail(rawValue)) {
      return 'أدخل بريدًا إلكترونيًا صالحًا';
    }
    return null;
  }

  Future<void> _pickDate({
    required DateTime? currentValue,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          currentValue ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
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
        onPicked(picked);
      });
    }
  }

  Future<void> _pickLicenseExpiryDate() async {
    await _pickDate(
      currentValue: _licenseExpiryDate,
      onPicked: (value) => _licenseExpiryDate = value,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final wasEditing = _driverToEdit != null;
    final authProvider = context.read<AuthProvider>();
    final driverProvider = context.read<DriverProvider>();
    final normalizedUsername = normalizeDriverTruckUsername(
      _driverUsernameController.text,
    );
    final password = _driverPasswordController.text.trim();
    final accountEmail = normalizeDriverAccountEmail(_emailController.text);
    final company = authProvider.user?.company.trim() ?? '';
    final selectedVehicle = _selectedVehicle;

    if (company.isEmpty) {
      _showErrorSnack('تعذر تحديد الشركة الحالية لإنشاء حساب السائق');
      return;
    }

    if (_isLegacyGeneratedDriverEmail(accountEmail) ||
        !isValidDriverAccountEmail(accountEmail)) {
      _showErrorSnack('أدخل بريدًا إلكترونيًا صالحًا لاستقبال رمز التحقق');
      return;
    }

    if (_linkedDriverUser == null && password.isEmpty) {
      _showErrorSnack('كلمة مرور حساب السائق مطلوبة عند إنشاء الحساب لأول مرة');
      return;
    }

    if (_iqamaIssueDate != null &&
        _iqamaExpiryDate != null &&
        _iqamaIssueDate!.isAfter(_iqamaExpiryDate!)) {
      _showErrorSnack('تاريخ إصدار الإقامة يجب أن يكون قبل تاريخ الانتهاء');
      return;
    }

    final driverData = {
      'name': _nameController.text.trim(),
      'nationalId': _nationalIdController.text.trim(),
      'licenseNumber': _licenseNumberController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': accountEmail,
      'address': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      'vehicleType': selectedVehicle?.vehicleType ?? 'غير محدد',
      'vehicleStatus': selectedVehicle?.status ?? 'فاضي',
      'vehicleNumber': selectedVehicle?.plateNumber,
      'linkedVehicleId': _selectedVehicleId,
      'licenseExpiryDate': _licenseExpiryDate?.toIso8601String(),
      'iqamaIssueDate': _iqamaIssueDate?.toIso8601String(),
      'iqamaExpiryDate': _iqamaExpiryDate?.toIso8601String(),
      'insuranceExpiryDate': _insuranceExpiryDate?.toIso8601String(),
      'operationCardExpiryDate': _operationCardExpiryDate?.toIso8601String(),
      'status': _status,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    bool success;
    if (wasEditing) {
      success = await driverProvider.updateDriver(_driverToEdit!.id, driverData);
    } else {
      success = await driverProvider.createDriver(driverData);
    }

    if (!success) {
      _showErrorSnack(driverProvider.error ?? 'حدث خطأ أثناء حفظ السائق');
      return;
    }

    final savedDriver = driverProvider.selectedDriver;
    if (savedDriver == null || savedDriver.id.isEmpty) {
      _showErrorSnack('تم حفظ السائق لكن تعذر قراءة البيانات المحدثة');
      return;
    }

    try {
      final linkedUser = await upsertDriverUser(
        driver: savedDriver,
        username: normalizedUsername,
        email: accountEmail,
        company: company,
        existingUser: _linkedDriverUser,
        password: password.isEmpty ? null : password,
      );

      if (!mounted) return;
      setState(() {
        _driverToEdit = savedDriver;
        _linkedDriverUser = linkedUser;
        _driverUsernameController.text = linkedUser.username;
        _driverPasswordController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasEditing
                ? 'تم تحديث السائق وربط حساب ${linkedUser.username}'
                : 'تم إنشاء السائق وحساب ${linkedUser.username}',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, savedDriver);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _driverToEdit = savedDriver;
      });
      _showErrorSnack(
        'تم حفظ السائق لكن تعذر حفظ حساب driver_truck: $error',
      );
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  bool get _isWideScreen => MediaQuery.of(context).size.width > 900;

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _driverUsernameController.dispose();
    _driverPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();
    final isEditing = _driverToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل السائق' : 'سائق جديد',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isWideScreen)
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: 520,
                            child: _buildBasicInfoCard(),
                          ),
                          SizedBox(
                            width: 520,
                            child: _buildVehicleLinkCard(vehicleProvider),
                          ),
                          SizedBox(
                            width: 520,
                            child: _buildStatusCard(),
                          ),
                          SizedBox(
                            width: 520,
                            child: _buildDocumentsCard(),
                          ),
                          SizedBox(
                            width: 520,
                            child: _buildDriverUserCard(),
                          ),
                          SizedBox(
                            width: 520,
                            child: _buildNotesCard(),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildBasicInfoCard(),
                          const SizedBox(height: 16),
                          _buildVehicleLinkCard(vehicleProvider),
                          const SizedBox(height: 16),
                          _buildStatusCard(),
                          const SizedBox(height: 16),
                          _buildDocumentsCard(),
                          const SizedBox(height: 16),
                          _buildDriverUserCard(),
                          const SizedBox(height: 16),
                          _buildNotesCard(),
                        ],
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: _isWideScreen ? 360 : double.infinity,
                      child: GradientButton(
                        onPressed: driverProvider.isLoading ? null : _submitForm,
                        text: driverProvider.isLoading
                            ? 'جاري الحفظ...'
                            : (isEditing ? 'تحديث السائق' : 'إنشاء السائق'),
                        gradient: AppColors.accentGradient,
                        isLoading: driverProvider.isLoading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildCard(
      title: 'البيانات الأساسية',
      icon: Icons.person_outline,
      children: [
        CustomTextField(
          controller: _nameController,
          labelText: 'اسم السائق *',
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'اسم السائق مطلوب';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _nationalIdController,
          labelText: 'رقم الهوية *',
          prefixIcon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'رقم الهوية مطلوب';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _licenseNumberController,
          labelText: 'رقم الرخصة *',
          prefixIcon: Icons.card_membership_outlined,
          onChanged: (_) => _setSuggestedDriverUsername(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'رقم الرخصة مطلوب';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _phoneController,
          labelText: 'رقم الهاتف *',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _setSuggestedDriverUsername(),
          validator: (value) {
            final phone = value?.trim() ?? '';
            if (phone.isEmpty) {
              return 'رقم الهاتف مطلوب';
            }
            if (!RegExp(r'^[0-9]{10,}$').hasMatch(phone)) {
              return 'رقم هاتف غير صالح';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildVehicleLinkCard(VehicleProvider vehicleProvider) {
    final vehicles = List<Vehicle>.from(vehicleProvider.vehicles)
      ..sort((a, b) => a.plateNumber.compareTo(b.plateNumber));
    final selectedVehicle = _selectedVehicle;

    final hasSelectedValue =
        _selectedVehicleId != null &&
        vehicles.any((vehicle) => vehicle.id == _selectedVehicleId);

    return _buildCard(
      title: 'ربط السيارة',
      icon: Icons.local_taxi_outlined,
      children: [
        DropdownButtonFormField<String?>(
          value: hasSelectedValue ? _selectedVehicleId : null,
          decoration: const InputDecoration(
            labelText: 'السيارة المرتبطة',
            prefixIcon: Icon(Icons.directions_car_filled_outlined),
            helperText: 'اختر سيارة مسجلة ليتم ربط السائق بها تلقائيًا',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('بدون ربط حاليًا'),
            ),
            ...vehicles.map(
              (vehicle) => DropdownMenuItem<String?>(
                value: vehicle.id,
                child: Text(
                  vehicle.optionLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: vehicleProvider.isLoading
              ? null
              : (value) {
                  setState(() {
                    _selectedVehicleId = value;
                    _setSuggestedDriverUsername(force: true);
                  });
                },
        ),
        if (vehicleProvider.isLoading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (vehicleProvider.error != null) ...[
          const SizedBox(height: 12),
          Text(
            vehicleProvider.error!,
            style: const TextStyle(
              color: AppColors.errorRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _buildInfoBanner(
          icon: Icons.info_outline,
          title: selectedVehicle == null
              ? 'لا توجد سيارة مرتبطة'
              : 'السيارة الحالية: ${selectedVehicle.plateNumber}',
          subtitle: selectedVehicle == null
              ? 'يمكنك حفظ السائق الآن وربطه بالسيارة لاحقًا من نفس الشاشة أو من شاشة السيارات.'
              : [
                  selectedVehicle.vehicleType,
                  selectedVehicle.status,
                  if (selectedVehicle.model.trim().isNotEmpty)
                    selectedVehicle.model.trim(),
                ].join(' • '),
        ),
        if (selectedVehicle != null) ...[
          const SizedBox(height: 12),
          _buildSummaryLine(
            icon: Icons.person_pin_outlined,
            label: 'السائق المرتبط الآن',
            value: selectedVehicle.linkedDriver?.name.trim().isNotEmpty == true
                ? selectedVehicle.linkedDriver!.name.trim()
                : 'غير مرتبط',
          ),
          const SizedBox(height: 8),
          _buildSummaryLine(
            icon: Icons.local_shipping_outlined,
            label: 'الصهريج المرتبط',
            value: selectedVehicle.linkedTanker?.number.trim().isNotEmpty ==
                    true
                ? selectedVehicle.linkedTanker!.number.trim()
                : 'غير مرتبط',
          ),
        ],
      ],
    );
  }

  Widget _buildStatusCard() {
    final selectedVehicle = _selectedVehicle;

    return _buildCard(
      title: 'الحالة والتواصل',
      icon: Icons.assignment_ind_outlined,
      children: [
        DropdownButtonFormField<String>(
          value: _statuses.contains(_status) ? _status : _statuses.first,
          decoration: const InputDecoration(
            labelText: 'حالة السائق',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          items: _statuses
              .map(
                (status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _status = value ?? _statuses.first;
            });
          },
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _pickLicenseExpiryDate,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'انتهاء رخصة القيادة',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            child: Text(
              _licenseExpiryDate == null
                  ? 'اختر التاريخ'
                  : DateFormat('yyyy/MM/dd').format(_licenseExpiryDate!),
              style: TextStyle(
                color: _licenseExpiryDate == null
                    ? AppColors.mediumGray
                    : AppColors.darkGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _addressController,
          labelText: 'العنوان',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 2,
        ),
        if (selectedVehicle != null) ...[
          const SizedBox(height: 14),
          _buildInfoBanner(
            icon: Icons.link_rounded,
            title: 'البيانات التشغيلية تُسحب من السيارة المرتبطة',
            subtitle:
                'نوع المركبة: ${selectedVehicle.vehicleType} • حالة السيارة: ${selectedVehicle.status}',
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentsCard() {
    return _buildCard(
      title: 'وثائق السائق',
      icon: Icons.badge_outlined,
      children: [
        _buildDateField(
          label: 'تاريخ إصدار الإقامة',
          value: _iqamaIssueDate,
          icon: Icons.event_available_outlined,
          onTap: () => _pickDate(
            currentValue: _iqamaIssueDate,
            onPicked: (value) => _iqamaIssueDate = value,
          ),
        ),
        const SizedBox(height: 14),
        _buildDateField(
          label: 'تاريخ انتهاء الإقامة',
          value: _iqamaExpiryDate,
          icon: Icons.event_busy_outlined,
          onTap: () => _pickDate(
            currentValue: _iqamaExpiryDate,
            onPicked: (value) => _iqamaExpiryDate = value,
          ),
          highlightWhenNearExpiry: true,
        ),
        const SizedBox(height: 14),
        _buildDateField(
          label: 'تاريخ انتهاء التأمين',
          value: _insuranceExpiryDate,
          icon: Icons.health_and_safety_outlined,
          onTap: () => _pickDate(
            currentValue: _insuranceExpiryDate,
            onPicked: (value) => _insuranceExpiryDate = value,
          ),
          highlightWhenNearExpiry: true,
        ),
        const SizedBox(height: 14),
        _buildDateField(
          label: 'تاريخ انتهاء بطاقة التشغيل',
          value: _operationCardExpiryDate,
          icon: Icons.credit_card_outlined,
          onTap: () => _pickDate(
            currentValue: _operationCardExpiryDate,
            onPicked: (value) => _operationCardExpiryDate = value,
          ),
          highlightWhenNearExpiry: true,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
    bool highlightWhenNearExpiry = false,
  }) {
    final isNearExpiry =
        highlightWhenNearExpiry &&
        value != null &&
        !value.isBefore(DateTime.now()) &&
        value.isBefore(DateTime.now().add(const Duration(days: 30)));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          value == null ? 'اختر التاريخ' : DateFormat('yyyy/MM/dd').format(value),
          style: TextStyle(
            color: value == null
                ? AppColors.mediumGray
                : (isNearExpiry ? AppColors.errorRed : AppColors.darkGray),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return _buildCard(
      title: 'ملاحظات',
      icon: Icons.note_alt_outlined,
      children: [
        CustomTextField(
          controller: _notesController,
          labelText: 'ملاحظات إضافية',
          prefixIcon: Icons.notes_outlined,
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildDriverUserCard() {
    final hasLinkedUser = _linkedDriverUser != null;
    final accountStatusColor = hasLinkedUser
        ? AppColors.successGreen
        : AppColors.pendingYellow;

    return _buildCard(
      title: 'حساب السائق driver_truck',
      icon: Icons.verified_user_outlined,
      trailing: _isLoadingLinkedUser
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accountStatusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accountStatusColor.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                hasLinkedUser ? 'مرتبط' : 'ينتظر الإنشاء',
                style: TextStyle(
                  color: accountStatusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
      children: [
        _buildInfoBanner(
          icon: hasLinkedUser
              ? Icons.verified_user_outlined
              : Icons.person_off_outlined,
          title: hasLinkedUser
              ? 'اسم المستخدم الحالي: ${_linkedDriverUser!.username}'
              : 'سيتم إنشاء حساب سائق مرتبط بهذا السائق',
          subtitle:
              'هذا البريد سيستقبل رمز التحقق عند دخول السائق، والحساب يشاهد فقط الطلبات المعيّنة له.',
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _driverUsernameController,
          labelText: 'اسم المستخدم *',
          prefixIcon: Icons.alternate_email,
          suffixIcon: IconButton(
            tooltip: 'اقتراح جديد',
            onPressed: () => setState(
              () => _setSuggestedDriverUsername(force: true),
            ),
            icon: const Icon(Icons.auto_fix_high_outlined),
          ),
          validator: (value) {
            final rawValue = (value ?? '').trim();
            if (rawValue.isEmpty) {
              return 'اسم المستخدم مطلوب';
            }
            final normalized = normalizeDriverTruckUsername(value ?? '');
            if (!normalized.startsWith('driver_truck')) {
              return 'اسم المستخدم يجب أن يبدأ بـ driver_truck';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _emailController,
          labelText: 'بريد حساب السائق *',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateDriverAccountEmail,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: _driverPasswordController,
          labelText: hasLinkedUser
              ? 'كلمة المرور الجديدة'
              : 'كلمة مرور الحساب *',
          prefixIcon: Icons.lock_outline,
          obscureText: true,
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (!hasLinkedUser && trimmed.isEmpty) {
              return 'كلمة المرور مطلوبة';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
