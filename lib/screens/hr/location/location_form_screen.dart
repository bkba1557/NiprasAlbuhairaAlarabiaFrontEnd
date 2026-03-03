import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:order_tracker/models/models_hr.dart';
import 'package:order_tracker/providers/hr/hr_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/screens/tasks/task_location_picker_screen.dart';
import 'package:provider/provider.dart';

class LocationFormScreen extends StatefulWidget {
  const LocationFormScreen({super.key});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  final _maxDistanceController = TextEditingController(text: '100');
  final _workStartController = TextEditingController(text: '08:00');
  final _workEndController = TextEditingController(text: '17:00');

  String _type = 'مكتب';
  double? _lat;
  double? _lng;
  bool _isSaving = false;
  bool _isLoadingEmployees = false;
  List<Employee> _employees = [];
  final Set<String> _selectedEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    _maxDistanceController.dispose();
    _workStartController.dispose();
    _workEndController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final provider = Provider.of<HRProvider>(context, listen: false);
      await provider.fetchEmployees(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _employees = provider.employees;
      });
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('تعذر جلب الموظفين: $error', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _setCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('يرجى تفعيل خدمات الموقع أولاً', AppColors.warningOrange);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnackBar('تم رفض صلاحية الموقع', AppColors.errorRed);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _lat = position.latitude;
      _lng = position.longitude;
    });
    _showSnackBar('تم تحديد الموقع الحالي', AppColors.successGreen);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      _showSnackBar('يرجى تحديد الإحداثيات', AppColors.warningOrange);
      return;
    }

    final radius = double.tryParse(_radiusController.text) ?? 100;
    final maxDistance =
        double.tryParse(_maxDistanceController.text) ?? radius;

    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'type': _type,
        'address': _addressController.text.trim(),
        'coordinates': {
          'latitude': _lat,
          'longitude': _lng,
        },
        'radius': radius,
        'workingHours': {
          'start': _workStartController.text.trim(),
          'end': _workEndController.text.trim(),
          'flexible': false,
        },
        'offDays': const [],
        'settings': {
          'requireLocation': true,
          'allowRemote': false,
          'maxDistance': maxDistance,
        },
      };

      final provider = Provider.of<HRProvider>(context, listen: false);
      final location = await provider.createLocation(data);

      if (location != null && _selectedEmployeeIds.isNotEmpty) {
        await provider.assignLocationToEmployees(
          _selectedEmployeeIds.toList(),
          location.id,
        );
      }

      if (!mounted) return;
      _showSnackBar('تم إنشاء الموقع بنجاح', AppColors.successGreen);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('حدث خطأ: $error', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectEmployees() async {
    if (_employees.isEmpty && !_isLoadingEmployees) {
      await _loadEmployees();
    }

    final searchController = TextEditingController();
    final selected = Set<String>.from(_selectedEmployeeIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.trim();
            final filtered = query.isEmpty
                ? _employees
                : _employees.where((e) {
                    return e.name.contains(query) ||
                        e.employeeId.contains(query);
                  }).toList();

            return AlertDialog(
              title: const Text('اختيار الموظفين'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'بحث بالاسم أو الرقم',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: _isLoadingEmployees
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                              ? const Center(child: Text('لا توجد نتائج'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final emp = filtered[index];
                                    final isSelected =
                                        selected.contains(emp.id);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      title: Text(emp.name),
                                      subtitle: Text(emp.employeeId),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            selected.add(emp.id);
                                          } else {
                                            selected.remove(emp.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('تم'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();

    if (result == null) return;
    setState(() {
      _selectedEmployeeIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _pickFromMap() async {
    final result = await Navigator.push<TaskLocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskLocationPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
          initialAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
      if (result.address != null && result.address!.isNotEmpty) {
        _addressController.text = result.address!;
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة موقع عمل'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الموقع',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'نوع الموقع',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'مكتب', child: Text('مكتب')),
                DropdownMenuItem(value: 'مصنع', child: Text('مصنع')),
                DropdownMenuItem(value: 'موقع', child: Text('موقع')),
                DropdownMenuItem(value: 'فرع', child: Text('فرع')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'نصف القطر بالمتر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxDistanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'أقصى مسافة مسموحة (متر)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _workStartController,
                    decoration: const InputDecoration(
                      labelText: 'بداية العمل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _workEndController,
                    decoration: const InputDecoration(
                      labelText: 'نهاية العمل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _setCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('تحديد موقعي الآن'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickFromMap,
                    icon: const Icon(Icons.map),
                    label: const Text('اختيار من الخريطة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'ربط الموظفين بالموقع',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedEmployeeIds.isEmpty
                          ? 'لم يتم اختيار موظفين'
                          : 'تم اختيار ${_selectedEmployeeIds.length} موظف',
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _selectEmployees,
                    icon: const Icon(Icons.group_add),
                    label: const Text('اختيار'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lat != null && _lng != null
                  ? 'الإحداثيات: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}'
                  : 'لم يتم تحديد الإحداثيات',
              style: const TextStyle(color: AppColors.mediumGray),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الموقع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hrTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
