import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/gradient_button.dart';
import 'package:provider/provider.dart';

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 120, child: Text(text, textAlign: TextAlign.center));
  }
}

class DailyInventoryScreen extends StatefulWidget {
  const DailyInventoryScreen({super.key});

  @override
  State<DailyInventoryScreen> createState() => _DailyInventoryScreenState();
}

class _DailyInventoryScreenState extends State<DailyInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final Map<String, double> _supplyPrices = {};
  final Map<String, double> _sellingPrices = {};

  String? _selectedStationId;
  DateTime _inventoryDate = DateTime.now();
  Station? _selectedStation;
  bool _isSubmitting = false;
  final List<FuelSupplyEntry> _fuelEntries = [];
  final Map<String, FuelBalanceReportRow> _previousInventoryByFuel = {};
  final Map<String, double> _cachedClosingBalances = {};
  double _totalPreviousBalance = 0;

  // إحصائيات الربح والخسارة
  double _totalProfit = 0;
  double _totalRevenue = 0;
  double _totalCost = 0;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _desktopScrollbarsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStations();
      if (mounted && !_desktopScrollbarsReady) {
        setState(() {
          _desktopScrollbarsReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    for (final entry in _fuelEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStations() async {
    final provider = Provider.of<StationProvider>(context, listen: false);
    await provider.fetchStations();
  }

  Future<void> _onStationChanged(String? value, List<Station> stations) async {
    Station? station;
    if (value != null && stations.isNotEmpty) {
      final matched = stations.where((s) => s.id == value).toList();
      if (matched.isNotEmpty) {
        station = matched.first;
      }
    }

    setState(() {
      _selectedStationId = value;
      _selectedStation = station;
      for (final entry in _fuelEntries) {
        entry.dispose();
      }
      _fuelEntries
        ..clear()
        ..addAll(
          station?.fuelTypes.map((fuelType) {
                final entry = FuelSupplyEntry(fuelType: fuelType);
                // تحميل أسعار الوقود
                _loadFuelPrices(fuelType, station);
                entry.recalculate();
                return entry;
              }).toList() ??
              [],
        );
    });

    if (value == null) return;

    final provider = Provider.of<StationProvider>(context, listen: false);
    await provider.fetchStationById(value, inventoryDate: _inventoryDate);
    await provider.fetchCurrentStock(value);
    if (!mounted) return;

    _applyTankCapacities(provider.fuelTankCapacities);
    _applyBackendStockSnapshot(provider.currentStock);
    _calculateProfitLoss();
  }

  void _loadFuelPrices(String fuelType, Station? station) {
    if (station != null) {
      final fuelPrice = station.fuelPrices.firstWhere(
        (price) => price.fuelType == fuelType,
        orElse: () => FuelPrice(
          id: '',
          fuelType: fuelType,
          price: 0,
          effectiveDate: DateTime.now(),
        ),
      );
      _supplyPrices[fuelType] = fuelPrice.price;
      _sellingPrices[fuelType] = fuelPrice.price;
    }
  }

  void _recalculateEntry(FuelSupplyEntry entry) {
    entry.recalculate();
    _calculateProfitLoss();
    setState(() {});
  }

  void _calculateProfitLoss() {
    double totalProfit = 0;
    double totalRevenue = 0;
    double totalCost = 0;

    for (final entry in _fuelEntries) {
      final sellingPrice = _sellingPrices[entry.fuelType] ?? 0;
      final supplyPrice = entry.supplyPriceValue > 0
          ? entry.supplyPriceValue
          : (_supplyPrices[entry.fuelType] ?? 0);

      // إيرادات المبيعات
      final revenue = entry.litersSoldValue * sellingPrice;
      // تكلفة التوريد
      final cost = entry.receivedQuantityValue * supplyPrice;
      // الربح/الخسارة
      final profit = revenue - (entry.litersSoldValue * supplyPrice);

      entry.sellingPrice = sellingPrice;
      entry.revenue = revenue;
      entry.profit = profit;

      totalProfit += profit;
      totalRevenue += revenue;
      totalCost += cost;
    }

    setState(() {
      _totalProfit = totalProfit;
      _totalRevenue = totalRevenue;
      _totalCost = totalCost;
    });
  }

  void _applyTankCapacities(Map<String, double> capacities) {
    var needsUpdate = false;

    for (final entry in _fuelEntries) {
      final capacity = capacities[entry.fuelType] ?? 0;
      if (entry.tankCapacity != capacity) {
        entry.updateTankCapacity(capacity);
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  double _stockValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  DateTime _buildInventoryRecordDate() {
    final now = DateTime.now();
    return DateTime(
      _inventoryDate.year,
      _inventoryDate.month,
      _inventoryDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  void _applyBackendStockSnapshot(List<Map<String, dynamic>> currentStock) {
    final snapshotByFuel = <String, Map<String, dynamic>>{};

    for (final item in currentStock) {
      final fuelType = _normalizeFuelType(item['fuelType']?.toString() ?? '');
      if (fuelType.isEmpty) continue;
      snapshotByFuel[fuelType] = item;
    }

    final stationProvider = context.read<StationProvider>();
    final sessionSalesByFuel = _salesTotalsFromSessions(stationProvider.sessions);

    double totalPrevious = 0;
    for (final entry in _fuelEntries) {
      final snapshot = snapshotByFuel[_normalizeFuelType(entry.fuelType)];
      final referenceBalance =
          snapshot != null && snapshot.containsKey('inventoryReferenceBalance')
          ? _stockValue(snapshot['inventoryReferenceBalance'])
          : null;
      final double backendSales = snapshot == null
          ? 0.0
          : _stockValue(snapshot['salesSinceInventory']);
      final double sessionSales =
          sessionSalesByFuel[_normalizeFuelType(entry.fuelType)] ?? 0.0;
      final double salesSinceInventory = backendSales > 0
          ? backendSales
          : sessionSales;
      entry.applyBackendSnapshot(
        inventoryReferenceBalance: referenceBalance,
        currentBalance: _stockValue(snapshot?['currentBalance']),
        salesSinceInventory: salesSinceInventory,
      );
      totalPrevious += entry.previousBalanceValue;
    }

    _totalPreviousBalance = totalPrevious;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCachedClosingBalances() async {}

  Future<void> _loadPreviousBalances() async {
    if (_selectedStationId == null || _fuelEntries.isEmpty) return;

    await _loadCachedClosingBalances();

    final provider = Provider.of<StationProvider>(context, listen: false);
    final targetDate = DateTime(
      _inventoryDate.year,
      _inventoryDate.month,
      _inventoryDate.day,
    );
    final endDate = targetDate.add(const Duration(days: 1));

    await provider.fetchFuelBalanceReport(
      stationId: _selectedStationId!,
      endDate: endDate,
    );

    _previousInventoryByFuel
      ..clear()
      ..addEntries(
        provider.fuelBalanceReport
            .where((row) => !row.date.isAfter(targetDate))
            .map((row) => MapEntry(_normalizeFuelType(row.fuelType), row)),
      );

    await _mergeInventoriesIntoPrevious(provider, targetDate);

    double totalPrevious = 0;
    for (final entry in _fuelEntries) {
      final previousRow =
          _previousInventoryByFuel[_normalizeFuelType(entry.fuelType)];
      double? previousValue;

      if (previousRow != null) {
        previousValue =
            previousRow.actualBalance ??
            previousRow.calculatedBalance ??
            previousRow.openingBalance;
        entry.hasPreviousBalance = true;
      } else if (_cachedClosingBalances.containsKey(
        _normalizeFuelType(entry.fuelType),
      )) {
        previousValue =
            _cachedClosingBalances[_normalizeFuelType(entry.fuelType)];
        entry.hasPreviousBalance = true;
      } else {
        entry.hasPreviousBalance = false;
      }

      if (previousValue != null) {
        entry.previousBalanceController.text = previousValue.toStringAsFixed(2);
      } else {
        entry.previousBalanceController.text = '0';
      }

      if (!entry.hasPreviousBalance) {
        final cachedValue =
            _cachedClosingBalances[_normalizeFuelType(entry.fuelType)];
        if (cachedValue != null && entry.openingBalanceController.text == '0') {
          entry.openingBalanceController.text = cachedValue.toStringAsFixed(2);
        }
      } else {
        entry.openingBalanceController.text =
            entry.previousBalanceController.text;
      }

      entry.recalculate();
      totalPrevious += entry.previousBalanceValue;
    }

    _totalPreviousBalance = totalPrevious;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _mergeInventoriesIntoPrevious(
    StationProvider provider,
    DateTime targetDate,
  ) async {
    if (_selectedStationId == null) return;

    String _formatDate(DateTime date) =>
        date.toIso8601String().split('T').first;

    try {
      await provider.fetchInventories(
        filters: {
          'stationId': _selectedStationId!,
          'endDate': _formatDate(targetDate),
        },
      );
    } catch (_) {
      return;
    }

    for (final inventory in provider.inventories) {
      if (inventory.inventoryDate.isAfter(targetDate)) continue;
      final key = _normalizeFuelType(inventory.fuelType);
      final candidate = _rowFromInventory(inventory);
      final existing = _previousInventoryByFuel[key];

      final shouldReplace =
          existing == null ||
          candidate.date.isAfter(existing.date) ||
          (candidate.date.isAtSameMomentAs(existing.date) &&
              existing.actualBalance == null &&
              candidate.actualBalance != null);

      if (shouldReplace) {
        _previousInventoryByFuel[key] = candidate;
      }
    }
  }

  FuelBalanceReportRow _rowFromInventory(DailyInventory inventory) {
    return FuelBalanceReportRow(
      date: DateTime(
        inventory.inventoryDate.year,
        inventory.inventoryDate.month,
        inventory.inventoryDate.day,
      ),
      arabicDate: inventory.arabicDate,
      fuelType: inventory.fuelType.trim(),
      openingBalance: inventory.previousBalance,
      received: inventory.receivedQuantity,
      sales: inventory.totalSales,
      calculatedBalance: inventory.calculatedBalance,
      actualBalance: inventory.actualBalance,
      difference: inventory.difference,
      differencePercentage: inventory.differencePercentage,
      status: inventory.status,
    );
  }

  String _normalizeFuelType(String value) {
    var normalized = value;
    normalized = normalized.replaceAll(RegExp(r'[\u200E\u200F]'), '');
    normalized = _arabicDigitsToWestern(normalized);
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = normalized.toLowerCase();

    if (lower.contains('الفرق') && lower.contains('91')) {
      return 'بنزين 91';
    }
    if (lower.contains('الفرق') && lower.contains('95')) {
      return 'بنزين 95';
    }
    if (lower.contains('بنزين') && lower.contains('91')) {
      return 'بنزين 91';
    }
    if (lower.contains('بنزين') && lower.contains('95')) {
      return 'بنزين 95';
    }
    if (lower.contains('ديزل') ||
        lower.contains('سولار') ||
        lower.contains('diesel')) {
      return 'ديزل';
    }
    if (lower.contains('كيروسين') || lower.contains('kerosene')) {
      return 'كيروسين';
    }

    return normalized;
  }

  String _arabicDigitsToWestern(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();

    for (final ch in input.runes) {
      final char = String.fromCharCode(ch);
      final indexArabic = arabic.indexOf(char);
      if (indexArabic != -1) {
        buffer.write(indexArabic);
        continue;
      }
      final indexEastern = eastern.indexOf(char);
      if (indexEastern != -1) {
        buffer.write(indexEastern);
        continue;
      }
      buffer.write(char);
    }

    return buffer.toString();
  }

  String _fuelTypeFromPump(String pumpId) {
    final pumps = _selectedStation?.pumps ?? const <Pump>[];
    for (final pump in pumps) {
      if (pump.id == pumpId && pump.fuelType.isNotEmpty) {
        return _normalizeFuelType(pump.fuelType);
      }
    }
    return '';
  }

  Map<String, double> _salesTotalsFromSessions(List<PumpSession> sessions) {
    if (_selectedStationId == null) return const <String, double>{};

    final totals = <String, double>{};

    final provider = context.read<StationProvider>();
    if (provider.sessionTotalsByFuel.isNotEmpty) {
      provider.sessionTotalsByFuel.forEach((key, value) {
        final normalized = _normalizeFuelType(key);
        if (normalized.isEmpty) return;
        totals[normalized] = (totals[normalized] ?? 0) + value;
      });
      return totals;
    }

    final fromDate = DateTime(
      _inventoryDate.year,
      _inventoryDate.month,
      _inventoryDate.day,
    );

    for (final session in sessions) {
      if (session.stationId != _selectedStationId) continue;
      if (session.sessionDate.isBefore(fromDate)) continue;

      final readings = session.nozzleReadings ?? [];
      if (readings.isNotEmpty) {
        final seenNozzles = <String>{};

        for (final reading in readings) {
          final nozzleKey =
              '${reading.nozzleId}|${reading.pumpId}|${reading.position}';
          if (!seenNozzles.add(nozzleKey)) continue;

          final liters = _sessionReadingLiters(reading);
          if (liters <= 0) continue;

          var fuelKey = _normalizeFuelType(
            reading.fuelType.isNotEmpty ? reading.fuelType : session.fuelType,
          );
          if (fuelKey.isEmpty && reading.pumpId.isNotEmpty) {
            fuelKey = _fuelTypeFromPump(reading.pumpId);
          }
          if (fuelKey.isEmpty) continue;

          totals[fuelKey] = (totals[fuelKey] ?? 0) + liters;
        }
        continue;
      }

      final pumps = session.pumps ?? [];
      if (pumps.isNotEmpty) {
        for (final pump in pumps) {
          if (pump.closingReading == null) continue;
          final liters = pump.closingReading! - pump.openingReading;
          if (liters <= 0) continue;
          var fuelKey = _normalizeFuelType(pump.fuelType);
          if (fuelKey.isEmpty && pump.pumpId.isNotEmpty) {
            fuelKey = _fuelTypeFromPump(pump.pumpId);
          }
          if (fuelKey.isEmpty) continue;
          totals[fuelKey] = (totals[fuelKey] ?? 0) + liters;
        }
        continue;
      }

      if (session.totalLiters != null && session.totalLiters! > 0) {
        var fuelKey = _normalizeFuelType(session.fuelType);
        if (fuelKey.isEmpty && session.pumpId.isNotEmpty) {
          fuelKey = _fuelTypeFromPump(session.pumpId);
        }
        if (fuelKey.isEmpty) continue;
        totals[fuelKey] = (totals[fuelKey] ?? 0) + session.totalLiters!;
      }
    }

    return totals;
  }

  double _sessionReadingLiters(NozzleReading reading) {
    // ✅ لو في قراءة إغلاق → هي المصدر الأساسي
    if (reading.closingReading != null) {
      final diff = reading.closingReading! - reading.openingReading;
      return diff > 0 ? diff : 0;
    }

    // ✅ استخدم totalLiters فقط لو مفيش قراءة إغلاق
    if (reading.totalLiters != null && reading.totalLiters! > 0) {
      return reading.totalLiters!;
    }

    return 0;
  }

  bool _isSameDay(DateTime sessionDate, DateTime inventoryDate) {
    final local = sessionDate.toLocal();
    return local.year == inventoryDate.year &&
        local.month == inventoryDate.month &&
        local.day == inventoryDate.day;
  }

  Future<void> _submitForm() async {
    if (_selectedStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المحطة أولاً'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (_fuelEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد أنواع وقود مسجلة في هذه المحطة'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final entriesToSubmit = _fuelEntries
        .where(
          (entry) =>
              entry.receivedQuantityValue > 0 || entry.difference.abs() > 0.001,
        )
        .toList();

    if (entriesToSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كمية توريد أو تعديل الرصيد الفعلي'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = Provider.of<StationProvider>(context, listen: false);
    String? errorMessage;

    final inventoryRecordDate = _buildInventoryRecordDate();

    for (final entry in entriesToSubmit) {
      entry.recalculate();

      final inventory = DailyInventory(
        id: '',
        stationId: _selectedStationId!,
        stationName: _selectedStation?.stationName ?? '',

        // ✅ التاريخ + الوقت (يسمح بتكرار نفس اليوم)
        inventoryDate: inventoryRecordDate,

        arabicDate: _getArabicDate(),
        fuelType: entry.fuelType,

        previousBalance: entry.previousBalanceValue,
        receivedQuantity: entry.receivedQuantityValue,
        tankerCount: entry.receivedQuantityValue > 0 ? 1 : 0,
        totalSales: entry.litersSoldValue,
        pumpCount: 0,

        calculatedBalance: entry.calculatedBalance,
        actualBalance: entry.actualBalanceValue,
        difference: entry.difference,
        differencePercentage: entry.calculatedBalance > 0
            ? (entry.difference / entry.calculatedBalance) * 100
            : 0,

        differenceReason: entry.difference != 0 ? 'عادي' : null,
        expenses: const [],
        totalExpenses: 0,
        totalRevenue: entry.revenue,
        netRevenue: entry.profit,

        status: 'مسودة',
        preparedById: null,
        preparedByName: null,
        approvedById: null,
        approvedByName: null,
        notes: _notesController.text,

        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await provider.createInventory(inventory);

      if (!success) {
        errorMessage =
            provider.error ??
            'حدث خطأ أثناء تسجيل التوريد لنوع الوقود ${entry.fuelType}';
        break;
      }
    }

    setState(() => _isSubmitting = false);

    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (!mounted) return;

    await provider.fetchCurrentStock(_selectedStationId!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل التوريدات بنجاح'),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inventoryDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _inventoryDate) {
      setState(() {
        _inventoryDate = picked;
      });
      if (_selectedStationId != null) {
        final provider = Provider.of<StationProvider>(context, listen: false);
        await provider.fetchStationById(
          _selectedStationId!,
          inventoryDate: _inventoryDate,
        );
        await provider.fetchCurrentStock(_selectedStationId!);
        if (!mounted) return;
        _applyTankCapacities(provider.fuelTankCapacities);
        _applyBackendStockSnapshot(provider.currentStock);
        _calculateProfitLoss();
      }
    }
  }

  Future<void> _openSupplyPriceDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        final Map<String, TextEditingController> controllers = {};

        return AlertDialog(
          title: const Text('تسعيرة التوريد للجميع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _fuelEntries.map((entry) {
                controllers[entry.fuelType] = TextEditingController(
                  text: entry.supplyPriceValue.toStringAsFixed(2),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.fuelType,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: controllers[entry.fuelType],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر التوريد',
                            border: OutlineInputBorder(),
                            suffixText: 'ريال',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                for (final entry in _fuelEntries) {
                  final controller = controllers[entry.fuelType];
                  if (controller != null && controller.text.isNotEmpty) {
                    entry.supplyPriceController.text = controller.text;
                  }
                }
                setState(() {});
                _calculateProfitLoss();
                Navigator.pop(context);
              },
              child: const Text('حفظ للجميع'),
            ),
          ],
        );
      },
    );
  }

  String _getArabicDate() {
    final arabicMonths = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    final now = DateTime.now();
    final hijriYear = now.year - 579;
    final monthIndex = now.month - 1;

    return '$hijriYear/${arabicMonths[monthIndex]}/${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final stations = stationProvider.stations;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 241, 241),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: const Text(
          'إضافة توريد جديد',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_fuelEntries.isNotEmpty)
            IconButton(
              onPressed: _openSupplyPriceDialog,
              icon: const Icon(Icons.price_change),
              tooltip: 'تسعيرة التوريد للكل',
            ),
        ],
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Align(
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                final isTablet =
                    constraints.maxWidth >= 600 && constraints.maxWidth < 900;
                final isDesktop = constraints.maxWidth >= 900;

                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile
                          ? 12
                          : isTablet
                          ? 20
                          : 32,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: isDesktop ? 1400 : 800,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // ================= البيانات الأساسية =================
                      _buildGeneralInfoCard(isMobile, isTablet, stations),
                      const SizedBox(height: 20),

                      // ================= إحصائيات الربح والخسارة =================
                      // if (_fuelEntries.isNotEmpty)
                      //   _buildProfitLossSummary(isMobile, isTablet),

                      // ================= رصيد الوقود في الخزانات =================
                      if (_fuelEntries.isNotEmpty)
                        _buildFuelStockOverview(isMobile, isTablet),

                      const SizedBox(height: 16),

                      // ================= ملخص التوريد =================
                      if (_fuelEntries.isNotEmpty)
                        _buildSummaryCard(isMobile, isTablet),

                      if (_selectedStation == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'اختر محطة لعرض أنواع الوقود وإضافة التوريد لكل منها.',
                          ),
                        ),
                      if (_selectedStation != null && _fuelEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'لم يتم تعريف أنواع وقود لهذه المحطة بعد.',
                          ),
                        ),
                      if (_fuelEntries.isNotEmpty)
                        Column(
                          children: [
                            const SizedBox(height: 12),
                            if (isDesktop) _buildDesktopTable(),
                            if (!isDesktop)
                              ..._fuelEntries
                                  .map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildEntryCard(
                                        entry,
                                        isMobile,
                                        isTablet,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          ],
                        ),
                      const SizedBox(height: 16),
                      _buildNotesCard(isMobile, isTablet),
                      const SizedBox(height: 32),
                      GradientButton(
                        onPressed: (_fuelEntries.isEmpty || _isSubmitting)
                            ? null
                            : _submitForm,
                        text: _isSubmitting
                            ? 'جارٍ تسجيل التوريد...'
                            : 'تسجيل التوريد',
                        gradient: AppColors.accentGradient,
                        isLoading: _isSubmitting || stationProvider.isLoading,
                      ),
                      const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard(
    bool isMobile,
    bool isTablet,
    List<Station> stations,
  ) {
    return AppSurfaceCard(
      padding: EdgeInsets.all(
        isMobile
            ? 16
            : isTablet
            ? 20
            : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'البيانات العامة',
              style: TextStyle(
                fontSize: isMobile
                    ? 18
                    : isTablet
                    ? 20
                    : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            // التاريخ
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd').format(_inventoryDate),
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // المحطة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: DropdownButton<String>(
                value: _selectedStationId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'اختر المحطة',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
                items: stations.map((station) {
                  return DropdownMenuItem<String>(
                    value: station.id,
                    child: Text(
                      station.stationName,
                      style: TextStyle(fontSize: isMobile ? 14 : 15),
                    ),
                  );
                }).toList(),
                onChanged: (value) => _onStationChanged(value, stations),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfitLossSummary(bool isMobile, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppSurfaceCard(
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إحصائيات الربح والخسارة',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 16
                        : isTablet
                        ? 18
                        : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _totalProfit >= 0
                        ? AppColors.successGreen.withOpacity(0.1)
                        : AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _totalProfit >= 0
                          ? AppColors.successGreen
                          : AppColors.errorRed,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _totalProfit >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 16,
                        color: _totalProfit >= 0
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _totalProfit >= 0 ? 'ربح' : 'خسارة',
                        style: TextStyle(
                          color: _totalProfit >= 0
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // الإحصائيات في صفوف
            isMobile
                ? Column(
                    children: [
                      _buildProfitStatTile(
                        label: 'إجمالي الإيرادات',
                        value: '${_totalRevenue.toStringAsFixed(2)} ريال',
                        color: AppColors.successGreen,
                        icon: Icons.arrow_upward,
                      ),
                      const SizedBox(height: 12),
                      _buildProfitStatTile(
                        label: 'إجمالي التكاليف',
                        value: '${_totalCost.toStringAsFixed(2)} ريال',
                        color: AppColors.errorRed,
                        icon: Icons.arrow_downward,
                      ),
                      const SizedBox(height: 12),
                      _buildProfitStatTile(
                        label: 'صافي الربح/الخسارة',
                        value: '${_totalProfit.toStringAsFixed(2)} ريال',
                        color: _totalProfit >= 0
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                        icon: _totalProfit >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildProfitStatTile(
                          label: 'إجمالي الإيرادات',
                          value: '${_totalRevenue.toStringAsFixed(2)} ريال',
                          color: AppColors.successGreen,
                          icon: Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildProfitStatTile(
                          label: 'إجمالي التكاليف',
                          value: '${_totalCost.toStringAsFixed(2)} ريال',
                          color: AppColors.errorRed,
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildProfitStatTile(
                          label: 'صافي الربح/الخسارة',
                          value: '${_totalProfit.toStringAsFixed(2)} ريال',
                          color: _totalProfit >= 0
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                          icon: _totalProfit >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 16),

            // الرصيد السابق
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إجمالي المخزون الحالي',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_totalPreviousBalance.toStringAsFixed(2)} لتر',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          'تاريخ التوريد المحدد: ${DateFormat('yyyy/MM/dd').format(_inventoryDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    ));
  }

  Widget _buildProfitStatTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelStockOverview(bool isMobile, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppSurfaceCard(
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Text(
                  'الوقود المتاح حاليًا في الخزانات',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 16
                        : isTablet
                        ? 18
                        : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // عرض الوقود في شبكة
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile
                    ? 1
                    : isTablet
                    ? 2
                    : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isMobile ? 3 : 2.5,
              ),
              itemCount: _fuelEntries.length,
              itemBuilder: (context, index) {
                final entry = _fuelEntries[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue.withOpacity(0.1),
                        AppColors.primaryBlue.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.fuelType,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.local_gas_station,
                            color: AppColors.primaryBlue.withOpacity(0.7),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الرصيد',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGray,
                                ),
                              ),
                              Text(
                                '${entry.postSalesBalance.toStringAsFixed(2)} لتر',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: entry.postSalesBalance >= 0
                                      ? AppColors.successGreen
                                      : AppColors.errorRed,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'القيمة',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGray,
                                ),
                              ),
                              Text(
                                '${(entry.postSalesBalance * (entry.sellingPrice ?? 0)).toStringAsFixed(2)} ريال',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warningOrange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (entry.hasTankCapacity) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: entry.tankCapacity > 0
                              ? (entry.postSalesBalance / entry.tankCapacity)
                                    .clamp(0, 1)
                              : 0,
                          backgroundColor: AppColors.lightGray,
                          color: AppColors.primaryBlue,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سعة الخزان: ${entry.tankCapacity.toStringAsFixed(0)} لتر',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isMobile, bool isTablet) {
    final totalReceived = _fuelEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.receivedQuantityValue,
    );
    final totalSold = _fuelEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.litersSoldValue,
    );
    final totalRemaining = _fuelEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.postSalesBalance,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppSurfaceCard(
        padding: EdgeInsets.all(
          isMobile
              ? 16
              : isTablet
              ? 20
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Text(
                  'ملخص التوريد',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 16
                        : isTablet
                        ? 18
                        : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile
                    ? 2
                    : isTablet
                    ? 3
                    : 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isMobile ? 1.2 : 1.5,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildSummaryStat(
                      'إجمالي التوريد',
                      '$totalReceived لتر',
                      AppColors.successGreen,
                      Icons.local_shipping,
                    );
                  case 1:
                    return _buildSummaryStat(
                      'إجمالي المبيعات',
                      '$totalSold لتر',
                      AppColors.warningOrange,
                      Icons.sell,
                    );
                  case 2:
                    return _buildSummaryStat(
                      'الرصيد المتبقي',
                      '$totalRemaining لتر',
                      AppColors.infoBlue,
                      Icons.inventory,
                    );
                  case 3:
                    return _buildSummaryStat(
                      'المخزون الحالي بالخزان',
                      '${_totalPreviousBalance.toStringAsFixed(2)} لتر',
                      AppColors.primaryBlue,
                      Icons.history,
                    );
                  default:
                    return const SizedBox();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    final showOpeningColumn = _fuelEntries.any(
      (entry) => !entry.hasPreviousBalance,
    );
    final dataTable = DataTable(
      columnSpacing: 16,
      horizontalMargin: 16,
      dataRowHeight: 70,
      headingRowHeight: 60,
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      dataTextStyle: const TextStyle(fontSize: 12),

      // ================= Columns =================
      columns: [
        const DataColumn(label: _TableHeader('نوع الوقود')),
        const DataColumn(label: _TableHeader('المخزون الحالي'), numeric: true),
        if (showOpeningColumn)
          const DataColumn(label: _TableHeader('قبل التوريد'), numeric: true),
        const DataColumn(label: _TableHeader('كمية التوريد'), numeric: true),
        const DataColumn(label: _TableHeader('سعر التوريد'), numeric: true),
        const DataColumn(label: _TableHeader('قيمة التوريد'), numeric: true),
        const DataColumn(label: _TableHeader('مبيعات منذ آخر جرد'), numeric: true),
        const DataColumn(label: _TableHeader('الإيرادات'), numeric: true),
        const DataColumn(label: _TableHeader('الرصيد الفعلي'), numeric: true),
        const DataColumn(label: _TableHeader('الفرق'), numeric: true),
        const DataColumn(label: _TableHeader('الربح / الخسارة'), numeric: true),
      ],

      // ================= Rows =================
      rows: _fuelEntries.map((entry) {
        final differenceColor = entry.difference >= 0
            ? AppColors.successGreen
            : AppColors.errorRed;

        final profitColor = entry.profit >= 0
            ? AppColors.successGreen
            : AppColors.errorRed;

        final cells = <DataCell>[
          _textCell(entry.fuelType, highlight: true),

          _numberCell(
            controller: entry.previousBalanceController,
            enabled: false,
            suffix: 'لتر',
          ),
        ];

        if (showOpeningColumn) {
          cells.add(
            _numberCell(
              controller: entry.openingBalanceController,
              suffix: 'لتر',
              enabled: false,
            ),
          );
        }

        cells.addAll([
          _numberCell(
            controller: entry.receivedQuantityController,
            suffix: 'لتر',
            onChanged: (_) => _recalculateEntry(entry),
          ),
          _numberCell(
            controller: entry.supplyPriceController,
            suffix: 'ريال',
            onChanged: (_) => _recalculateEntry(entry),
          ),
          _valueCell(
            '${entry.supplyTotalCost.toStringAsFixed(2)} ريال',
            AppColors.infoBlue,
          ),
          _numberCell(
            controller: entry.litersSoldController,
            enabled: false,
            suffix: 'لتر',
          ),
          _valueCell(
            '${entry.revenue.toStringAsFixed(2)} ريال',
            AppColors.warningOrange,
          ),
          _numberCell(
            controller: entry.actualBalanceController,
            suffix: 'لتر',
            onChanged: (_) {
              entry.markActualBalanceEdited();
              _recalculateEntry(entry);
            },
          ),
          _differenceCell(entry, differenceColor),
          _profitCell(entry, profitColor),
        ]);

        return DataRow(cells: cells);
      }).toList(),
    );

    Widget verticalScrollable = SingleChildScrollView(
      controller: _verticalController,
      scrollDirection: Axis.vertical,
      child: dataTable,
    );

    if (_desktopScrollbarsReady) {
      verticalScrollable = Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        trackVisibility: true,
        child: verticalScrollable,
      );
    }

    Widget horizontalScrollable = SingleChildScrollView(
      controller: _horizontalController,
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1500),
        child: verticalScrollable,
      ),
    );

    if (_desktopScrollbarsReady) {
      horizontalScrollable = Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: horizontalScrollable,
      );
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.table_chart, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Text(
                  'إدخال بيانات التوريد',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  'عدد أنوااع الوقود: ${_fuelEntries.length}',
                  style: TextStyle(color: AppColors.mediumGray, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 520, child: horizontalScrollable),
        ],
      ),
    );
  }

  DataCell _textCell(String value, {bool highlight = false}) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
            color: highlight ? AppColors.primaryBlue : AppColors.darkGray,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  DataCell _numberCell({
    required TextEditingController controller,
    bool enabled = true,
    String? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return DataCell(
      SizedBox(
        width: 140,
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 8,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  DataCell _valueCell(String value, Color color) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  DataCell _differenceCell(FuelSupplyEntry entry, Color color) {
    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${entry.difference.toStringAsFixed(2)} لتر',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${entry.differencePercentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  DataCell _profitCell(FuelSupplyEntry entry, Color color) {
    final perLiterProfit = (entry.sellingPrice ?? 0) - entry.supplyPriceValue;

    return DataCell(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${entry.profit.toStringAsFixed(2)} ريال',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${perLiterProfit.toStringAsFixed(2)} ريال/لتر',
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(FuelSupplyEntry entry, bool isMobile, bool isTablet) {
    final differenceColor = entry.difference >= 0
        ? AppColors.successGreen
        : AppColors.errorRed;
    final profitColor = entry.profit >= 0
        ? AppColors.successGreen
        : AppColors.errorRed;

    return AppSurfaceCard(
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header with fuel type and prices
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.1),
                    AppColors.primaryBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.fuelType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildPriceChip(
                        'سعر البيع',
                        '${entry.sellingPrice?.toStringAsFixed(2) ?? '0'}',
                        AppColors.successGreen,
                      ),
                      const SizedBox(width: 8),
                      _buildPriceChip(
                        'سعر التوريد',
                        entry.supplyPriceValue.toStringAsFixed(2),
                        AppColors.warningOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!entry.hasPreviousBalance)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildInputField(
                  controller: entry.openingBalanceController,
                  label: 'رصيد افتتاحي',
                  icon: Icons.add_circle_outline,
                  suffix: 'لتر',
                  onChanged: (_) => _recalculateEntry(entry),
                  color: AppColors.primaryBlue.withOpacity(0.08),
                ),
              ),

            // Input fields in grid layout
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isMobile ? 3 : 2,
              ),
              itemCount: 5,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildInputField(
                      controller: entry.previousBalanceController,
                      label: 'المخزون الحالي',
                      icon: Icons.history,
                      suffix: 'لتر',
                      enabled: false,
                      color: AppColors.primaryBlue.withOpacity(0.1),
                    );
                  case 1:
                    return _buildInputField(
                      controller: entry.receivedQuantityController,
                      label: 'كمية التوريد',
                      icon: Icons.local_shipping,
                      suffix: 'لتر',
                      onChanged: (_) => _recalculateEntry(entry),
                      color: AppColors.successGreen.withOpacity(0.1),
                    );
                  case 2:
                    return _buildInputField(
                      controller: entry.supplyPriceController,
                      label: 'سعر التوريد',
                      icon: Icons.price_change,
                      suffix: 'ريال',
                      onChanged: (_) => _recalculateEntry(entry),
                      color: AppColors.infoBlue.withOpacity(0.1),
                    );
                  case 3:
                    return _buildInputField(
                      controller: entry.litersSoldController,
                      label: 'مبيعات منذ آخر جرد',
                      icon: Icons.sell,
                      suffix: 'لتر',
                      enabled: false,
                      color: AppColors.warningOrange.withOpacity(0.1),
                    );
                  case 4:
                    return _buildInputField(
                      controller: entry.actualBalanceController,
                      label: 'الرصيد الفعلي',
                      icon: Icons.straighten,
                      suffix: 'لتر',
                      onChanged: (_) {
                        entry.markActualBalanceEdited();
                        _recalculateEntry(entry);
                      },
                      color: AppColors.infoBlue.withOpacity(0.1),
                    );
                  default:
                    return const SizedBox();
                }
              },
            ),

            const SizedBox(height: 16),

            // Results cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isMobile ? 2.5 : 1.5,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildResultCard(
                      'قيمة التوريد',
                      '${entry.supplyTotalCost.toStringAsFixed(2)} ريال',
                      AppColors.infoBlue,
                      Icons.monetization_on,
                    );
                  case 1:
                    return _buildResultCard(
                      'الرصيد المتوقع',
                      '${entry.postSalesBalance.toStringAsFixed(2)} لتر',
                      AppColors.primaryBlue,
                      Icons.calculate,
                    );
                  case 2:
                    return _buildResultCard(
                      'الفرق',
                      '${entry.difference.toStringAsFixed(2)} لتر',
                      differenceColor,
                      entry.difference >= 0
                          ? Icons.add_circle
                          : Icons.remove_circle,
                      subtitle:
                          '${entry.differencePercentage.toStringAsFixed(1)}%',
                    );
                  case 3:
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            profitColor.withOpacity(0.2),
                            profitColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: profitColor.withOpacity(0.5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            profitColor == AppColors.successGreen
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: profitColor,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الربح/الخسارة',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                          Text(
                            '${entry.profit.toStringAsFixed(2)} ريال',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: profitColor,
                            ),
                          ),
                          Text(
                            '${((entry.sellingPrice ?? 0) - entry.supplyPriceValue).toStringAsFixed(2)} ريال/لتر',
                            style: TextStyle(fontSize: 11, color: profitColor),
                          ),
                        ],
                      ),
                    );
                  default:
                    return const SizedBox();
                }
              },
            ),

            if (entry.hasTankCapacity) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.storage,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'سعة الخزان',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${entry.tankCapacity.toStringAsFixed(0)} لتر',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: entry.tankCapacity > 0
                          ? (entry.postSalesBalance / entry.tankCapacity).clamp(
                              0,
                              1,
                            )
                          : 0,
                      backgroundColor: AppColors.lightGray,
                      color: AppColors.primaryBlue,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'معدل الامتلاء: ${(entry.tankCapacity > 0 ? (entry.postSalesBalance / entry.tankCapacity) * 100 : 0).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
    );
  }

  Widget _buildPriceChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(' ريال', style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
    bool enabled = true,
    Color? color,
    void Function(String)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color ?? AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.mediumGray, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: label,
                hintStyle: TextStyle(color: AppColors.mediumGray),
              ),
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.end,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffix,
            style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard(bool isMobile, bool isTablet) {
    return AppSurfaceCard(
      padding: EdgeInsets.all(
        isMobile
            ? 16
            : isTablet
            ? 20
            : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.note, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Text(
                  'ملاحظات',
                  style: TextStyle(
                    fontSize: isMobile
                        ? 16
                        : isTablet
                        ? 18
                        : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'أضف ملاحظات إضافية هنا...',
                  hintStyle: TextStyle(color: AppColors.mediumGray),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class FuelSupplyEntry {
  FuelSupplyEntry({required this.fuelType}) {
    previousBalanceController.text = '0';
    receivedQuantityController.text = '0';
    actualBalanceController.text = '0';
    litersSoldController.text = '0';
    openingBalanceController.text = '0';
    supplyPriceController.text = '0';
    recalculate();
  }

  final String fuelType;
  final TextEditingController previousBalanceController =
      TextEditingController();
  final TextEditingController receivedQuantityController =
      TextEditingController();
  final TextEditingController actualBalanceController = TextEditingController();
  final TextEditingController litersSoldController = TextEditingController();
  final TextEditingController openingBalanceController =
      TextEditingController();
  final TextEditingController supplyPriceController = TextEditingController();

  double supplyPriceValue = 0;
  double supplyTotalCost = 0;
  double previousBalanceValue = 0;
  double receivedQuantityValue = 0;
  double actualBalanceValue = 0;
  double litersSoldValue = 0;
  double calculatedBalance = 0;
  double postSalesBalance = 0;
  double difference = 0;
  double openingBalanceValue = 0;
  double tankCapacity = 0;
  bool hasPreviousBalance = false;
  bool salesAlreadyAppliedInBalance = false;
  bool _actualBalanceEdited = false;
  bool _updatingActualBalance = false;
  bool get hasTankCapacity => tankCapacity > 0;
  double differencePercentage = 0;

  // الربح والخسارة
  double? sellingPrice;
  double revenue = 0;
  double profit = 0;

  void recalculate() {
    openingBalanceValue = _parse(openingBalanceController.text);
    final priorBalance = hasPreviousBalance
        ? _parse(previousBalanceController.text)
        : openingBalanceValue;

    previousBalanceValue = priorBalance;
    receivedQuantityValue = _parse(receivedQuantityController.text);
    litersSoldValue = _parse(litersSoldController.text);
    supplyPriceValue = _parse(supplyPriceController.text);
    supplyTotalCost = receivedQuantityValue * supplyPriceValue;

    calculatedBalance = previousBalanceValue + receivedQuantityValue;
    postSalesBalance = salesAlreadyAppliedInBalance
        ? calculatedBalance
        : calculatedBalance - litersSoldValue;

    if (!_actualBalanceEdited) {
      actualBalanceValue = postSalesBalance;
      _setActualBalance(postSalesBalance);
    } else {
      actualBalanceValue = _parse(actualBalanceController.text);
    }

    difference = actualBalanceValue - postSalesBalance;
    differencePercentage = calculatedBalance > 0
        ? (difference / calculatedBalance) * 100
        : 0;
  }

  void applyBackendSnapshot({
    double? inventoryReferenceBalance,
    required double currentBalance,
    required double salesSinceInventory,
  }) {
    hasPreviousBalance = true;
    _actualBalanceEdited = false;

    final baseline = inventoryReferenceBalance ?? currentBalance;
    final expectedRemaining = baseline - salesSinceInventory;
    const tolerance = 0.01;

    final salesApplied = inventoryReferenceBalance == null
        ? false
        : (currentBalance - expectedRemaining).abs() <= tolerance
        ? true
        : (currentBalance - inventoryReferenceBalance).abs() <= tolerance &&
              salesSinceInventory > 0
        ? false
        : true;

    salesAlreadyAppliedInBalance = salesApplied;

    final openingForUi = salesApplied ? currentBalance : baseline;
    previousBalanceController.text = openingForUi.toStringAsFixed(2);
    openingBalanceController.text = openingForUi.toStringAsFixed(2);
    litersSoldController.text = salesSinceInventory.toStringAsFixed(2);
    recalculate();
  }

  void markActualBalanceEdited() {
    if (_updatingActualBalance) return;
    _actualBalanceEdited = true;
  }

  void _setActualBalance(double value) {
    final formatted = value.toStringAsFixed(2);
    if (actualBalanceController.text == formatted) return;
    _updatingActualBalance = true;
    actualBalanceController.text = formatted;
    _updatingActualBalance = false;
  }

  void updateTankCapacity(double capacity) {
    tankCapacity = capacity;
    recalculate();
  }

  double _parse(String input) {
    final cleaned = input.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  void dispose() {
    previousBalanceController.dispose();
    receivedQuantityController.dispose();
    actualBalanceController.dispose();
    litersSoldController.dispose();
    openingBalanceController.dispose();
    supplyPriceController.dispose();
  }
}
