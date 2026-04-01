import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:order_tracker/models/driver_tracking_models.dart';
import 'package:order_tracker/models/order_model.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/providers/driver_tracking_provider.dart';
import 'package:order_tracker/providers/order_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/driver_background_location_permission.dart';
import 'package:order_tracker/utils/tracking_directions_service.dart';
import 'package:order_tracker/widgets/maps/advanced_web_map.dart';
import 'package:provider/provider.dart';

class DriverDeliveryTrackingScreen extends StatefulWidget {
  final String? orderId;
  final Order? initialOrder;

  const DriverDeliveryTrackingScreen({
    super.key,
    this.orderId,
    this.initialOrder,
  });

  @override
  State<DriverDeliveryTrackingScreen> createState() =>
      _DriverDeliveryTrackingScreenState();
}

class _DriverDeliveryTrackingScreenState
    extends State<DriverDeliveryTrackingScreen> {
  static const List<String> _fuelTypes = <String>[
    'بنزين 91',
    'بنزين 95',
    'ديزل',
    'كيروسين',
    'غاز طبيعي',
    'أخرى',
  ];

  Order? _order;
  String? _driverId;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _orderRefreshTimer;
  List<LatLng> _routePoints = const <LatLng>[];
  double? _distanceKm;
  int? _durationMinutes;
  DateTime? _lastPublishedAt;
  LatLng? _lastPublishedLocation;
  DateTime? _lastRouteRefreshAt;
  String? _error;
  String? _routeError;
  bool _isPreparing = true;
  bool _isSharing = false;
  bool _isRouteLoading = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _orderRefreshTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  String get _normalizedStatus => _order?.status.trim() ?? '';

  bool get _hasLoadingData {
    final order = _order;
    if (order == null) return false;
    final hasFuel = order.actualFuelType?.trim().isNotEmpty == true;
    final hasLiters = (order.actualLoadedLiters ?? 0) > 0;
    return hasFuel && hasLiters;
  }

  bool get _isHeadingToLoadingStation {
    const postLoadingStatuses = <String>{
      'تم التحميل',
      'في الطريق',
      'تم التسليم',
      'تم التنفيذ',
      'مكتمل',
      'ملغى',
    };
    return !postLoadingStatuses.contains(_normalizedStatus);
  }

  bool get _isFinalStatus {
    const finalStatuses = <String>{
      'تم التسليم',
      'تم التنفيذ',
      'مكتمل',
      'ملغى',
    };
    return finalStatuses.contains(_normalizedStatus);
  }

  bool get _canSubmitLoadingData {
    if (_hasLoadingData) return false;
    return const <String>{
      'جاهز للتحميل',
      'في انتظار التحميل',
      'تم التحميل',
    }.contains(_normalizedStatus);
  }

  String get _loadingStationName {
    final order = _order;
    if (order == null) return 'محطة أرامكو';

    final explicitStation = order.loadingStationName?.trim();
    if (explicitStation != null && explicitStation.isNotEmpty) {
      return explicitStation;
    }

    if (order.supplierName.trim().isNotEmpty) {
      return order.supplierName.trim();
    }

    return 'محطة أرامكو';
  }

  String get _loadingStationDestinationText {
    final order = _order;
    if (order == null) return '';

    if (order.supplierAddress?.trim().isNotEmpty == true) {
      return order.supplierAddress!.trim();
    }

    return _loadingStationName;
  }

  String get _customerDestinationText {
    final order = _order;
    if (order == null) return '';

    if (order.address?.trim().isNotEmpty == true) {
      return order.address!.trim();
    }

    if (order.customerAddress?.trim().isNotEmpty == true) {
      return order.customerAddress!.trim();
    }

    final parts = <String>[
      if (order.city?.trim().isNotEmpty == true) order.city!.trim(),
      if (order.area?.trim().isNotEmpty == true) order.area!.trim(),
    ];

    return parts.join(' - ');
  }

  String get _destinationText {
    return _isHeadingToLoadingStation
        ? _loadingStationDestinationText
        : _customerDestinationText;
  }

  String get _destinationLabel {
    return _isHeadingToLoadingStation ? 'وجهة التعبئة' : 'وجهة التسليم';
  }

  String get _stageTitle {
    return _isHeadingToLoadingStation
        ? 'التوجه إلى محطة أرامكو'
        : 'التوجه إلى العميل';
  }

  String get _destinationMarkerTitle {
    return _isHeadingToLoadingStation ? _loadingStationName : 'موقع العميل';
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthProvider>();
    final driverId = auth.user?.driverId;
    if (driverId == null || driverId.trim().isEmpty) {
      setState(() {
        _error = 'لا يوجد سائق مرتبط بهذا المستخدم';
        _isPreparing = false;
      });
      return;
    }

    _driverId = driverId;

    try {
      await _loadOrder(forceRefresh: true);
      final locationReady = await _ensureLocationPermission();
      if (!locationReady) {
        setState(() => _isPreparing = false);
        return;
      }

      await _loadCurrentLocation();
      await _refreshRoute(force: true);
      await _startSharing();
      _startOrderRefresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _loadOrder({bool forceRefresh = false}) async {
    final orderProvider = context.read<OrderProvider>();
    final preferredOrderId = widget.orderId ?? widget.initialOrder?.id;
    if (preferredOrderId == null || preferredOrderId.isEmpty) {
      throw Exception('معرف الطلب غير متاح');
    }

    final fallbackOrder =
        widget.initialOrder ??
        orderProvider.getOrderById(preferredOrderId) ??
        _order;
    if (fallbackOrder != null && fallbackOrder.id.isNotEmpty) {
      _setOrder(fallbackOrder, notify: !forceRefresh);
    }

    if (forceRefresh) {
      await orderProvider.fetchOrderById(preferredOrderId, silent: true);
      final freshOrder =
          orderProvider.selectedOrder ??
          orderProvider.getOrderById(preferredOrderId);

      if (freshOrder != null) {
        _setOrder(freshOrder);
      } else if (orderProvider.error != null && mounted) {
        setState(() {
          _error = orderProvider.error;
        });
      }
    }

    if (_order == null) {
      throw Exception('تعذر تحميل بيانات الطلب');
    }
  }

  void _setOrder(Order order, {bool notify = true}) {
    if (!mounted || !notify) {
      _order = order;
    } else {
      setState(() {
        _order = order;
      });
    }

    if (_isFinalStatus) {
      unawaited(_stopSharing());
    }
  }

  void _startOrderRefresh() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted || _order == null) return;
      await _loadOrder(forceRefresh: true);
      await _refreshRoute(force: true);
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'خدمة الموقع غير مفعلة على الجهاز';
      });
      return false;
    }

    var permission = await DriverBackgroundLocationPermission
        .requestBackgroundLocationPermission();

    if (permission == LocationPermission.deniedForever && mounted) {
      await DriverBackgroundLocationPermission.showSettingsDialog(context);
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _error = 'تم رفض صلاحية الموقع، ولا يمكن تشغيل التتبع الحي';
      });
      return false;
    }

    return true;
  }

  Future<void> _loadCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    if (!mounted) return;
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    await _publishLocation(position, force: true);
  }

  Future<void> _startSharing() async {
    if (_isSharing || _isFinalStatus) return;
    await _positionSubscription?.cancel();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _trackingLocationSettings,
        ).listen(
          (position) async {
            if (!mounted) return;
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
            await _publishLocation(position);
            unawaited(_refreshRoute());
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _error = error.toString();
            });
          },
        );

    if (mounted) {
      setState(() {
        _isSharing = true;
      });
    }
  }

  Future<void> _stopSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _publishLocation(Position position, {bool force = false}) async {
    if (_driverId == null || _order == null || _isFinalStatus) return;

    final nextLocation = LatLng(position.latitude, position.longitude);
    final now = DateTime.now();
    final movedEnough =
        _lastPublishedLocation == null ||
        Geolocator.distanceBetween(
              _lastPublishedLocation!.latitude,
              _lastPublishedLocation!.longitude,
              nextLocation.latitude,
              nextLocation.longitude,
            ) >=
            15;
    final waitedEnough =
        _lastPublishedAt == null ||
        now.difference(_lastPublishedAt!).inSeconds >= 8;

    if (!force && !movedEnough && !waitedEnough) {
      return;
    }

    final snapshot = DriverLocationSnapshot(
      id: '',
      driverId: _driverId!,
      orderId: _order!.id,
      latitude: nextLocation.latitude,
      longitude: nextLocation.longitude,
      accuracy: position.accuracy,
      speed: position.speed >= 0 ? position.speed : 0,
      heading: position.heading >= 0 ? position.heading : 0,
      timestamp: now,
    );

    final trackingProvider = context.read<DriverTrackingProvider>();
    final ok = await trackingProvider.publishDriverLocation(snapshot: snapshot);
    if (!ok || !mounted) {
      if (mounted && trackingProvider.error != null) {
        setState(() {
          _error = trackingProvider.error;
        });
      }
      return;
    }

    setState(() {
      _lastPublishedAt = now;
      _lastPublishedLocation = nextLocation;
      _error = null;
    });
  }

  Future<void> _refreshRoute({bool force = false}) async {
    if (_currentLocation == null || _order == null) return;

    final destinationText = _destinationText;
    if (destinationText.isEmpty) {
      setState(() {
        _routePoints = const <LatLng>[];
        _distanceKm = null;
        _durationMinutes = null;
        _routeError = 'عنوان الوجهة غير مكتمل';
      });
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRouteRefreshAt != null &&
        now.difference(_lastRouteRefreshAt!).inSeconds < 12) {
      return;
    }
    _lastRouteRefreshAt = now;

    setState(() {
      _isRouteLoading = true;
      _routeError = null;
    });

    try {
      final routes = await fetchTrackingRoutes(
        origin: '${_currentLocation!.latitude},${_currentLocation!.longitude}',
        destination: destinationText,
      );
      if (!mounted) return;

      if (routes.isEmpty) {
        setState(() {
          _routePoints = const <LatLng>[];
          _distanceKm = null;
          _durationMinutes = null;
          _routeError = 'لم يتم العثور على مسار للوجهة الحالية';
          _isRouteLoading = false;
        });
        return;
      }

      final route = routes.first;
      setState(() {
        _routePoints = route.points;
        _distanceKm = route.distanceKm;
        _durationMinutes = route.durationMinutes;
        _routeError = null;
        _isRouteLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _routeError = error.toString();
        _isRouteLoading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
    await _loadOrder(forceRefresh: true);
    await _refreshRoute(force: true);
  }

  Future<void> _updateStatus(String nextStatus) async {
    if (_order == null || _isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    final provider = context.read<OrderProvider>();
    final ok = await provider.updateOrderStatus(_order!.id, nextStatus);

    if (!mounted) return;

    if (ok) {
      await _loadOrder(forceRefresh: true);

      if (nextStatus == 'تم التسليم') {
        await _stopSharing();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب إلى $nextStatus'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _refreshRoute(force: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'فشل تحديث حالة الطلب'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  List<String> _allowedNextStatuses(String currentStatus) {
    if (!_hasLoadingData &&
        const <String>{
          'جاهز للتحميل',
          'في انتظار التحميل',
          'تم التحميل',
        }.contains(currentStatus.trim())) {
      return const <String>[];
    }

    switch (currentStatus.trim()) {
      case 'تم التحميل':
        return const <String>['في الطريق'];
      case 'في الطريق':
        return const <String>['تم التسليم'];
      default:
        return const <String>[];
    }
  }

  Future<void> _submitLoadingData() async {
    final order = _order;
    if (order == null) return;

    final formKey = GlobalKey<FormState>();
    final litersController = TextEditingController(
      text: order.actualLoadedLiters == null
          ? ''
          : _formatLiters(order.actualLoadedLiters),
    );
    final notesController = TextEditingController(
      text: order.driverLoadingNotes ?? '',
    );
    var selectedFuel = order.actualFuelType?.trim().isNotEmpty == true
        ? order.actualFuelType!.trim()
        : order.fuelType?.trim().isNotEmpty == true
        ? order.fuelType!.trim()
        : _fuelTypes.first;
    String? submitError;
    bool isSubmitting = false;

    final submitted =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                Future<void> handleSubmit() async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final liters = double.tryParse(
                    litersController.text.trim().replaceAll(',', '.'),
                  );
                  if (liters == null || liters <= 0) {
                    setDialogState(() {
                      submitError = 'أدخل كمية فعلية صحيحة باللتر';
                    });
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = true;
                    submitError = null;
                  });

                  final ok =
                      await context.read<OrderProvider>().submitDriverLoadingData(
                            order.id,
                            actualFuelType: selectedFuel,
                            actualLoadedLiters: liters,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );

                  if (!mounted) return;

                  if (ok) {
                    Navigator.of(dialogContext).pop(true);
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = false;
                    submitError =
                        context.read<OrderProvider>().error ??
                        'فشل إرسال بيانات التعبئة';
                  });
                }

                return AlertDialog(
                  title: const Text('إرسال بيانات التعبئة الفعلية'),
                  content: SizedBox(
                    width: 420,
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedFuel,
                            decoration: const InputDecoration(
                              labelText: 'نوع الوقود الفعلي',
                              border: OutlineInputBorder(),
                            ),
                            items: _fuelTypes
                                .map(
                                  (fuel) => DropdownMenuItem<String>(
                                    value: fuel,
                                    child: Text(fuel),
                                  ),
                                )
                                .toList(),
                            onChanged: isSubmitting
                                ? null
                                : (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return;
                                    }
                                    setDialogState(() {
                                      selectedFuel = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: litersController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'عدد اللترات الفعلية',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                value?.trim().replaceAll(',', '.') ?? '',
                              );
                              if (parsed == null || parsed <= 0) {
                                return 'أدخل كمية صحيحة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: notesController,
                            enabled: !isSubmitting,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات السائق',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (submitError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              submitError!,
                              style: const TextStyle(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton.icon(
                      onPressed: isSubmitting ? null : handleSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isSubmitting ? 'جارٍ الإرسال...' : 'إرسال البيانات',
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    litersController.dispose();
    notesController.dispose();

    if (!mounted || !submitted) return;

    await _loadOrder(forceRefresh: true);
    await _refreshRoute(force: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال بيانات التعبئة وتحويل الرحلة إلى العميل'),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return 'لم يتم الإرسال بعد';
    final local = value.toLocal();
    final twoDigits = (int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'غير متاح';
    final local = value.toLocal();
    final twoDigits = (int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _formatLiters(double? value) {
    if (value == null) return 'غير محدد';
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  LocationSettings get _trackingLocationSettings {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          intervalDuration: Duration(seconds: 10),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: 'التتبع المباشر للطلبات مفعل',
            notificationText:
                'يتم تحديث موقعك في الخلفية حتى يمكن متابعة الطلب مباشرة.',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        );
    }
  }

  LatLng get _mapCenter {
    if (_currentLocation != null) return _currentLocation!;
    if (_routePoints.isNotEmpty) return _routePoints.first;
    return const LatLng(24.7136, 46.6753);
  }

  Widget _buildMap() {
    final currentLocation = _currentLocation;
    final destinationLocation = _routePoints.isEmpty ? null : _routePoints.last;

    final markers = <Marker>{
      if (currentLocation != null)
        Marker(
          markerId: const MarkerId('driver-current'),
          position: currentLocation,
          infoWindow: const InfoWindow(title: 'موقعك الحالي'),
        ),
      if (destinationLocation != null)
        Marker(
          markerId: const MarkerId('driver-destination'),
          position: destinationLocation,
          infoWindow: InfoWindow(title: _destinationMarkerTitle),
        ),
    };

    final polylines = <Polyline>{
      if (_routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('delivery-route'),
          points: _routePoints,
          color: AppColors.primaryBlue,
          width: 5,
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            Positioned.fill(
              child: kIsWeb
                  ? AdvancedWebMap(
                      center: _mapCenter,
                      zoom: 13,
                      primaryMarker: destinationLocation ?? currentLocation,
                      secondaryMarker: destinationLocation != null
                          ? currentLocation
                          : null,
                      polyline: _routePoints.length >= 2 ? _routePoints : null,
                    )
                  : GoogleMap(
                      key: ValueKey(
                        '${_mapCenter.latitude}-${_mapCenter.longitude}-${_routePoints.length}-${_destinationText.hashCode}',
                      ),
                      initialCameraPosition: CameraPosition(
                        target: _mapCenter,
                        zoom: 13,
                      ),
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                    ),
            ),
            if (_isRouteLoading)
              const Positioned(
                top: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSummaryCard(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _stageTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.status,
                    style: const TextStyle(
                      color: AppColors.statusGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DeliveryInfoRow(
              label: _destinationLabel,
              value: _destinationText.isEmpty ? 'غير محددة' : _destinationText,
            ),
            _DeliveryInfoRow(
              label: 'المسافة المتبقية',
              value: _distanceKm == null
                  ? 'غير متاحة'
                  : '${_distanceKm!.toStringAsFixed(1)} كم',
            ),
            _DeliveryInfoRow(
              label: 'الوقت المتوقع',
              value: formatTrackingDuration(_durationMinutes),
            ),
            _DeliveryInfoRow(
              label: 'آخر إرسال',
              value: _formatTimestamp(_lastPublishedAt),
            ),
            _DeliveryInfoRow(
              label: 'حالة التتبع',
              value: _isSharing ? 'يعمل الآن' : 'متوقف',
            ),
            if (_routeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _routeError!,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFinalStatus
                        ? null
                        : (_isSharing ? _stopSharing : _startSharing),
                    icon: Icon(
                      _isSharing
                          ? Icons.pause_circle_outline
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      _isSharing ? 'إيقاف التتبع' : 'تشغيل التتبع',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRouteLoading
                        ? null
                        : () => _refreshRoute(force: true),
                    icon: const Icon(Icons.alt_route),
                    label: const Text('تحديث المسار'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الطلب ${order.orderNumber}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _DeliveryInfoRow(
              label: 'العميل',
              value: order.customer?.name.trim().isNotEmpty == true
                  ? order.customer!.name.trim()
                  : 'غير محدد',
            ),
            _DeliveryInfoRow(
              label: 'محطة التعبئة',
              value: _loadingStationName,
            ),
            _DeliveryInfoRow(
              label: 'الوقود المطلوب',
              value: order.fuelType?.trim().isNotEmpty == true
                  ? order.fuelType!.trim()
                  : 'غير محدد',
            ),
            _DeliveryInfoRow(
              label: 'الكمية المطلوبة',
              value: order.quantity == null
                  ? 'غير محددة'
                  : '${_formatLiters(order.quantity)} ${order.unit ?? 'لتر'}',
            ),
            if (order.notes?.trim().isNotEmpty == true)
              _DeliveryInfoRow(
                label: 'ملاحظات الطلب',
                value: order.notes!.trim(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(Order order) {
    final hasAnyLoadingData =
        _hasLoadingData ||
        order.driverLoadingSubmittedAt != null ||
        order.driverLoadingNotes?.trim().isNotEmpty == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات التعبئة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (hasAnyLoadingData) ...[
              _DeliveryInfoRow(
                label: 'الوقود الفعلي',
                value: order.actualFuelType?.trim().isNotEmpty == true
                    ? order.actualFuelType!.trim()
                    : 'غير محدد',
              ),
              _DeliveryInfoRow(
                label: 'اللترات الفعلية',
                value: order.actualLoadedLiters == null
                    ? 'غير محددة'
                    : '${_formatLiters(order.actualLoadedLiters)} لتر',
              ),
              _DeliveryInfoRow(
                label: 'وقت الإرسال',
                value: _formatDateTime(order.driverLoadingSubmittedAt),
              ),
              if (order.driverLoadingNotes?.trim().isNotEmpty == true)
                _DeliveryInfoRow(
                  label: 'ملاحظات السائق',
                  value: order.driverLoadingNotes!.trim(),
                ),
              if (_hasLoadingData) ...[
                const SizedBox(height: 8),
                Text(
                  'تم إرسال بيانات التعبئة. استكمل الرحلة إلى العميل.',
                  style: TextStyle(
                    color: AppColors.successGreen.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ] else ...[
              Text(
                _canSubmitLoadingData
                    ? 'بعد التعبئة من محطة أرامكو أدخل نوع الوقود الفعلي وعدد اللترات ثم أرسلها ليتم تحويل مسارك إلى العميل.'
                    : 'ستظهر هنا بيانات التعبئة بمجرد إرسالها من السائق.',
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_canSubmitLoadingData) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitLoadingData,
                  icon: const Icon(Icons.local_gas_station_rounded),
                  label: const Text('إرسال بيانات التعبئة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverActionsCard(List<String> nextStatuses) {
    if (nextStatuses.isEmpty) {
      if (_canSubmitLoadingData || _order == null) {
        return const SizedBox.shrink();
      }

      final message = _hasLoadingData
          ? 'لا توجد إجراءات إضافية حالياً لهذا الطلب.'
          : 'أدخل بيانات التعبئة أولاً قبل بدء التوصيل إلى العميل.';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إجراءات السائق',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: nextStatuses
                  .map(
                    (status) => ElevatedButton.icon(
                      onPressed: _isUpdatingStatus
                          ? null
                          : () => _updateStatus(status),
                      icon: _isUpdatingStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(status),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final nextStatuses = order == null
        ? const <String>[]
        : _allowedNextStatuses(order.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنفيذ الطلب والتتبع الحي'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _isPreparing ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : order == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? 'لا توجد بيانات للطلب',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMap(),
                  const SizedBox(height: 16),
                  _buildTrackingSummaryCard(order),
                  const SizedBox(height: 12),
                  _buildOrderDetailsCard(order),
                  const SizedBox(height: 12),
                  _buildLoadingCard(order),
                  const SizedBox(height: 12),
                  _buildDriverActionsCard(nextStatuses),
                ],
              ),
            ),
    );
  }
}

class _DeliveryInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeliveryInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
