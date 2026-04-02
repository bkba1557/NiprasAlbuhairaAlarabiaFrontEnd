import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/localization/app_localizations.dart' as loc;
import 'package:order_tracker/models/models.dart';
import 'package:order_tracker/models/station_models.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/language_provider.dart';
import 'package:order_tracker/providers/station_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart' show AppColors;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SessionCountdown extends StatefulWidget {
  final DateTime sessionDate;
  final bool isOpen;

  const SessionCountdown({
    super.key,
    required this.sessionDate,
    required this.isOpen,
  });

  @override
  State<SessionCountdown> createState() => _SessionCountdownState();
}

class _SessionCountdownState extends State<SessionCountdown> {
  late Duration remaining;
  late Timer _timer;

  static const Duration maxDuration = Duration(hours: 12);

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_calculateRemaining);
    });
  }

  void _calculateRemaining() {
    final endTime = widget.sessionDate.add(maxDuration);
    remaining = endTime.difference(DateTime.now());

    if (remaining.isNegative) {
      remaining = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final bool isExpired = remaining == Duration.zero;

    if (isExpired) {
      return _warningView();
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(loc.AppStrings.timeLeftUntilShiftEnds),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _warningView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(loc.AppStrings.shiftTimeHasEnded),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.tr(loc.AppStrings.pleaseCloseAndHandover),
          style: const TextStyle(fontSize: 12, color: Colors.red),
        ),
      ],
    );
  }
}

class _SessionMonthOption {
  final String key;
  final String label;

  const _SessionMonthOption({required this.key, required this.label});
}

class SessionsListScreen extends StatefulWidget {
  const SessionsListScreen({super.key});

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _filterStatus = 'الكل';
  List<String> _filterStationIds = [];
  String? _filterFuelType;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _selectedMonthKey;

  bool _initializedForStationScope = false;
  bool _showFilters = false;
  final Map<String, Map<String, double>> _stationPriceCache = {};
  StationProvider? _stationProvider;

  bool get _isOwnerStation => context.read<AuthProvider>().isOwnerStation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initByRole();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.read<StationProvider>();
    if (_stationProvider != provider) {
      _stationProvider?.removeListener(_onStationProviderChanged);
      _stationProvider = provider;
      _stationProvider?.addListener(_onStationProviderChanged);
    }

    _syncStationPriceCacheFromProvider();
  }

  @override
  void dispose() {
    _stationProvider?.removeListener(_onStationProviderChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStationProviderChanged() {
    if (!mounted) return;
    _syncStationPriceCacheFromProvider();
  }

  void _syncStationPriceCacheFromProvider() {
    final provider = _stationProvider;
    if (provider == null || _stationPriceCache.isEmpty) return;

    var changed = false;
    for (final stationId in _stationPriceCache.keys.toList()) {
      final cachedStation = provider.getCachedStation(stationId);
      if (cachedStation == null) continue;

      final next = <String, double>{
        for (final price in cachedStation.fuelPrices)
          price.fuelType: price.price,
      };

      if (mapEquals(_stationPriceCache[stationId], next)) continue;
      _stationPriceCache[stationId] = next;
      changed = true;
    }

    if (changed) {
      setState(() {});
    }
  }

  Future<void> _initByRole() async {
    final auth = context.read<AuthProvider>();
    final stationProvider = context.read<StationProvider>();
    final user = auth.user;

    final initialStationScope = _defaultStationScope(user);

    if (initialStationScope.isNotEmpty && !_initializedForStationScope) {
      setState(() {
        _filterStationIds = initialStationScope;
        _initializedForStationScope = true;
      });
    }

    if (user != null && user.role == 'station_boy' && user.stationId != null) {
      await stationProvider.fetchStations(forceStationId: user.stationId);
    } else {
      await stationProvider.fetchStations();
    }

    if (!mounted) return;
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    final filters = <String, dynamic>{};
    // limit=0 => اجلب كل الجلسات بدون حد أقصى من الـ API
    filters['limit'] = 0;

    if (_filterStatus != context.tr(loc.AppStrings.filterStatusAll)) {
      filters['status'] = _filterStatus;
    }
    if (_filterStationIds.isNotEmpty) {
      filters['stationIds'] = _filterStationIds;
    }
    if (_filterFuelType != null) filters['fuelType'] = _filterFuelType;
    if (_filterStartDate != null) {
      filters['startDate'] = _filterStartDate!.toIso8601String();
    }
    if (_filterEndDate != null) {
      filters['endDate'] = _filterEndDate!.toIso8601String();
    }

    final provider = context.read<StationProvider>();
    await provider.fetchSessions(filters: filters);
    await _prepareStationPriceCache(provider.sessions);
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.front, (_) => false);
    }
  }

  List<String> _defaultStationScope(User? user) {
    if (user == null) return const <String>[];
    if (user.role == 'station_boy' && user.stationId != null) {
      return <String>[user.stationId!];
    }
    if (user.role == 'owner_station' && user.stationIds.isNotEmpty) {
      return List<String>.from(user.stationIds);
    }
    return const <String>[];
  }

  bool _isStationScopedUser(User? user) {
    return user?.role == 'station_boy' || user?.role == 'owner_station';
  }

  bool _hasActiveFilters() {
    final user = context.read<AuthProvider>().user;
    final isStationScoped = _isStationScopedUser(user);
    return _filterStatus != context.tr(loc.AppStrings.filterStatusAll) ||
        (!isStationScoped && _filterStationIds.isNotEmpty) ||
        _filterFuelType != null ||
        _filterStartDate != null ||
        _filterEndDate != null;
  }

  void _clearFilters() {
    final user = context.read<AuthProvider>().user;
    setState(() {
      _filterStatus = context.tr(loc.AppStrings.filterStatusAll);
      _filterFuelType = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _filterStationIds = _defaultStationScope(user);
    });
    _loadSessions();
  }

  Future<void> _pickStations(List<Station> stations) async {
    final tempSelection = _filterStationIds.toSet();
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اختيار المحطات'),
              content: SizedBox(
                width: 420,
                child: stations.isEmpty
                    ? const Text('لا توجد محطات متاحة')
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: stations.map((station) {
                            final isChecked = tempSelection.contains(
                              station.id,
                            );
                            return CheckboxListTile(
                              value: isChecked,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                '${station.stationCode} - ${station.stationName}',
                              ),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    tempSelection.add(station.id);
                                  } else {
                                    tempSelection.remove(station.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, <String>[]),
                  child: const Text('مسح'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, tempSelection.toList()),
                  child: const Text('تطبيق'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _filterStationIds = picked;
    });
    await _loadSessions();
  }

  String _stationFilterLabel(List<Station> stations) {
    if (stations.isEmpty) {
      return 'جاري تحميل المحطات';
    }

    if (_filterStationIds.isEmpty) {
      return 'جميع المحطات';
    }

    final selectedStations = stations
        .where((station) => _filterStationIds.contains(station.id))
        .toList();

    if (selectedStations.isEmpty) {
      return 'جميع المحطات';
    }

    if (selectedStations.length == 1) {
      final station = selectedStations.first;
      return '${station.stationCode} - ${station.stationName}';
    }

    if (selectedStations.length == 2) {
      return selectedStations.map((station) => station.stationName).join('، ');
    }

    return '${selectedStations.length} محطات محددة';
  }

  void _showLanguageSelector() {
    final languageProvider = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  context.tr(loc.AppStrings.languageDialogTitle),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...loc.AppLanguage.values.map((language) {
                final isSelected = languageProvider.language == language;
                return ListTile(
                  leading: isSelected ? const Icon(Icons.check) : null,
                  title: Text(language.nativeName),
                  onTap: () {
                    languageProvider.setLanguage(language);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _prepareStationPriceCache(List<PumpSession> sessions) async {
    if (!mounted) return;
    final provider = context.read<StationProvider>();
    final stationIds = sessions
        .map((session) => session.stationId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final stationId in stationIds) {
      if (_stationPriceCache.containsKey(stationId)) continue;

      try {
        final station = await provider.fetchStationDetails(stationId);
        if (!mounted) return;
        setState(() {
          _stationPriceCache[stationId] = station != null
              ? {
                  for (final price in station.fuelPrices)
                    price.fuelType: price.price,
                }
              : {};
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _stationPriceCache[stationId] = {};
        });
      }
    }
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  List<_SessionMonthOption> _buildMonthOptions(List<PumpSession> sessions) {
    final uniqueMonths = <String, DateTime>{};

    for (final session in sessions) {
      final localDate = session.sessionDate.toLocal();
      final monthStart = DateTime(localDate.year, localDate.month);
      final key = _monthKey(monthStart);
      uniqueMonths.putIfAbsent(key, () => monthStart);
    }

    final sortedMonths = uniqueMonths.values.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedMonths
        .map(
          (monthStart) => _SessionMonthOption(
            key: _monthKey(monthStart),
            label: DateFormat('yyyy/MM').format(monthStart),
          ),
        )
        .toList();
  }

  String? _resolveSelectedMonthKey(List<_SessionMonthOption> monthOptions) {
    if (monthOptions.isEmpty) return null;

    final exists =
        _selectedMonthKey != null &&
        monthOptions.any((month) => month.key == _selectedMonthKey);
    return exists ? _selectedMonthKey : monthOptions.first.key;
  }

  List<PumpSession> _filterSessionsByMonth(
    List<PumpSession> sessions,
    String? selectedMonthKey,
  ) {
    if (selectedMonthKey == null) return sessions;

    return sessions.where((session) {
      final localDate = session.sessionDate.toLocal();
      return _monthKey(DateTime(localDate.year, localDate.month)) ==
          selectedMonthKey;
    }).toList();
  }

  Widget _buildMonthSelectorAction({
    required bool isLargeScreen,
    required List<_SessionMonthOption> monthOptions,
    required String? selectedMonthKey,
  }) {
    if (monthOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    String selectedMonthLabel = monthOptions.first.label;
    for (final option in monthOptions) {
      if (option.key == selectedMonthKey) {
        selectedMonthLabel = option.label;
        break;
      }
    }

    return PopupMenuButton<String>(
      tooltip: 'اختيار الشهر',
      onSelected: (value) {
        setState(() {
          _selectedMonthKey = value;
        });
      },
      itemBuilder: (context) => monthOptions
          .map(
            (option) => PopupMenuItem<String>(
              value: option.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (option.key == selectedMonthKey)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 8),
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  Text(option.label),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 10 : 4,
          vertical: 10,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              selectedMonthLabel,
              style: TextStyle(
                color: Colors.white,
                fontSize: isLargeScreen ? 13 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  double _sessionLiters(PumpSession session) {
    if (session.totalLiters != null && session.totalLiters! > 0) {
      return session.totalLiters!;
    }

    final readings = session.nozzleReadings ?? [];
    return readings
        .map(_sessionReadingLiters)
        .fold(0.0, (prev, liters) => prev + liters);
  }

  double _sessionReadingLiters(NozzleReading reading) {
    if (reading.closingReading == null) return 0;
    final diff = reading.closingReading! - reading.openingReading;
    return diff > 0 ? diff : 0;
  }

  Map<String, double>? _stationPricesFor(String stationId) {
    final cached = _stationPriceCache[stationId];
    if (cached != null && cached.isNotEmpty) return cached;

    final provider = _stationProvider;
    final station = provider?.getCachedStation(stationId);
    if (station == null) return cached;

    return <String, double>{
      for (final price in station.fuelPrices) price.fuelType: price.price,
    };
  }

  double? _lookupStationFuelPrice(
    Map<String, double>? stationPrices,
    String fuelType,
  ) {
    if (stationPrices == null || stationPrices.isEmpty) return null;

    final direct = stationPrices[fuelType];
    if (direct != null && direct > 0) return direct;

    final normalized = fuelType.trim();
    for (final entry in stationPrices.entries) {
      if (entry.key.trim() == normalized && entry.value > 0) {
        return entry.value;
      }
    }

    return null;
  }

  double _sessionUnitPrice(PumpSession session) {
    final stationPrices = _stationPricesFor(session.stationId);
    final readings = session.nozzleReadings ?? [];
    final usedFuelTypes = <String>{
      ...readings
        .map((reading) => reading.fuelType)
        .where((type) => type.isNotEmpty)
        .toSet(),
      if (session.fuelType.isNotEmpty) session.fuelType,
    };

    final availablePrices = <double>[];
    if (stationPrices != null) {
      for (final fuelType in usedFuelTypes) {
        final price = _lookupStationFuelPrice(stationPrices, fuelType);
        if (price != null && price > 0) {
          availablePrices.add(price);
        }
      }
    }

    if (availablePrices.isNotEmpty) {
      final total = availablePrices.reduce((value, element) => value + element);
      return total / availablePrices.length;
    }

    if (session.unitPrice != null && session.unitPrice! > 0) {
      return session.unitPrice!;
    }

    final fallbackPrices = (session.nozzleReadings ?? [])
        .map((n) => n.unitPrice ?? 0)
        .where((price) => price > 0)
        .toList();
    if (fallbackPrices.isNotEmpty) {
      final total = fallbackPrices.reduce((value, element) => value + element);
      return total / fallbackPrices.length;
    }

    return 0;
  }

  double _sessionExpectedAmount(PumpSession session) {
    final stationPrices = _stationPricesFor(session.stationId);
    final readings = session.nozzleReadings ?? [];
    final fallbackUnitPrice = _sessionUnitPrice(session);
    double total = 0;

    for (final reading in readings) {
      final liters = _sessionReadingLiters(reading);
      if (liters == 0) continue;

      final price =
          _lookupStationFuelPrice(stationPrices, reading.fuelType) ??
          reading.unitPrice ??
          fallbackUnitPrice;
      if (price <= 0) continue;

      total += liters * price;
    }

    return total;
  }

  double _sessionActualSales(PumpSession session) {
    return session.totalSales ?? session.paymentTypes.total;
  }

  double _sessionDifference(PumpSession session) {
    final expected = _sessionExpectedAmount(session);
    final actual = _sessionActualSales(session);
    if (session.calculatedDifference != null) {
      return session.calculatedDifference!;
    }
    return actual - expected;
  }

  String _sessionEmployeeName(PumpSession session) {
    return session.closingEmployeeName ??
        session.openingEmployeeName ??
        context.tr(loc.AppStrings.statusUndefined);
  }

  String _formatPrice(double value) {
    if (value.isNaN) return '0.00';
    return value.toStringAsFixed(2);
  }

  double _sessionOpeningReadingValue(PumpSession session) {
    final pumps = session.pumps ?? [];
    if (pumps.isNotEmpty) {
      return pumps.fold<double>(0, (sum, p) => sum + (p.openingReading ?? 0));
    }
    return session.openingReading;
  }

  double _sessionClosingReadingValue(PumpSession session) {
    final pumps = session.pumps ?? [];
    if (pumps.isNotEmpty) {
      return pumps.fold<double>(0, (sum, p) => sum + (p.closingReading ?? 0));
    }
    return session.closingReading ?? 0;
  }

  Map<String, double> _sessionFuelTypePrices(PumpSession session) {
    final stationPrices = _stationPricesFor(session.stationId) ?? {};
    final readings = session.nozzleReadings ?? [];

    final prices = <String, double>{};
    for (final reading in readings) {
      final fuelType = reading.fuelType.trim();
      if (fuelType.isEmpty) continue;

      final price =
          _lookupStationFuelPrice(stationPrices, fuelType) ??
          reading.unitPrice ??
          session.unitPrice ??
          0;
      if (price <= 0) continue;

      prices[fuelType] = price;
    }

    if (prices.isEmpty && session.fuelType.isNotEmpty) {
      final fallbackPrice =
          _lookupStationFuelPrice(stationPrices, session.fuelType) ??
          session.unitPrice ??
          0;
      if (fallbackPrice > 0) {
        prices[session.fuelType] = fallbackPrice;
      }
    }

    return prices;
  }

  Widget _buildOpeningReadingsByNozzle(
    PumpSession session,
    bool isLargeScreen,
  ) {
    final readings = session.nozzleReadings ?? [];

    if (readings.isEmpty) {
      return const Text('---');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: readings.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            context.tr(loc.AppStrings.pumpNozzleTemplate, {
                  'pumpNumber': r.pumpNumber,
                  'nozzleNumber': r.nozzleNumber,
                }) +
                ': ${r.openingReading.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isLargeScreen ? 12 : 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryBlue,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSoldQuantityByNozzle(PumpSession session, bool isLargeScreen) {
    final readings = session.nozzleReadings ?? [];

    if (readings.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }

    return SizedBox(
      width: 220,
      height: 90,
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: readings.map((r) {
              final liters = r.totalLiters ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(loc.AppStrings.pumpNozzleFuelTemplate, {
                        'pumpNumber': r.pumpNumber,
                        'nozzleNumber': r.nozzleNumber,
                        'fuelType': r.fuelType,
                      }),
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 2),

                    Text(
                      context.tr(loc.AppStrings.quantityLabel, {
                        'amount': liters.toStringAsFixed(2),
                      }),
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.successGreen,
                      ),
                    ),

                    const Divider(height: 8, thickness: 0.4),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDifferenceByNozzle(PumpSession session, bool isLargeScreen) {
    final readings = session.nozzleReadings ?? [];

    if (readings.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }

    final stationPrices = _stationPricesFor(session.stationId);
    final fallbackUnitPrice = _sessionUnitPrice(session);

    return SizedBox(
      width: 260,
      height: 90,
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: readings.map((r) {
              final liters = r.totalLiters ?? 0;
              final price =
                  _lookupStationFuelPrice(stationPrices, r.fuelType) ??
                  r.unitPrice ??
                  fallbackUnitPrice;
              final expectedAmount = liters * price;
              final actualAmount = r.totalAmount ?? expectedAmount;
              final diff = actualAmount - expectedAmount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    Text(
                      context.tr(loc.AppStrings.pumpNozzleFuelTemplate, {
                        'pumpNumber': r.pumpNumber,
                        'nozzleNumber': r.nozzleNumber,
                        'fuelType': r.fuelType,
                      }),
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      context.tr(loc.AppStrings.formatTemplate, {
                        'liters': liters.toStringAsFixed(2),
                        'price': price.toStringAsFixed(2),
                        'total': expectedAmount.toStringAsFixed(2),
                      }),
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 10,
                        color: AppColors.darkGray,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      context.tr(loc.AppStrings.differenceTemplate, {
                        'difference': diff.toStringAsFixed(2),
                      }),
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 11,
                        fontWeight: FontWeight.bold,
                        color: diff == 0
                            ? AppColors.successGreen
                            : AppColors.warningOrange,
                      ),
                    ),

                    const Divider(height: 8, thickness: 0.4),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTable(List<PumpSession> sessions, bool isLargeScreen) {
    final ScrollController horizontalController = ScrollController();
    final ScrollController verticalController = ScrollController();

    return Scrollbar(
      controller: verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: verticalController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1800),
              child: DataTable(
                dataRowMinHeight: 90,
                dataRowMaxHeight: 100,
                columnSpacing: 24,
                horizontalMargin: 16,

                columns: [
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.sessionNumberColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.stationColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.statusColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.openingClosingReadingsColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.soldQuantityColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.differenceColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.fuelPricesColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.employeeColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.amountColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.shiftColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.dateColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      context.tr(loc.AppStrings.actionsColumn),
                      style: _tableHeaderStyle(isLargeScreen),
                    ),
                  ),
                ],

                rows: sessions.map((session) {
                  final pumps = session.pumps ?? [];
                  final employeeName = _sessionEmployeeName(session);
                  final fuelPrices = _sessionFuelTypePrices(session);
                  final fuelPriceText = fuelPrices.entries
                      .map((e) => '${e.key}: ${_formatPrice(e.value)}')
                      .join('\n');

                  final pumpNumbersFromPumps = pumps
                      .map((p) => p.pumpNumber)
                      .toSet()
                      .join(context.tr(loc.AppStrings.pumpSeparator));

                  final computedDifference =
                      _sessionActualSales(session) -
                      _sessionExpectedAmount(session);

                  return DataRow(
                    onSelectChanged: (_) {
                      Navigator.pushNamed(
                        context,
                        '/session/details',
                        arguments: session.id,
                      );
                    },
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Text(
                            session.sessionNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isLargeScreen ? 14 : 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            session.stationName,
                            style: TextStyle(fontSize: isLargeScreen ? 20 : 12),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: _buildStatusChip(session, isLargeScreen),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: _buildFullNozzleReadings(
                            session,
                            isLargeScreen,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: _buildSoldQuantityByNozzle(
                            session,
                            isLargeScreen,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 240,
                          child: _buildDifferenceByNozzle(
                            session,
                            isLargeScreen,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            fuelPriceText.isEmpty ? '---' : fuelPriceText,
                          ),
                        ),
                      ),
                      DataCell(SizedBox(width: 130, child: Text(employeeName))),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Text(_formatPrice(computedDifference)),
                        ),
                      ),
                      DataCell(
                        SizedBox(width: 100, child: Text(session.shiftType)),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat(
                                  'yyyy/MM/dd',
                                ).format(session.sessionDate),
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 13 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                DateFormat('HH:mm').format(session.sessionDate),
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 12 : 11,
                                  color: Colors.grey,
                                ),
                              ),

                              const SizedBox(height: 6),

                              SessionCountdown(
                                sessionDate: session.sessionDate,
                                isOpen:
                                    session.status ==
                                    context.tr(loc.AppStrings.statusOpen),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: _buildActions(session, isLargeScreen),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PumpSession session, bool isLargeScreen) {
    final color = _getStatusColor(session.status);
    String statusText = session.status;

    // تحويل النص العربي إلى المفتاح المناسب
    if (session.status == context.tr(loc.AppStrings.statusOpen)) {
      statusText = context.tr(loc.AppStrings.statusOpen);
    } else if (session.status == context.tr(loc.AppStrings.statusClosed)) {
      statusText = context.tr(loc.AppStrings.statusClosed);
    } else if (session.status == context.tr(loc.AppStrings.statusApproved)) {
      statusText = context.tr(loc.AppStrings.statusApproved);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: color,
          fontSize: isLargeScreen ? 15 : 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActions(PumpSession session, bool isLargeScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.status == context.tr(loc.AppStrings.statusOpen) &&
            !_isOwnerStation)
          IconButton(
            icon: Icon(
              Icons.stop_circle,
              size: isLargeScreen ? 20 : 18,
              color: AppColors.warningOrange,
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/sessions/close',
                arguments: session,
              );
            },
            tooltip: context.tr(loc.AppStrings.closeSessionTooltip),
          ),
        IconButton(
          icon: Icon(
            Icons.remove_red_eye,
            size: isLargeScreen ? 20 : 18,
            color: AppColors.primaryBlue,
          ),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/session/details',
              arguments: session.id,
            );
          },
          tooltip: context.tr(loc.AppStrings.viewDetailsTooltip),
        ),
      ],
    );
  }

  Widget _buildReadingsSummary(List<PumpSession> sessions, bool isLargeScreen) {
    final openingTotal = sessions
        .map(_sessionOpeningReadingValue)
        .fold(0.0, (prev, value) => prev + value);
    final closingTotal = sessions
        .map(_sessionClosingReadingValue)
        .fold(0.0, (prev, value) => prev + value);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 20 : 16,
        vertical: 8,
      ),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(loc.AppStrings.totalOpeningReading),
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${openingTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(loc.AppStrings.totalClosingReading),
                      style: const TextStyle(color: AppColors.mediumGray),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${closingTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _tableHeaderStyle(bool isLargeScreen) {
    return TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: isLargeScreen ? 15 : 13,
      color: AppColors.primaryBlue,
    );
  }

  Color _getStatusColor(String status) {
    if (status == context.tr(loc.AppStrings.statusOpen)) {
      return AppColors.infoBlue;
    } else if (status == context.tr(loc.AppStrings.statusClosed)) {
      return AppColors.warningOrange;
    } else if (status == context.tr(loc.AppStrings.statusApproved)) {
      return AppColors.successGreen;
    } else {
      return AppColors.mediumGray;
    }
  }

  Widget _buildFullNozzleReadings(PumpSession session, bool isLargeScreen) {
    final readings = session.nozzleReadings ?? [];

    if (readings.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }

    return SizedBox(
      width: 240,
      height: 90,
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: readings.map((r) {
              final bool hasClosing = r.closingReading != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(loc.AppStrings.pumpNozzleFuelTemplate, {
                        'pumpNumber': r.pumpNumber,
                        'nozzleNumber': r.nozzleNumber,
                        'fuelType': r.fuelType,
                      }),
                      style: TextStyle(
                        fontSize: isLargeScreen ? 12 : 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),

                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: isLargeScreen ? 11 : 11,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${context.tr(loc.AppStrings.openingReadingLabelShort)} ',
                          ),
                          TextSpan(
                            text: r.openingReading.toStringAsFixed(2),
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: '  →  '),
                          TextSpan(
                            text:
                                '${context.tr(loc.AppStrings.closingReadingLabelShort)} ',
                          ),
                          TextSpan(
                            text: hasClosing
                                ? r.closingReading!.toStringAsFixed(2)
                                : context.tr(
                                    loc.AppStrings.readingEntryPending,
                                  ),
                            style: TextStyle(
                              color: hasClosing
                                  ? AppColors.successGreen
                                  : AppColors.warningOrange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 8, thickness: 0.4),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(bool isLargeScreen) {
    final stationProvider = context.watch<StationProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isStationBoy = user?.role == 'station_boy';
    final statusOptions = {
      context.tr(loc.AppStrings.filterStatusAll):
          loc.AppStrings.filterStatusAll,
      context.tr(loc.AppStrings.statusOpen): loc.AppStrings.filterStatusOpen,
      context.tr(loc.AppStrings.filterStatusPending):
          loc.AppStrings.filterStatusPending,
      context.tr(loc.AppStrings.statusClosed):
          loc.AppStrings.filterStatusClosed,
    };
    final fuelOptions = {
      context.tr(loc.AppStrings.filterFuelTypeAll):
          loc.AppStrings.filterFuelTypeAll,
      context.tr(loc.AppStrings.filterFuelType91):
          loc.AppStrings.filterFuelType91,
      context.tr(loc.AppStrings.filterFuelType95):
          loc.AppStrings.filterFuelType95,
      context.tr(loc.AppStrings.filterFuelTypeDiesel):
          loc.AppStrings.filterFuelTypeDiesel,
      context.tr(loc.AppStrings.filterFuelTypeGas):
          loc.AppStrings.filterFuelTypeGas,
    };

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(
        bottom: 16,
        left: isLargeScreen ? 20 : 0,
        right: isLargeScreen ? 20 : 0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(loc.AppStrings.filtersTitle),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isLargeScreen ? 18 : 16,
                  ),
                ),
                Row(
                  children: [
                    if (_hasActiveFilters())
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all),
                        label: Text(context.tr(loc.AppStrings.clearFilters)),
                      ),
                    IconButton(
                      icon: Icon(
                        _showFilters ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (_showFilters) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  if (!isStationBoy)
                    Container(
                      width: isLargeScreen ? 280 : 220,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.lightGray),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: stationProvider.isStationsLoading
                            ? null
                            : () => _pickStations(stationProvider.stations),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _stationFilterLabel(stationProvider.stations),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: stationProvider.isStationsLoading
                                      ? AppColors.mediumGray
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (stationProvider.isStationsLoading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    width: isLargeScreen ? 180 : 150,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightGray),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: statusOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(context.tr(entry.value)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _filterStatus = value!;
                        });
                        _loadSessions();
                      },
                    ),
                  ),
                  Container(
                    width: isLargeScreen ? 180 : 150,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightGray),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _filterFuelType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(context.tr(loc.AppStrings.filterFuelType)),
                      items: fuelOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value:
                              entry.key ==
                                  context.tr(loc.AppStrings.filterFuelTypeAll)
                              ? null
                              : entry.key,
                          child: Text(context.tr(entry.value)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _filterFuelType = value;
                        });
                        _loadSessions();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isLargeScreen ? 300 : 250,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _filterStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  _filterStartDate = date;
                                });
                                _loadSessions();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.lightGray),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterStartDate == null
                                        ? context.tr(loc.AppStrings.fromDate)
                                        : DateFormat(
                                            'yyyy/MM/dd',
                                          ).format(_filterStartDate!),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate:
                                    _filterEndDate ??
                                    _filterStartDate ??
                                    DateTime.now(),
                                firstDate: _filterStartDate ?? DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  _filterEndDate = date;
                                });
                                _loadSessions();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.lightGray),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterEndDate == null
                                        ? context.tr(loc.AppStrings.toDate)
                                        : DateFormat(
                                            'yyyy/MM/dd',
                                          ).format(_filterEndDate!),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadSessions,
                    icon: const Icon(Icons.search),
                    label: Text(context.tr(loc.AppStrings.applyFilters)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();

    final allSessions = stationProvider.sessions;
    final monthOptions = _buildMonthOptions(allSessions);
    final selectedMonthKey = _resolveSelectedMonthKey(monthOptions);
    final sessions = _filterSessionsByMonth(allSessions, selectedMonthKey);
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(loc.AppStrings.sessionsTitle),
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: isLargeScreen,
        actions: [
          _buildMonthSelectorAction(
            isLargeScreen: isLargeScreen,
            monthOptions: monthOptions,
            selectedMonthKey: selectedMonthKey,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: context.tr(loc.AppStrings.filterListTooltip),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: context.tr(loc.AppStrings.languageTooltip),
            onPressed: _showLanguageSelector,
          ),
          if (!isLargeScreen)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: context.tr(loc.AppStrings.logoutTooltip),
              onPressed: _logout,
            ),
          if (isLargeScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 20),
                label: Text(context.tr(loc.AppStrings.logout)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 20 : 16,
              vertical: 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr(loc.AppStrings.searchHint),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 20 : 16,
                        vertical: isLargeScreen ? 16 : 14,
                      ),
                    ),
                  ),
                ),
                // if (isLargeScreen)
                //   Padding(
                //     padding: const EdgeInsets.only(left: 16),
                //     child: ElevatedButton.icon(
                //       onPressed: () {
                //         Navigator.pushNamed(context, '/sessions/open');
                //       },
                //       icon: const Icon(Icons.add),
                //       label: Text(context.tr(loc.AppStrings.newSession)),
                //       style: ElevatedButton.styleFrom(
                //         padding: EdgeInsets.symmetric(
                //           horizontal: isLargeScreen ? 24 : 16,
                //           vertical: isLargeScreen ? 16 : 14,
                //         ),
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
          _buildFiltersPanel(isLargeScreen),
          if (sessions.isNotEmpty)
            _buildReadingsSummary(sessions, isLargeScreen),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 20 : 0),
              child: RefreshIndicator(
                onRefresh: _loadSessions,
                child: stationProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 80,
                              color: AppColors.lightGray,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr(loc.AppStrings.noSessions),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr(loc.AppStrings.openNewSessionHint),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isLargeScreen
                    ? _buildSessionTable(sessions, isLargeScreen)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildSessionCard(
                            sessions[index],
                            isLargeScreen,
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !isLargeScreen && !_isOwnerStation
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/sessions/open');
              },
              child: const Icon(Icons.play_arrow),
            )
          : null,
    );
  }

  Widget _buildSessionCard(PumpSession session, bool isLargeScreen) {
    Color statusColor = _getStatusColor(session.status);
    IconData statusIcon;

    if (session.status == context.tr(loc.AppStrings.statusOpen)) {
      statusIcon = Icons.play_circle_fill;
    } else if (session.status == context.tr(loc.AppStrings.statusClosed)) {
      statusIcon = Icons.stop_circle;
    } else if (session.status == context.tr(loc.AppStrings.statusApproved)) {
      statusIcon = Icons.check_circle;
    } else {
      statusIcon = Icons.circle;
    }

    final pumps = session.pumps ?? [];
    final hasPumps = pumps.isNotEmpty;

    final openingReadingFromPumps = pumps.fold<double>(
      0,
      (sum, p) => sum + (p.openingReading ?? 0),
    );

    final closingReadingFromPumps = pumps.fold<double>(
      0,
      (sum, p) => sum + (p.closingReading ?? 0),
    );

    final pumpNumbersFromPumps = pumps
        .map((p) => p.pumpNumber)
        .toSet()
        .join(context.tr(loc.AppStrings.pumpSeparator));

    final fuelTypesFromPumps = pumps
        .map((p) => p.fuelType)
        .toSet()
        .join(context.tr(loc.AppStrings.fuelTypeSeparator));
    final unitPrice = _sessionUnitPrice(session);
    final sessionLiters = _sessionLiters(session);
    final expectedAmount = _sessionExpectedAmount(session);
    final differenceValue = _sessionDifference(session);
    final employeeName = _sessionEmployeeName(session);
    final openingTotal = _sessionOpeningReadingValue(session);
    final closingTotal = _sessionClosingReadingValue(session);
    final fuelPrices = _sessionFuelTypePrices(session);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/session/details',
            arguments: session.id,
          );
        },
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.sessionNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isLargeScreen ? 18 : 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              session.stationName,
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: isLargeScreen ? 15 : 14,
                              ),
                            ),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.mediumGray,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              hasPumps
                                  ? pumpNumbersFromPumps
                                  : session.pumpNumber,
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: isLargeScreen ? 15 : 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      session.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isLargeScreen ? 13 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(loc.AppStrings.litersPricePerFuelType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFuelPriceRow(fuelPrices, isLargeScreen),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(loc.AppStrings.totalOpeningReading),
                          style: const TextStyle(color: AppColors.mediumGray),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          openingTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(loc.AppStrings.totalClosingReading),
                          style: const TextStyle(color: AppColors.mediumGray),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          closingTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoColumn(
                    context.tr(loc.AppStrings.literPrice),
                    Text(
                      '${_formatPrice(unitPrice)} ${context.tr(loc.AppStrings.currencySaudiRiyal)}',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 15 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    flex: 2,
                  ),
                  _buildInfoColumn(
                    context.tr(loc.AppStrings.soldQuantity),
                    Text(
                      '${sessionLiters.toStringAsFixed(2)} ${context.tr(loc.AppStrings.liters)}',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 15 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    flex: 2,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLargeScreen)
                Row(
                  children: [
                    _buildInfoColumn(
                      context.tr(loc.AppStrings.readingsColumn),
                      _buildOpeningReadingsByNozzle(session, isLargeScreen),
                      flex: 3,
                    ),
                    _buildInfoColumn(
                      context.tr(loc.AppStrings.quantity),
                      Text(
                        session.totalLiters?.toStringAsFixed(2) ?? '0.00',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 15 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildInfoColumn(
                      context.tr(loc.AppStrings.amount),
                      Text(
                        session.totalAmount?.toStringAsFixed(2) ?? '0.00',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 15 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildInfoColumn(
                      context.tr(loc.AppStrings.shiftColumn),
                      Text(
                        session.shiftType,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 15 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildInfoColumn(
                      context.tr(loc.AppStrings.dateColumn),
                      Text(
                        DateFormat('yyyy/MM/dd').format(session.sessionDate),
                        style: TextStyle(
                          fontSize: isLargeScreen ? 15 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildInfoColumn(
                      context.tr(loc.AppStrings.fuelType),
                      Text(
                        hasPumps ? fuelTypesFromPumps : session.fuelType,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 15 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoColumn(
                            context.tr(loc.AppStrings.readingsColumn),
                            Row(
                              children: [
                                Text(
                                  hasPumps && closingReadingFromPumps > 0
                                      ? closingReadingFromPumps.toStringAsFixed(
                                          2,
                                        )
                                      : session.closingReading?.toStringAsFixed(
                                              2,
                                            ) ??
                                            '---',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_back,
                                  size: 14,
                                  color: AppColors.lightGray,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasPumps
                                      ? openingReadingFromPumps.toStringAsFixed(
                                          2,
                                        )
                                      : session.openingReading.toStringAsFixed(
                                          2,
                                        ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoColumn(
                            context.tr(loc.AppStrings.quantity),
                            Text(
                              session.totalLiters?.toStringAsFixed(2) ?? '0.00',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoColumn(
                            context.tr(loc.AppStrings.amount),
                            Text(
                              session.totalAmount?.toStringAsFixed(2) ?? '0.00',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoColumn(
                            context.tr(loc.AppStrings.shiftColumn),
                            Text(
                              session.shiftType,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoColumn(
                            context.tr(loc.AppStrings.dateColumn),
                            Text(
                              DateFormat(
                                'yyyy/MM/dd',
                              ).format(session.sessionDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoColumn(
                            context.tr(loc.AppStrings.fuelType),
                            Text(
                              hasPumps ? fuelTypesFromPumps : session.fuelType,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoColumn(
                    context.tr(loc.AppStrings.expectedAmount),
                    Text(
                      '${_formatPrice(expectedAmount)} ${context.tr(loc.AppStrings.currencySaudiRiyal)}',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 15 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    flex: 3,
                  ),
                  _buildInfoColumn(
                    context.tr(loc.AppStrings.differenceColumn),
                    Text(
                      '${_formatPrice(differenceValue)} ${context.tr(loc.AppStrings.currencySaudiRiyal)}',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 15 : 14,
                        fontWeight: FontWeight.w500,
                        color: differenceValue >= 0
                            ? AppColors.successGreen
                            : AppColors.errorRed,
                      ),
                    ),
                    flex: 2,
                  ),
                  _buildInfoColumn(
                    context.tr(loc.AppStrings.employeeColumn),
                    Text(
                      employeeName,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 15 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    flex: 3,
                  ),
                ],
              ),
              if (session.status == context.tr(loc.AppStrings.statusOpen) &&
                  !_isOwnerStation) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/sessions/close',
                            arguments: session,
                          );
                        },
                        icon: Icon(
                          Icons.stop_circle,
                          size: isLargeScreen ? 20 : 18,
                        ),
                        label: Text(
                          context.tr(loc.AppStrings.closeSession),
                          style: TextStyle(fontSize: isLargeScreen ? 15 : 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningOrange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isLargeScreen ? 14 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    if (isLargeScreen) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/session/details',
                            arguments: session.id,
                          );
                        },
                        icon: Icon(
                          Icons.remove_red_eye,
                          size: isLargeScreen ? 20 : 18,
                        ),
                        label: Text(context.tr(loc.AppStrings.viewDetails)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isLargeScreen ? 14 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    if (!isLargeScreen) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/session/details',
                            arguments: session.id,
                          );
                        },
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, Widget value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.mediumGray, fontSize: 12),
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }

  Widget _buildFuelPriceRow(
    Map<String, double> fuelPrices,
    bool isLargeScreen,
  ) {
    if (fuelPrices.isEmpty) {
      return Text(
        context.tr(loc.AppStrings.fuelPriceUnavailable),
        style: TextStyle(
          fontSize: isLargeScreen ? 14 : 13,
          color: AppColors.mediumGray,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: fuelPrices.entries.map((entry) {
        return Chip(
          label: Text(
            '${entry.key}: ${_formatPrice(entry.value)} ${context.tr(loc.AppStrings.currencySaudiRiyal)}',
            style: TextStyle(fontSize: isLargeScreen ? 13 : 12),
          ),
          backgroundColor: Colors.blue.shade50,
          side: BorderSide(color: Colors.blue.shade100),
        );
      }).toList(),
    );
  }
}
