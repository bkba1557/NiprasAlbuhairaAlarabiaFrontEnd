import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/vehicle_model.dart';
import 'package:order_tracker/providers/maintenance_provider.dart';
import 'package:order_tracker/providers/vehicle_provider.dart';
import 'package:provider/provider.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final dynamic maintenanceRecord;

  const MaintenanceFormScreen({super.key, this.maintenanceRecord});

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVehicleId;
  String? _inspectionMonth;

  @override
  void initState() {
    super.initState();
    _inspectionMonth = widget.maintenanceRecord?['inspectionMonth']?.toString() ??
        DateFormat('yyyy-MM').format(DateTime.now());
    _selectedVehicleId = widget.maintenanceRecord?['vehicleId']?.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vehicleProvider = context.read<VehicleProvider>();
      if (vehicleProvider.vehicles.isEmpty && !vehicleProvider.isLoading) {
        await vehicleProvider.fetchVehicles();
      }
      if (!mounted) return;
      if ((_selectedVehicleId ?? '').isEmpty) {
        final plateNumber =
            widget.maintenanceRecord?['plateNumber']?.toString().trim() ?? '';
        if (plateNumber.isNotEmpty) {
          Vehicle? vehicle;
          for (final item in vehicleProvider.vehicles) {
            if (item.plateNumber.trim() == plateNumber) {
              vehicle = item;
              break;
            }
          }
          if (vehicle != null) {
            final selectedVehicleId = vehicle.id;
            setState(() {
              _selectedVehicleId = selectedVehicleId;
            });
          }
        }
      } else {
        setState(() {});
      }
    });
  }

  Vehicle? get _selectedVehicle {
    return context.read<VehicleProvider>().findById(_selectedVehicleId);
  }

  Future<void> _pickInspectionMonth() async {
    final baseDate = DateTime.tryParse('${_inspectionMonth ?? ''}-01') ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: baseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _inspectionMonth = DateFormat('yyyy-MM').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      _showSnack('اختر سيارة صحيحة قبل الحفظ', Colors.red);
      return;
    }
    if (vehicle.linkedDriver == null) {
      _showSnack('السيارة المختارة غير مربوطة بسائق', Colors.red);
      return;
    }
    if (vehicle.linkedTanker == null) {
      _showSnack('السيارة المختارة غير مربوطة بصهريج', Colors.red);
      return;
    }

    final provider = context.read<MaintenanceProvider>();
    final payload = {
      'vehicleId': vehicle.id,
      'driverRecordId': vehicle.linkedDriver!.id,
      'tankerId': vehicle.linkedTanker!.id,
      'inspectionMonth':
          _inspectionMonth ?? DateFormat('yyyy-MM').format(DateTime.now()),
      'plateNumber': vehicle.plateNumber,
      'vehicleType': vehicle.vehicleType,
      'fuelType': vehicle.fuelType,
      'tankNumber': vehicle.linkedTanker!.number,
      'driverId': vehicle.linkedDriver!.nationalId ?? '',
      'driverName': vehicle.linkedDriver!.name,
      'driverLicenseNumber': vehicle.linkedDriver!.licenseNumber,
      'driverLicenseExpiry':
          vehicle.linkedDriver!.licenseExpiryDate?.toIso8601String(),
      'vehicleLicenseNumber': vehicle.vehicleLicenseNumber,
      'vehicleLicenseIssueDate':
          vehicle.vehicleLicenseIssueDate?.toIso8601String(),
      'vehicleLicenseExpiry': vehicle.vehicleLicenseExpiry?.toIso8601String(),
      'vehicleOperatingCardNumber': vehicle.vehicleOperatingCardNumber,
      'vehicleOperatingCardIssueDate':
          vehicle.vehicleOperatingCardIssueDate?.toIso8601String(),
      'vehicleOperatingCardExpiryDate':
          vehicle.vehicleOperatingCardExpiryDate?.toIso8601String(),
      'vehicleRegistrationSerialNumber': vehicle.vehicleRegistrationSerialNumber,
      'vehicleRegistrationNumber': vehicle.vehicleRegistrationNumber,
      'vehicleRegistrationIssueDate':
          vehicle.vehicleRegistrationIssueDate?.toIso8601String(),
      'vehicleRegistrationExpiryDate':
          vehicle.vehicleRegistrationExpiryDate?.toIso8601String(),
      'vehicleInsurancePolicyNumber': vehicle.vehicleInsurancePolicyNumber,
      'vehicleInsuranceIssueDate':
          vehicle.vehicleInsuranceIssueDate?.toIso8601String(),
      'vehicleInsuranceExpiryDate':
          vehicle.vehicleInsuranceExpiryDate?.toIso8601String(),
      'vehiclePeriodicInspectionIssueDate':
          vehicle.vehiclePeriodicInspectionIssueDate?.toIso8601String(),
      'vehiclePeriodicInspectionExpiryDate':
          vehicle.vehiclePeriodicInspectionExpiryDate?.toIso8601String(),
      'vehiclePeriodicInspectionDocumentNumber':
          vehicle.vehiclePeriodicInspectionDocumentNumber,
    };

    try {
      if (widget.maintenanceRecord != null) {
        await provider.updateMaintenanceRecord(
          widget.maintenanceRecord['_id'] ?? widget.maintenanceRecord['id'],
          payload,
        );
        _showSnack('تم تحديث سجل الصيانة بنجاح', Colors.green);
      } else {
        await provider.createMaintenanceRecord(payload);
        _showSnack('تم إنشاء سجل الصيانة بنجاح', Colors.green);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnack('حدث خطأ: $e', Colors.red);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final provider = context.watch<MaintenanceProvider>();
    final selectedVehicle = _selectedVehicle;
    final vehicles = List<Vehicle>.from(vehicleProvider.vehicles)
      ..sort((a, b) => a.plateNumber.compareTo(b.plateNumber));
    final hasSelectedVehicle =
        _selectedVehicleId != null &&
        vehicles.any((vehicle) => vehicle.id == _selectedVehicleId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.maintenanceRecord != null
              ? 'تعديل سجل الصيانة'
              : 'سجل صيانة جديد',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختيار السيارة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: hasSelectedVehicle ? _selectedVehicleId : null,
                      decoration: const InputDecoration(
                        labelText: 'السيارة',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                        helperText:
                            'بعد اختيار السيارة ستظهر بياناتها وربطها بالسائق والصهريج تلقائيًا',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('اختر سيارة'),
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
                              });
                            },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'اختر السيارة أولًا';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickInspectionMonth,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'شهر الفحص',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(
                          _inspectionMonth ?? DateFormat('yyyy-MM').format(DateTime.now()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (vehicleProvider.isLoading && vehicles.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (selectedVehicle == null)
              _buildMessageCard(
                'اختر سيارة لعرض جميع بياناتها وربطها التشغيلي.',
                Colors.blue,
              )
            else ...[
              _buildFleetCard(selectedVehicle),
              const SizedBox(height: 16),
              _buildDocumentsCard(selectedVehicle),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : _submitForm,
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(widget.maintenanceRecord != null
                      ? Icons.save_outlined
                      : Icons.add_circle_outline),
              label: Text(
                widget.maintenanceRecord != null
                    ? 'حفظ التغييرات'
                    : 'إنشاء السجل',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFleetCard(Vehicle vehicle) {
    final driver = vehicle.linkedDriver;
    final tanker = vehicle.linkedTanker;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات السيارة والربط',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _buildLine('رقم السيارة', vehicle.plateNumber),
            _buildLine('نوع السيارة', vehicle.vehicleType),
            _buildLine('الحالة', vehicle.status),
            _buildLine('الموديل', vehicle.model.isEmpty ? 'غير محدد' : vehicle.model),
            _buildLine('نوع الوقود', vehicle.fuelType ?? 'غير محدد'),
            _buildLine('السائق', driver?.name ?? 'غير مرتبط'),
            _buildLine('هوية السائق', driver?.nationalId ?? 'غير مسجلة'),
            _buildLine('رخصة السائق', driver?.licenseNumber ?? 'غير مسجلة'),
            _buildLine('الصهريج', tanker?.number ?? 'غير مرتبط'),
            _buildLine(
              'سعة الصهريج',
              tanker?.capacityLiters == null
                  ? 'غير محددة'
                  : '${tanker!.capacityLiters} لتر',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsCard(Vehicle vehicle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات المستندات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _buildLine('رخصة المركبة', vehicle.vehicleLicenseNumber),
            _buildLine('انتهاء رخصة المركبة', _formatDate(vehicle.vehicleLicenseExpiry)),
            _buildLine('بطاقة التشغيل', vehicle.vehicleOperatingCardNumber),
            _buildLine(
              'انتهاء بطاقة التشغيل',
              _formatDate(vehicle.vehicleOperatingCardExpiryDate),
            ),
            _buildLine('رقم الاستمارة', vehicle.vehicleRegistrationNumber),
            _buildLine(
              'انتهاء الاستمارة',
              _formatDate(vehicle.vehicleRegistrationExpiryDate),
            ),
            _buildLine('وثيقة التأمين', vehicle.vehicleInsurancePolicyNumber),
            _buildLine(
              'انتهاء التأمين',
              _formatDate(vehicle.vehicleInsuranceExpiryDate),
            ),
            _buildLine(
              'الفحص الدوري',
              _formatDate(vehicle.vehiclePeriodicInspectionExpiryDate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.trim().isEmpty ? 'غير محدد' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String text, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    return DateFormat('yyyy/MM/dd').format(value.toLocal());
  }
}
