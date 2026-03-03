import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_maintenance_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/screens/tasks/task_location_picker_screen.dart';
import 'package:order_tracker/utils/constants.dart';

class StationMaintenanceFormScreen extends StatefulWidget {
  const StationMaintenanceFormScreen({super.key});

  @override
  State<StationMaintenanceFormScreen> createState() =>
      _StationMaintenanceFormScreenState();
}

class _StationMaintenanceFormScreenState
    extends State<StationMaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stationNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _mapsUrlController = TextEditingController();

  List<Station> _stations = [];
  String? _selectedStationId;
  bool _loadingStations = false;

  List<User> _technicians = [];
  String? _selectedTechnicianId;
  bool _loadingTechnicians = false;
  bool _saving = false;

  String _requestType = 'maintenance';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['type'] is String) {
        setState(() => _requestType = args['type'] as String);
      }
      _loadStations();
      _loadTechnicians();
    });
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapsUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicians() async {
    setState(() => _loadingTechnicians = true);
    try {
      final provider = context.read<StationMaintenanceProvider>();
      final technicians = await provider.fetchTechnicians();
      if (!mounted) return;
      final filtered = technicians
          .where(
            (tech) => tech.role.trim().toLowerCase() == 'maintenance_station',
          )
          .toList();
      setState(() => _technicians = filtered);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل الفنيين: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingTechnicians = false);
      }
    }
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final stationProvider = context.read<StationProvider>();
      await stationProvider.fetchStations(limit: 0);
      if (!mounted) return;
      final stations = List<Station>.from(stationProvider.stations);
      stations.sort((a, b) => a.stationName.compareTo(b.stationName));
      setState(() => _stations = stations);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل المحطات: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingStations = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStationId == null || _selectedStationId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المحطة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    if (_selectedTechnicianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الفني المسؤول'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<StationMaintenanceProvider>();
    final selectedStation = _stations.firstWhere(
      (station) => station.id == _selectedStationId,
      orElse: () => Station(
        id: _selectedStationId!,
        stationCode: '',
        stationName: _stationNameController.text.trim(),
        location: _addressController.text.trim(),
        city: '',
        managerName: '',
        managerPhone: '',
        fuelTypes: const [],
        pumps: const [],
        fuelPrices: const [],
        createdById: '',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final selectedTech = _technicians.firstWhere(
      (tech) => tech.id == _selectedTechnicianId,
      orElse: () => User(
        id: _selectedTechnicianId!,
        name: '',
        email: '',
        role: '',
        company: '',
      ),
    );

    final created = await provider.createRequest(
      type: _requestType,
      stationName: selectedStation.stationName.trim(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      technicianId: _selectedTechnicianId!,
      stationAddress: _addressController.text.trim(),
      stationLat: _parseDouble(_latController.text),
      stationLng: _parseDouble(_lngController.text),
      googleMapsUrl: _mapsUrlController.text.trim().isEmpty
          ? _buildMapsUrlFromCoords()
          : _mapsUrlController.text.trim(),
      technicianName: selectedTech.name,
      stationId: selectedStation.id,
    );

    setState(() => _saving = false);

    if (!mounted) return;
    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الطلب بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ أثناء الحفظ'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _pickLocationOnMap() async {
    final initialLat = _parseDouble(_latController.text);
    final initialLng = _parseDouble(_lngController.text);
    final result = await Navigator.push<TaskLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskLocationPickerScreen(
          initialLat: initialLat,
          initialLng: initialLng,
          initialAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        ),
      ),
    );

    if (result == null) return;

    _latController.text = result.latitude.toStringAsFixed(6);
    _lngController.text = result.longitude.toStringAsFixed(6);

    if (result.address != null && result.address!.trim().isNotEmpty) {
      _addressController.text = result.address!.trim();
    } else {
      final parts = [
        result.city,
        result.district,
        result.street,
      ].where((item) => item != null && item!.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        _addressController.text = parts.join(' - ');
      }
    }

    if (_mapsUrlController.text.trim().isEmpty) {
      final url = _buildMapsUrlFromCoords();
      if (url != null) _mapsUrlController.text = url;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _requestType == 'development'
        ? 'إنشاء تطوير محطة'
        : _requestType == 'other'
            ? 'إنشاء طلب محطة'
            : 'إنشاء صيانة محطة';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final maxWidth =
              constraints.maxWidth < 900 ? constraints.maxWidth : 900.0;
          final horizontalPadding = isCompact ? 16.0 : 24.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  children: [
            TextFormField(
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'رقم الطلب',
                hintText: 'يتم توليده تلقائياً بعد الحفظ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _requestType,
              decoration: const InputDecoration(labelText: 'نوع الطلب'),
              items: const [
                DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                DropdownMenuItem(value: 'development', child: Text('تطوير')),
                DropdownMenuItem(value: 'other', child: Text('أخرى')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _requestType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_loadingStations)
              const Center(child: CircularProgressIndicator())
            else if (_stations.isEmpty)
              Text(
                'لا توجد محطات مسجلة حالياً',
                style: const TextStyle(color: AppColors.errorRed),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedStationId,
                decoration: const InputDecoration(labelText: 'اسم المحطة'),
                items: _stations
                    .map(
                      (station) => DropdownMenuItem<String>(
                        value: station.id,
                        child: Text(
                          station.stationCode.isNotEmpty
                              ? '${station.stationName} (${station.stationCode})'
                              : station.stationName,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final selected = _stations.firstWhere(
                    (station) => station.id == value,
                    orElse: () => _stations.first,
                  );
                  final addressParts = [
                    selected.location,
                    selected.city,
                  ].where((part) => part.trim().isNotEmpty).toList();
                  setState(() {
                    _selectedStationId = value;
                    _stationNameController.text = selected.stationName;
                    if (addressParts.isNotEmpty) {
                      _addressController.text = addressParts.join(' - ');
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'اسم المحطة مطلوب';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان الطلب'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'عنوان الطلب مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'وصف الأعمال'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Text(
              'موقع المحطة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _pickLocationOnMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('اختيار من الخريطة'),
              ),
            ),
            if (_addressController.text.trim().isNotEmpty ||
                (_latController.text.trim().isNotEmpty &&
                    _lngController.text.trim().isNotEmpty)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Text(
                  _addressController.text.trim().isNotEmpty
                      ? _addressController.text.trim()
                      : 'الموقع المختار: ${_latController.text}, ${_lngController.text}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'تعيين الفني',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_loadingTechnicians)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _selectedTechnicianId,
                decoration: const InputDecoration(
                  labelText: 'اختر الفني',
                ),
                items: _technicians
                    .map(
                      (tech) => DropdownMenuItem<String>(
                        value: tech.id,
                        child: Text(tech.name.isNotEmpty ? tech.name : tech.email),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedTechnicianId = value);
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى اختيار الفني';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الطلب'),
            ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double? _parseDouble(String value) {
    if (value.trim().isEmpty) return null;
    final sanitized = value.replaceAll(',', '.');
    return double.tryParse(sanitized);
  }

  String? _buildMapsUrlFromCoords() {
    final lat = _parseDouble(_latController.text);
    final lng = _parseDouble(_lngController.text);
    if (lat == null || lng == null) return null;
    return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
  }
}
