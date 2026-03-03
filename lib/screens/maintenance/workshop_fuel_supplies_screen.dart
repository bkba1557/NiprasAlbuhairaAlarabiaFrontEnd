import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:provider/provider.dart';

class WorkshopFuelSuppliesScreen extends StatefulWidget {
  const WorkshopFuelSuppliesScreen({super.key});

  @override
  State<WorkshopFuelSuppliesScreen> createState() =>
      _WorkshopFuelSuppliesScreenState();
}

class _WorkshopFuelSuppliesScreenState extends State<WorkshopFuelSuppliesScreen> {
  String? _stationId;
  String? _stationName;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _stationId = args?['stationId'];
      _stationName = args?['stationName'];
      _loadSupplies();
    });
  }

  Future<void> _loadSupplies() async {
    if (_stationId == null) return;
    await context.read<WorkshopFuelProvider>().fetchSupplies(
          stationId: _stationId!,
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _loadSupplies();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkshopFuelProvider>();
    final supplies = provider.supplies;

    return Scaffold(
      appBar: AppBar(
        title: Text('توريدات الوقود - ${_stationName ?? ''}'),
        actions: [
          IconButton(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSupplies,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: supplies.length,
          itemBuilder: (context, index) {
            final supply = supplies[index];
            final date = DateTime.tryParse(supply['createdAt']?.toString() ?? '') ??
                DateTime.now();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  '${(supply['quantity'] ?? 0).toString()} لتر',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${DateFormat('yyyy/MM/dd').format(date)} | ${supply['supplierName'] ?? 'بدون مورد'}',
                ),
                trailing: Text(
                  '${(supply['totalAmount'] ?? 0).toString()} ريال',
                  style: const TextStyle(color: AppColors.successGreen),
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.workshopFuelSupplyDetails,
                    arguments: supply,
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            AppRoutes.workshopFuelSupplyForm,
            arguments: {
              'stationId': _stationId,
              'stationName': _stationName,
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
