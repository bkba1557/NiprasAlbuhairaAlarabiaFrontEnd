import 'dart:async';
import 'package:flutter/material.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/stations/inventory_filter_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'الكل';
  String? _filterStationId;
  String? _filterFuelType;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isTankLoading = false;
  final Map<String, double> _liveSalesByKey = {};
  Timer? _liveTimer;

  // For table view
  List<String> _tableColumns = [];
  Map<String, double> _columnWidths = {};
  ScrollController _horizontalScrollController = ScrollController();
  ScrollController _verticalScrollController = ScrollController();

  Future<void> _approveInventory(DailyInventory inventory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاعتماد'),
        content: const Text('هل أنت متأكد من اعتماد هذا الجرد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = Provider.of<StationProvider>(context, listen: false);
    final success = await provider.approveInventory(inventory.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اعتماد الجرد بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadInventories();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل اعتماد الجرد'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _deleteInventory(DailyInventory inventory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من حذف هذا الجرد؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = Provider.of<StationProvider>(context, listen: false);
    final success = await provider.deleteInventory(inventory.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الجرد بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadInventories();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل حذف الجرد'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _editInventory(DailyInventory inventory) async {
    final prevCtrl =
        TextEditingController(text: inventory.previousBalance.toStringAsFixed(2));
    final receivedCtrl =
        TextEditingController(text: inventory.receivedQuantity.toStringAsFixed(2));
    final salesCtrl =
        TextEditingController(text: inventory.totalSales.toStringAsFixed(2));
    final actualCtrl = TextEditingController(
      text: inventory.actualBalance?.toStringAsFixed(2) ?? '',
    );
    final notesCtrl = TextEditingController(text: inventory.notes ?? '');
    final diffReasonCtrl =
        TextEditingController(text: inventory.differenceReason ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الجرد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: prevCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الرصيد السابق'),
              ),
              TextField(
                controller: receivedCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الواردات'),
              ),
              TextField(
                controller: salesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبيعات'),
              ),
              TextField(
                controller: actualCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الرصيد الفعلي'),
              ),
              TextField(
                controller: diffReasonCtrl,
                decoration: const InputDecoration(labelText: 'سبب الفرق'),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousBalance = double.tryParse(prevCtrl.text.trim()) ?? 0;
    final receivedQuantity = double.tryParse(receivedCtrl.text.trim()) ?? 0;
    final totalSales = double.tryParse(salesCtrl.text.trim()) ?? 0;
    final actualBalance =
        actualCtrl.text.trim().isEmpty ? null : double.tryParse(actualCtrl.text.trim());

    final calculatedBalance = previousBalance + receivedQuantity - totalSales;
    final difference =
        actualBalance != null ? (actualBalance - calculatedBalance) : null;
    final differencePercentage =
        (difference != null && calculatedBalance != 0)
            ? (difference / calculatedBalance) * 100
            : null;

    final updates = {
      'previousBalance': previousBalance,
      'receivedQuantity': receivedQuantity,
      'totalSales': totalSales,
      'calculatedBalance': calculatedBalance,
      'actualBalance': actualBalance,
      'difference': difference,
      'differencePercentage': differencePercentage,
      'differenceReason': diffReasonCtrl.text.trim().isEmpty
          ? null
          : diffReasonCtrl.text.trim(),
      'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final provider = Provider.of<StationProvider>(context, listen: false);
    final success = await provider.updateInventory(inventory.id, updates);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الجرد بنجاح'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadInventories();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل تحديث الجرد'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventories();
      _initializeTableColumns();
    });
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadInventories();
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _initializeTableColumns() {
    setState(() {
      _tableColumns = [
        'التاريخ',
        'المحطة',
        'نوع الوقود',
        'الحالة',
        'الرصيد الافتتاحي',
        'الواردات',
        'المبيعات',
        'الرصيد المحسوب',
        'الرصيد الفعلي',
        'الفرق',
        'الإيرادات',
        'المصروفات',
        'صافي الربح',
        'الإجراءات',
      ];

      // Initialize column widths based on content
      _columnWidths = {
        'التاريخ': 120.0,
        'المحطة': 180.0,
        'نوع الوقود': 100.0,
        'الحالة': 100.0,
        'الرصيد الافتتاحي': 140.0,
        'الواردات': 100.0,
        'المبيعات': 100.0,
        'الرصيد المحسوب': 140.0,
        'الرصيد الفعلي': 140.0,
        'الفرق': 120.0,
        'الإيرادات': 120.0,
        'المصروفات': 120.0,
        'صافي الربح': 120.0,
        'الإجراءات': 180.0,
      };
    });
  }

  Future<void> _loadInventories() async {
    final filters = <String, dynamic>{};
    if (_filterStatus != 'الكل') filters['status'] = _filterStatus;
    if (_filterStationId != null) filters['stationId'] = _filterStationId;
    if (_filterFuelType != null) filters['fuelType'] = _filterFuelType;
    if (_filterStartDate != null)
      filters['startDate'] = _filterStartDate!.toIso8601String();
    if (_filterEndDate != null)
      filters['endDate'] = _filterEndDate!.toIso8601String();

    await Provider.of<StationProvider>(
      context,
      listen: false,
    ).fetchInventories(filters: filters);

    await _loadLiveSales(filters);
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _filterStatus = filters['status'] ?? 'الكل';
      _filterStationId = filters['stationId'];
      _filterFuelType = filters['fuelType'];
      _filterStartDate = filters['startDate'];
      _filterEndDate = filters['endDate'];
    });
    _loadInventories();
  }

  void _clearFilters() {
    setState(() {
      _filterStatus = 'الكل';
      _filterStationId = null;
      _filterFuelType = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _loadInventories();
  }


  String _normalizeFuelType(String value) {
    var normalized = value;
    normalized = normalized.replaceAll(RegExp(r'[‎‏]'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = normalized.toLowerCase();

    if (lower.contains('\u0627\u0644\u0641\u0631\u0642') && lower.contains('91')) {
      return '\u0628\u0646\u0632\u064a\u0646 91';
    }
    if (lower.contains('\u0627\u0644\u0641\u0631\u0642') && lower.contains('95')) {
      return '\u0628\u0646\u0632\u064a\u0646 95';
    }
    if (lower.contains('\u062f\u064a\u0632\u0644') ||
        lower.contains('\u0633\u0648\u0644\u0627\u0631') ||
        lower.contains('diesel')) {
      return '\u062f\u064a\u0632\u0644';
    }
    if (lower.contains('\u0643\u064a\u0631\u0648\u0633\u064a\u0646') ||
        lower.contains('kerosene')) {
      return '\u0643\u064a\u0631\u0648\u0633\u064a\u0646';
    }
    return normalized;
  }

  String _inventoryKey(String stationId, String fuelType, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '$stationId|${_normalizeFuelType(fuelType)}|${d.toIso8601String()}';
  }

  double _sessionReadingLiters(NozzleReading reading) {
    if (reading.closingReading != null) {
      final diff = reading.closingReading! - reading.openingReading;
      return diff > 0 ? diff : 0;
    }
    if (reading.totalLiters != null && reading.totalLiters! > 0) {
      return reading.totalLiters!;
    }
    return 0;
  }

  Future<void> _loadLiveSales(Map<String, dynamic> inventoryFilters) async {
    final provider = Provider.of<StationProvider>(context, listen: false);

    if (provider.inventories.isEmpty) {
      _liveSalesByKey.clear();
      return;
    }

    final dates = provider.inventories.map((inv) => inv.inventoryDate).toList();
    dates.sort();
    final start = DateTime(dates.first.year, dates.first.month, dates.first.day);
    final end = DateTime(dates.last.year, dates.last.month, dates.last.day, 23, 59, 59, 999);

    final filters = <String, dynamic>{
      'startDate': start.toIso8601String(),
      'endDate': end.toIso8601String(),
    };
    if (inventoryFilters['stationId'] != null) {
      filters['stationId'] = inventoryFilters['stationId'];
    }

    await provider.fetchSessions(filters: filters);

    final totals = <String, double>{};
    for (final session in provider.sessions) {
      final sessionDate = DateTime(
        session.sessionDate.year,
        session.sessionDate.month,
        session.sessionDate.day,
      );

      final readings = session.nozzleReadings ?? [];
      if (readings.isNotEmpty) {
        for (final reading in readings) {
          final liters = _sessionReadingLiters(reading);
          if (liters <= 0) continue;
          final fuelType = reading.fuelType.isNotEmpty
              ? reading.fuelType
              : session.fuelType;
          final key = _inventoryKey(session.stationId, fuelType, sessionDate);
          totals[key] = (totals[key] ?? 0) + liters;
        }
        continue;
      }

      if (session.totalLiters != null && session.totalLiters! > 0) {
        final key = _inventoryKey(
          session.stationId,
          session.fuelType,
          sessionDate,
        );
        totals[key] = (totals[key] ?? 0) + session.totalLiters!;
      }
    }

    _liveSalesByKey
      ..clear()
      ..addAll(totals);
  }

  String _getColumnValue(DailyInventory inventory, String column) {
    final salesColumn = _tableColumns.length > 6 ? _tableColumns[6] : 'المبيعات';
    final calculatedColumn =
        _tableColumns.length > 7 ? _tableColumns[7] : 'الرصيد المحسوب';
    final differenceColumn =
        _tableColumns.length > 9 ? _tableColumns[9] : 'الفرق';

    final liveSales = _liveSalesByKey[_inventoryKey(
      inventory.stationId,
      inventory.fuelType,
      inventory.inventoryDate,
    )] ?? inventory.totalSales;

    final calculatedLive =
        inventory.previousBalance + inventory.receivedQuantity - liveSales;
    final differenceLive = inventory.actualBalance != null
        ? inventory.actualBalance! - calculatedLive
        : null;

    if (column == salesColumn) {
      return '${liveSales.toStringAsFixed(2)} لتر';
    }
    if (column == calculatedColumn) {
      return '${calculatedLive.toStringAsFixed(2)} لتر';
    }
    if (column == differenceColumn) {
      if (inventory.actualBalance != null) {
        final diff = inventory.actualBalance! - calculatedLive;
        final percentage = calculatedLive != 0
            ? ' (${(diff / calculatedLive * 100).toStringAsFixed(1)}%)'
            : '';
        return '${diff.toStringAsFixed(2)} لتر$percentage';
      }
      return '---';
    }

    switch (column) {
      case 'التاريخ':
        return DateFormat('yyyy/MM/dd').format(inventory.inventoryDate);
      case 'المحطة':
        return inventory.stationName;
      case 'نوع الوقود':
        return inventory.fuelType;
      case 'الحالة':
        return inventory.status;
      case 'الرصيد الافتتاحي':
        return '${inventory.previousBalance.toStringAsFixed(2)} لتر';
      case 'الواردات':
        return '${inventory.receivedQuantity.toStringAsFixed(2)} لتر';
      case 'الرصيد الفعلي':
        return inventory.actualBalance != null
            ? '${inventory.actualBalance!.toStringAsFixed(2)} لتر'
            : '---';
      case 'الإيرادات':
        return '${inventory.totalRevenue.toStringAsFixed(2)} ريال';
      case 'المصروفات':
        return '${inventory.totalExpenses.toStringAsFixed(2)} ريال';
      case 'صافي الربح':
        return inventory.netRevenue != null
            ? '${inventory.netRevenue!.toStringAsFixed(2)} ريال'
            : '---';
      case 'الإجراءات':
        return '';
      default:
        return '';
    }
  }

Color _getColumnColor(DailyInventory inventory, String column) {
    switch (column) {
      case 'الحالة':
        switch (inventory.status) {
          case 'مسودة':
            return AppColors.warningOrange;
          case 'مكتمل':
            return AppColors.infoBlue;
          case 'معتمد':
            return AppColors.successGreen;
          case 'ملغى':
            return AppColors.errorRed;
          default:
            return Colors.black;
        }
      case 'الفرق':
        if (inventory.difference != null) {
          return inventory.difference! >= 0
              ? AppColors.successGreen
              : AppColors.errorRed;
        }
        return Colors.black;
      case 'صافي الربح':
        if (inventory.netRevenue != null) {
          return inventory.netRevenue! >= 0
              ? AppColors.successGreen
              : AppColors.errorRed;
        }
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final stationProvider = Provider.of<StationProvider>(context);
    final inventories = stationProvider.inventories;
    final stations = stationProvider.stations;

    if (isMobile) {
      return _buildMobileLayout(
        context,
        stationProvider,
        inventories,
        stations,
      );
    } else {
      return _buildTableLayout(context, stationProvider, inventories, stations);
    }
  }

  Widget _buildMobileLayout(
    BuildContext context,
    StationProvider stationProvider,
    List<DailyInventory> inventories,
    List<Station> stations,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الجرد اليومي',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_hasActiveFilters())
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'مسح الفلاتر',
            ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/inventory/create');
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث بالمحطة أو نوع الوقود...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 14.0,
                      ),
                    ),
                    onChanged: (value) {
                      // TODO: Implement search
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  onPressed: () async {
                    final filters = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => InventoryFilterDialog(
                        currentFilters: {
                          'status': _filterStatus,
                          'stationId': _filterStationId,
                          'fuelType': _filterFuelType,
                          'startDate': _filterStartDate,
                          'endDate': _filterEndDate,
                        },
                        stations: stations,
                      ),
                    );

                    if (filters != null) {
                      _applyFilters(filters);
                    }
                  },
                  icon: const Icon(Icons.filter_alt),
                  tooltip: 'تصفية',
                  iconSize: 22.0,
                ),
              ],
            ),
          ),
          // Active Filters Chips
          if (_hasActiveFilters())
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              color: AppColors.backgroundGray,
              child: Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: [
                  if (_filterStatus != 'الكل')
                    Chip(
                      label: Text('الحالة: $_filterStatus'),
                      onDeleted: () {
                        setState(() {
                          _filterStatus = 'الكل';
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterStationId != null)
                    Chip(
                      label: Text(
                        'المحطة: ${stations.firstWhere((s) => s.id == _filterStationId).stationName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterStationId = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterFuelType != null)
                    Chip(
                      label: Text('نوع الوقود: $_filterFuelType'),
                      onDeleted: () {
                        setState(() {
                          _filterFuelType = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterStartDate != null)
                    Chip(
                      label: Text(
                        'من: ${DateFormat('yyyy/MM/dd').format(_filterStartDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterStartDate = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterEndDate != null)
                    Chip(
                      label: Text(
                        'إلى: ${DateFormat('yyyy/MM/dd').format(_filterEndDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterEndDate = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                ],
              ),
            ),
          // Inventory List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInventories,
              child: stationProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : inventories.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد سجلات جرد',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12.0),
                      itemCount: inventories.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildMobileInventoryCard(inventories[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/inventory/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMobileInventoryCard(DailyInventory inventory) {
    final liveSales = _liveSalesByKey[_inventoryKey(
      inventory.stationId,
      inventory.fuelType,
      inventory.inventoryDate,
    )] ?? inventory.totalSales;

    final calculatedLive =
        inventory.previousBalance + inventory.receivedQuantity - liveSales;
    final differenceLive = inventory.actualBalance != null
        ? inventory.actualBalance! - calculatedLive
        : null;
    Color statusColor;
    IconData statusIcon;

    switch (inventory.status) {
      case 'مسودة':
        statusColor = AppColors.warningOrange;
        statusIcon = Icons.drafts;
        break;
      case 'مكتمل':
        statusColor = AppColors.infoBlue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'معتمد':
        statusColor = AppColors.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'ملغى':
        statusColor = AppColors.errorRed;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.mediumGray;
        statusIcon = Icons.circle;
    }

    final differenceColor = differenceLive != null
        ? (differenceLive >= 0
              ? AppColors.successGreen
              : AppColors.errorRed)
        : AppColors.mediumGray;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/inventory/details',
            arguments: inventory.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18.0),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inventory.stationName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              DateFormat(
                                'yyyy/MM/dd',
                              ).format(inventory.inventoryDate),
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: 12.0,
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.mediumGray,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Expanded(
                              child: Text(
                                inventory.fuelType,
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 12.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      inventory.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Summary
              _buildMobileSummary(
                inventory,
                differenceColor,
                liveSales,
                calculatedLive,
                differenceLive,
              ),
              // Actions
              if (inventory.status == 'مسودة')
                Column(
                  children: [
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _approveInventory(inventory);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('اعتماد الجرد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/inventory/details',
                              arguments: inventory.id,
                            );
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('تعديل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSummary(
    DailyInventory inventory,
    Color differenceColor,
    double liveSales,
    double calculatedLive,
    double? differenceLive,
  ) {
    final differencePercent = (differenceLive != null && calculatedLive != 0)
        ? (differenceLive / calculatedLive) * 100
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'الرصيد الافتتاحي',
                '${inventory.previousBalance.toStringAsFixed(2)} لتر',
                isMobile: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryItem(
                'الواردات',
                '${inventory.receivedQuantity.toStringAsFixed(2)} لتر',
                isMobile: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'المبيعات',
                '${liveSales.toStringAsFixed(2)} لتر',
                isMobile: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryItem(
                'الرصيد المحسوب',
                '${calculatedLive.toStringAsFixed(2)} \u0644\u062a\u0631',
                isMobile: true,
                color: AppColors.infoBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'الرصيد الفعلي',
                inventory.actualBalance?.toStringAsFixed(2) ?? '---',
                isMobile: true,
                color: AppColors.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الفرق',
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 11),
                  ),
                  Row(
                    children: [
                      Text(
                        differenceLive?.toStringAsFixed(2) ?? '---',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: differenceColor,
                        ),
                      ),
                      if (differencePercent != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '(${differencePercent!.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 11,
                              color: differenceColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'الإيرادات',
                '${inventory.totalRevenue.toStringAsFixed(2)} ريال',
                isMobile: true,
                color: AppColors.warningOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryItem(
                'المصروفات',
                '${inventory.totalExpenses.toStringAsFixed(2)} ريال',
                isMobile: true,
                color: AppColors.errorRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          'صافي الربح',
          inventory.netRevenue?.toStringAsFixed(2) ?? '---',
          isMobile: true,
          color: inventory.netRevenue != null
              ? (inventory.netRevenue! >= 0
                    ? AppColors.successGreen
                    : AppColors.errorRed)
              : AppColors.mediumGray,
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/inventory/details',
                  arguments: inventory.id,
                );
              },
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('عرض'),
            ),
            const SizedBox(width: 8),
            if (inventory.status == 'مسودة')
              TextButton.icon(
                onPressed: () => _editInventory(inventory),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('تعديل'),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _deleteInventory(inventory),
              icon: const Icon(Icons.delete, size: 18, color: AppColors.errorRed),
              label: const Text('حذف', style: TextStyle(color: AppColors.errorRed)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableLayout(
    BuildContext context,
    StationProvider stationProvider,
    List<DailyInventory> inventories,
    List<Station> stations,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الجرد اليومي',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_hasActiveFilters())
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'مسح الفلاتر',
            ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/inventory/create');
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث بالمحطة أو نوع الوقود...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                    ),
                    onChanged: (value) {
                      // TODO: Implement search
                    },
                  ),
                ),
                const SizedBox(width: 12.0),
                IconButton(
                  onPressed: () async {
                    final filters = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => InventoryFilterDialog(
                        currentFilters: {
                          'status': _filterStatus,
                          'stationId': _filterStationId,
                          'fuelType': _filterFuelType,
                          'startDate': _filterStartDate,
                          'endDate': _filterEndDate,
                        },
                        stations: stations,
                      ),
                    );

                    if (filters != null) {
                      _applyFilters(filters);
                    }
                  },
                  icon: const Icon(Icons.filter_alt),
                  tooltip: 'تصفية',
                  iconSize: 24.0,
                ),
              ],
            ),
          ),
          // Active Filters Chips
          if (_hasActiveFilters())
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              color: AppColors.backgroundGray,
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  if (_filterStatus != 'الكل')
                    Chip(
                      label: Text('الحالة: $_filterStatus'),
                      onDeleted: () {
                        setState(() {
                          _filterStatus = 'الكل';
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterStationId != null)
                    Chip(
                      label: Text(
                        'المحطة: ${stations.firstWhere((s) => s.id == _filterStationId).stationName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterStationId = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterFuelType != null)
                    Chip(
                      label: Text('نوع الوقود: $_filterFuelType'),
                      onDeleted: () {
                        setState(() {
                          _filterFuelType = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterStartDate != null)
                    Chip(
                      label: Text(
                        'من: ${DateFormat('yyyy/MM/dd').format(_filterStartDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterStartDate = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (_filterEndDate != null)
                    Chip(
                      label: Text(
                        'إلى: ${DateFormat('yyyy/MM/dd').format(_filterEndDate!)}',
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterEndDate = null;
                        });
                        _loadInventories();
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                ],
              ),
            ),
          // Table Header
          Container(
            height: 60,
            color: AppColors.primaryBlue.withOpacity(0.1),
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tableColumns.map((column) {
                    return Container(
                      width: _columnWidths[column] ?? 150,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: AppColors.lightGray,
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: AppColors.lightGray,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        column,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          // Table Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInventories,
              child: stationProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : inventories.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد سجلات جرد',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: _tableColumns.map((column) {
                                return DataColumn(
                                  label: Container(
                                    width: _columnWidths[column] ?? 150,
                                    child: Text(
                                      column,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                              rows: inventories.map((inventory) {
                                return DataRow(
                                  cells: _tableColumns.map((column) {
                                    if (column == 'الإجراءات') {
                                      return DataCell(
                                        Container(
                                          width: _columnWidths[column] ?? 180,
                                          child: Row(
                                            children: [
                                              IconButton(
                                                onPressed: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/inventory/details',
                                                    arguments: inventory.id,
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.visibility,
                                                ),
                                                tooltip: 'عرض التفاصيل',
                                                iconSize: 20,
                                              ),
                                              if (inventory.status ==
                                                  'مسودة') ...[
                                                IconButton(
                                                  onPressed: () {
                                                    _approveInventory(
                                                      inventory,
                                                    );
                                                  },
                                                  icon: const Icon(Icons.check),
                                                  tooltip: 'اعتماد الجرد',
                                                  iconSize: 20,
                                                  color: AppColors.successGreen,
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    Navigator.pushNamed(
                                                      context,
                                                      '/inventory/details',
                                                      arguments: inventory.id,
                                                    );
                                                  },
                                                  icon: const Icon(Icons.edit),
                                                  tooltip: 'تعديل',
                                                  iconSize: 20,
                                                  color: AppColors.primaryBlue,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    } else {
                                      return DataCell(
                                        Container(
                                          width: _columnWidths[column] ?? 150,
                                          child: Text(
                                            _getColumnValue(inventory, column),
                                            style: TextStyle(
                                              color: _getColumnColor(
                                                inventory,
                                                column,
                                              ),
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      );
                                    }
                                  }).toList(),
                                  onSelectChanged: (selected) {
                                    Navigator.pushNamed(
                                      context,
                                      '/inventory/details',
                                      arguments: inventory.id,
                                    );
                                  },
                                );
                              }).toList(),
                              dividerThickness: 1,
                              dataRowHeight: 60,
                              headingRowHeight: 0,
                              horizontalMargin: 0,
                              columnSpacing: 0,
                              showCheckboxColumn: false,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Table Footer with summary
          Container(
            height: 40,
            color: AppColors.backgroundGray,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'إجمالي ${inventories.length} سجل',
                    style: const TextStyle(color: AppColors.mediumGray),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'آخر تحديث: ${DateFormat('HH:mm').format(DateTime.now())}',
                    style: const TextStyle(color: AppColors.mediumGray),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/inventory/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value, {
    Color? color,
    bool isMobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.mediumGray,
            fontSize: isMobile ? 11 : 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return _filterStatus != 'الكل' ||
        _filterStationId != null ||
        _filterFuelType != null ||
        _filterStartDate != null ||
        _filterEndDate != null;
  }
}
