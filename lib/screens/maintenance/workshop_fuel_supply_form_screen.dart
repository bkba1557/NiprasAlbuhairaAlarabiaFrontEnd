import 'package:flutter/material.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class WorkshopFuelSupplyFormScreen extends StatefulWidget {
  const WorkshopFuelSupplyFormScreen({super.key});

  @override
  State<WorkshopFuelSupplyFormScreen> createState() =>
      _WorkshopFuelSupplyFormScreenState();
}

class _WorkshopFuelSupplyFormScreenState
    extends State<WorkshopFuelSupplyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _tankerController = TextEditingController();
  final _notesController = TextEditingController();

  String? _stationId;
  String? _stationName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _stationId = args?['stationId'];
      _stationName = args?['stationName'];
      final provider = context.read<WorkshopFuelProvider>();
      if (provider.unitPrice > 0) {
        _priceController.text = provider.unitPrice.toString();
      }
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _tankerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_stationId == null) return;
    final provider = context.read<WorkshopFuelProvider>();

    final payload = {
      'stationId': _stationId,
      'stationName': _stationName,
      'quantity': double.tryParse(_quantityController.text.trim()) ?? 0,
      'unitPrice': double.tryParse(_priceController.text.trim()) ?? 0,
      'supplierName': _supplierController.text.trim(),
      'tankerNumber': _tankerController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    final success = await provider.createSupply(payload);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة التوريد بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل إضافة التوريد'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة توريد'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الكمية (لتر)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الكمية مطلوبة';
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
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'اسم المورد'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tankerController,
                decoration: const InputDecoration(labelText: 'رقم التنكر'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
