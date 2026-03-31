import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/custom_text_field.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';

class StationFormScreen extends StatefulWidget {
  final Station? stationToEdit;

  const StationFormScreen({super.key, this.stationToEdit});

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _stationNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();

  final List<String> _availableFuelTypes = [
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
  ];

  List<String> _selectedFuelTypes = ['بنزين 91'];

  bool isWeb(BuildContext context) => MediaQuery.of(context).size.width >= 1100;

  @override
  void initState() {
    super.initState();
    if (widget.stationToEdit != null) {
      _initializeFormWithStation();
    }
  }

  void _initializeFormWithStation() {
    final station = widget.stationToEdit!;
    _stationNameController.text = station.stationName;
    _locationController.text = station.location;
    _cityController.text = station.city;
    _managerNameController.text = station.managerName;
    _managerPhoneController.text = station.managerPhone;
    _selectedFuelTypes = List.from(station.fuelTypes);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final stationProvider = Provider.of<StationProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final station = Station(
      id: widget.stationToEdit?.id ?? '',
      stationCode: widget.stationToEdit?.stationCode ?? '',
      stationName: _stationNameController.text.trim(),
      location: _locationController.text.trim(),
      city: _cityController.text.trim(),
      managerName: _managerNameController.text.trim(),
      managerPhone: _managerPhoneController.text.trim(),
      fuelTypes: _selectedFuelTypes,
      pumps: widget.stationToEdit?.pumps ?? [],
      fuelPrices: widget.stationToEdit?.fuelPrices ?? [],
      createdById: authProvider.user?.id ?? '',
      createdByName: authProvider.user?.name,
      isActive: true,
      createdAt: widget.stationToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = widget.stationToEdit != null
        ? false
        : await stationProvider.createStation(station);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم حفظ المحطة بنجاح'
              : (stationProvider.error ?? 'حدث خطأ'),
        ),
        backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
      ),
    );

    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final bool web = isWeb(context);
    final bool isEditing = widget.stationToEdit != null;
    final bool isOwner = authProvider.role == 'owner';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل المحطة' : 'إضافة محطة جديدة',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (isEditing && isOwner)
            IconButton(
              tooltip: 'حذف المحطة',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد حذف المحطة'),
                    content: const Text(
                      'هل أنت متأكد أنك تريد حذف هذه المحطة؟ سيتم حذف جميع البيانات المرتبطة بها ولا يمكن التراجع عن هذا الإجراء.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorRed,
                        ),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                final stationId = widget.stationToEdit?.id;
                if (stationId == null || stationId.isEmpty) return;

                final success = await stationProvider.deleteStation(stationId);

                if (!mounted) return;

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف المحطة بنجاح'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        stationProvider.error ?? 'فشل حذف المحطة',
                      ),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(web ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStationInfoCard(web),
                  const SizedBox(height: 16),
                  _buildFuelTypesCard(web),
                  const SizedBox(height: 28),
                  GradientButton(
                    onPressed: stationProvider.isLoading ? null : _submitForm,
                    text: stationProvider.isLoading
                        ? 'جاري الحفظ...'
                        : (isEditing ? 'تحديث المحطة' : 'إنشاء المحطة'),
                    gradient: AppColors.accentGradient,
                    isLoading: stationProvider.isLoading,
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

  // ================= Widgets =================

  Widget _buildStationInfoCard(bool web) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(web ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('معلومات المحطة'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _stationNameController,
              labelText: 'اسم المحطة',
              prefixIcon: Icons.business,
              validator: _requiredValidator,
              fieldColor: AppColors.primaryBlue.withOpacity(0.05),
            ),
            const SizedBox(height: 14),
            web
                ? Row(
                    children: [
                      Expanded(child: _cityField()),
                      const SizedBox(width: 14),
                      Expanded(child: _locationField()),
                    ],
                  )
                : Column(
                    children: [
                      _cityField(),
                      const SizedBox(height: 14),
                      _locationField(),
                    ],
                  ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _managerNameController,
              labelText: 'اسم المدير',
              prefixIcon: Icons.person,
              validator: _requiredValidator,
              fieldColor: AppColors.primaryBlue.withOpacity(0.05),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _managerPhoneController,
              labelText: 'هاتف المدير',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: _requiredValidator,
              fieldColor: AppColors.primaryBlue.withOpacity(0.05),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypesCard(bool web) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(web ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('أنواع الوقود المتاحة'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableFuelTypes.map((fuelType) {
                final isSelected = _selectedFuelTypes.contains(fuelType);
                return FilterChip(
                  label: Text(fuelType),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selected
                          ? _selectedFuelTypes.add(fuelType)
                          : _selectedFuelTypes.remove(fuelType);
                    });
                  },
                  selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                  backgroundColor: AppColors.backgroundGray,
                  checkmarkColor: AppColors.primaryBlue,
                );
              }).toList(),
            ),
            if (_selectedFuelTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'يجب اختيار نوع وقود واحد على الأقل',
                  style: TextStyle(color: AppColors.errorRed),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= Helpers =================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _cityField() => CustomTextField(
    controller: _cityController,
    labelText: 'المدينة',
    prefixIcon: Icons.location_city,
    validator: _requiredValidator,
    fieldColor: AppColors.primaryBlue.withOpacity(0.05),
  );

  Widget _locationField() => CustomTextField(
    controller: _locationController,
    labelText: 'الموقع التفصيلي',
    prefixIcon: Icons.location_on,
    validator: _requiredValidator,
    fieldColor: AppColors.primaryBlue.withOpacity(0.05),
  );

  String? _requiredValidator(String? value) =>
      value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null;
}
