import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:order_tracker/models/driver_tracking_models.dart';
import 'package:order_tracker/providers/driver_tracking_provider.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/tracking_directions_service.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';
import 'package:order_tracker/widgets/maps/advanced_web_map.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverLiveTrackingScreen extends StatefulWidget {
  final String driverId;

  const DriverLiveTrackingScreen({super.key, required this.driverId});

  @override
  State<DriverLiveTrackingScreen> createState() =>
      _DriverLiveTrackingScreenState();
}

class _DriverLiveTrackingScreenState extends State<DriverLiveTrackingScreen> {
  static const LatLng _fallbackCenter = LatLng(24.7136, 46.6753);
  static const Duration _trackingRefreshInterval = Duration(seconds: 6);

  Timer? _refreshTimer;
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = const <LatLng>[];
  LatLng? _ownerLocation;
  double? _distanceKm;
  int? _durationMinutes;
  String? _routeError;
  String? _ownerLocationError;
  bool _isRouteLoading = false;
  bool _isOwnerLocationLoading = false;
  BitmapDescriptor? _ownerMarkerIcon;
  BitmapDescriptor? _truckMarkerIcon;
  String? _lastBoundsSignature;
  bool _isFallbackRoute = false;
  bool _isMapFullscreen = false;
  bool _followDriver = true;
  bool _ignoreNextCameraMoveStarted = false;
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _prepareMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshTracking();
      _refreshTimer = Timer.periodic(
        _trackingRefreshInterval,
        (_) => _refreshTracking(silent: true),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    context.read<DriverTrackingProvider>().clearDetail();
    super.dispose();
  }

  Future<void> _prepareMarkerIcons() async {
    if (kIsWeb) return;

    try {
      final ownerBytes = await _buildOwnerMarkerBytes();
      final truckBytes = await _buildTruckMarkerBytes();
      if (!mounted) return;
      setState(() {
        _ownerMarkerIcon = BitmapDescriptor.fromBytes(ownerBytes);
        _truckMarkerIcon = BitmapDescriptor.fromBytes(truckBytes);
      });
    } catch (_) {}
  }

  Future<void> _refreshTracking({bool silent = false}) async {
    await _refreshOwnerLocation(silent: silent);

    final provider = context.read<DriverTrackingProvider>();
    final detail = await provider.fetchDriverDetail(
      widget.driverId,
      silent: silent,
    );
    if (detail == null) return;

    await _refreshRoute(detail);
  }

  Future<void> _refreshOwnerLocation({bool silent = false}) async {
    if (_isOwnerLocationLoading) return;

    if (!silent && mounted) {
      setState(() => _isOwnerLocationLoading = true);
    } else {
      _isOwnerLocationLoading = true;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _ownerLocation = null;
          _ownerLocationError = 'فعّل خدمة الموقع لعرض المسار بينك وبين السائق';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _ownerLocation = null;
          _ownerLocationError =
              'اسمح بالوصول إلى موقعك حتى يتم رسم المسار الحقيقي على الطريق';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _ownerLocation = null;
          _ownerLocationError =
              'صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات الجهاز';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      if (!mounted) return;

      setState(() {
        _ownerLocation = LatLng(position.latitude, position.longitude);
        _ownerLocationError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ownerLocation = null;
        _ownerLocationError =
            'تعذر تحديد موقعك الحالي الآن. أعد المحاولة من تحديث الموقع';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isOwnerLocationLoading = false);
    }
  }

  Future<void> _refreshRoute(DriverTrackingDetail detail) async {
    final ownerLocation = _ownerLocation;
    final lastLocation = detail.summary.lastLocation;

    if (ownerLocation == null || lastLocation == null) {
      if (!mounted) return;
      setState(() {
        _routePoints = const <LatLng>[];
        _distanceKm = null;
        _durationMinutes = null;
        _routeError = ownerLocation == null ? _ownerLocationError : null;
        _isFallbackRoute = false;
        _isRouteLoading = false;
      });
      return;
    }

    final driverLocation = LatLng(lastLocation.latitude, lastLocation.longitude);

    setState(() {
      _isRouteLoading = true;
      _routeError = null;
    });

    try {
      final routes = await fetchTrackingRoutes(
        origin: '${ownerLocation.latitude},${ownerLocation.longitude}',
        destination: '${driverLocation.latitude},${driverLocation.longitude}',
        alternatives: false,
      );

      if (!mounted) return;

      if (routes.isEmpty) {
        final fallback = _buildDirectRoute(ownerLocation, driverLocation);
        setState(() {
          _routePoints = fallback;
          _distanceKm = null;
          _durationMinutes = null;
          _routeError = 'لم يتم العثور على مسار طريق حقيقي. تم عرض خط مباشر.';
          _isFallbackRoute = true;
          _isRouteLoading = false;
        });
        if (fallback.length >= 2) {
          _scheduleFitToRoute(fallback);
        }
        return;
      }

      final route = routes.first;
      final sanitized = _sanitizeRoutePoints(route.points);
      final useFallback = sanitized.length < 2;
      final fallback = _buildDirectRoute(ownerLocation, driverLocation);
      setState(() {
        _routePoints = useFallback ? fallback : sanitized;
        _distanceKm = route.distanceKm;
        _durationMinutes = route.durationMinutes;
        _routeError =
            useFallback
                ? 'تعذر رسم المسار التفصيلي. تم عرض خط مباشر.'
                : null;
        _isFallbackRoute = useFallback;
        _isRouteLoading = false;
      });
      if (useFallback) {
        if (fallback.length >= 2) {
          _scheduleFitToRoute(fallback);
        }
      } else {
        _scheduleFitToRoute(sanitized);
      }
    } catch (_) {
      if (!mounted) return;
      final fallback = _buildDirectRoute(ownerLocation, driverLocation);
      setState(() {
        _routePoints = fallback;
        _distanceKm = null;
        _durationMinutes = null;
        _routeError = 'تعذر جلب المسار من الخريطة الآن. تم عرض خط مباشر.';
        _isFallbackRoute = true;
        _isRouteLoading = false;
      });
      if (fallback.length >= 2) {
        _scheduleFitToRoute(fallback);
      }
    }
  }




  List<LatLng> _sanitizeRoutePoints(List<LatLng> points) {
    return points.where((point) {
      final lat = point.latitude;
      final lng = point.longitude;
      if (!lat.isFinite || !lng.isFinite) return false;
      if (lat.abs() > 90 || lng.abs() > 180) return false;
      return true;
    }).toList();
  }

  List<LatLng> _buildDirectRoute(LatLng start, LatLng end) {
    if (_isSameLocation(start, end)) {
      return [start];
    }
    return [start, end];
  }

  bool _isSameLocation(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }

  void _scheduleFitToRoute(List<LatLng> points) {
    if (kIsWeb || points.isEmpty || !_followDriver) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToPoints(points);
    });
  }

  Future<void> _fitMapToPoints(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    final signature = _polylineSignature(points);
    if (_lastBoundsSignature == signature) return;

    if (points.length == 1) {
      await _animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15),
        ),
      );
      _lastBoundsSignature = signature;
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if ((maxLat - minLat).abs() < 0.0008) {
      minLat -= 0.0004;
      maxLat += 0.0004;
    }
    if ((maxLng - minLng).abs() < 0.0008) {
      minLng -= 0.0004;
      maxLng += 0.0004;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await _animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
      _lastBoundsSignature = signature;
    } catch (_) {
      await _animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _midpoint(points), zoom: 13),
        ),
      );
      _lastBoundsSignature = signature;
    }
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;
    _ignoreNextCameraMoveStarted = true;
    try {
      await controller.animateCamera(update);
    } finally {
      _ignoreNextCameraMoveStarted = false;
    }
  }

  void _zoomIn() {
    _animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _resumeFollowDriver(DriverTrackingDetail detail) async {
    if (!mounted) return;
    setState(() {
      _followDriver = true;
      _lastBoundsSignature = null;
    });

    if (_routePoints.length >= 2) {
      await _fitMapToPoints(_routePoints);
      return;
    }

    final lastLocation = detail.summary.lastLocation;
    if (lastLocation == null) return;

    await _animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lastLocation.latitude, lastLocation.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  Future<void> _centerOnOwner() async {
    final ownerLocation = _ownerLocation;
    if (ownerLocation == null) return;

    if (!mounted) return;
    setState(() => _followDriver = false);

    await _animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: ownerLocation, zoom: 15),
      ),
    );
  }

  Future<void> _centerOnDriver(DriverTrackingDetail detail) async {
    final lastLocation = detail.summary.lastLocation;
    if (lastLocation == null) return;

    if (!mounted) return;
    setState(() => _followDriver = false);

    await _animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lastLocation.latitude, lastLocation.longitude),
          zoom: 16,
        ),
      ),
    );
  }

  Widget _buildMapControls(DriverTrackingDetail detail) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(6),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<MapType>(
            tooltip: 'نوع الخريطة',
            onSelected: (value) => setState(() => _mapType = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: MapType.normal, child: Text('عادية')),
              PopupMenuItem(value: MapType.satellite, child: Text('قمر صناعي')),
              PopupMenuItem(value: MapType.hybrid, child: Text('هجينة')),
              PopupMenuItem(value: MapType.terrain, child: Text('تضاريس')),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.layers_rounded),
            ),
          ),
          const Divider(height: 1),
          IconButton(
            tooltip: 'تكبير',
            onPressed: _zoomIn,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'تصغير',
            onPressed: _zoomOut,
            icon: const Icon(Icons.remove),
          ),
          const Divider(height: 1),
          IconButton(
            tooltip: 'موقع السائق',
            onPressed: () => _centerOnDriver(detail),
            icon: const Icon(Icons.local_shipping_rounded),
          ),
          IconButton(
            tooltip: _followDriver ? 'متابعة السائق' : 'العودة لموقع السائق',
            onPressed: () => _resumeFollowDriver(detail),
            icon: Icon(
              _followDriver
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNavigationOptions(DriverTrackingDetail detail) async {
    if (detail.summary.lastLocation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد موقع حديث للسائق')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختيار لغة الإرشادات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.navigation_rounded),
                  title: const Text('ملاحة بالعربية'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startExternalNavigation(detail, languageCode: 'ar');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.navigation_rounded),
                  title: const Text('Navigation (English)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startExternalNavigation(detail, languageCode: 'en');
                  },
                ),
                Text(
                  'ملاحظة: صوت الإرشادات يعتمد على إعدادات تطبيق الخرائط في جهازك.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startExternalNavigation(
    DriverTrackingDetail detail, {
    required String languageCode,
  }) async {
    final lastLocation = detail.summary.lastLocation;
    if (lastLocation == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${lastLocation.latitude},${lastLocation.longitude}&travelmode=driving&dir_action=navigate&hl=$languageCode',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح تطبيق الخرائط')),
      );
    }
  }

  String _polylineSignature(List<LatLng> points) {
    final first = points.first;
    final last = points.last;
    return '${points.length}-'
        '${first.latitude.toStringAsFixed(5)}-'
        '${first.longitude.toStringAsFixed(5)}-'
        '${last.latitude.toStringAsFixed(5)}-'
        '${last.longitude.toStringAsFixed(5)}';
  }

  Color _statusColor(DriverTrackingSummary summary) {
    if (summary.hasActiveOrder) return AppColors.statusGold;
    final status = summary.driver.status.trim();
    if (status == 'في إجازة') return AppColors.pendingYellow;
    if (status == 'مرفود' || status == 'غير نشط') return AppColors.errorRed;
    return AppColors.successGreen;
  }

  String _statusLabel(DriverTrackingSummary summary) {
    if (summary.hasActiveOrder) return 'معه طلب';
    final status = summary.driver.status.trim();
    if (status == 'في إجازة') return 'إجازة';
    if (status == 'مرفود') return 'مرفود';
    if (status == 'غير نشط') return 'غير نشط';
    return status.isEmpty ? 'فاضي' : status;
  }

  String _vehicleTrackingLabel(DriverTrackingSummary summary) {
    if (summary.hasActiveOrder) return 'في طلب';
    final vehicleStatus = summary.driver.vehicleStatus.trim();
    if (vehicleStatus == 'تحت الصيانة') return 'تحت الصيانة';
    return 'فاضي';
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return 'غير متاح';
    final local = value.toLocal();
    final twoDigits = (int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _formatCoordinates(DriverLocationSnapshot? snapshot) {
    if (snapshot == null) return 'غير متاح';
    return '${snapshot.latitude.toStringAsFixed(5)}, ${snapshot.longitude.toStringAsFixed(5)}';
  }

  String _formatLatLng(LatLng? point) {
    if (point == null) return 'غير متاح';
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  String _routeStatusLabel() {
    if (_isRouteLoading || _isOwnerLocationLoading) return 'جارٍ التحديث';
    if (_ownerLocation == null) return 'بانتظار موقعك';
    if (_isFallbackRoute) return 'خط مباشر';
    if (_routePoints.length >= 2) return 'على الطريق';
    return 'بدون مسار';
  }

  LatLng _resolveCenter(DriverTrackingDetail detail) {
    if (_routePoints.isNotEmpty) {
      return _midpoint(_routePoints);
    }

    final ownerLocation = _ownerLocation;
    final lastLocation = detail.summary.lastLocation;
    if (ownerLocation != null && lastLocation != null) {
      return _midpoint([
        ownerLocation,
        LatLng(lastLocation.latitude, lastLocation.longitude),
      ]);
    }

    if (lastLocation != null) {
      return LatLng(lastLocation.latitude, lastLocation.longitude);
    }

    return ownerLocation ?? _fallbackCenter;
  }

  LatLng _midpoint(List<LatLng> points) {
    if (points.isEmpty) return _fallbackCenter;
    double lat = 0;
    double lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  Widget _buildMap(DriverTrackingDetail detail) {
    final summary = detail.summary;
    final currentLocation = summary.lastLocation == null
        ? null
        : LatLng(
            summary.lastLocation!.latitude,
            summary.lastLocation!.longitude,
          );
    final center = _resolveCenter(detail);
    final polylinePoints = _routePoints;
    final routeAvailable = polylinePoints.length >= 2;

    final markers = <Marker>{
      if (_ownerLocation != null)
        Marker(
          markerId: const MarkerId('owner-current'),
          position: _ownerLocation!,
          icon:
              _ownerMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'موقعك الحالي'),
        ),
      if (currentLocation != null)
        Marker(
          markerId: const MarkerId('driver-current'),
          position: currentLocation,
          icon:
              _truckMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: summary.driver.name),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: summary.lastLocation?.heading ?? 0,
        ),
    };

    final polylines = <Polyline>{
      if (routeAvailable)
        Polyline(
          polylineId: const PolylineId('driver-route-outline'),
          points: polylinePoints,
          width: 10,
          color: const Color(0xFF1B33B7),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      if (routeAvailable)
        Polyline(
          polylineId: const PolylineId('driver-route-main'),
          points: polylinePoints,
          width: 6,
          color: const Color(0xFF5B7CFF),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };

    final webPrimaryMarker = _ownerLocation ?? currentLocation;
    final webSecondaryMarker =
        _ownerLocation != null && currentLocation != null ? currentLocation : null;
    final webPrimaryIcon = _ownerLocation != null
        ? _ownerMarkerDataUrl
        : _truckMarkerDataUrl;
    final webSecondaryIcon =
        _ownerLocation != null && currentLocation != null ? _truckMarkerDataUrl : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: kIsWeb
                ? AdvancedWebMap(
                    center: center,
                    zoom: 13,
                    primaryMarker: webPrimaryMarker,
                    secondaryMarker: webSecondaryMarker,
                    primaryMarkerIcon: webPrimaryIcon,
                    secondaryMarkerIcon: webSecondaryIcon,
                    polylineOutline: routeAvailable ? polylinePoints : null,
                    polyline: routeAvailable ? polylinePoints : null,
                    useMapId: false,
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: 13,
                    ),
                    mapType: _mapType,
                    markers: markers,
                    polylines: polylines,
                    zoomControlsEnabled: false,
                    myLocationEnabled: _ownerLocation != null,
                    myLocationButtonEnabled: false,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    onCameraMoveStarted: () {
                      if (_ignoreNextCameraMoveStarted) return;
                      if (!_followDriver) return;
                      setState(() => _followDriver = false);
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (routeAvailable) {
                        _scheduleFitToRoute(polylinePoints);
                      }
                    },
                  ),
          ),
          PositionedDirectional(
            top: 12,
            start: 12,
            child: Card(
              child: InkWell(
                onTap: _centerOnOwner,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ownerLocation == null ? 'حدد موقعك' : 'موقع المالك',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      if (_isOwnerLocationLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        InkWell(
                          onTap: () => _refreshTracking(),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 12,
            end: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControls(detail),
                if (_isRouteLoading) ...[
                  const SizedBox(height: 10),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TrackingInfoRow> _buildRouteRows() {
    final rows = <_TrackingInfoRow>[
      _TrackingInfoRow(
        label: 'موقعك الحالي',
        value: _ownerLocation == null
            ? (_ownerLocationError ?? 'بانتظار تحديد موقعك')
            : _formatLatLng(_ownerLocation),
      ),
      _TrackingInfoRow(
        label: 'المسافة عبر الطريق',
        value: _distanceKm == null
            ? 'غير متاحة'
            : '${_distanceKm!.toStringAsFixed(1)} كم',
      ),
      _TrackingInfoRow(
        label: 'الوقت المتوقع',
        value: formatTrackingDuration(_durationMinutes),
      ),
    ];

    if (_routeError != null && _routeError!.trim().isNotEmpty) {
      rows.add(
        _TrackingInfoRow(
          label: 'ملاحظة المسار',
          value: _routeError!,
        ),
      );
    }

    return rows;
  }

  List<_TrackingInfoRow> _buildOrderRows(TrackedOrderSummary order) {
    final rows = <_TrackingInfoRow>[
      _TrackingInfoRow(label: 'رقم الطلب', value: order.orderNumber),
      _TrackingInfoRow(
        label: 'الوجهة',
        value: order.destinationText.isEmpty ? 'غير محددة' : order.destinationText,
      ),
    ];

    if ((order.orderSource ?? '').trim().isNotEmpty) {
      rows.add(
        _TrackingInfoRow(label: 'مصدر الطلب', value: order.orderSource!.trim()),
      );
    }
    if ((order.supplierName ?? '').trim().isNotEmpty) {
      rows.add(
        _TrackingInfoRow(label: 'المورد', value: order.supplierName!.trim()),
      );
    }
    if ((order.customerName ?? '').trim().isNotEmpty) {
      rows.add(
        _TrackingInfoRow(label: 'العميل', value: order.customerName!.trim()),
      );
    }

    return rows;
  }

  Future<Uint8List> _buildOwnerMarkerBytes({int size = 140}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size * 0.5, size * 0.5);

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: size * 0.22)),
      Colors.black.withValues(alpha: 0.30),
      10,
      true,
    );

    canvas.drawCircle(
      center,
      size * 0.22,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      size * 0.16,
      Paint()..color = const Color(0xFF1A73E8),
    );
    canvas.drawCircle(
      center,
      size * 0.07,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildTruckMarkerBytes({int size = 156}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size * 0.5, size * 0.5);

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: size * 0.26)),
      Colors.black.withValues(alpha: 0.32),
      12,
      true,
    );

    canvas.drawCircle(
      center,
      size * 0.26,
      Paint()..color = AppColors.primaryBlue,
    );

    final truckPaint = Paint()..color = Colors.white;
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.24, size * 0.39, size * 0.28, size * 0.14),
      Radius.circular(size * 0.03),
    );
    final cabRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.51, size * 0.41, size * 0.12, size * 0.12),
      Radius.circular(size * 0.025),
    );
    final baseRect = Rect.fromLTWH(size * 0.29, size * 0.50, size * 0.35, size * 0.05);

    canvas.drawRRect(tankRect, truckPaint);
    canvas.drawRRect(cabRect, truckPaint);
    canvas.drawRect(baseRect, truckPaint);

    canvas.drawCircle(
      Offset(size * 0.36, size * 0.58),
      size * 0.045,
      truckPaint,
    );
    canvas.drawCircle(
      Offset(size * 0.58, size * 0.58),
      size * 0.045,
      truckPaint,
    );
    canvas.drawCircle(
      Offset(size * 0.36, size * 0.58),
      size * 0.022,
      Paint()..color = AppColors.primaryBlue,
    );
    canvas.drawCircle(
      Offset(size * 0.58, size * 0.58),
      size * 0.022,
      Paint()..color = AppColors.primaryBlue,
    );

    final droplet = Path()
      ..moveTo(size * 0.44, size * 0.31)
      ..cubicTo(
        size * 0.40,
        size * 0.37,
        size * 0.39,
        size * 0.42,
        size * 0.44,
        size * 0.46,
      )
      ..cubicTo(
        size * 0.49,
        size * 0.42,
        size * 0.48,
        size * 0.37,
        size * 0.44,
        size * 0.31,
      )
      ..close();
    canvas.drawPath(
      droplet,
      Paint()..color = AppColors.statusGold,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  String get _ownerMarkerDataUrl => Uri.dataFromString(
    '''
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="18" fill="white"/>
  <circle cx="32" cy="32" r="13" fill="#1A73E8"/>
  <circle cx="32" cy="32" r="5.5" fill="white"/>
</svg>
''',
    mimeType: 'image/svg+xml',
  ).toString();

  String get _truckMarkerDataUrl => Uri.dataFromString(
    '''
<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 72 72">
  <circle cx="36" cy="36" r="26" fill="#1A2980"/>
  <path d="M25 28h18a3 3 0 0 1 3 3v9H23v-9a3 3 0 0 1 2-3Z" fill="white"/>
  <path d="M46 31h8l4 5v4H46v-9Z" fill="white"/>
  <rect x="27" y="40" width="29" height="4" rx="2" fill="white"/>
  <circle cx="32" cy="46" r="5" fill="white"/>
  <circle cx="52" cy="46" r="5" fill="white"/>
  <circle cx="32" cy="46" r="2.4" fill="#1A2980"/>
  <circle cx="52" cy="46" r="2.4" fill="#1A2980"/>
  <path d="M36 18c-3 4-4 7-4 9a4 4 0 1 0 8 0c0-2-1-5-4-9Z" fill="#D4AF37"/>
</svg>
''',
    mimeType: 'image/svg+xml',
  ).toString();

  @override
  Widget build(BuildContext context) {
    return Consumer<DriverTrackingProvider>(
      builder: (context, provider, _) {
        final detail = provider.selectedDetail;

        return Scaffold(
          appBar: AppBar(
            title: const Text('التتبع الحي للسائق'),
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: provider.isLoading
                    ? null
                    : () => _refreshTracking(),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: _isMapFullscreen ? 'إظهار البيانات' : 'عرض الخريطة كاملة',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _isMapFullscreen = !_isMapFullscreen);
                },
                icon: Icon(
                  _isMapFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
              ),
            ],
          ),
          body: provider.isLoading && detail == null
              ? const Center(child: CircularProgressIndicator())
              : detail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      provider.error ?? 'لا توجد بيانات تتبع لهذا السائق',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildMap(detail),
                      ),
                    ),
                    if (!_isMapFullscreen)
                      DraggableScrollableSheet(
                        minChildSize: 0.24,
                        initialChildSize: 0.52,
                        maxChildSize: 0.92,
                        builder: (context, scrollController) {
                          return SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(26),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: RefreshIndicator(
                                    onRefresh: () => _refreshTracking(),
                                    child: ListView(
                                      controller: scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        16,
                                      ),
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 44,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () =>
                                                _showNavigationOptions(detail),
                                            icon: const Icon(
                                              Icons.navigation_rounded,
                                            ),
                                            label: const Text('ابدأ الملاحة'),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _DriverTrackingInfoCard(
                                          title: detail.summary.driver.name,
                                          color: _statusColor(detail.summary),
                                          statusLabel: _statusLabel(
                                            detail.summary,
                                          ),
                                          rows: [
                                            _TrackingInfoRow(
                                              label: 'الجوال',
                                              value: detail.summary.driver.phone,
                                            ),
                                            _TrackingInfoRow(
                                              label: 'المركبة',
                                              value:
                                                  detail.summary.driver
                                                      .vehicleNumber ??
                                                  'غير محدد',
                                            ),
                                            _TrackingInfoRow(
                                              label: 'نوع المركبة',
                                              value: detail
                                                  .summary.driver.vehicleType,
                                            ),
                                            _TrackingInfoRow(
                                              label: 'حالة السيارة',
                                              value: _vehicleTrackingLabel(
                                                detail.summary,
                                              ),
                                            ),
                                            _TrackingInfoRow(
                                              label: 'آخر تحديث',
                                              value: _formatTimestamp(
                                                detail.summary.lastLocation
                                                    ?.timestamp,
                                              ),
                                            ),
                                            _TrackingInfoRow(
                                              label: 'إحداثيات السائق',
                                              value: _formatCoordinates(
                                                detail.summary.lastLocation,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _DriverTrackingInfoCard(
                                          title: 'المسار بينك وبين السائق',
                                          color: AppColors.primaryBlue,
                                          statusLabel: _routeStatusLabel(),
                                          rows: _buildRouteRows(),
                                        ),
                                        if (detail.summary.activeOrder != null)
                                          ...[
                                            const SizedBox(height: 12),
                                            _DriverTrackingInfoCard(
                                              title: 'الطلب الحالي',
                                              color: AppColors.statusGold,
                                              statusLabel: detail
                                                  .summary.activeOrder!.status,
                                              rows: _buildOrderRows(
                                                detail.summary.activeOrder!,
                                              ),
                                            ),
                                          ],
                                        const SizedBox(height: 12),
                                        Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'آخر نقاط الحركة',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                                const SizedBox(height: 12),
                                                if (detail.history.isEmpty)
                                                  const Text(
                                                    'لا يوجد مسار محفوظ حتى الآن',
                                                  )
                                                else
                                                  ...detail.history.reversed
                                                      .take(6)
                                                      .map(
                                                        (point) => Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                            bottom: 10,
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .local_shipping_outlined,
                                                                color: AppColors
                                                                    .primaryBlue,
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  '${point.latitude.toStringAsFixed(5)}, '
                                                                  '${point.longitude.toStringAsFixed(5)}',
                                                                ),
                                                              ),
                                                              Text(
                                                                _formatTimestamp(
                                                                  point.timestamp,
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                  color: AppColors
                                                                      .mediumGray,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _DriverTrackingInfoCard extends StatelessWidget {
  final String title;
  final String statusLabel;
  final Color color;
  final List<_TrackingInfoRow> rows;

  const _DriverTrackingInfoCard({
    required this.title,
    required this.statusLabel,
    required this.color,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
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
                    title,
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingInfoRow {
  final String label;
  final String value;

  const _TrackingInfoRow({required this.label, required this.value});
}
