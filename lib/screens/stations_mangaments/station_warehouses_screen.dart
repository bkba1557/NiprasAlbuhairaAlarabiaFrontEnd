import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:provider/provider.dart';

class StationWarehousesScreen extends StatefulWidget {
  const StationWarehousesScreen({super.key});

  @override
  State<StationWarehousesScreen> createState() => _StationWarehousesScreenState();
}

class _StationWarehousesScreenState extends State<StationWarehousesScreen> {
  final NumberFormat _litersFormat = NumberFormat.decimalPattern('ar');

  List<Station> _stations = const [];
  List<_WarehouseFuelRow> _rows = const [];
  String? _selectedStationId;
  String? _errorMessage;
  bool _isLoadingStations = false;
  bool _isLoadingStock = false;

  bool get _isBusy => _isLoadingStations || _isLoadingStock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingStations = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<StationProvider>();
      await provider.fetchStations(limit: 0);

      final stations = _filterAccessibleStations(provider.stations);
      final selectedStationId = stations.length == 1 ? stations.first.id : null;

      if (!mounted) return;
      setState(() {
        _stations = stations;
        _selectedStationId = selectedStationId;
        _rows = const [];
      });

      if (selectedStationId != null) {
        await _loadCurrentStock(selectedStationId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingStations = false;
      });
    }
  }

  List<Station> _filterAccessibleStations(List<Station> stations) {
    final auth = context.read<AuthProvider>();

    if (auth.isStationBoy) {
      final assignedStationId = auth.stationId;
      if (assignedStationId == null || assignedStationId.isEmpty) {
        return const [];
      }

      return stations.where((station) => station.id == assignedStationId).toList();
    }

    if (auth.isOwnerStation && auth.stationIds.isNotEmpty) {
      final allowedIds = auth.stationIds.toSet();
      return stations.where((station) => allowedIds.contains(station.id)).toList();
    }

    return stations;
  }

  Future<void> _loadCurrentStock(String stationId) async {
    setState(() {
      _isLoadingStock = true;
      _errorMessage = null;
      _rows = const [];
    });

    try {
      final provider = context.read<StationProvider>();
      await provider.fetchCurrentStock(stationId);

      Station? station;
      for (final item in _stations) {
        if (item.id == stationId) {
          station = item;
          break;
        }
      }

      final rows = station == null
          ? const <_WarehouseFuelRow>[]
          : _buildFuelRows(station, provider.currentStock);

      if (!mounted) return;
      setState(() {
        _rows = rows.where((row) => row.shouldDisplay).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingStock = false;
      });
    }
  }

  List<_WarehouseFuelRow> _buildFuelRows(
    Station station,
    List<Map<String, dynamic>> currentStock,
  ) {
    final rowsByFuel = <String, Map<String, dynamic>>{};

    for (final row in currentStock) {
      final fuelType = row['fuelType']?.toString().trim() ?? '';
      if (fuelType.isEmpty) continue;
      rowsByFuel[fuelType] = row;
    }

    final orderedFuelTypes = <String>[
      ...station.fuelTypes,
      ...rowsByFuel.keys.where((fuelType) => !station.fuelTypes.contains(fuelType)),
    ];

    return orderedFuelTypes.map((fuelType) {
      final row = rowsByFuel[fuelType];
      final referenceBalance = _toDouble(
        row?['inventoryReferenceBalance'] ?? row?['currentBalance'],
      );
      final available = _toDouble(row?['currentBalance']);
      final capacity = _toDouble(row?['capacity']);
      final sold = _toDouble(row?['salesSinceInventory']);

      return _WarehouseFuelRow(
        fuelType: fuelType,
        referenceBalance: referenceBalance,
        available: available,
        capacity: capacity,
        soldSinceInventory: sold,
      );
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _formatLiters(double value) => '${_litersFormat.format(value)} لتر';

  Station? get _selectedStation {
    final selectedStationId = _selectedStationId;
    if (selectedStationId == null || selectedStationId.isEmpty) return null;

    for (final station in _stations) {
      if (station.id == selectedStationId) {
        return station;
      }
    }

    return null;
  }

  Future<void> _refresh() async {
    final selectedStationId = _selectedStationId;
    if (selectedStationId == null || selectedStationId.isEmpty) {
      await _loadInitialData();
      return;
    }

    await _loadCurrentStock(selectedStationId);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;
    final isTablet = width >= 700;
    final isPhone = width < 600;
    final horizontalPadding = isDesktop ? 28.0 : (isTablet ? 20.0 : 14.0);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('المخازن'),
        flexibleSpace: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const AppSoftBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isPhone ? 14 : 20,
                    horizontalPadding,
                    120,
                  ),
                  children: [
                    _buildFilterCard(isPhone: isPhone),
                    if (_isBusy) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(minHeight: 4),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorCard(_errorMessage!),
                    ],
                    if (_selectedStation != null && _rows.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHeroCard(_selectedStation!, isPhone: isPhone),
                      const SizedBox(height: 16),
                      _buildFuelCardsSection(isPhone: isPhone),
                    ] else if (_selectedStation != null &&
                        !_isBusy &&
                        _errorMessage == null) ...[
                      const SizedBox(height: 16),
                      _buildEmptyStockState(),
                    ] else if (_selectedStation == null &&
                        !_isBusy &&
                        _errorMessage == null) ...[
                      const SizedBox(height: 16),
                      _buildChooseStationState(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard({required bool isPhone}) {
    final auth = context.read<AuthProvider>();
    final stationCount = _stations.length;
    final ownsStationsOnly = auth.isOwnerStation || auth.isStationBoy;

    return AppSurfaceCard(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      child: _stations.isEmpty
          ? const Text(
              'لا توجد محطات مرتبطة بهذا المستخدم حالياً.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختيار المحطة',
                  style: TextStyle(
                    fontSize: isPhone ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ownsStationsOnly
                      ? 'تظهر هنا المحطات المرتبطة بحسابك فقط. اختر محطة لعرض الرصيد قبل البيع، والمباع، والمتاح الحالي لكل نوع وقود.'
                      : 'اختر محطة لعرض الرصيد قبل البيع، والمباع، والمتاح الحالي لكل نوع وقود.',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    fontSize: isPhone ? 12 : 14,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedStationId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'المحطة',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.92),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: AppColors.appBarWaterBright.withValues(alpha: 0.10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppColors.appBarWaterBright,
                        width: 1.4,
                      ),
                    ),
                  ),
                  items: _stations
                      .map(
                        (station) => DropdownMenuItem<String>(
                          value: station.id,
                          child: Text(
                            station.stationName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoadingStations
                      ? null
                      : (value) async {
                          if (value == null || value == _selectedStationId) return;
                          setState(() {
                            _selectedStationId = value;
                          });
                          await _loadCurrentStock(value);
                        },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metaChip(
                      icon: Icons.apartment_rounded,
                      label: 'المتاح لك $stationCount محطة',
                    ),
                    if (_selectedStation != null)
                      _metaChip(
                        icon: Icons.local_gas_station_rounded,
                        label: 'الأنواع المعروضة ${_rows.length}',
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCard(Station station, {required bool isPhone}) {
    final totalReference = _rows.fold<double>(
      0,
      (sum, row) => sum + row.referenceBalance,
    );
    final totalSold = _rows.fold<double>(
      0,
      (sum, row) => sum + row.soldSinceInventory,
    );
    final totalAvailable = _rows.fold<double>(
      0,
      (sum, row) => sum + row.available,
    );

    return Container(
      padding: EdgeInsets.all(isPhone ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF0F4C5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isPhone ? 24 : 28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.stationName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isPhone ? 22 : 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (station.stationCode.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        station.stationCode,
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: isPhone ? 12 : 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'إجمالي المتاح بعد خصم المبيعات',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: isPhone ? 12 : 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatLiters(totalAvailable),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: isPhone ? 24 : 34,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: isPhone ? 58 : 68,
                height: isPhone ? 58 : 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isPhone ? 18 : 22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  Icons.warehouse_rounded,
                  color: Colors.white,
                  size: isPhone ? 28 : 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroMetric(
                label: 'قبل خصم المبيعات',
                value: _formatLiters(totalReference),
              ),
              _heroMetric(
                label: 'إجمالي المباع',
                value: _formatLiters(totalSold),
              ),
              _heroMetric(
                label: 'الأنواع المعروضة',
                value: '${_rows.length}',
              ),
              _heroMetric(
                label: 'المدينة',
                value: station.city,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuelCardsSection({required bool isPhone}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 3
            : width >= 700
                ? 2
                : 1;
        final spacing = isPhone ? 10.0 : 14.0;
        final itemWidth =
            (width - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _rows
              .map(
                (row) => SizedBox(
                  width: itemWidth,
                  child: _buildFuelCard(row, isPhone: isPhone),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildFuelCard(_WarehouseFuelRow row, {required bool isPhone}) {
    final accent = _fuelAccent(row.fuelType);
    final ratio = row.capacity <= 0
        ? 0.0
        : (row.available / row.capacity).clamp(0.0, 1.0);
    final hadSales = row.soldSinceInventory > 0;
    final isSoldOut = row.available <= 0 && hadSales;

    return AppSurfaceCard(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isPhone ? 42 : 48,
                height: isPhone ? 42 : 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isPhone ? 14 : 16),
                ),
                child: Icon(
                  Icons.opacity_rounded,
                  color: accent,
                  size: isPhone ? 22 : 26,
                ),
              ),
              SizedBox(width: isPhone ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fuelType,
                      style: TextStyle(
                        fontSize: isPhone ? 16 : 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hadSales ? 'المتاح بعد خصم المبيعات' : 'الرصيد الحالي',
                      style: TextStyle(
                        fontSize: isPhone ? 11 : 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isPhone ? 14 : 16),
          Text(
            _formatLiters(row.available),
            style: TextStyle(
              fontSize: isPhone ? 23 : 28,
              fontWeight: FontWeight.w900,
              color: accent,
              height: 1.0,
            ),
          ),
          if (isSoldOut) ...[
            const SizedBox(height: 6),
            Text(
              'تم بيع الكمية كاملة منذ آخر جرد',
              style: TextStyle(
                color: const Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: isPhone ? 11 : 12,
              ),
            ),
          ],
          SizedBox(height: isPhone ? 10 : 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: isPhone ? 8 : 10,
              child: LinearProgressIndicator(
                value: row.capacity > 0 ? ratio : 0,
                backgroundColor: accent.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          SizedBox(height: isPhone ? 10 : 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final columns = constraints.maxWidth >= 420
                  ? 3
                  : constraints.maxWidth >= 280
                  ? 2
                  : 1;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
              final breakdownTiles = [
                _stockBreakdownTile(
                  label: 'قبل الخصم',
                  value: _formatLiters(row.referenceBalance),
                  accent: const Color(0xFF0F172A),
                  isPhone: isPhone,
                ),
                _stockBreakdownTile(
                  label: 'المباع',
                  value: _formatLiters(row.soldSinceInventory),
                  accent: const Color(0xFFF97316),
                  isPhone: isPhone,
                ),
                _stockBreakdownTile(
                  label: 'المتاح الآن',
                  value: _formatLiters(row.available),
                  accent: accent,
                  isPhone: isPhone,
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: breakdownTiles
                    .map(
                      (tile) => SizedBox(
                        width: itemWidth,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          SizedBox(height: isPhone ? 10 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stockInfoPill(
                label: 'السعة',
                value: row.capacity > 0 ? _formatLiters(row.capacity) : 'غير محددة',
              ),
              _stockInfoPill(
                label: 'المباع منذ آخر جرد',
                value: _formatLiters(row.soldSinceInventory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      color: AppColors.errorRed.withValues(alpha: 0.08),
      border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.20)),
      boxShadow: const [],
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseStationState() {
    return const AppSurfaceCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 60,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 14),
          Text(
            'اختر محطة لعرض المخزون',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'بعد اختيار المحطة ستظهر هنا أنواع الوقود المتاحة حالياً، وكذلك الأنواع التي عليها مبيعات منذ آخر جرد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStockState() {
    return const AppSurfaceCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 60,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 14),
          Text(
            'لا يوجد مخزون أو مبيعات حالياً',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'المحطة المختارة لا تحتوي حالياً على رصيد متاح أو مبيعات مسجلة لأي نوع وقود.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.appBarWaterDeep),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockInfoPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBreakdownTile({
    required String label,
    required String value,
    required Color accent,
    required bool isPhone,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 10 : 12,
        vertical: isPhone ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.80),
              fontWeight: FontWeight.w700,
              fontSize: isPhone ? 11 : 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: isPhone ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _fuelAccent(String fuelType) {
    if (fuelType.contains('95')) return const Color(0xFF2563EB);
    if (fuelType.contains('91')) return const Color(0xFF16A34A);
    if (fuelType.contains('ديزل')) return const Color(0xFFEA580C);
    if (fuelType.contains('كيروسين')) return const Color(0xFF7C3AED);
    return AppColors.appBarWaterDeep;
  }
}

class _WarehouseFuelRow {
  final String fuelType;
  final double referenceBalance;
  final double available;
  final double capacity;
  final double soldSinceInventory;

  const _WarehouseFuelRow({
    required this.fuelType,
    required this.referenceBalance,
    required this.available,
    required this.capacity,
    required this.soldSinceInventory,
  });

  bool get shouldDisplay => available > 0 || soldSinceInventory > 0;
}
