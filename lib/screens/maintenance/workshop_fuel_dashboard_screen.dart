import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/providers/workshop_fuel_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/maintenance/stats_card.dart';
import 'package:provider/provider.dart';

class WorkshopFuelDashboardScreen extends StatefulWidget {
  const WorkshopFuelDashboardScreen({super.key});

  @override
  State<WorkshopFuelDashboardScreen> createState() =>
      _WorkshopFuelDashboardScreenState();
}

class _WorkshopFuelDashboardScreenState
    extends State<WorkshopFuelDashboardScreen> {
  String? _stationId;
  String? _stationName;
  bool _loadingStations = false;
  DateTime _statsStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _statsEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    await _loadStations();
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    final stationProvider = context.read<StationProvider>();
    await stationProvider.fetchStations();

    final auth = context.read<AuthProvider>();
    String? selected = auth.stationId;
    if (selected == null ||
        stationProvider.stations.every((s) => s.id != selected)) {
      if (stationProvider.stations.isNotEmpty) {
        selected = stationProvider.stations.first.id;
      }
    }

    if (selected != null) {
      final station = stationProvider.stations.firstWhere(
        (s) => s.id == selected,
        orElse: () => stationProvider.stations.first,
      );
      _stationId = station.id;
      _stationName = station.stationName;
    }

    setState(() => _loadingStations = false);
  }

  Future<void> _loadData() async {
    if (_stationId == null) return;
    final fuelProvider = context.read<WorkshopFuelProvider>();
    await fuelProvider.fetchSettings(_stationId!);
    await fuelProvider.fetchRefuels(
      stationId: _stationId!,
      startDate: _statsStart,
      endDate: _statsEnd,
    );
    await fuelProvider.fetchReadings(
      stationId: _stationId!,
      startDate: _statsStart,
      endDate: _statsEnd,
    );
  }

  bool _canManage(String? role) {
    return [
      'owner',
      'admin',
      'manager',
      'maintenance',
      'maintenance_technician',
      'maintenance_car_management',
    ].contains(role);
  }

  double _readNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _topDrivers(List<Map<String, dynamic>> refuels) {
    final totals = <String, Map<String, dynamic>>{};
    for (final refuel in refuels) {
      final name = refuel['driverName']?.toString().trim().isNotEmpty == true
          ? refuel['driverName'].toString()
          : 'سائق غير معروف';
      final liters = _readNum(refuel['liters']);
      if (!totals.containsKey(name)) {
        totals[name] = {
          'driverName': name,
          'liters': 0.0,
          'vehicleNumber': refuel['vehicleNumber']?.toString() ?? '',
        };
      }
      totals[name]!['liters'] =
          (totals[name]!['liters'] as double) + liters;
    }
    final list = totals.values.toList();
    list.sort((a, b) =>
        (b['liters'] as double).compareTo(a['liters'] as double));
    return list;
  }

  Future<void> _confirmDeleteRefuel(Map<String, dynamic> refuel) async {
    final refuelId = (refuel['_id'] ?? refuel['id'] ?? '').toString();
    if (refuelId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التعبئة'),
        content: const Text('هل تريد حذف هذه التعبئة وإرجاع الكمية إلى الخزان؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = context.read<WorkshopFuelProvider>();
    final success = await provider.deleteRefuel(refuelId);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف التعبئة وإرجاع الكمية إلى الخزان'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل حذف التعبئة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _showSettingsDialog(WorkshopFuelProvider provider) async {
    if (_stationId == null) return;
    final capacityCtrl = TextEditingController(
      text: provider.capacity > 0 ? provider.capacity.toString() : '',
    );
    final priceCtrl = TextEditingController(
      text: provider.unitPrice > 0 ? provider.unitPrice.toString() : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات خزان الوقود'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: capacityCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعة الخزان (لتر)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'سعر اللتر (ريال/لتر)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final capacity = double.tryParse(capacityCtrl.text.trim());
    final price = double.tryParse(priceCtrl.text.trim());

    final success = await provider.updateSettings(
      stationId: _stationId!,
      stationName: _stationName,
      capacity: capacity,
      unitPrice: price,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الإعدادات بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل تحديث الإعدادات'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _showReadingDialog(WorkshopFuelProvider provider) async {
    if (_stationId == null) return;
    final readings = provider.readings;
    Map<String, dynamic>? last;
    if (readings.isNotEmpty) {
      readings.sort((a, b) {
        final ad = DateTime.tryParse(a['readingDate']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd = DateTime.tryParse(b['readingDate']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      last = readings.first;
    }
    final prev = _readNum(last?['currentReading']);
    final currentCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إدخال قراءة العداد'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('التاريخ: '),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('القراءة السابقة: ${prev.toStringAsFixed(2)} لتر'),
              const SizedBox(height: 12),
              TextField(
                controller: currentCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'القراءة الحالية'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final current = double.tryParse(currentCtrl.text.trim());
    if (current == null) return;

    final success = await provider.createReading({
      'stationId': _stationId,
      'stationName': _stationName,
      'currentReading': current,
      'readingDate': selectedDate.toIso8601String(),
      'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
    });

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ القراءة بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await provider.fetchReadings(
        stationId: _stationId!,
        startDate: _statsStart,
        endDate: _statsEnd,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل حفظ القراءة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fuelProvider = context.watch<WorkshopFuelProvider>();
    final stationProvider = context.watch<StationProvider>();
    final auth = context.watch<AuthProvider>();
    final role = auth.role;
    final canManage = _canManage(role);

    final balance = fuelProvider.currentBalance;
    final capacity = fuelProvider.capacity;
    final price = fuelProvider.unitPrice;
    final thresholdPercent = fuelProvider.lowThresholdPercent;
    final thresholdLiters = capacity > 0 ? capacity * thresholdPercent / 100 : 0;
    final percent =
        capacity > 0 ? (balance / capacity).clamp(0, 1).toDouble() : 0.0;

    final refuels = fuelProvider.refuels;
    final totalLiters = refuels.fold<double>(0, (sum, r) => sum + _readNum(r['liters']));
    final totalAmount = refuels.fold<double>(0, (sum, r) => sum + _readNum(r['totalAmount']));
    final topDrivers = _topDrivers(refuels).take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مخزون وقود الورشة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingStations)
                const LinearProgressIndicator()
              else if (stationProvider.stations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGray),
                  ),
                  child: DropdownButton<String>(
                    value: _stationId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: stationProvider.stations.map((station) {
                      return DropdownMenuItem(
                        value: station.id,
                        child: Text(station.stationName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final station = stationProvider.stations.firstWhere(
                        (s) => s.id == value,
                      );
                      setState(() {
                        _stationId = station.id;
                        _stationName = station.stationName;
                      });
                      _loadData();
                    },
                  ),
                )
              else
                const Text('لا توجد محطات مسجلة.'),

              const SizedBox(height: 16),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'حالة خزان الوقود',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (canManage)
                            TextButton.icon(
                              onPressed: () => _showSettingsDialog(fuelProvider),
                              icon: const Icon(Icons.settings),
                              label: const Text('الإعدادات'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: capacity > 0 ? percent : 0,
                        minHeight: 10,
                        backgroundColor: AppColors.lightGray,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          balance <= thresholdLiters && capacity > 0
                              ? AppColors.errorRed
                              : AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip('الرصيد', '${balance.toStringAsFixed(2)} لتر'),
                          _buildInfoChip(
                            'السعة',
                            capacity > 0
                                ? '${capacity.toStringAsFixed(2)} لتر'
                                : 'غير محدد',
                          ),
                          _buildInfoChip(
                            'سعر اللتر',
                            price > 0
                                ? '${price.toStringAsFixed(2)} ريال'
                                : 'غير محدد',
                          ),
                          _buildInfoChip(
                            'حد التنبيه',
                            '${thresholdPercent.toStringAsFixed(0)}%',
                          ),
                        ],
                      ),
                      if (capacity > 0 && balance <= thresholdLiters)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: const [
                              Icon(Icons.warning, color: AppColors.errorRed),
                              SizedBox(width: 8),
                              Text(
                                'تنبيه: مستوى الوقود اقترب من حد التنبيه',
                                style: TextStyle(color: AppColors.errorRed),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _stationId == null
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.workshopFuelSupplyForm,
                              arguments: {
                                'stationId': _stationId,
                                'stationName': _stationName,
                              },
                            );
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة توريد'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _stationId == null
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.workshopFuelSupplies,
                              arguments: {
                                'stationId': _stationId,
                                'stationName': _stationName,
                              },
                            );
                          },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('التوريدات'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _stationId == null
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.workshopFuelRefuelForm,
                              arguments: {
                                'stationId': _stationId,
                                'stationName': _stationName,
                              },
                            );
                          },
                    icon: const Icon(Icons.local_gas_station),
                    label: const Text('تعبئة وقود'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _stationId == null
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.workshopFuelReport,
                              arguments: {
                                'stationId': _stationId,
                                'stationName': _stationName,
                              },
                            );
                          },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('التقارير'),
                  ),
                  TextButton.icon(
                    onPressed: _stationId == null
                        ? null
                        : () => _showReadingDialog(fuelProvider),
                    icon: const Icon(Icons.speed),
                    label: const Text('قراءة العداد'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 900
                    ? 3
                    : MediaQuery.of(context).size.width > 600
                        ? 2
                        : 1,
                childAspectRatio: 2.2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  StatsCard(
                    title: 'عدد التعبئات',
                    value: refuels.length.toString(),
                    icon: Icons.local_gas_station,
                    color: AppColors.primaryBlue,
                    subtitle: 'آخر 30 يوم',
                    isLargeScreen: MediaQuery.of(context).size.width > 900,
                  ),
                  StatsCard(
                    title: 'إجمالي اللترات',
                    value: totalLiters.toStringAsFixed(2),
                    icon: Icons.opacity,
                    color: AppColors.infoBlue,
                    subtitle: 'لتر',
                    isLargeScreen: MediaQuery.of(context).size.width > 900,
                  ),
                  StatsCard(
                    title: 'إجمالي المبلغ',
                    value: totalAmount.toStringAsFixed(2),
                    icon: Icons.payments,
                    color: AppColors.successGreen,
                    subtitle: 'ريال',
                    isLargeScreen: MediaQuery.of(context).size.width > 900,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'أكثر السائقين تعبئة',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (topDrivers.isEmpty)
                const Text('لا توجد بيانات لهذه الفترة')
              else
                Column(
                  children: topDrivers.map((driver) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryBlue,
                        child: Text(
                          driver['driverName'].toString().isNotEmpty
                              ? driver['driverName'].toString()[0]
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(driver['driverName']),
                      subtitle: Text(
                        driver['vehicleNumber']?.toString().isNotEmpty == true
                            ? 'السيارة: ${driver['vehicleNumber']}'
                            : 'لا توجد سيارة محددة',
                      ),
                      trailing: Text(
                        '${(driver['liters'] as double).toStringAsFixed(2)} لتر',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),

              Text(
                'آخر التعبئات',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (refuels.isEmpty)
                const Text('لا توجد تعبئات مسجلة')
              else
                Column(
                  children: refuels.take(6).map((refuel) {
                    final date = DateTime.tryParse(
                          refuel['createdAt']?.toString() ?? '',
                        ) ??
                        DateTime.now();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_gas_station),
                        title: Text(
                          refuel['driverName']?.toString() ?? 'سائق غير معروف',
                        ),
                        subtitle: Text(
                          'السيارة: ${refuel['vehicleNumber'] ?? '--'} | ${DateFormat('yyyy/MM/dd').format(date)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_readNum(refuel['liters']).toStringAsFixed(2)} لتر',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (canManage) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'حذف التعبئة',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.errorRed,
                                ),
                                onPressed: () => _confirmDeleteRefuel(refuel),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.mediumGray),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}


