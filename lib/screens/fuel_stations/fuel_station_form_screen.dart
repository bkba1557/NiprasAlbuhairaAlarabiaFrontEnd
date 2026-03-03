import 'package:flutter/material.dart';
import 'package:order_tracker/models/fuel_station_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/fuel_station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/attachment_item.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class FuelStationFormScreen extends StatefulWidget {
  final FuelStation? stationToEdit;

  const FuelStationFormScreen({super.key, this.stationToEdit});

  @override
  State<FuelStationFormScreen> createState() => _FuelStationFormScreenState();
}

bool _isSubmitting = false;

// Dialog for adding/editing fuel types
class FuelTypeDialog extends StatefulWidget {
  final StationFuelType? fuelType;
  final Function(StationFuelType) onSave;

  const FuelTypeDialog({super.key, this.fuelType, required this.onSave});

  @override
  State<FuelTypeDialog> createState() => _FuelTypeDialogState();
}

class _FuelTypeDialogState extends State<FuelTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fuelNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _availableController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _tankController = TextEditingController();

  DateTime _lastDeliveryDate = DateTime.now();
  DateTime _nextDeliveryDate = DateTime.now().add(const Duration(days: 7));
  String _status = 'متاح';
  final List<String> _statuses = ['متاح', 'قيد التوريد', 'غير متاح'];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FuelStationProvider>(context, listen: false);

      debugPrint(
        '🟡 [FuelTypeScreen] initState → isCreatingStation BEFORE reset = ${provider.isCreatingStation}',
      );

      provider.resetCreateStationLoading();

      debugPrint(
        '🟢 [FuelTypeScreen] initState → isCreatingStation AFTER reset = ${provider.isCreatingStation}',
      );
    });

    if (widget.fuelType != null) {
      final fuelType = widget.fuelType!;
      _fuelNameController.text = fuelType.fuelName;
      _priceController.text = fuelType.pricePerLiter.toString();
      _availableController.text = fuelType.availableQuantity.toString();
      _capacityController.text = fuelType.capacity.toString();
      _tankController.text = fuelType.tankNumber;
      _lastDeliveryDate = fuelType.lastDeliveryDate;
      _nextDeliveryDate = fuelType.nextDeliveryDate;
      _status = fuelType.status;
    }
  }

  Future<void> _pickDate(String field) async {
    final initialDate = field == 'last' ? _lastDeliveryDate : _nextDeliveryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (field == 'last') {
          _lastDeliveryDate = picked;
        } else {
          _nextDeliveryDate = picked;
        }
      });
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final fuelType = StationFuelType(
      id: widget.fuelType?.id ?? '',
      fuelName: _fuelNameController.text.trim(),
      pricePerLiter: double.tryParse(_priceController.text) ?? 0,
      availableQuantity: double.tryParse(_availableController.text) ?? 0,
      capacity: double.tryParse(_capacityController.text) ?? 0,
      tankNumber: _tankController.text.trim(),
      lastDeliveryDate: _lastDeliveryDate,
      nextDeliveryDate: _nextDeliveryDate,
      status: _status,
    );

    widget.onSave(fuelType);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return AlertDialog(
      title: Text(
        widget.fuelType != null ? 'تحديث نوع الوقود' : 'إضافة نوع وقود',
      ),
      content: SingleChildScrollView(
        child: Container(
          width: isLargeScreen ? 500 : null,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _fuelNameController,
                  labelText: 'اسم الوقود',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _priceController,
                        labelText: 'السعر للتر',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'هذا الحقل مطلوب';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _availableController,
                        labelText: 'الكمية المتوفرة (لتر)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _capacityController,
                        labelText: 'السعة (لتر)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _tankController,
                        labelText: 'رقم الخزان',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate('last'),
                        child: _buildDateField('آخر تسليم', _lastDeliveryDate),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate('next'),
                        child: _buildDateField(
                          'التسليم القادم',
                          _nextDeliveryDate,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.lightGray),
                  ),
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _statuses.map((value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _handleSave, child: const Text('حفظ')),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(DateFormat('yyyy/MM/dd').format(date)),
        ],
      ),
    );
  }
}

// Widget for displaying fuel type entries
class FuelTypeItem extends StatelessWidget {
  final StationFuelType fuelType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FuelTypeItem({
    super.key,
    required this.fuelType,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  fuelType.fuelName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'السعر: ${fuelType.pricePerLiter.toStringAsFixed(2)} SAR',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'متوفر: ${fuelType.availableQuantity.toStringAsFixed(1)} لتر',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'السعة: ${fuelType.capacity.toStringAsFixed(1)} لتر',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('الخزان: ${fuelType.tankNumber}')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  fuelType.status,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'آخر تسليم: ${DateFormat('yyyy/MM/dd').format(fuelType.lastDeliveryDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelStationFormScreenState extends State<FuelStationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _stationCodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _googleMapsLinkController =
      TextEditingController();
  final TextEditingController _wazeLinkController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _managerPhoneController = TextEditingController();
  final TextEditingController _managerEmailController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String _stationType = 'رئيسية';
  String _status = 'نشطة';
  DateTime _establishedDate = DateTime.now();
  DateTime _lastMaintenanceDate = DateTime.now();
  DateTime _nextMaintenanceDate = DateTime.now().add(const Duration(days: 30));
  List<StationEquipment> _equipment = [];
  List<StationFuelType> _fuelTypes = [];
  List<String> _attachmentPaths = [];
  List<String> _newAttachmentPaths = [];

  final List<String> _stationTypes = ['رئيسية', 'فرعية', 'متنقلة'];
  final List<String> _statuses = ['نشطة', 'متوقفة', 'صيانة', 'مغلقة'];
  final List<String> _fuelNames = [
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
    'غاز طبيعي',
  ];
  final List<String> _equipmentTypes = [
    'مضخة',
    'خزان',
    'نظام أمن',
    'نظام حريق',
    'مولد',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.stationToEdit != null) {
      _initializeFormWithStation();
    } else {
      _stationCodeController.text = _generateStationCode();
      _getCurrentLocation();
    }
  }

  void _initializeFormWithStation() {
    final station = widget.stationToEdit!;
    _stationNameController.text = station.stationName;
    _stationCodeController.text = station.stationCode;
    _addressController.text = station.address;
    _latitudeController.text = station.latitude.toString();
    _longitudeController.text = station.longitude.toString();
    _googleMapsLinkController.text = station.googleMapsLink ?? '';
    _wazeLinkController.text = station.wazeLink ?? '';
    _capacityController.text = station.capacity.toString();
    _managerNameController.text = station.managerName;
    _managerPhoneController.text = station.managerPhone;
    _managerEmailController.text = station.managerEmail ?? '';
    _regionController.text = station.region;
    _cityController.text = station.city;
    _stationType = station.stationType;
    _status = station.status;
    _establishedDate = station.establishedDate;
    _lastMaintenanceDate = station.lastMaintenanceDate;
    _nextMaintenanceDate = station.nextMaintenanceDate;
    _equipment = List.from(station.equipment);
    _fuelTypes = List.from(station.fuelTypes);
  }

  String _generateStationCode() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(
      4,
      '0',
    );
    return 'ST${year}${month}$random';
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الحصول على الموقع الحالي'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pickDate(BuildContext context, String field) async {
    final initialDate = field == 'established'
        ? _establishedDate
        : field == 'lastMaintenance'
        ? _lastMaintenanceDate
        : _nextMaintenanceDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
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
        if (field == 'established') {
          _establishedDate = picked;
        } else if (field == 'lastMaintenance') {
          _lastMaintenanceDate = picked;
        } else {
          _nextMaintenanceDate = picked;
        }
      });
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        _newAttachmentPaths.addAll(result.paths.whereType<String>());
      });
    }
  }

  void _addEquipment() {
    showDialog(
      context: context,
      builder: (context) => EquipmentDialog(
        onSave: (equipment) {
          setState(() {
            _equipment.add(equipment);
          });
        },
      ),
    );
  }

  void _editEquipment(int index) {
    showDialog(
      context: context,
      builder: (context) => EquipmentDialog(
        equipment: _equipment[index],
        onSave: (equipment) {
          setState(() {
            _equipment[index] = equipment;
          });
        },
      ),
    );
  }

  void _removeEquipment(int index) {
    setState(() {
      _equipment.removeAt(index);
    });
  }

  void _addFuelType() {
    showDialog(
      context: context,
      builder: (context) => FuelTypeDialog(
        onSave: (fuelType) {
          setState(() {
            _fuelTypes.add(fuelType);
          });
        },
      ),
    );
  }

  void _editFuelType(int index) {
    showDialog(
      context: context,
      builder: (context) => FuelTypeDialog(
        fuelType: _fuelTypes[index],
        onSave: (fuelType) {
          setState(() {
            _fuelTypes[index] = fuelType;
          });
        },
      ),
    );
  }

  void _removeFuelType(int index) {
    setState(() {
      _fuelTypes.removeAt(index);
    });
  }

  Future<void> _openMapsForLocation() async {
    final lat = double.tryParse(_latitudeController.text) ?? 0;
    final lng = double.tryParse(_longitudeController.text) ?? 0;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _generateMapsLinks() {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat != null && lng != null) {
      setState(() {
        _googleMapsLinkController.text =
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        _wazeLinkController.text =
            'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
      });
    }
  }

  Future<void> _submitForm() async {
    debugPrint('🟣 [_submitForm] CALLED');

    final provider = context.read<FuelStationProvider>();

    // منع الضغط المتكرر تماماً
    if (provider.isCreatingStation) {
      debugPrint('⛔ [_submitForm] BLOCKED → already creating');
      return;
    }

    // التحقق من وجود FormState
    final formState = _formKey.currentState;
    if (formState == null) {
      debugPrint('💥 [_submitForm] formState == null');
      return;
    }

    // التحقق من صحة النموذج
    final isValid = formState.validate();
    debugPrint('🟠 [_submitForm] form validate = $isValid');

    if (!isValid) {
      debugPrint('⛔ [_submitForm] FORM NOT VALID → STOP');

      // إلغاء التركيز بعد انتهاء الـ build الحالي فقط
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).unfocus();
      });
      return;
    }

    // إظهار حالة التحميل محلياً في الشاشة
    setState(() {
      _isSubmitting = true; // ← تحتاج تعريف هذا المتغير في الكلاس
    });

    final authProvider = context.read<AuthProvider>();

    debugPrint(
      '👤 [_submitForm] userId=${authProvider.user?.id} | userName=${authProvider.user?.name}',
    );

    // تجهيز كائن المحطة
    final station = FuelStation(
      id: widget.stationToEdit?.id ?? '',
      stationName: _stationNameController.text.trim(),
      stationCode: _stationCodeController.text.trim(),
      address: _addressController.text.trim(),
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
      googleMapsLink: _googleMapsLinkController.text.trim().isNotEmpty
          ? _googleMapsLinkController.text.trim()
          : null,
      wazeLink: _wazeLinkController.text.trim().isNotEmpty
          ? _wazeLinkController.text.trim()
          : null,
      stationType: _stationType,
      status: _status,
      capacity: double.parse(_capacityController.text.trim()),
      managerName: _managerNameController.text.trim(),
      managerPhone: _managerPhoneController.text.trim(),
      managerEmail: _managerEmailController.text.trim().isNotEmpty
          ? _managerEmailController.text.trim()
          : null,
      region: _regionController.text.trim(),
      city: _cityController.text.trim(),
      equipment: _equipment,
      fuelTypes: _fuelTypes,
      attachments: [],
      establishedDate: _establishedDate,
      lastMaintenanceDate: _lastMaintenanceDate,
      nextMaintenanceDate: _nextMaintenanceDate,
      totalTechnicians: widget.stationToEdit?.totalTechnicians ?? 0,
      createdBy: authProvider.user?.id ?? '',
      createdByName: authProvider.user?.name ?? '',
      createdAt: widget.stationToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    debugPrint('📦 [_submitForm] Station object prepared');
    debugPrint(
      '📎 [_submitForm] Attachments count = ${_newAttachmentPaths.length}',
    );

    bool success = false;
    String? errorMessage;

    try {
      debugPrint('🚀 [_submitForm] Calling createStation...');

      success = await provider.createStation(
        station,
        _newAttachmentPaths.isNotEmpty ? _newAttachmentPaths : null,
      );

      debugPrint('✅ [_submitForm] createStation returned → $success');

      if (success) {
        debugPrint('🎉 [_submitForm] SUCCESS');
        errorMessage = null;
      } else {
        debugPrint(
          '❌ [_submitForm] FAILED → provider.error = ${provider.error}',
        );
        errorMessage = provider.error ?? 'حدث خطأ أثناء حفظ المحطة';
      }
    } catch (e, stack) {
      debugPrint('💥 [_submitForm] EXCEPTION: $e');
      debugPrint('📚 STACK TRACE:\n$stack');
      errorMessage = 'خطأ غير متوقع: $e';
      success = false;
    }

    // مهم: نعيد التحقق من mounted قبل أي تحديث واجهة
    if (!mounted) return;

    // إرجاع الشاشة إلى الحالة الطبيعية
    setState(() {
      _isSubmitting = false;
    });

    // عرض النتيجة للمستخدم
    if (success) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.stationToEdit != null
                ? 'تم تحديث المحطة بنجاح'
                : 'تم إنشاء المحطة بنجاح',
          ),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );

      // الرجوع للشاشة السابقة بعد تأخير بسيط ليتمكن المستخدم من رؤية الرسالة
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'حدث خطأ أثناء الحفظ'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingStation = context.select<FuelStationProvider, bool>(
      (p) => p.isCreatingStation,
    );
    final isEditing = widget.stationToEdit != null;

    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل محطة الوقود' : 'إضافة محطة وقود جديدة'),
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
      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 16,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 1200 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Layout based on screen size
                  if (isLargeScreen)
                    _buildLargeScreenLayout()
                  else
                    _buildSmallScreenLayout(),

                  const SizedBox(height: 32),

                  // Submit Button
                  Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: isLargeScreen ? 500 : double.infinity,
                      ),
                      child: GradientButton(
                        onPressed: isCreatingStation ? null : _submitForm,
                        text: isCreatingStation
                            ? 'جاري الحفظ...'
                            : (isEditing ? 'تحديث المحطة' : 'إنشاء المحطة'),
                        gradient: AppColors.accentGradient,
                        isLoading: isCreatingStation,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Column(
      children: [
        // First Row: Basic Info + Location
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildBasicInfoCard()),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildLocationCard(),
                  const SizedBox(height: 16),
                  _buildManagerInfoCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Second Row: Capacity + Equipment + Fuel Types
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildCapacityDatesCard()),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildEquipmentCard(),
                  const SizedBox(height: 16),
                  _buildFuelTypesCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Third Row: Attachments
        _buildAttachmentsCard(),
      ],
    );
  }

  Widget _buildSmallScreenLayout() {
    return Column(
      children: [
        _buildBasicInfoCard(),
        const SizedBox(height: 16),
        _buildLocationCard(),
        const SizedBox(height: 16),
        _buildManagerInfoCard(),
        const SizedBox(height: 16),
        _buildCapacityDatesCard(),
        const SizedBox(height: 16),
        _buildEquipmentCard(),
        const SizedBox(height: 16),
        _buildFuelTypesCard(),
        const SizedBox(height: 16),
        _buildAttachmentsCard(),
      ],
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المعلومات الأساسية',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _stationNameController,
              labelText: 'اسم المحطة',
              prefixIcon: Icons.local_gas_station,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              },
              fieldColor: AppColors.primaryBlue.withOpacity(0.05),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _stationCodeController,
              labelText: 'كود المحطة',
              prefixIcon: Icons.numbers,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              },
              fieldColor: AppColors.primaryBlue.withOpacity(0.05),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _regionController,
                    labelText: 'المنطقة',
                    prefixIcon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                    fieldColor: AppColors.primaryBlue.withOpacity(0.05),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _cityController,
                    labelText: 'المدينة',
                    prefixIcon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                    fieldColor: AppColors.primaryBlue.withOpacity(0.05),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: DropdownButton<String>(
                      value: _stationType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _stationTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _stationType = value!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray),
                    ),
                    child: DropdownButton<String>(
                      value: _status,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _statuses.map((String value) {
                        Color statusColor;
                        switch (value) {
                          case 'نشطة':
                            statusColor = Colors.green;
                            break;
                          case 'صيانة':
                            statusColor = Colors.orange;
                            break;
                          case 'متوقفة':
                            statusColor = Colors.red;
                            break;
                          case 'مغلقة':
                            statusColor = Colors.grey;
                            break;
                          default:
                            statusColor = AppColors.primaryBlue;
                        }
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _status = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الموقع الجغرافي',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('الموقع الحالي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.infoBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _addressController,
              labelText: 'العنوان التفصيلي',
              prefixIcon: Icons.location_on,
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              },
              fieldColor: AppColors.infoBlue.withOpacity(0.05),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _latitudeController,
                    labelText: 'خط العرض',
                    prefixIcon: Icons.explore,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                    fieldColor: AppColors.infoBlue.withOpacity(0.05),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _longitudeController,
                    labelText: 'خط الطول',
                    prefixIcon: Icons.explore,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                    fieldColor: AppColors.infoBlue.withOpacity(0.05),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _googleMapsLinkController,
                    labelText: 'رابط Google Maps',
                    prefixIcon: Icons.map,
                    fieldColor: AppColors.infoBlue.withOpacity(0.05),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _wazeLinkController,
                    labelText: 'رابط Waze',
                    prefixIcon: Icons.directions_car,
                    fieldColor: AppColors.infoBlue.withOpacity(0.05),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _generateMapsLinks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                    ),
                    child: const Text('توليد الروابط'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openMapsForLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningOrange,
                    ),
                    child: const Text('فتح في الخريطة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات مدير المحطة',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _managerNameController,
              labelText: 'اسم المدير',
              prefixIcon: Icons.person,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              },
              fieldColor: AppColors.secondaryTeal.withOpacity(0.05),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _managerPhoneController,
                    labelText: 'هاتف المدير',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      return null;
                    },
                    fieldColor: AppColors.secondaryTeal.withOpacity(0.05),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _managerEmailController,
                    labelText: 'بريد المدير',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    fieldColor: AppColors.secondaryTeal.withOpacity(0.05),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityDatesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السعة والتواريخ',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _capacityController,
              labelText: 'السعة الإجمالية (لتر)',
              prefixIcon: Icons.storage,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }

                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'أدخل رقم صحيح أكبر من صفر';
                }

                return null;
              },
              fieldColor: AppColors.warningOrange.withOpacity(0.05),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, 'established'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تاريخ التأسيس',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'yyyy/MM/dd',
                                ).format(_establishedDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, 'lastMaintenance'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'آخر صيانة',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'yyyy/MM/dd',
                                ).format(_lastMaintenanceDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, 'nextMaintenance'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الصيانة القادمة',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'yyyy/MM/dd',
                                ).format(_nextMaintenanceDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المعدات والأجهزة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addEquipment,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة معدات'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_equipment.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.build, size: 48, color: AppColors.mediumGray),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد معدات مضافة',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._equipment.asMap().entries.map(
                (entry) => EquipmentItem(
                  equipment: entry.value,
                  onEdit: () => _editEquipment(entry.key),
                  onDelete: () => _removeEquipment(entry.key),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'أنواع الوقود المتوفرة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addFuelType,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة نوع وقود'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_fuelTypes.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.local_gas_station,
                      size: 48,
                      color: AppColors.mediumGray,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد أنواع وقود مضافة',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._fuelTypes.asMap().entries.map(
                (entry) => FuelTypeItem(
                  fuelType: entry.value,
                  onEdit: () => _editFuelType(entry.key),
                  onDelete: () => _removeFuelType(entry.key),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المرفقات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة مرفقات'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_newAttachmentPaths.isEmpty &&
                (widget.stationToEdit?.attachments.isEmpty ?? true))
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 48,
                      color: AppColors.mediumGray,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد مرفقات',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Existing attachments from editing
                  if (widget.stationToEdit != null)
                    ...widget.stationToEdit!.attachments.map(
                      (attachment) => AttachmentItem(
                        fileName: attachment.filename,
                        fileSize: 'موجود على السيرفر',
                        onDelete: () {
                          // TODO: Implement delete existing attachment
                        },
                        canDelete: false,
                      ),
                    ),
                  // New attachments
                  ..._newAttachmentPaths.asMap().entries.map(
                    (entry) => AttachmentItem(
                      fileName: entry.value.split('/').last,
                      fileSize: _formatFileSize(entry.value),
                      onDelete: () {
                        setState(() {
                          _newAttachmentPaths.removeAt(entry.key);
                        });
                      },
                      canDelete: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(String path) {
    try {
      final file = File(path);
      final size = file.lengthSync();
      if (size < 1024) {
        return '${size} B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'غير معروف';
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المحطة'),
        content: const Text(
          'هل أنت متأكد من حذف هذه المحطة؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement delete station
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حذف المحطة بنجاح'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
              Navigator.pop(context);
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

// Dialog for adding/editing equipment
class EquipmentDialog extends StatefulWidget {
  final StationEquipment? equipment;
  final Function(StationEquipment) onSave;

  const EquipmentDialog({super.key, this.equipment, required this.onSave});

  @override
  State<EquipmentDialog> createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<EquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _type = 'مضخة';
  DateTime _installationDate = DateTime.now();
  DateTime _lastServiceDate = DateTime.now();
  DateTime _nextServiceDate = DateTime.now().add(const Duration(days: 180));
  String _status = 'نشط';

  final List<String> _types = [
    'مضخة',
    'خزان',
    'نظام أمن',
    'نظام حريق',
    'مولد',
    'أخرى',
  ];
  final List<String> _statuses = ['نشط', 'معطل', 'تحت الصيانة'];

  @override
  void initState() {
    super.initState();
    if (widget.equipment != null) {
      final equipment = widget.equipment!;
      _nameController.text = equipment.equipmentName;
      _serialController.text = equipment.serialNumber;
      _manufacturerController.text = equipment.manufacturer;
      _type = equipment.equipmentType;
      _installationDate = equipment.installationDate;
      _lastServiceDate = equipment.lastServiceDate;
      _nextServiceDate = equipment.nextServiceDate;
      _status = equipment.status;
      _notesController.text = equipment.notes ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return AlertDialog(
      title: Text(
        widget.equipment != null ? 'تعديل المعدة' : 'إضافة معدة جديدة',
      ),
      content: SingleChildScrollView(
        child: Container(
          width: isLargeScreen ? 500 : null,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'اسم المعدة',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _serialController,
                        labelText: 'الرقم التسلسلي',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'هذا الحقل مطلوب';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _manufacturerController,
                        labelText: 'الشركة المصنعة',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'هذا الحقل مطلوب';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _type,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _types.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _type = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _status,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _statuses.map((String value) {
                            Color statusColor;
                            switch (value) {
                              case 'نشط':
                                statusColor = Colors.green;
                                break;
                              case 'معطل':
                                statusColor = Colors.red;
                                break;
                              case 'تحت الصيانة':
                                statusColor = Colors.orange;
                                break;
                              default:
                                statusColor = Colors.grey;
                            }
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _status = value!;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate('installation'),
                        child: _buildDateField(
                          'تاريخ التركيب',
                          _installationDate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate('lastService'),
                        child: _buildDateField('آخر صيانة', _lastServiceDate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickDate('nextService'),
                  child: _buildDateField('الصيانة القادمة', _nextServiceDate),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _notesController,
                  labelText: 'ملاحظات',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final equipment = StationEquipment(
                id: widget.equipment?.id ?? '',
                equipmentName: _nameController.text,
                equipmentType: _type,
                serialNumber: _serialController.text,
                manufacturer: _manufacturerController.text,
                installationDate: _installationDate,
                lastServiceDate: _lastServiceDate,
                nextServiceDate: _nextServiceDate,
                status: _status,
                notes: _notesController.text.isNotEmpty
                    ? _notesController.text
                    : null,
              );
              widget.onSave(equipment);
              Navigator.pop(context);
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  Future<void> _pickDate(String field) async {
    DateTime initialDate;
    if (field == 'installation') {
      initialDate = _installationDate;
    } else if (field == 'lastService') {
      initialDate = _lastServiceDate;
    } else {
      initialDate = _nextServiceDate;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (field == 'installation') {
          _installationDate = picked;
        } else if (field == 'lastService') {
          _lastServiceDate = picked;
        } else {
          _nextServiceDate = picked;
        }
      });
    }
  }

  Widget _buildDateField(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تاريخ التركيب',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(DateFormat('yyyy/MM/dd').format(date)),
        ],
      ),
    );
  }
}

class EquipmentItem extends StatelessWidget {
  final StationEquipment equipment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EquipmentItem({
    super.key,
    required this.equipment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (equipment.status) {
      case 'نشط':
        statusColor = Colors.green;
        break;
      case 'معطل':
        statusColor = Colors.red;
        break;
      case 'تحت الصيانة':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.build, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipment.equipmentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${equipment.equipmentType} - ${equipment.manufacturer}',
                  style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'SN: ${equipment.serialNumber}',
                  style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        equipment.status,
                        style: TextStyle(fontSize: 10, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      DateFormat('yyyy/MM').format(equipment.nextServiceDate),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
