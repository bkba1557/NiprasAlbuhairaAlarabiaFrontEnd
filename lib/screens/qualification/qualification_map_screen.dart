import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/utils/web_platform.dart' as web_platform;
import 'package:order_tracker/widgets/app_soft_background.dart';
import 'package:order_tracker/widgets/app_surface_card.dart';

class QualificationStationsMapScreen extends StatefulWidget {
  final QualificationStation? initialStation;

  const QualificationStationsMapScreen({super.key, this.initialStation});

  @override
  State<QualificationStationsMapScreen> createState() =>
      _QualificationStationsMapScreenState();
}

class _QualificationStationsMapScreenState
    extends State<QualificationStationsMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, _RouteInfo> _routeCache = {};
  final Set<String> _selectedIds = {};
  QualificationStatus? _statusFilter;
  String? _selectedStationId;
  Position? _currentPosition;
  QualificationStation? _activeStation;
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  QualificationStation? _pendingFocusStation;
  final Map<QualificationStatus, BitmapDescriptor> _statusMarkerIcons = {};
  BitmapDescriptor? _currentMarkerIcon;
  List<LatLng> _routePoints = [];
  bool _locating = false;
  bool _routeLoading = false;
  bool _showSelectedOnly = false;
  bool _webMapsReady = !kIsWeb;
  bool _checkingWebMaps = false;
  bool _isMapFullscreen = false;

  @override
  void initState() {
    super.initState();
    _prepareMarkerIcons();
    if (kIsWeb) {
      _checkWebMapsReady();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInspections();
      _ensureCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspections() async {
    await context.read<QualificationProvider>().fetchStations(limit: 0);
    if (!mounted) return;
    final initial = widget.initialStation;
    if (initial != null && initial.id.isNotEmpty) {
      final provider = context.read<QualificationProvider>();
      final match = provider.stations.firstWhere(
        (station) => station.id == initial.id,
        orElse: () => initial,
      );
      await _selectStation(match);
      if (_mapController == null) {
        _pendingFocusStation = match;
      }
    }
  }

  Future<void> _checkWebMapsReady() async {
    if (!kIsWeb || _checkingWebMaps) return;
    _checkingWebMaps = true;
    try {
      for (var attempt = 0; attempt < 24; attempt++) {
        final mapsLoaded = web_platform.isGoogleMapsReady();
        final loadState = web_platform.googleMapsLoadState();
        if (!mounted) return;
        if (mapsLoaded) {
          setState(() => _webMapsReady = true);
          return;
        }
        if (loadState == 'auth_failure' ||
            loadState == 'load_error' ||
            loadState == 'loaded_no_maps') {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (mounted) {
        setState(() => _webMapsReady = false);
      }
    } finally {
      _checkingWebMaps = false;
    }
  }

  String _statusLabel(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return 'تحت الدراسة';
      case QualificationStatus.negotiating:
        return 'جاري التفاوض';
      case QualificationStatus.agreed:
        return 'تم الاتفاق';
      case QualificationStatus.notAgreed:
        return 'لم يتم الاتفاق';
    }
  }

  Color _statusColor(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return Colors.amber.shade700;
      case QualificationStatus.negotiating:
        return Colors.blue.shade700;
      case QualificationStatus.agreed:
        return Colors.green;
      case QualificationStatus.notAgreed:
        return Colors.red;
    }
  }

  double _statusHue(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return BitmapDescriptor.hueYellow;
      case QualificationStatus.negotiating:
        return BitmapDescriptor.hueAzure;
      case QualificationStatus.agreed:
        return BitmapDescriptor.hueGreen;
      case QualificationStatus.notAgreed:
        return BitmapDescriptor.hueRed;
    }
  }

  Future<void> _prepareMarkerIcons() async {
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      final logoBytes = logoData.buffer.asUint8List();
      final statusIcons = <QualificationStatus, BitmapDescriptor>{
        QualificationStatus.underReview: BitmapDescriptor.fromBytes(
          await _buildStationMarkerBytes(
            _statusColor(QualificationStatus.underReview),
            logoBytes,
          ),
        ),
        QualificationStatus.negotiating: BitmapDescriptor.fromBytes(
          await _buildStationMarkerBytes(
            _statusColor(QualificationStatus.negotiating),
            logoBytes,
          ),
        ),
        QualificationStatus.agreed: BitmapDescriptor.fromBytes(
          await _buildStationMarkerBytes(
            _statusColor(QualificationStatus.agreed),
            logoBytes,
          ),
        ),
        QualificationStatus.notAgreed: BitmapDescriptor.fromBytes(
          await _buildStationMarkerBytes(
            _statusColor(QualificationStatus.notAgreed),
            logoBytes,
          ),
        ),
      };
      final currentBytes = await _buildCurrentMarkerBytes();
      if (!mounted) return;
      setState(() {
        _statusMarkerIcons
          ..clear()
          ..addAll(statusIcons);
        _currentMarkerIcon = BitmapDescriptor.fromBytes(currentBytes);
      });
    } catch (_) {
      // Fallback to default markers.
    }
  }

  Future<Uint8List> _buildStationMarkerBytes(
    Color color,
    Uint8List logoBytes, {
    int size = 120,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    final center = Offset(size * 0.5, size * 0.42);
    final radius = size * 0.22;

    canvas.drawCircle(center, radius, paint);
    final pinPath = Path()
      ..moveTo(center.dx - radius * 0.7, center.dy + radius * 0.3)
      ..lineTo(center.dx + radius * 0.7, center.dy + radius * 0.3)
      ..lineTo(center.dx, size * 0.96)
      ..close();
    canvas.drawPath(pinPath, paint);

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, innerPaint);

    final codec = await ui.instantiateImageCodec(
      logoBytes,
      targetWidth: (radius * 1.0).round(),
      targetHeight: (radius * 1.0).round(),
    );
    final frame = await codec.getNextFrame();
    final logo = frame.image;

    final logoSize = radius * 1.0;
    final logoOffset = Offset(
      center.dx - logoSize / 2,
      center.dy - logoSize / 2,
    );
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromLTWH(logoOffset.dx, logoOffset.dy, logoSize, logoSize),
      Paint(),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildCurrentMarkerBytes({int size = 110}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size * 0.5, size * 0.5);
    final outerPaint = Paint()..color = Colors.white;
    final innerPaint = Paint()..color = const Color(0xFF2563EB);
    canvas.drawCircle(center, size * 0.22, outerPaint);
    canvas.drawCircle(center, size * 0.18, innerPaint);
    canvas.drawCircle(center, size * 0.08, outerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _ensureCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
      if (_activeStation != null) {
        await _refreshRouteForActive();
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<QualificationStation> _applyFilters(
    List<QualificationStation> stations,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return stations.where((station) {
      final matchesQuery =
          query.isEmpty ||
          station.name.toLowerCase().contains(query) ||
          station.city.toLowerCase().contains(query) ||
          station.region.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == null
          ? true
          : station.status == _statusFilter;
      final matchesSelected =
          !_showSelectedOnly || _selectedIds.contains(station.id);
      return matchesQuery && matchesStatus && matchesSelected;
    }).toList();
  }

  Future<_RouteInfo?> _fetchRouteInfo(QualificationStation station) async {
    final location = station.location;
    if (_currentPosition == null) return null;
    final cached = _routeCache[station.id];
    if (cached != null) return cached;

    final directMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      location.lat,
      location.lng,
    );

    final uri =
        Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.mapsDirections}',
        ).replace(
          queryParameters: {
            'origin':
                '${_currentPosition!.latitude},${_currentPosition!.longitude}',
            'destination': '${location.lat},${location.lng}',
            'mode': 'driving',
            'language': 'ar',
            'alternatives': 'false',
          },
        );

    try {
      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        final fallbackInfo = _RouteInfo(
          distanceKm: null,
          durationMinutes: null,
          points: const [],
          directDistanceKm: directMeters / 1000,
        );
        _routeCache[station.id] = fallbackInfo;
        return fallbackInfo;
      }
      final data = json.decode(response.body);
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) {
        final fallbackInfo = _RouteInfo(
          distanceKm: null,
          durationMinutes: null,
          points: const [],
          directDistanceKm: directMeters / 1000,
        );
        _routeCache[station.id] = fallbackInfo;
        return fallbackInfo;
      }
      final first = routes.first;
      final distanceMeters = (first['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (first['duration'] as num?)?.toInt() ?? 0;
      final polyline = first['polyline']?.toString() ?? '';
      final points = polyline.isNotEmpty
          ? _decodePolyline(polyline)
          : <LatLng>[];
      final info = _RouteInfo(
        distanceKm: distanceMeters / 1000,
        durationMinutes: (durationSeconds / 60).round(),
        points: points,
        directDistanceKm: directMeters / 1000,
      );
      _routeCache[station.id] = info;
      return info;
    } catch (_) {
      final fallbackInfo = _RouteInfo(
        distanceKm: null,
        durationMinutes: null,
        points: const [],
        directDistanceKm: directMeters / 1000,
      );
      _routeCache[station.id] = fallbackInfo;
      return fallbackInfo;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _showSelectedOnly = false;
      }
    });
  }

  Future<void> _refreshRouteForActive() async {
    final station = _activeStation;
    if (station == null) return;
    final info = await _fetchRouteInfo(station);
    if (!mounted) return;
    setState(() {
      if (info != null && info.points.isNotEmpty) {
        _routePoints = info.points;
      } else if (_currentPosition != null) {
        _routePoints = [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(station.location.lat, station.location.lng),
        ];
      } else {
        _routePoints = [];
      }
    });
  }

  void _fitMapToSelection(QualificationStation station) {
    if (_mapController == null) return;
    if (_currentPosition == null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(station.location.lat, station.location.lng),
        ),
      );
      return;
    }

    final swLat = math.min(_currentPosition!.latitude, station.location.lat);
    final swLng = math.min(_currentPosition!.longitude, station.location.lng);
    final neLat = math.max(_currentPosition!.latitude, station.location.lat);
    final neLng = math.max(_currentPosition!.longitude, station.location.lng);

    final bounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  Widget _buildMapControls() {
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
        ],
      ),
    );
  }

  Future<void> _selectStation(QualificationStation station) async {
    setState(() {
      _activeStation = station;
      _selectedStationId = station.id;
      _routeLoading = true;
    });
    if (_currentPosition == null) {
      await _ensureCurrentLocation();
    }
    await _refreshRouteForActive();
    if (!mounted) return;
    setState(() {
      _routeLoading = false;
    });
    _fitMapToSelection(station);
  }

  Future<void> _showStationDetails(QualificationStation station) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: FutureBuilder<_RouteInfo?>(
            future: _fetchRouteInfo(station),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final routeDistanceText = (info?.distanceKm != null)
                  ? '${info!.distanceKm!.toStringAsFixed(2)} كم'
                  : 'غير متاح';
              final directDistanceText = (info?.directDistanceKm != null)
                  ? '${info!.directDistanceKm.toStringAsFixed(2)} كم'
                  : 'غير متاح';
              final durationText = (info?.durationMinutes != null)
                  ? '${info!.durationMinutes} دقيقة'
                  : 'غير متاح';

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          station.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(station.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusColor(station.status),
                          ),
                        ),
                        child: Text(
                          _statusLabel(station.status),
                          style: TextStyle(
                            color: _statusColor(station.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${station.city} • ${station.region}'),
                  if (station.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      station.address,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.route, size: 18),
                      const SizedBox(width: 6),
                      Text('المسافة بالطريق: $routeDistanceText'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.straighten, size: 18),
                      const SizedBox(width: 6),
                      Text('المسافة الخطية: $directDistanceText'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('الوقت: $durationText'),
                    ],
                  ),
                  if (_currentPosition == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'لم يتم الحصول على موقعك الحالي بعد',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showNavigationOptions(station);
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('ابدأ الملاحة'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _toggleSelected(station.id);
                        },
                        icon: Icon(
                          _selectedIds.contains(station.id)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                        ),
                        label: Text(
                          _selectedIds.contains(station.id)
                              ? 'إزالة من المحدد'
                              : 'تحديد المحطة',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.qualificationDetails,
                            arguments: station,
                          );
                        },
                        child: const Text('عرض التفاصيل'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showNavigationOptions(QualificationStation station) async {
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
                    _startExternalNavigation(station, languageCode: 'ar');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.navigation_rounded),
                  title: const Text('Navigation (English)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startExternalNavigation(station, languageCode: 'en');
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
    QualificationStation station, {
    required String languageCode,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${station.location.lat},${station.location.lng}&travelmode=driving&dir_action=navigate&hl=$languageCode',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح تطبيق الخرائط')),
      );
    }
  }

  Widget _buildStationSelector(List<QualificationStation> stations) {
    if (stations.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...stations]..sort((a, b) => a.name.compareTo(b.name));

    return DropdownButtonFormField<String>(
      value: _selectedStationId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'اختر محطة',
        prefixIcon: const Icon(Icons.place_outlined),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: sorted
          .map(
            (station) => DropdownMenuItem<String>(
              value: station.id,
              child: Text(station.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) async {
        if (value == null) return;
        final selected = sorted.firstWhere((s) => s.id == value);
        setState(() => _selectedStationId = value);
        await _selectStation(selected);
        if (!mounted) return;
        await _showStationDetails(selected);
      },
    );
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'ابحث عن محطة',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('الكل'),
              selected: _statusFilter == null,
              onSelected: (_) => setState(() => _statusFilter = null),
            ),
            FilterChip(
              label: const Text('تحت الدراسة'),
              selected: _statusFilter == QualificationStatus.underReview,
              onSelected: (_) => setState(
                () => _statusFilter = QualificationStatus.underReview,
              ),
            ),
            FilterChip(
              label: const Text('جاري التفاوض'),
              selected: _statusFilter == QualificationStatus.negotiating,
              onSelected: (_) => setState(
                () => _statusFilter = QualificationStatus.negotiating,
              ),
            ),
            FilterChip(
              label: const Text('تم الاتفاق'),
              selected: _statusFilter == QualificationStatus.agreed,
              onSelected: (_) =>
                  setState(() => _statusFilter = QualificationStatus.agreed),
            ),
            FilterChip(
              label: const Text('لم يتم الاتفاق'),
              selected: _statusFilter == QualificationStatus.notAgreed,
              onSelected: (_) =>
                  setState(() => _statusFilter = QualificationStatus.notAgreed),
            ),
            if (_selectedIds.isNotEmpty)
              FilterChip(
                label: Text('المحدد فقط (${_selectedIds.length})'),
                selected: _showSelectedOnly,
                onSelected: (_) {
                  setState(() => _showSelectedOnly = !_showSelectedOnly);
                },
              ),
            if (_selectedIds.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedIds.clear();
                    _showSelectedOnly = false;
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('مسح التحديد'),
              ),
            if (_locating)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _ensureCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('تحديد موقعي'),
              ),
          ],
        ),
      ],
    );
  }

  InputDecoration _surfaceInputDecoration({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.84),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
      ),
    );
  }

  IconData _statusIcon(QualificationStatus status) {
    switch (status) {
      case QualificationStatus.underReview:
        return Icons.hourglass_top_rounded;
      case QualificationStatus.negotiating:
        return Icons.handshake_outlined;
      case QualificationStatus.agreed:
        return Icons.verified_rounded;
      case QualificationStatus.notAgreed:
        return Icons.block_rounded;
    }
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.darkGray,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? color : AppColors.darkGray,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.78),
      selectedColor: color.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected ? color.withValues(alpha: 0.34) : AppColors.silverLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildModernStationSelector(List<QualificationStation> stations) {
    if (stations.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...stations]..sort((a, b) => a.name.compareTo(b.name));

    return DropdownButtonFormField<String>(
      value: _selectedStationId,
      isExpanded: true,
      decoration: _surfaceInputDecoration(
        hintText: 'اختر محطة للتركيز عليها',
        labelText: 'المحطة المختارة',
        prefixIcon: const Icon(Icons.place_outlined),
      ),
      items: sorted
          .map(
            (station) => DropdownMenuItem<String>(
              value: station.id,
              child: Text(station.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) async {
        if (value == null) return;
        final selected = sorted.firstWhere((s) => s.id == value);
        setState(() => _selectedStationId = value);
        await _selectStation(selected);
      },
    );
  }

  Widget _buildModernSearchField() {
    return TextField(
      controller: _searchController,
      decoration: _surfaceInputDecoration(
        hintText: 'ابحث عن محطة أو مدينة أو منطقة',
        labelText: 'البحث',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildModernControlsCard({
    required List<QualificationStation> allStations,
    required List<QualificationStation> filteredStations,
    required bool compact,
    bool draggable = false,
  }) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
        : const EdgeInsets.all(18);

    return AppSurfaceCard(
      padding: padding,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draggable) ...[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لوحة التحكم في الخريطة',
                      style: TextStyle(
                        color: AppColors.darkGray,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'فلترة المحطات، تتبع المسار، والتركيز السريع على أي موقع من شاشة واحدة.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة التحكم في الخريطة',
                            style: TextStyle(
                              color: AppColors.darkGray,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'فلترة المحطات، تتبع المسار، والتركيز السريع على أي موقع من شاشة واحدة.',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildSummaryChip(
                          icon: Icons.local_gas_station_rounded,
                          label: 'إجمالي المحطات',
                          value: '${allStations.length}',
                          color: AppColors.primaryBlue,
                        ),
                        _buildSummaryChip(
                          icon: Icons.filter_alt_outlined,
                          label: 'نتائج الفلترة',
                          value: '${filteredStations.length}',
                          color: AppColors.secondaryTeal,
                        ),
                        _buildSummaryChip(
                          icon: Icons.checklist_rounded,
                          label: 'المحدد',
                          value: '${_selectedIds.length}',
                          color: AppColors.warningOrange,
                        ),
                      ],
                    ),
                  ],
                ),
          if (compact) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSummaryChip(
                  icon: Icons.local_gas_station_rounded,
                  label: 'إجمالي المحطات',
                  value: '${allStations.length}',
                  color: AppColors.primaryBlue,
                ),
                _buildSummaryChip(
                  icon: Icons.filter_alt_outlined,
                  label: 'نتائج الفلترة',
                  value: '${filteredStations.length}',
                  color: AppColors.secondaryTeal,
                ),
                _buildSummaryChip(
                  icon: Icons.checklist_rounded,
                  label: 'المحدد',
                  value: '${_selectedIds.length}',
                  color: AppColors.warningOrange,
                ),
              ],
            ),
          ],
          SizedBox(height: compact ? 12 : 18),
          compact
              ? Column(
                  children: [
                    _buildModernStationSelector(allStations),
                    const SizedBox(height: 10),
                    _buildModernSearchField(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildModernStationSelector(allStations)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildModernSearchField()),
                  ],
                ),
          SizedBox(height: compact ? 12 : 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModernFilterChip(
                label: 'الكل',
                selected: _statusFilter == null,
                color: AppColors.primaryBlue,
                onTap: () => setState(() => _statusFilter = null),
              ),
              _buildModernFilterChip(
                label: 'تحت الدراسة',
                selected: _statusFilter == QualificationStatus.underReview,
                color: Colors.amber.shade700,
                onTap: () => setState(
                  () => _statusFilter = QualificationStatus.underReview,
                ),
              ),
              _buildModernFilterChip(
                label: 'جاري التفاوض',
                selected: _statusFilter == QualificationStatus.negotiating,
                color: Colors.blue.shade700,
                onTap: () => setState(
                  () => _statusFilter = QualificationStatus.negotiating,
                ),
              ),
              _buildModernFilterChip(
                label: 'تم الاتفاق',
                selected: _statusFilter == QualificationStatus.agreed,
                color: AppColors.successGreen,
                onTap: () =>
                    setState(() => _statusFilter = QualificationStatus.agreed),
              ),
              _buildModernFilterChip(
                label: 'لم يتم الاتفاق',
                selected: _statusFilter == QualificationStatus.notAgreed,
                color: AppColors.errorRed,
                onTap: () => setState(
                  () => _statusFilter = QualificationStatus.notAgreed,
                ),
              ),
              if (_selectedIds.isNotEmpty)
                _buildModernFilterChip(
                  label: 'المحدد فقط (${_selectedIds.length})',
                  selected: _showSelectedOnly,
                  color: AppColors.warningOrange,
                  onTap: () {
                    setState(() => _showSelectedOnly = !_showSelectedOnly);
                  },
                ),
              if (_locating)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: _ensureCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('تحديد موقعي'),
                ),
              if (_selectedIds.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedIds.clear();
                      _showSelectedOnly = false;
                    });
                  },
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('مسح التحديد'),
                ),
              OutlinedButton.icon(
                onPressed: _loadInspections,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث البيانات'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStationOverlay(QualificationStation station) {
    final cachedRoute = _routeCache[station.id];
    final statusColor = _statusColor(station.status);
    final routeDistance = cachedRoute?.distanceKm != null
        ? '${cachedRoute!.distanceKm!.toStringAsFixed(1)} كم'
        : 'غير متاح';
    final duration = cachedRoute?.durationMinutes != null
        ? '${cachedRoute!.durationMinutes} دقيقة'
        : 'غير متاح';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(
                      color: AppColors.darkGray,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(station.status), size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel(station.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${station.city} • ${station.region}',
              style: const TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (station.address.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                station.address,
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSummaryChip(
                  icon: Icons.route_outlined,
                  label: 'المسافة',
                  value: routeDistance,
                  color: AppColors.primaryBlue,
                ),
                _buildSummaryChip(
                  icon: Icons.timer_outlined,
                  label: 'المدة',
                  value: duration,
                  color: AppColors.secondaryTeal,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showStationDetails(station),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('عرض التفاصيل'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showNavigationOptions(station),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('ابدأ الملاحة'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _toggleSelected(station.id),
                  icon: Icon(
                    _selectedIds.contains(station.id)
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                  ),
                  label: Text(
                    _selectedIds.contains(station.id)
                        ? 'إزالة من المحدد'
                        : 'تحديد المحطة',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebMapsState() {
    final isWaiting = _checkingWebMaps && !_webMapsReady;
    final loadError = web_platform.googleMapsLoadError();
    return Container(
      color: const Color(0xFFF2F3F5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isWaiting) ...[
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text(
              'جارٍ تحميل Google Maps...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ] else ...[
            const Icon(Icons.map_outlined, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            const Text(
              'تعذّر تحميل Google Maps على الويب',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              loadError ??
                  'غالبًا السبب أن مكتبة الخرائط لم تكتمل بعد أو يوجد قيد على مفتاح Google Maps.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkWebMapsReady,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QualificationProvider>();
    final allStations = provider.stations;
    final stations = _applyFilters(allStations);
    final hasStations = stations.isNotEmpty;

    final LatLng initialCenter;
    if (_currentPosition != null) {
      initialCenter = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } else if (hasStations) {
      final first = stations.first;
      initialCenter = LatLng(first.location.lat, first.location.lng);
    } else {
      initialCenter = const LatLng(24.7136, 46.6753);
    }

    final markers = <Marker>{};
    for (final station in stations) {
      final icon =
          _statusMarkerIcons[station.status] ??
          BitmapDescriptor.defaultMarkerWithHue(_statusHue(station.status));
      markers.add(
        Marker(
          markerId: MarkerId('station_${station.id}'),
          position: LatLng(station.location.lat, station.location.lng),
          icon: icon,
          infoWindow: InfoWindow(title: station.name),
          onTap: () {
            _selectStation(station);
            _showStationDetails(station);
          },
        ),
      );
    }
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon:
              _currentMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'موقعي الحالي'),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (_routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: AppColors.primaryBlue,
          width: 4,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const ui.Color.fromARGB(255, 245, 242, 242),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        title: const Text('خريطة محطات التأهيل'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadInspections,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: _isMapFullscreen ? 'إظهار لوحة التحكم' : 'عرض الخريطة كاملة',
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
      body: Stack(
        children: [
          const AppSoftBackground(),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 940;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 12 : 18,
                    isCompact ? 12 : 18,
                    isCompact ? 12 : 18,
                    isCompact ? 12 : 18,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1480),
                      child: Builder(
                        builder: (context) {
                          final mapOuterRadius =
                              BorderRadius.circular(isCompact ? 26 : 30);
                          final mapInnerRadius =
                              BorderRadius.circular(isCompact ? 20 : 24);
                          final mapPadding = EdgeInsets.all(isCompact ? 6 : 10);

                          final mapCard = AppSurfaceCard(
                            padding: mapPadding,
                            borderRadius: mapOuterRadius,
                            child: ClipRRect(
                              borderRadius: mapInnerRadius,
                              child: provider.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : (!hasStations && _currentPosition == null)
                                      ? const Center(
                                          child: Text('لا توجد محطات للعرض'),
                                        )
                                      : Stack(
                                          children: [
                                            Positioned.fill(
                                              child: kIsWeb && !_webMapsReady
                                                  ? _buildWebMapsState()
                                                  : GoogleMap(
                                                      initialCameraPosition:
                                                          CameraPosition(
                                                        target: initialCenter,
                                                        zoom: 10,
                                                      ),
                                                      mapType: _mapType,
                                                      markers: markers,
                                                      polylines: polylines,
                                                      myLocationEnabled: true,
                                                      myLocationButtonEnabled:
                                                          false,
                                                      zoomControlsEnabled: false,
                                                      zoomGesturesEnabled: true,
                                                      scrollGesturesEnabled: true,
                                                      rotateGesturesEnabled: true,
                                                      tiltGesturesEnabled: true,
                                                      compassEnabled: true,
                                                      gestureRecognizers: <Factory<
                                                        OneSequenceGestureRecognizer
                                                      >>{
                                                        Factory<
                                                          OneSequenceGestureRecognizer
                                                        >(
                                                          () =>
                                                              EagerGestureRecognizer(),
                                                        ),
                                                      },
                                                      onMapCreated:
                                                          (controller) {
                                                        _mapController =
                                                            controller;
                                                        final pending =
                                                            _pendingFocusStation;
                                                        if (pending != null) {
                                                          _fitMapToSelection(
                                                            pending,
                                                          );
                                                          _pendingFocusStation =
                                                              null;
                                                        }
                                                      },
                                                    ),
                                            ),
                                            if (_activeStation != null)
                                              PositionedDirectional(
                                                top: 16,
                                                start: 16,
                                                child:
                                                    _buildActiveStationOverlay(
                                                  _activeStation!,
                                                ),
                                              ),
                                            if (_routeLoading)
                                              PositionedDirectional(
                                                top: 16,
                                                end: 16,
                                                child: AppSurfaceCard(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                    Radius.circular(18),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: const [
                                                      SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'جاري تحديث المسار',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            PositionedDirectional(
                                              top: _routeLoading ? 72 : 16,
                                              end: 16,
                                              child: _buildMapControls(),
                                            ),
                                          ],
                                        ),
                            ),
                          );

                          if (isCompact) {
                            return Stack(
                              children: [
                                Positioned.fill(child: mapCard),
                                if (!_isMapFullscreen)
                                  DraggableScrollableSheet(
                                    minChildSize: 0.18,
                                    initialChildSize: 0.36,
                                    maxChildSize: 0.92,
                                    builder: (context, scrollController) {
                                      return SafeArea(
                                        top: false,
                                        child: SingleChildScrollView(
                                          controller: scrollController,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                              bottom: 12,
                                            ),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: _buildModernControlsCard(
                                                allStations: allStations,
                                                filteredStations: stations,
                                                compact: true,
                                                draggable: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              if (!_isMapFullscreen) ...[
                                _buildModernControlsCard(
                                  allStations: allStations,
                                  filteredStations: stations,
                                  compact: false,
                                ),
                                const SizedBox(height: 16),
                              ],
                              Expanded(child: mapCard),
                            ],
                          );
                        },
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
}

class _RouteInfo {
  final double? distanceKm;
  final int? durationMinutes;
  final List<LatLng> points;
  final double directDistanceKm;

  const _RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
    required this.directDistanceKm,
  });
}
