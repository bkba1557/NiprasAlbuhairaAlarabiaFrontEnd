import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/driver_model.dart';
import 'package:order_tracker/providers/driver_provider.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class WorkshopFuelRefuelFormScreen extends StatefulWidget {
  const WorkshopFuelRefuelFormScreen({super.key});

  @override
  State<WorkshopFuelRefuelFormScreen> createState() =>
      _WorkshopFuelRefuelFormScreenState();
}

class _WorkshopFuelRefuelFormScreenState
    extends State<WorkshopFuelRefuelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _refuelDate = DateTime.now();
  String? _stationId;
  String? _stationName;
  Driver? _selectedDriver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _stationId = args?['stationId'];
      _stationName = args?['stationName'];

      await context.read<DriverProvider>().fetchDrivers();

      if (!mounted) return;
      final provider = context.read<WorkshopFuelProvider>();
      if (provider.unitPrice > 0) {
        _priceController.text = provider.unitPrice.toString();
      }
    });
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _vehicleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stationId == null) return;

    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار السائق'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final provider = context.read<WorkshopFuelProvider>();
    final payload = {
      'stationId': _stationId,
      'stationName': _stationName,
      'liters': double.tryParse(_litersController.text.trim()) ?? 0,
      'unitPrice': double.tryParse(_priceController.text.trim()) ?? 0,
      'driverId': _selectedDriver?.id,
      'driverName': _selectedDriver?.name,
      'vehicleNumber': _vehicleController.text.trim(),
      'notes': _notesController.text.trim(),
      'refuelDate': _refuelDate.toIso8601String(),
    };

    final success = await provider.createRefuel(payload);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل التعبئة بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل تسجيل التعبئة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _pickRefuelDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _refuelDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked == null) return;
    setState(() => _refuelDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();
    final fuelProvider = context.watch<WorkshopFuelProvider>();
    final balance = fuelProvider.currentBalance;
    final dateLabel = DateFormat('yyyy/MM/dd', 'ar').format(_refuelDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعبئة وقود جديدة'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              InkWell(
                onTap: _pickRefuelDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ التعبئة',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(dateLabel),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Driver>(
                value: _selectedDriver,
                isExpanded: true,
                items: driverProvider.drivers.map((driver) {
                  return DropdownMenuItem(
                    value: driver,
                    child: Text(driver.name),
                  );
                }).toList(),
                onChanged: (driver) {
                  setState(() {
                    _selectedDriver = driver;
                    _vehicleController.text = driver?.vehicleNumber ?? '';
                  });
                },
                decoration: const InputDecoration(labelText: 'السائق'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleController,
                decoration: const InputDecoration(labelText: 'رقم السيارة'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _litersController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'عدد اللترات'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'عدد اللترات مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'سعر اللتر'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'رصيد الخزان الحالي: ${balance.toStringAsFixed(2)} لتر',
                  style: const TextStyle(color: AppColors.mediumGray),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text('حفظ التعبئة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
