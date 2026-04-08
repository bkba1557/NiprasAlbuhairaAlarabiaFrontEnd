import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/models/tanker_model.dart';
import 'package:order_tracker/models/vehicle_model.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/driver_tracking_provider.dart';
import 'package:order_tracker/providers/tanker_provider.dart';
import 'package:order_tracker/providers/vehicle_provider.dart';
import 'package:order_tracker/screens/tracking/driver_live_tracking_screen.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/tracking/tracking_page_shell.dart';
import 'package:provider/provider.dart';

class VehiclesTrackingScreen extends StatefulWidget {
  const VehiclesTrackingScreen({super.key});

  @override
  State<VehiclesTrackingScreen> createState() => _VehiclesTrackingScreenState();
}

class _VehiclesTrackingScreenState extends State<VehiclesTrackingScreen> {
  static const List<String> _vehicleTypes = [
    'سيارة صغيرة',
    'شاحنة صغيرة',
    'شاحنة كبيرة',
    'تانكر',
    'أخرى',
  ];

  static const List<String> _statuses = [
    'فاضي',
    'في طلب',
    'تحت الصيانة',
    'شغال',
    'متوقف',
  ];

  static const List<String> _fuelTypes = [
    'بنزين',
    'ديزل',
    'كيروسين',
    'غاز طبيعي',
    'كهرباء',
  ];

  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => context.read<VehicleProvider>().fetchVehicles(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.trim()) {
      case 'في طلب':
        return AppColors.statusGold;
      case 'تحت الصيانة':
        return AppColors.pendingYellow;
      case 'شغال':
        return AppColors.infoBlue;
      case 'متوقف':
        return AppColors.errorRed;
      default:
        return AppColors.successGreen;
    }
  }

  List<Vehicle> _applySearch(List<Vehicle> vehicles) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return vehicles;
    return vehicles.where((vehicle) {
      return vehicle.plateNumber.toLowerCase().contains(query) ||
          vehicle.vehicleType.toLowerCase().contains(query) ||
          vehicle.status.toLowerCase().contains(query) ||
          vehicle.model.toLowerCase().contains(query) ||
          (vehicle.fuelType ?? '').toLowerCase().contains(query) ||
          vehicle.notes.toLowerCase().contains(query) ||
          (vehicle.linkedDriver?.name ?? '').toLowerCase().contains(query) ||
          (vehicle.linkedTanker?.number ?? '').toLowerCase().contains(query);
    }).toList();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    final local = value.toLocal();
    return '${local.year}/${_twoDigits(local.month)}/${_twoDigits(local.day)}';
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return '${_formatDate(local)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  Future<void> _openLiveTracking(Vehicle vehicle) async {
    final driverId = vehicle.linkedDriverId?.trim() ?? '';
    if (driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن فتح التتبع بدون سائق مرتبط بالسيارة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverLiveTrackingScreen(driverId: driverId),
      ),
    );
  }

  Future<List<Driver>> _loadDriverOptions({Vehicle? vehicle}) async {
    final provider = context.read<DriverProvider>();
    final drivers = await provider.fetchActiveDrivers();
    final items = List<Driver>.from(drivers);
    final linkedDriver = vehicle?.linkedDriver;
    if (linkedDriver != null && items.every((item) => item.id != linkedDriver.id)) {
      items.insert(
        0,
        Driver(
          id: linkedDriver.id,
          name: linkedDriver.name,
          nationalId: linkedDriver.nationalId,
          licenseNumber: linkedDriver.licenseNumber,
          phone: linkedDriver.phone,
          vehicleType: vehicle?.vehicleType ?? 'غير محدد',
          vehicleNumber: vehicle?.plateNumber,
          vehicleStatus: vehicle?.status ?? 'فاضي',
          status: linkedDriver.status,
          isActive: true,
          createdById: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<List<Tanker>> _loadTankerOptions({Vehicle? vehicle}) async {
    final provider = context.read<TankerProvider>();
    await provider.fetchTankers();
    final items = List<Tanker>.from(provider.tankers);
    final linkedTanker = vehicle?.linkedTanker;
    if (linkedTanker != null && items.every((item) => item.id != linkedTanker.id)) {
      items.insert(
        0,
        Tanker(
          id: linkedTanker.id,
          number: linkedTanker.number,
          status: linkedTanker.status,
          capacityLiters: linkedTanker.capacityLiters,
          fuelType: linkedTanker.fuelType,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    items.sort((a, b) => a.number.compareTo(b.number));
    return items;
  }

  Future<void> _showVehicleForm({Vehicle? vehicle}) async {
    final provider = context.read<VehicleProvider>();
    final driverOptions = await _loadDriverOptions(vehicle: vehicle);
    final tankerOptions = await _loadTankerOptions(vehicle: vehicle);
    if (!mounted) return;

    final plateController = TextEditingController(text: vehicle?.plateNumber ?? '');
    final modelController = TextEditingController(text: vehicle?.model ?? '');
    final yearController = TextEditingController(
      text: vehicle?.year?.toString() ?? '',
    );
    final licenseNumberController = TextEditingController(
      text: vehicle?.vehicleLicenseNumber ?? '',
    );
    final operatingCardController = TextEditingController(
      text: vehicle?.vehicleOperatingCardNumber ?? '',
    );
    final registrationNumberController = TextEditingController(
      text: vehicle?.vehicleRegistrationNumber ?? '',
    );
    final insurancePolicyController = TextEditingController(
      text: vehicle?.vehicleInsurancePolicyNumber ?? '',
    );
    final periodicInspectionDocumentController = TextEditingController(
      text: vehicle?.vehiclePeriodicInspectionDocumentNumber ?? '',
    );
    final notesController = TextEditingController(text: vehicle?.notes ?? '');

    String vehicleType = _vehicleTypes.contains(vehicle?.vehicleType)
        ? vehicle!.vehicleType
        : _vehicleTypes[2];
    String status =
        _statuses.contains(vehicle?.status) ? vehicle!.status : _statuses.first;
    String? fuelType = _fuelTypes.contains(vehicle?.fuelType)
        ? vehicle!.fuelType
        : null;
    String? linkedDriverId = vehicle?.linkedDriverId;
    String? linkedTankerId = vehicle?.linkedTankerId;

    DateTime? vehicleLicenseIssueDate = vehicle?.vehicleLicenseIssueDate;
    DateTime? vehicleLicenseExpiry = vehicle?.vehicleLicenseExpiry;
    DateTime? vehicleOperatingCardIssueDate =
        vehicle?.vehicleOperatingCardIssueDate;
    DateTime? vehicleOperatingCardExpiryDate =
        vehicle?.vehicleOperatingCardExpiryDate;
    DateTime? vehicleRegistrationIssueDate = vehicle?.vehicleRegistrationIssueDate;
    DateTime? vehicleRegistrationExpiryDate =
        vehicle?.vehicleRegistrationExpiryDate;
    DateTime? vehicleInsuranceIssueDate = vehicle?.vehicleInsuranceIssueDate;
    DateTime? vehicleInsuranceExpiryDate =
        vehicle?.vehicleInsuranceExpiryDate;
    DateTime? vehiclePeriodicInspectionIssueDate =
        vehicle?.vehiclePeriodicInspectionIssueDate;
    DateTime? vehiclePeriodicInspectionExpiryDate =
        vehicle?.vehiclePeriodicInspectionExpiryDate;

    Future<void> pickDate(
      StateSetter setDialogState,
      DateTime? currentValue,
      ValueChanged<DateTime?> onChanged,
    ) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: currentValue ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      );
      if (picked != null) {
        setDialogState(() {
          onChanged(picked);
        });
      }
    }

    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(vehicle == null ? 'إضافة سيارة' : 'تعديل السيارة'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: plateController,
                          decoration: const InputDecoration(
                            labelText: 'رقم اللوحة / السيارة',
                            prefixIcon: Icon(Icons.directions_car_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'رقم اللوحة مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: vehicleType,
                                decoration: const InputDecoration(
                                  labelText: 'نوع السيارة',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: _vehicleTypes
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    vehicleType = value ?? _vehicleTypes[2];
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: status,
                                decoration: const InputDecoration(
                                  labelText: 'الحالة',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                                items: _statuses
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    status = value ?? _statuses.first;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: modelController,
                                decoration: const InputDecoration(
                                  labelText: 'الموديل',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: yearController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'سنة الصنع',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: fuelType,
                          decoration: const InputDecoration(
                            labelText: 'نوع الوقود',
                            prefixIcon: Icon(Icons.local_gas_station_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('غير محدد'),
                            ),
                            ..._fuelTypes.map(
                              (item) => DropdownMenuItem<String?>(
                                value: item,
                                child: Text(item),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              fuelType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: linkedDriverId != null &&
                                  driverOptions.any((item) => item.id == linkedDriverId)
                              ? linkedDriverId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'السائق المرتبط',
                            prefixIcon: Icon(Icons.person_pin_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('بدون ربط'),
                            ),
                            ...driverOptions.map(
                              (driver) => DropdownMenuItem<String?>(
                                value: driver.id,
                                child: Text(
                                  [
                                    driver.name,
                                    if ((driver.nationalId ?? '').trim().isNotEmpty)
                                      driver.nationalId!.trim(),
                                  ].join(' • '),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              linkedDriverId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: linkedTankerId != null &&
                                  tankerOptions.any((item) => item.id == linkedTankerId)
                              ? linkedTankerId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'الصهريج المرتبط',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('بدون ربط'),
                            ),
                            ...tankerOptions.map(
                              (tanker) => DropdownMenuItem<String?>(
                                value: tanker.id,
                                child: Text(tanker.number),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              linkedTankerId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: licenseNumberController,
                          decoration: const InputDecoration(
                            labelText: 'رقم رخصة المركبة',
                            prefixIcon: Icon(Icons.article_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'إصدار رخصة المركبة',
                          value: vehicleLicenseIssueDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleLicenseIssueDate,
                            (value) => vehicleLicenseIssueDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'انتهاء رخصة المركبة',
                          value: vehicleLicenseExpiry,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleLicenseExpiry,
                            (value) => vehicleLicenseExpiry = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: operatingCardController,
                          decoration: const InputDecoration(
                            labelText: 'رقم بطاقة التشغيل',
                            prefixIcon: Icon(Icons.credit_card_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'إصدار بطاقة التشغيل',
                          value: vehicleOperatingCardIssueDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleOperatingCardIssueDate,
                            (value) => vehicleOperatingCardIssueDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'انتهاء بطاقة التشغيل',
                          value: vehicleOperatingCardExpiryDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleOperatingCardExpiryDate,
                            (value) => vehicleOperatingCardExpiryDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: registrationNumberController,
                          decoration: const InputDecoration(
                            labelText: 'رقم الاستمارة',
                            prefixIcon: Icon(Icons.confirmation_number_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'إصدار الاستمارة',
                          value: vehicleRegistrationIssueDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleRegistrationIssueDate,
                            (value) => vehicleRegistrationIssueDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'انتهاء الاستمارة',
                          value: vehicleRegistrationExpiryDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleRegistrationExpiryDate,
                            (value) => vehicleRegistrationExpiryDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: insurancePolicyController,
                          decoration: const InputDecoration(
                            labelText: 'رقم وثيقة التأمين',
                            prefixIcon: Icon(Icons.shield_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'إصدار التأمين',
                          value: vehicleInsuranceIssueDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleInsuranceIssueDate,
                            (value) => vehicleInsuranceIssueDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'انتهاء التأمين',
                          value: vehicleInsuranceExpiryDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehicleInsuranceExpiryDate,
                            (value) => vehicleInsuranceExpiryDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: periodicInspectionDocumentController,
                          decoration: const InputDecoration(
                            labelText: 'رقم وثيقة الفحص الدوري',
                            prefixIcon: Icon(Icons.fact_check_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'إصدار الفحص الدوري',
                          value: vehiclePeriodicInspectionIssueDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehiclePeriodicInspectionIssueDate,
                            (value) =>
                                vehiclePeriodicInspectionIssueDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogDateField(
                          label: 'انتهاء الفحص الدوري',
                          value: vehiclePeriodicInspectionExpiryDate,
                          onTap: () => pickDate(
                            setDialogState,
                            vehiclePeriodicInspectionExpiryDate,
                            (value) =>
                                vehiclePeriodicInspectionExpiryDate = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final payload = Vehicle(
                            id: vehicle?.id ?? '',
                            plateNumber: plateController.text.trim(),
                            vehicleType: vehicleType,
                            status: status,
                            model: modelController.text.trim(),
                            year: int.tryParse(yearController.text.trim()),
                            fuelType: fuelType,
                            vehicleLicenseNumber: licenseNumberController.text.trim(),
                            vehicleLicenseIssueDate: vehicleLicenseIssueDate,
                            vehicleLicenseExpiry: vehicleLicenseExpiry,
                            vehicleOperatingCardNumber:
                                operatingCardController.text.trim(),
                            vehicleOperatingCardIssueDate:
                                vehicleOperatingCardIssueDate,
                            vehicleOperatingCardExpiryDate:
                                vehicleOperatingCardExpiryDate,
                            vehicleRegistrationNumber:
                                registrationNumberController.text.trim(),
                            vehicleRegistrationIssueDate:
                                vehicleRegistrationIssueDate,
                            vehicleRegistrationExpiryDate:
                                vehicleRegistrationExpiryDate,
                            vehicleInsurancePolicyNumber:
                                insurancePolicyController.text.trim(),
                            vehicleInsuranceIssueDate: vehicleInsuranceIssueDate,
                            vehicleInsuranceExpiryDate:
                                vehicleInsuranceExpiryDate,
                            vehiclePeriodicInspectionIssueDate:
                                vehiclePeriodicInspectionIssueDate,
                            vehiclePeriodicInspectionExpiryDate:
                                vehiclePeriodicInspectionExpiryDate,
                            vehiclePeriodicInspectionDocumentNumber:
                                periodicInspectionDocumentController.text.trim(),
                            notes: notesController.text.trim(),
                            linkedDriverId: linkedDriverId,
                            linkedTankerId: linkedTankerId,
                            createdAt: vehicle?.createdAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          final saved = vehicle == null
                              ? await provider.createVehicle(payload)
                              : await provider.updateVehicle(vehicle.id, payload);

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, saved);
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    plateController.dispose();
    modelController.dispose();
    yearController.dispose();
    licenseNumberController.dispose();
    operatingCardController.dispose();
    registrationNumberController.dispose();
    insurancePolicyController.dispose();
    periodicInspectionDocumentController.dispose();
    notesController.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vehicle == null ? 'تمت إضافة السيارة' : 'تم تحديث السيارة'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await context.read<VehicleProvider>().fetchVehicles(silent: true);
      if (!mounted) return;
      await context.read<TankerProvider>().fetchTankers(silent: true);
      if (!mounted) return;
      await context.read<DriverTrackingProvider>().fetchTrackingDrivers(
        silent: true,
      );
    } else if (result == false && mounted && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Vehicle vehicle) async {
    final provider = context.read<VehicleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('حذف السيارة'),
          content: Text('هل أنت متأكد من حذف السيارة ${vehicle.plateNumber}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final deleted = await provider.deleteVehicle(vehicle.id);
    if (!mounted) return;
    if (deleted) {
      await context.read<TankerProvider>().fetchTankers(silent: true);
      if (!mounted) return;
      await context.read<DriverTrackingProvider>().fetchTrackingDrivers(
        silent: true,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'تم حذف السيارة' : (provider.error ?? 'فشل الحذف')),
        backgroundColor: deleted ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, provider, _) {
        final allVehicles = provider.vehicles;
        final items = _applySearch(allVehicles);
        final availableCount =
            allVehicles.where((vehicle) => vehicle.status == 'فاضي').length;
        final linkedCount = allVehicles
            .where(
              (vehicle) =>
                  (vehicle.linkedDriverId?.trim().isNotEmpty ?? false) ||
                  (vehicle.linkedTankerId?.trim().isNotEmpty ?? false),
            )
            .length;
        final trackedCount =
            allVehicles.where((vehicle) => vehicle.lastLocation != null).length;

        return RefreshIndicator(
          onRefresh: provider.fetchVehicles,
          child: TrackingPageShell(
            icon: Icons.directions_car_filled_rounded,
            title: 'متابعة السيارات',
            subtitle:
                'إدارة السيارات، ربطها بالسائقين والصهاريج، ومراجعة حالة التشغيل والتتبع من شاشة واحدة.',
            metrics: [
              TrackingMetric(
                label: 'إجمالي السيارات',
                value: '${allVehicles.length}',
                icon: Icons.directions_car_rounded,
                color: AppColors.primaryBlue,
                helper: 'كل السيارات المسجلة في النظام',
              ),
              TrackingMetric(
                label: 'متاحة حاليًا',
                value: '$availableCount',
                icon: Icons.check_circle_rounded,
                color: AppColors.successGreen,
                helper: 'سيارات جاهزة للإسناد أو التشغيل',
              ),
              TrackingMetric(
                label: 'مرتبطة بأسطول',
                value: '$linkedCount',
                icon: Icons.link_rounded,
                color: AppColors.infoBlue,
                helper: 'مرتبطة بسائق أو صهريج',
              ),
              TrackingMetric(
                label: 'تتبع مباشر',
                value: '$trackedCount',
                icon: Icons.route_rounded,
                color: AppColors.statusGold,
                helper: 'وصلت لها إحداثيات حديثة',
              ),
            ],
            headerActions: _buildHeaderActions(provider),
            toolbar: _buildToolbar(items.length),
            child: _buildContent(provider, items),
          ),
        );
      },
    );
  }

  Widget _buildHeaderActions(VehicleProvider provider) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: provider.isLoading
              ? null
              : () => provider.fetchVehicles(silent: true),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تحديث'),
        ),
        OutlinedButton.icon(
          onPressed: provider.isLoading ? null : () => _showVehicleForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة سيارة'),
        ),
      ],
    );
  }

  Widget _buildToolbar(int resultCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final chips = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            TrackingStatusBadge(
              label: '$resultCount نتيجة',
              color: AppColors.infoBlue,
              icon: Icons.filter_alt_rounded,
            ),
            const TrackingStatusBadge(
              label: 'تحديث تلقائي كل 12 ثانية',
              color: AppColors.secondaryTeal,
              icon: Icons.schedule_rounded,
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: TrackingSearchField(
                  controller: _searchController,
                  hintText: 'ابحث برقم السيارة أو السائق أو الصهريج أو الحالة...',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              chips,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackingSearchField(
              controller: _searchController,
              hintText: 'ابحث برقم السيارة أو السائق أو الصهريج أو الحالة...',
              onChanged: (_) => setState(() {}),
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            chips,
          ],
        );
      },
    );
  }

  Widget _buildContent(VehicleProvider provider, List<Vehicle> items) {
    if (provider.isLoading && provider.vehicles.isEmpty) {
      return const TrackingStateCard(
        icon: Icons.directions_car_outlined,
        title: 'جاري تحميل السيارات',
        message: 'يتم الآن جلب السيارات وروابط السائقين والصهاريج.',
        color: AppColors.infoBlue,
        action: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }

    if (provider.error != null && provider.vehicles.isEmpty) {
      return TrackingStateCard(
        icon: Icons.error_outline_rounded,
        title: 'تعذر تحميل السيارات',
        message: provider.error ?? 'حدث خطأ أثناء جلب السيارات.',
        color: AppColors.errorRed,
        action: FilledButton.icon(
          onPressed: provider.fetchVehicles,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }

    if (items.isEmpty) {
      return TrackingStateCard(
        icon: Icons.search_off_rounded,
        title: 'لا توجد نتائج حاليًا',
        message: _searchController.text.trim().isEmpty
            ? 'لا توجد سيارات مسجلة في النظام حاليًا.'
            : 'لا توجد سيارات مطابقة لنص البحث الحالي.',
        color: AppColors.primaryBlue,
        action: _searchController.text.trim().isEmpty
            ? FilledButton.icon(
                onPressed: () => _showVehicleForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة سيارة'),
              )
            : OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('مسح البحث'),
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1320 ? 3 : (width >= 860 ? 2 : 1);
        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map(
                (vehicle) => SizedBox(
                  width: cardWidth,
                  child: _buildVehicleCard(provider, vehicle),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildVehicleCard(VehicleProvider provider, Vehicle vehicle) {
    final color = _statusColor(vehicle.status);
    final driverText = vehicle.linkedDriver?.name.trim().isNotEmpty == true
        ? vehicle.linkedDriver!.name.trim()
        : 'بدون سائق';
    final tankerText = vehicle.linkedTanker?.number.trim().isNotEmpty == true
        ? vehicle.linkedTanker!.number.trim()
        : 'بدون صهريج';
    final lastUpdate = vehicle.lastLocation == null
        ? 'لا يوجد تتبع مباشر بعد'
        : 'آخر تحديث ${_formatTimestamp(vehicle.lastLocation!.timestamp)}';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      color: Colors.white.withValues(alpha: 0.82),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.plateNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.vehicleType}${vehicle.model.trim().isNotEmpty ? ' • ${vehicle.model.trim()}' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TrackingStatusBadge(
                label: vehicle.status,
                color: color,
                icon: Icons.flag_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_pin_outlined, driverText),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.local_shipping_outlined, tankerText),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.route_outlined, lastUpdate),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.article_outlined,
            vehicle.vehicleLicenseNumber.trim().isEmpty
                ? 'رخصة المركبة غير مسجلة'
                : 'الرخصة ${vehicle.vehicleLicenseNumber.trim()}',
          ),
          if (vehicle.activeOrder != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'الطلب الحالي ${vehicle.activeOrder!.orderNumber} • ${vehicle.activeOrder!.status}',
                style: const TextStyle(
                  color: Color(0xFF7C5A03),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openLiveTracking(vehicle),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('فتح التتبع'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: () => _showVehicleForm(vehicle: vehicle),
                icon: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: provider.isLoading ? null : () => _confirmDelete(vehicle),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
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

  Widget _buildDialogDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _formatDate(value),
          style: TextStyle(
            color: value == null ? AppColors.mediumGray : AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
