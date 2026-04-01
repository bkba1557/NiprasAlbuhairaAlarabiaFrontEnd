import 'package:flutter/material.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final dynamic maintenanceRecord;

  const MaintenanceFormScreen({super.key, this.maintenanceRecord});

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _driverIdController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _tankNumberController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _driverLicenseController =
      TextEditingController();
  final TextEditingController _vehicleLicenseController =
      TextEditingController();
  final TextEditingController _vehicleOperatingCardNumberController =
      TextEditingController();
  final TextEditingController _driverOperatingCardNameController =
      TextEditingController();
  final TextEditingController _driverOperatingCardNumberController =
      TextEditingController();
  final TextEditingController _vehicleRegistrationSerialNumberController =
      TextEditingController();
  final TextEditingController _vehicleRegistrationNumberController =
      TextEditingController();
  final TextEditingController _driverInsurancePolicyNumberController =
      TextEditingController();
  final TextEditingController _vehicleInsurancePolicyNumberController =
      TextEditingController();

  DateTime _driverLicenseExpiry = DateTime.now().add(const Duration(days: 365));
  DateTime _vehicleLicenseExpiry = DateTime.now().add(
    const Duration(days: 365),
  );
  DateTime _vehicleOperatingCardIssueDate = DateTime.now();
  DateTime _vehicleOperatingCardExpiryDate = DateTime.now().add(
    const Duration(days: 365),
  );
  DateTime _driverOperatingCardIssueDate = DateTime.now();
  DateTime _driverOperatingCardExpiryDate = DateTime.now().add(
    const Duration(days: 365),
  );
  DateTime _vehicleRegistrationIssueDate = DateTime.now();
  DateTime _vehicleRegistrationExpiryDate = DateTime.now().add(
    const Duration(days: 365),
  );
  DateTime _driverInsuranceIssueDate = DateTime.now();
  DateTime _driverInsuranceExpiryDate = DateTime.now().add(
    const Duration(days: 365),
  );
  DateTime _vehicleInsuranceIssueDate = DateTime.now();
  DateTime _vehicleInsuranceExpiryDate = DateTime.now().add(
    const Duration(days: 365),
  );
  DateTime _vehiclePeriodicInspectionIssueDate = DateTime.now();
  DateTime _vehiclePeriodicInspectionExpiryDate = DateTime.now().add(
    const Duration(days: 365),
  );
  String _vehicleType = 'صهريج وقود';
  String _fuelType = 'ديزل';
  String? _inspectionMonth;

  final List<String> _vehicleTypes = [
    'صهريج وقود',
    'ناقلة غاز',
    'مركبة خفيفة',
    'مركبة ثقيلة',
  ];

  final List<String> _fuelTypes = ['بنزين', 'ديزل', 'غاز طبيعي', 'كهرباء'];

  @override
  void initState() {
    super.initState();
    if (widget.maintenanceRecord != null) {
      _loadExistingData();
    } else {
      _inspectionMonth = DateFormat('yyyy-MM').format(DateTime.now());
    }
    _normalizeDropdownValues();
  }

  void _loadExistingData() {
    final record = widget.maintenanceRecord;
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }
      if (value == null) {
        return null;
      }
      return DateTime.tryParse(value.toString());
    }

    _driverIdController.text = record['driverId']?.toString() ?? '';
    _driverNameController.text = record['driverName']?.toString() ?? '';
    _tankNumberController.text = record['tankNumber']?.toString() ?? '';
    _plateNumberController.text = record['plateNumber']?.toString() ?? '';
    _driverLicenseController.text =
        record['driverLicenseNumber']?.toString() ?? '';
    _vehicleLicenseController.text =
        record['vehicleLicenseNumber']?.toString() ?? '';

    final driverExpiry = parseDate(record['driverLicenseExpiry']);
    if (driverExpiry != null) {
      _driverLicenseExpiry = driverExpiry;
    }

    final vehicleExpiry = parseDate(record['vehicleLicenseExpiry']);
    if (vehicleExpiry != null) {
      _vehicleLicenseExpiry = vehicleExpiry;
    }

    _vehicleOperatingCardNumberController.text =
        record['vehicleOperatingCardNumber']?.toString() ?? '';
    final vehicleOperatingIssue = parseDate(
      record['vehicleOperatingCardIssueDate'],
    );
    if (vehicleOperatingIssue != null) {
      _vehicleOperatingCardIssueDate = vehicleOperatingIssue;
    }
    final vehicleOperatingExpiry = parseDate(
      record['vehicleOperatingCardExpiryDate'],
    );
    if (vehicleOperatingExpiry != null) {
      _vehicleOperatingCardExpiryDate = vehicleOperatingExpiry;
    }

    _driverOperatingCardNameController.text =
        record['driverOperatingCardName']?.toString() ?? '';
    _driverOperatingCardNumberController.text =
        record['driverOperatingCardNumber']?.toString() ?? '';
    final driverOperatingIssue = parseDate(
      record['driverOperatingCardIssueDate'],
    );
    if (driverOperatingIssue != null) {
      _driverOperatingCardIssueDate = driverOperatingIssue;
    }
    final driverOperatingExpiry = parseDate(
      record['driverOperatingCardExpiryDate'],
    );
    if (driverOperatingExpiry != null) {
      _driverOperatingCardExpiryDate = driverOperatingExpiry;
    }

    _vehicleRegistrationSerialNumberController.text =
        record['vehicleRegistrationSerialNumber']?.toString() ?? '';
    _vehicleRegistrationNumberController.text =
        record['vehicleRegistrationNumber']?.toString() ?? '';
    final vehicleRegistrationIssue = parseDate(
      record['vehicleRegistrationIssueDate'],
    );
    if (vehicleRegistrationIssue != null) {
      _vehicleRegistrationIssueDate = vehicleRegistrationIssue;
    }
    final vehicleRegistrationExpiry = parseDate(
      record['vehicleRegistrationExpiryDate'],
    );
    if (vehicleRegistrationExpiry != null) {
      _vehicleRegistrationExpiryDate = vehicleRegistrationExpiry;
    }

    _driverInsurancePolicyNumberController.text =
        record['driverInsurancePolicyNumber']?.toString() ?? '';
    final driverInsuranceIssue = parseDate(record['driverInsuranceIssueDate']);
    if (driverInsuranceIssue != null) {
      _driverInsuranceIssueDate = driverInsuranceIssue;
    }
    final driverInsuranceExpiry = parseDate(
      record['driverInsuranceExpiryDate'],
    );
    if (driverInsuranceExpiry != null) {
      _driverInsuranceExpiryDate = driverInsuranceExpiry;
    }

    _vehicleInsurancePolicyNumberController.text =
        record['vehicleInsurancePolicyNumber']?.toString() ?? '';
    final vehicleInsuranceIssue = parseDate(
      record['vehicleInsuranceIssueDate'],
    );
    if (vehicleInsuranceIssue != null) {
      _vehicleInsuranceIssueDate = vehicleInsuranceIssue;
    }
    final vehicleInsuranceExpiry = parseDate(
      record['vehicleInsuranceExpiryDate'],
    );
    if (vehicleInsuranceExpiry != null) {
      _vehicleInsuranceExpiryDate = vehicleInsuranceExpiry;
    }

    final periodicInspectionIssue = parseDate(
      record['vehiclePeriodicInspectionIssueDate'],
    );
    if (periodicInspectionIssue != null) {
      _vehiclePeriodicInspectionIssueDate = periodicInspectionIssue;
    }

    final periodicInspectionExpiry = parseDate(
      record['vehiclePeriodicInspectionExpiryDate'],
    );
    if (periodicInspectionExpiry != null) {
      _vehiclePeriodicInspectionExpiryDate = periodicInspectionExpiry;
    }

    _vehicleType = record['vehicleType']?.toString() ?? 'صهريج وقود';
    _fuelType = record['fuelType']?.toString() ?? 'ديزل';
    _inspectionMonth =
        record['inspectionMonth'] ??
        DateFormat('yyyy-MM').format(DateTime.now());
    _normalizeDropdownValues();
  }

  void _normalizeDropdownValues() {
    if (_vehicleTypes.isNotEmpty && !_vehicleTypes.contains(_vehicleType)) {
      _vehicleType = _vehicleTypes.first;
    }
    if (_fuelTypes.isNotEmpty && !_fuelTypes.contains(_fuelType)) {
      _fuelType = _fuelTypes.first;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDriverLicense) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDriverLicense
          ? _driverLicenseExpiry
          : _vehicleLicenseExpiry,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      setState(() {
        if (isDriverLicense) {
          _driverLicenseExpiry = picked;
        } else {
          _vehicleLicenseExpiry = picked;
        }
      });
    }
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );

    if (picked != null) {
      setState(() {
        onPicked(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<MaintenanceProvider>(context, listen: false);

    final maintenanceData = {
      'driverId': _driverIdController.text.trim(),
      'driverName': _driverNameController.text.trim(),
      'tankNumber': _tankNumberController.text.trim(),
      'plateNumber': _plateNumberController.text.trim(),
      'driverLicenseNumber': _driverLicenseController.text.trim(),
      'driverLicenseExpiry': _driverLicenseExpiry.toIso8601String(),
      'vehicleLicenseNumber': _vehicleLicenseController.text.trim(),
      'vehicleLicenseExpiry': _vehicleLicenseExpiry.toIso8601String(),
      'vehicleType': _vehicleType,
      'fuelType': _fuelType,
      'inspectionMonth':
          _inspectionMonth ?? DateFormat('yyyy-MM').format(DateTime.now()),
      'vehicleOperatingCardNumber': _vehicleOperatingCardNumberController.text
          .trim(),
      'vehicleOperatingCardIssueDate': _vehicleOperatingCardIssueDate
          .toIso8601String(),
      'vehicleOperatingCardExpiryDate': _vehicleOperatingCardExpiryDate
          .toIso8601String(),
      'driverOperatingCardName':
          _driverOperatingCardNameController.text.trim().isNotEmpty
          ? _driverOperatingCardNameController.text.trim()
          : _driverNameController.text.trim(),
      'driverOperatingCardNumber': _driverOperatingCardNumberController.text
          .trim(),
      'driverOperatingCardIssueDate': _driverOperatingCardIssueDate
          .toIso8601String(),
      'driverOperatingCardExpiryDate': _driverOperatingCardExpiryDate
          .toIso8601String(),
      'vehicleRegistrationSerialNumber':
          _vehicleRegistrationSerialNumberController.text.trim(),
      'vehicleRegistrationNumber': _vehicleRegistrationNumberController.text
          .trim(),
      'vehicleRegistrationIssueDate': _vehicleRegistrationIssueDate
          .toIso8601String(),
      'vehicleRegistrationExpiryDate': _vehicleRegistrationExpiryDate
          .toIso8601String(),
      'driverInsurancePolicyNumber': _driverInsurancePolicyNumberController.text
          .trim(),
      'driverInsuranceIssueDate': _driverInsuranceIssueDate.toIso8601String(),
      'driverInsuranceExpiryDate': _driverInsuranceExpiryDate.toIso8601String(),
      'vehicleInsurancePolicyNumber': _vehicleInsurancePolicyNumberController
          .text
          .trim(),
      'vehicleInsuranceIssueDate': _vehicleInsuranceIssueDate.toIso8601String(),
      'vehicleInsuranceExpiryDate': _vehicleInsuranceExpiryDate
          .toIso8601String(),
      'vehiclePeriodicInspectionIssueDate':
          _vehiclePeriodicInspectionIssueDate.toIso8601String(),
      'vehiclePeriodicInspectionExpiryDate':
          _vehiclePeriodicInspectionExpiryDate.toIso8601String(),
      'insuranceNumber': _vehicleInsurancePolicyNumberController.text.trim(),
      'insuranceExpiry': _vehicleInsuranceExpiryDate.toIso8601String(),
    };

    try {
      if (widget.maintenanceRecord != null) {
        await provider.updateMaintenanceRecord(
          widget.maintenanceRecord['_id'] ?? widget.maintenanceRecord['id'],
          maintenanceData,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث سجل الصيانة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await provider.createMaintenanceRecord(maintenanceData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء سجل الصيانة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MaintenanceProvider>(context, listen: false);

    final isEditing = widget.maintenanceRecord != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;
    final isMediumScreen = screenWidth > 768;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل سجل الصيانة' : 'سجل صيانة جديد',
          style: TextStyle(
            fontSize: isLargeScreen
                ? 24
                : isMediumScreen
                ? 20
                : 18,
          ),
        ),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen
                  ? 40
                  : isMediumScreen
                  ? 24
                  : 16,
              vertical: isLargeScreen
                  ? 32
                  : isMediumScreen
                  ? 24
                  : 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
                maxWidth: isLargeScreen ? 800 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // 📋 Basic Information
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Colors.blue,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'معلومات السائق والمركبة',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),

                          // Driver ID
                          _buildFormField(
                            context: context,
                            controller: _driverIdController,
                            label: 'رقم هوية السائق',
                            hintText: 'أدخل رقم الهوية',
                            icon: Icons.badge_outlined,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال رقم الهوية';
                              }
                              return null;
                            },
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          // Driver Name
                          _buildFormField(
                            context: context,
                            controller: _driverNameController,
                            label: 'اسم السائق',
                            hintText: 'أدخل اسم السائق',
                            icon: Icons.person,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال اسم السائق';
                              }
                              return null;
                            },
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          // Tank Number
                          _buildFormField(
                            context: context,
                            controller: _tankNumberController,
                            label: 'رقم التانكي',
                            hintText: 'أدخل رقم التانكي',
                            icon: Icons.local_gas_station_outlined,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال رقم التانكي';
                              }
                              return null;
                            },
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          // Plate Number
                          _buildFormField(
                            context: context,
                            controller: _plateNumberController,
                            label: 'رقم لوحة السيارة',
                            hintText: 'أدخل رقم اللوحة',
                            icon: Icons.directions_car_outlined,
                            isRequired: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال رقم اللوحة';
                              }
                              return null;
                            },
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // 📝 License Information
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card_outlined,
                                color: Colors.purple,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'معلومات الرخصة',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),

                          if (isLargeScreen || isMediumScreen)
                            // Responsive Layout for Large/Medium Screens
                            Column(
                              children: [
                                // Driver License Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildFormField(
                                        context: context,
                                        controller: _driverLicenseController,
                                        label: 'رقم رخصة السائق',
                                        hintText: 'رقم الرخصة',
                                        icon: Icons.credit_card,
                                        isRequired: true,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'يرجى إدخال رقم الرخصة';
                                          }
                                          return null;
                                        },
                                        isLargeScreen: isLargeScreen,
                                        isMediumScreen: isMediumScreen,
                                      ),
                                    ),
                                    SizedBox(
                                      width: isLargeScreen
                                          ? 24
                                          : isMediumScreen
                                          ? 16
                                          : 12,
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: _buildDateField(
                                        context: context,
                                        label: 'انتهاء الرخصة',
                                        date: _driverLicenseExpiry,
                                        onTap: () => _selectDate(context, true),
                                        isLargeScreen: isLargeScreen,
                                        isMediumScreen: isMediumScreen,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: isLargeScreen
                                      ? 20
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),

                                // Vehicle License Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildFormField(
                                        context: context,
                                        controller: _vehicleLicenseController,
                                        label: 'رقم رخصة المركبة',
                                        hintText: 'رقم الرخصة',
                                        icon: Icons.directions_car,
                                        isRequired: true,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'يرجى إدخال رقم الرخصة';
                                          }
                                          return null;
                                        },
                                        isLargeScreen: isLargeScreen,
                                        isMediumScreen: isMediumScreen,
                                      ),
                                    ),
                                    SizedBox(
                                      width: isLargeScreen
                                          ? 24
                                          : isMediumScreen
                                          ? 16
                                          : 12,
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: _buildDateField(
                                        context: context,
                                        label: 'انتهاء الرخصة',
                                        date: _vehicleLicenseExpiry,
                                        onTap: () =>
                                            _selectDate(context, false),
                                        isLargeScreen: isLargeScreen,
                                        isMediumScreen: isMediumScreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            // Single Column Layout for Small Screens
                            Column(
                              children: [
                                _buildFormField(
                                  context: context,
                                  controller: _driverLicenseController,
                                  label: 'رقم رخصة السائق',
                                  hintText: 'رقم الرخصة',
                                  icon: Icons.credit_card,
                                  isRequired: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'يرجى إدخال رقم الرخصة';
                                    }
                                    return null;
                                  },
                                  isLargeScreen: isLargeScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                                SizedBox(
                                  height: isLargeScreen
                                      ? 20
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),

                                _buildDateField(
                                  context: context,
                                  label: 'انتهاء الرخصة',
                                  date: _driverLicenseExpiry,
                                  onTap: () => _selectDate(context, true),
                                  isLargeScreen: isLargeScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                                SizedBox(
                                  height: isLargeScreen
                                      ? 20
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),

                                _buildFormField(
                                  context: context,
                                  controller: _vehicleLicenseController,
                                  label: 'رقم رخصة المركبة',
                                  hintText: 'رقم الرخصة',
                                  icon: Icons.directions_car,
                                  isRequired: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'يرجى إدخال رقم الرخصة';
                                    }
                                    return null;
                                  },
                                  isLargeScreen: isLargeScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                                SizedBox(
                                  height: isLargeScreen
                                      ? 20
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),

                                _buildDateField(
                                  context: context,
                                  label: 'انتهاء الرخصة',
                                  date: _vehicleLicenseExpiry,
                                  onTap: () => _selectDate(context, false),
                                  isLargeScreen: isLargeScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // 🚗 Vehicle Information
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.car_repair_outlined,
                                color: Colors.teal,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                'معلومات إضافية',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),

                          // Vehicle Type
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    color: Colors.teal,
                                    size: isLargeScreen
                                        ? 24
                                        : isMediumScreen
                                        ? 20
                                        : 16,
                                  ),
                                  SizedBox(
                                    width: isLargeScreen
                                        ? 12
                                        : isMediumScreen
                                        ? 8
                                        : 6,
                                  ),
                                  Text(
                                    'نوع المركبة *',
                                    style: TextStyle(
                                      fontSize: isLargeScreen
                                          ? 18
                                          : isMediumScreen
                                          ? 16
                                          : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isLargeScreen
                                      ? 16
                                      : isMediumScreen
                                      ? 12
                                      : 10,
                                  vertical: isLargeScreen
                                      ? 8
                                      : isMediumScreen
                                      ? 6
                                      : 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButton<String>(
                                  value: _vehicleType,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: isLargeScreen
                                        ? 32
                                        : isMediumScreen
                                        ? 28
                                        : 24,
                                    color: Colors.teal,
                                  ),
                                  style: TextStyle(
                                    fontSize: isLargeScreen
                                        ? 18
                                        : isMediumScreen
                                        ? 16
                                        : 14,
                                    color: Colors.black87,
                                  ),
                                  items: _vehicleTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: isLargeScreen
                                              ? 8
                                              : isMediumScreen
                                              ? 6
                                              : 4,
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: isLargeScreen
                                                ? 16
                                                : isMediumScreen
                                                ? 14
                                                : 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _vehicleType = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          // Fuel Type
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_gas_station,
                                    color: Colors.orange,
                                    size: isLargeScreen
                                        ? 24
                                        : isMediumScreen
                                        ? 20
                                        : 16,
                                  ),
                                  SizedBox(
                                    width: isLargeScreen
                                        ? 12
                                        : isMediumScreen
                                        ? 8
                                        : 6,
                                  ),
                                  Text(
                                    'نوع الوقود *',
                                    style: TextStyle(
                                      fontSize: isLargeScreen
                                          ? 18
                                          : isMediumScreen
                                          ? 16
                                          : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isLargeScreen
                                      ? 16
                                      : isMediumScreen
                                      ? 12
                                      : 10,
                                  vertical: isLargeScreen
                                      ? 8
                                      : isMediumScreen
                                      ? 6
                                      : 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButton<String>(
                                  value: _fuelType,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: isLargeScreen
                                        ? 32
                                        : isMediumScreen
                                        ? 28
                                        : 24,
                                    color: Colors.orange,
                                  ),
                                  style: TextStyle(
                                    fontSize: isLargeScreen
                                        ? 18
                                        : isMediumScreen
                                        ? 16
                                        : 14,
                                    color: Colors.black87,
                                  ),
                                  items: _fuelTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: isLargeScreen
                                              ? 8
                                              : isMediumScreen
                                              ? 6
                                              : 4,
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: isLargeScreen
                                                ? 16
                                                : isMediumScreen
                                                ? 14
                                                : 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _fuelType = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            height: isLargeScreen
                                ? 20
                                : isMediumScreen
                                ? 16
                                : 12,
                          ),

                          // Inspection Month (Only for new records)
                          if (!isEditing)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      color: Colors.blue,
                                      size: isLargeScreen
                                          ? 24
                                          : isMediumScreen
                                          ? 20
                                          : 16,
                                    ),
                                    SizedBox(
                                      width: isLargeScreen
                                          ? 12
                                          : isMediumScreen
                                          ? 8
                                          : 6,
                                    ),
                                    Text(
                                      'شهر التفتيش',
                                      style: TextStyle(
                                        fontSize: isLargeScreen
                                            ? 18
                                            : isMediumScreen
                                            ? 16
                                            : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.all(
                                    isLargeScreen
                                        ? 20
                                        : isMediumScreen
                                        ? 16
                                        : 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('MMMM yyyy').format(
                                          DateTime.parse(
                                            '$_inspectionMonth-01',
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: isLargeScreen
                                              ? 18
                                              : isMediumScreen
                                              ? 16
                                              : 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      Icon(
                                        Icons.lock_clock,
                                        color: Colors.blue,
                                        size: isLargeScreen
                                            ? 24
                                            : isMediumScreen
                                            ? 20
                                            : 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // Operating Cards
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                color: Colors.teal,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                '\u0628\u0637\u0627\u0642\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),
                          Text(
                            '\u0628\u0637\u0627\u0642\u0629 \u062a\u0634\u063a\u064a\u0644 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                            style: TextStyle(
                              fontSize: isLargeScreen
                                  ? 18
                                  : isMediumScreen
                                  ? 16
                                  : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildFormField(
                            context: context,
                            controller: _vehicleOperatingCardNumberController,
                            label:
                                '\u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u062a\u0634\u063a\u064a\u0644',
                            hintText:
                                '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u062a\u0634\u063a\u064a\u0644 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                            icon: Icons.confirmation_number_outlined,
                            isRequired: false,
                            validator: (_) => null,
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                          SizedBox(height: 12),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                                    date: _vehicleOperatingCardIssueDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _vehicleOperatingCardIssueDate,
                                      onPicked: (value) {
                                        _vehicleOperatingCardIssueDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                                    date: _vehicleOperatingCardExpiryDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _vehicleOperatingCardExpiryDate,
                                      onPicked: (value) {
                                        _vehicleOperatingCardExpiryDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                              date: _vehicleOperatingCardIssueDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehicleOperatingCardIssueDate,
                                onPicked: (value) {
                                  _vehicleOperatingCardIssueDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                              date: _vehicleOperatingCardExpiryDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehicleOperatingCardExpiryDate,
                                onPicked: (value) {
                                  _vehicleOperatingCardExpiryDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                          SizedBox(height: 20),
                          Text(
                            '\u0628\u0637\u0627\u0642\u0629 \u062a\u0634\u063a\u064a\u0644 \u0627\u0644\u0633\u0627\u0626\u0642',
                            style: TextStyle(
                              fontSize: isLargeScreen
                                  ? 18
                                  : isMediumScreen
                                  ? 16
                                  : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          SizedBox(height: 12),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    context: context,
                                    controller:
                                        _driverOperatingCardNameController,
                                    label:
                                        '\u0627\u0633\u0645 \u0627\u0644\u0633\u0627\u0626\u0642',
                                    hintText:
                                        '\u0627\u062f\u062e\u0644 \u0627\u0633\u0645 \u0627\u0644\u0633\u0627\u0626\u0642',
                                    icon: Icons.person_outline,
                                    isRequired: false,
                                    validator: (_) => null,
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildFormField(
                                    context: context,
                                    controller:
                                        _driverOperatingCardNumberController,
                                    label:
                                        '\u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u0633\u0627\u0626\u0642',
                                    hintText:
                                        '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u0633\u0627\u0626\u0642',
                                    icon: Icons.credit_card,
                                    isRequired: false,
                                    validator: (_) => null,
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildFormField(
                              context: context,
                              controller: _driverOperatingCardNameController,
                              label:
                                  '\u0627\u0633\u0645 \u0627\u0644\u0633\u0627\u0626\u0642',
                              hintText:
                                  '\u0627\u062f\u062e\u0644 \u0627\u0633\u0645 \u0627\u0644\u0633\u0627\u0626\u0642',
                              icon: Icons.person_outline,
                              isRequired: false,
                              validator: (_) => null,
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              context: context,
                              controller: _driverOperatingCardNumberController,
                              label:
                                  '\u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u0633\u0627\u0626\u0642',
                              hintText:
                                  '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u0633\u0627\u0626\u0642',
                              icon: Icons.credit_card,
                              isRequired: false,
                              validator: (_) => null,
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                          SizedBox(height: 12),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                                    date: _driverOperatingCardIssueDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _driverOperatingCardIssueDate,
                                      onPicked: (value) {
                                        _driverOperatingCardIssueDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                                    date: _driverOperatingCardExpiryDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _driverOperatingCardExpiryDate,
                                      onPicked: (value) {
                                        _driverOperatingCardExpiryDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                              date: _driverOperatingCardIssueDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _driverOperatingCardIssueDate,
                                onPicked: (value) {
                                  _driverOperatingCardIssueDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                              date: _driverOperatingCardExpiryDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _driverOperatingCardExpiryDate,
                                onPicked: (value) {
                                  _driverOperatingCardExpiryDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // Vehicle Registration
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                color: Colors.green,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                '\u0627\u0633\u062a\u0645\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    context: context,
                                    controller:
                                        _vehicleRegistrationSerialNumberController,
                                    label:
                                        '\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u0644\u0633\u0644\u064a',
                                    hintText:
                                        '\u0627\u062f\u062e\u0644 \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u0644\u0633\u0644\u064a',
                                    icon: Icons.tag,
                                    isRequired: false,
                                    validator: (_) => null,
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildFormField(
                                    context: context,
                                    controller:
                                        _vehicleRegistrationNumberController,
                                    label:
                                        '\u0631\u0642\u0645 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                                    hintText:
                                        '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                                    icon: Icons.directions_car,
                                    isRequired: false,
                                    validator: (_) => null,
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildFormField(
                              context: context,
                              controller:
                                  _vehicleRegistrationSerialNumberController,
                              label:
                                  '\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u0644\u0633\u0644\u064a',
                              hintText:
                                  '\u0627\u062f\u062e\u0644 \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u0644\u0633\u0644\u064a',
                              icon: Icons.tag,
                              isRequired: false,
                              validator: (_) => null,
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildFormField(
                              context: context,
                              controller: _vehicleRegistrationNumberController,
                              label:
                                  '\u0631\u0642\u0645 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                              hintText:
                                  '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                              icon: Icons.directions_car,
                              isRequired: false,
                              validator: (_) => null,
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                          SizedBox(height: 12),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                                    date: _vehicleRegistrationIssueDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _vehicleRegistrationIssueDate,
                                      onPicked: (value) {
                                        _vehicleRegistrationIssueDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                                    date: _vehicleRegistrationExpiryDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _vehicleRegistrationExpiryDate,
                                      onPicked: (value) {
                                        _vehicleRegistrationExpiryDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                              date: _vehicleRegistrationIssueDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehicleRegistrationIssueDate,
                                onPicked: (value) {
                                  _vehicleRegistrationIssueDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                              date: _vehicleRegistrationExpiryDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehicleRegistrationExpiryDate,
                                onPicked: (value) {
                                  _vehicleRegistrationExpiryDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                          SizedBox(height: 20),
                          _buildSaudiVehicleLicenseCard(
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // Periodic Vehicle Inspection (Vehicle Safety Center)
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.fact_check_outlined,
                                color: Colors.deepOrange,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Expanded(
                                child: Text(
                                  '\u0627\u0644\u0641\u062d\u0635 \u0627\u0644\u062f\u0648\u0631\u064a (\u0645\u0631\u0643\u0632 \u0633\u0644\u0627\u0645\u0629 \u0627\u0644\u0645\u0631\u0643\u0628\u0627\u062a)',
                                  style: TextStyle(
                                    fontSize: isLargeScreen
                                        ? 22
                                        : isMediumScreen
                                        ? 18
                                        : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label: '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                                    date: _vehiclePeriodicInspectionIssueDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _vehiclePeriodicInspectionIssueDate,
                                      onPicked: (value) {
                                        _vehiclePeriodicInspectionIssueDate =
                                            value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label: '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                                    date: _vehiclePeriodicInspectionExpiryDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate:
                                          _vehiclePeriodicInspectionExpiryDate,
                                      onPicked: (value) {
                                        _vehiclePeriodicInspectionExpiryDate =
                                            value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                              date: _vehiclePeriodicInspectionIssueDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehiclePeriodicInspectionIssueDate,
                                onPicked: (value) {
                                  _vehiclePeriodicInspectionIssueDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                              date: _vehiclePeriodicInspectionExpiryDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate:
                                    _vehiclePeriodicInspectionExpiryDate,
                                onPicked: (value) {
                                  _vehiclePeriodicInspectionExpiryDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 32
                        : isMediumScreen
                        ? 24
                        : 16,
                  ),

                  // =========================
                  // Insurance
                  // =========================
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isLargeScreen
                            ? 32
                            : isMediumScreen
                            ? 24
                            : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: Colors.indigo,
                                size: isLargeScreen
                                    ? 28
                                    : isMediumScreen
                                    ? 24
                                    : 20,
                              ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                '\u0627\u0644\u062a\u0623\u0645\u064a\u0646',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 22
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: isLargeScreen
                                ? 24
                                : isMediumScreen
                                ? 20
                                : 16,
                          ),
                          Text(
                            '\u062a\u0623\u0645\u064a\u0646 \u0627\u0644\u0633\u0627\u0626\u0642',
                            style: TextStyle(
                              fontSize: isLargeScreen
                                  ? 18
                                  : isMediumScreen
                                  ? 16
                                  : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildFormField(
                            context: context,
                            controller: _driverInsurancePolicyNumberController,
                            label:
                                '\u0631\u0642\u0645 \u0627\u0644\u0628\u0648\u0644\u064a\u0635\u0629',
                            hintText:
                                '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0627\u0644\u0628\u0648\u0644\u064a\u0635\u0629',
                            icon: Icons.numbers,
                            isRequired: false,
                            validator: (_) => null,
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                          SizedBox(height: 12),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                                    date: _driverInsuranceIssueDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate: _driverInsuranceIssueDate,
                                      onPicked: (value) {
                                        _driverInsuranceIssueDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                                    date: _driverInsuranceExpiryDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate: _driverInsuranceExpiryDate,
                                      onPicked: (value) {
                                        _driverInsuranceExpiryDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                              date: _driverInsuranceIssueDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _driverInsuranceIssueDate,
                                onPicked: (value) {
                                  _driverInsuranceIssueDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                              date: _driverInsuranceExpiryDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _driverInsuranceExpiryDate,
                                onPicked: (value) {
                                  _driverInsuranceExpiryDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                          SizedBox(height: 20),
                          Text(
                            '\u062a\u0623\u0645\u064a\u0646 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                            style: TextStyle(
                              fontSize: isLargeScreen
                                  ? 18
                                  : isMediumScreen
                                  ? 16
                                  : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildFormField(
                            context: context,
                            controller: _vehicleInsurancePolicyNumberController,
                            label:
                                '\u0631\u0642\u0645 \u0627\u0644\u0628\u0648\u0644\u064a\u0635\u0629',
                            hintText:
                                '\u0627\u062f\u062e\u0644 \u0631\u0642\u0645 \u0627\u0644\u0628\u0648\u0644\u064a\u0635\u0629',
                            icon: Icons.numbers,
                            isRequired: false,
                            validator: (_) => null,
                            isLargeScreen: isLargeScreen,
                            isMediumScreen: isMediumScreen,
                          ),
                          SizedBox(height: 12),
                          if (isLargeScreen || isMediumScreen)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                                    date: _vehicleInsuranceIssueDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate: _vehicleInsuranceIssueDate,
                                      onPicked: (value) {
                                        _vehicleInsuranceIssueDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(
                                  width: isLargeScreen
                                      ? 24
                                      : isMediumScreen
                                      ? 16
                                      : 12,
                                ),
                                Expanded(
                                  child: _buildDateField(
                                    context: context,
                                    label:
                                        '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                                    date: _vehicleInsuranceExpiryDate,
                                    onTap: () => _pickDate(
                                      context: context,
                                      initialDate: _vehicleInsuranceExpiryDate,
                                      onPicked: (value) {
                                        _vehicleInsuranceExpiryDate = value;
                                      },
                                    ),
                                    isLargeScreen: isLargeScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                              date: _vehicleInsuranceIssueDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehicleInsuranceIssueDate,
                                onPicked: (value) {
                                  _vehicleInsuranceIssueDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: 12),
                            _buildDateField(
                              context: context,
                              label:
                                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
                              date: _vehicleInsuranceExpiryDate,
                              onTap: () => _pickDate(
                                context: context,
                                initialDate: _vehicleInsuranceExpiryDate,
                                onPicked: (value) {
                                  _vehicleInsuranceExpiryDate = value;
                                },
                              ),
                              isLargeScreen: isLargeScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height: isLargeScreen
                        ? 40
                        : isMediumScreen
                        ? 32
                        : 24,
                  ),

                  // =========================
                  // ✅ Submit Button
                  // =========================
                  Consumer<MaintenanceProvider>(
                    builder: (context, provider, _) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isLargeScreen
                                  ? 22
                                  : isMediumScreen
                                  ? 18
                                  : 16,
                              horizontal: isLargeScreen
                                  ? 40
                                  : isMediumScreen
                                  ? 32
                                  : 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: Colors.blue.shade300,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (provider.isLoading)
                                SizedBox(
                                  height: isLargeScreen
                                      ? 28
                                      : isMediumScreen
                                      ? 24
                                      : 20,
                                  width: isLargeScreen
                                      ? 28
                                      : isMediumScreen
                                      ? 24
                                      : 20,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              else
                                Icon(
                                  isEditing
                                      ? Icons.save_outlined
                                      : Icons.add_circle_outline,
                                  size: isLargeScreen
                                      ? 28
                                      : isMediumScreen
                                      ? 24
                                      : 20,
                                ),
                              SizedBox(
                                width: isLargeScreen
                                    ? 16
                                    : isMediumScreen
                                    ? 12
                                    : 8,
                              ),
                              Text(
                                isEditing ? 'حفظ التغييرات' : 'إنشاء السجل',
                                style: TextStyle(
                                  fontSize: isLargeScreen
                                      ? 20
                                      : isMediumScreen
                                      ? 18
                                      : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 120
                        : 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required bool isRequired,
    required String? Function(String?)? validator,
    required bool isLargeScreen,
    required bool isMediumScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Colors.blue.shade700,
              size: isLargeScreen
                  ? 24
                  : isMediumScreen
                  ? 20
                  : 16,
            ),
            SizedBox(
              width: isLargeScreen
                  ? 12
                  : isMediumScreen
                  ? 8
                  : 6,
            ),
            Text(
              '$label${isRequired ? ' *' : ''}',
              style: TextStyle(
                fontSize: isLargeScreen
                    ? 18
                    : isMediumScreen
                    ? 16
                    : 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        CustomTextField(
          controller: controller,
          labelText: hintText,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSaudiVehicleLicenseCard({
    required bool isLargeScreen,
    required bool isMediumScreen,
  }) {
    final titleSize = isLargeScreen
        ? 18.0
        : isMediumScreen
        ? 16.0
        : 14.0;
    final labelSize = isLargeScreen
        ? 14.0
        : isMediumScreen
        ? 12.0
        : 11.0;
    final valueSize = isLargeScreen
        ? 16.0
        : isMediumScreen
        ? 14.0
        : 12.0;

    final serialNumber = _vehicleRegistrationSerialNumberController.text.trim();
    final vehicleNumber = _vehicleRegistrationNumberController.text.trim();
    final plateNumber = _plateNumberController.text.trim();

    Widget buildField(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: labelSize,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '-',
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(
        isLargeScreen
            ? 20
            : isMediumScreen
            ? 16
            : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0E8B3A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isLargeScreen
                  ? 10
                  : isMediumScreen
                  ? 8
                  : 6,
              horizontal: isLargeScreen
                  ? 14
                  : isMediumScreen
                  ? 12
                  : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0E8B3A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '\u0631\u062e\u0635\u0629 \u0633\u064a\u0631 \u0645\u0631\u0643\u0628\u0629',
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: isLargeScreen ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: buildField(
                  '\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u0644\u0633\u0644\u064a',
                  serialNumber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildField(
                  '\u0631\u0642\u0645 \u0627\u0644\u0633\u064a\u0627\u0631\u0629',
                  vehicleNumber,
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 10),
          Row(
            children: [
              Expanded(
                child: buildField(
                  '\u0631\u0642\u0645 \u0627\u0644\u0644\u0648\u062d\u0629',
                  plateNumber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildField(
                  '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0625\u0635\u062f\u0627\u0631',
                  DateFormat(
                    'yyyy/MM/dd',
                  ).format(_vehicleRegistrationIssueDate),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 12 : 10),
          buildField(
            '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621',
            DateFormat('yyyy/MM/dd').format(_vehicleRegistrationExpiryDate),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required bool isLargeScreen,
    required bool isMediumScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: Colors.purple.shade700,
              size: isLargeScreen
                  ? 24
                  : isMediumScreen
                  ? 20
                  : 16,
            ),
            SizedBox(
              width: isLargeScreen
                  ? 12
                  : isMediumScreen
                  ? 8
                  : 6,
            ),
            Text(
              '$label *',
              style: TextStyle(
                fontSize: isLargeScreen
                    ? 18
                    : isMediumScreen
                    ? 16
                    : 14,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen
                  ? 20
                  : isMediumScreen
                  ? 16
                  : 12,
              vertical: isLargeScreen
                  ? 20
                  : isMediumScreen
                  ? 16
                  : 12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy/MM/dd').format(date),
                  style: TextStyle(
                    fontSize: isLargeScreen
                        ? 18
                        : isMediumScreen
                        ? 16
                        : 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.purple.shade700,
                  size: isLargeScreen
                      ? 24
                      : isMediumScreen
                      ? 20
                      : 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
