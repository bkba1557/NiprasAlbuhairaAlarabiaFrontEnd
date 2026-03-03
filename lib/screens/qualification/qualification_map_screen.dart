import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:order_tracker/providers/qualification_provider.dart';
import 'package:order_tracker/models/qualification_models.dart';
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/constants.dart';

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
  QualificationStation? _pendingFocusStation;
  final Map<QualificationStatus, BitmapDescriptor> _statusMarkerIcons = {};
  BitmapDescriptor? _currentMarkerIcon;
  List<LatLng> _routePoints = [];
  bool _locating = false;
  bool _routeLoading = false;
  bool _showSelectedOnly = false;

  @override
  void initState() {
    super.initState();
    _prepareMarkerIcons();
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
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
      if (_activeStation != null) {
        await _refreshRouteForActive();
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<QualificationStation> _applyFilters(List<QualificationStation> stations) {
    final query = _searchController.text.trim().toLowerCase();
    return stations.where((station) {
      final matchesQuery = query.isEmpty ||
          station.name.toLowerCase().contains(query) ||
          station.city.toLowerCase().contains(query) ||
          station.region.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == null ? true : station.status == _statusFilter;
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

    final uri = Uri.parse(
      '${ApiEndpoints.baseUrl}${ApiEndpoints.mapsDirections}',
    ).replace(queryParameters: {
      'origin': '${_currentPosition!.latitude},${_currentPosition!.longitude}',
      'destination': '${location.lat},${location.lng}',
      'mode': 'driving',
      'language': 'ar',
      'alternatives': 'false',
    });

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
      final points =
          polyline.isNotEmpty ? _decodePolyline(polyline) : <LatLng>[];
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

    final swLat = math.min(
      _currentPosition!.latitude,
      station.location.lat,
    );
    final swLng = math.min(
      _currentPosition!.longitude,
      station.location.lng,
    );
    final neLat = math.max(
      _currentPosition!.latitude,
      station.location.lat,
    );
    final neLng = math.max(
      _currentPosition!.longitude,
      station.location.lng,
    );

    final bounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
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
                          border:
                              Border.all(color: _statusColor(station.status)),
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

  Widget _buildStationSelector(List<QualificationStation> stations) {
    if (stations.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...stations]
      ..sort((a, b) => a.name.compareTo(b.name));

    return DropdownButtonFormField<String>(
      value: _selectedStationId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'اختر محطة',
        prefixIcon: const Icon(Icons.place_outlined),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: sorted
          .map(
            (station) => DropdownMenuItem<String>(
              value: station.id,
              child: Text(
                station.name,
                overflow: TextOverflow.ellipsis,
              ),
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
              onSelected: (_) =>
                  setState(() => _statusFilter = QualificationStatus.underReview),
            ),
            FilterChip(
              label: const Text('جاري التفاوض'),
              selected: _statusFilter == QualificationStatus.negotiating,
              onSelected: (_) =>
                  setState(() => _statusFilter = QualificationStatus.negotiating),
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
      initialCenter = LatLng(
        first.location.lat,
        first.location.lng,
      );
    } else {
      initialCenter = const LatLng(24.7136, 46.6753);
    }

    final markers = <Marker>{};
    for (final station in stations) {
      final icon = _statusMarkerIcons[station.status] ??
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
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _currentMarkerIcon ??
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
      appBar: AppBar(
        title: const Text('خريطة محطات التأهيل'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildStationSelector(allStations),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadInspections,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilterBar(),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF6F8FF),
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (!hasStations && _currentPosition == null)
                      ? const Center(child: Text('لا توجد محطات للعرض'))
                      : Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: initialCenter,
                                zoom: 10,
                              ),
                              markers: markers,
                              polylines: polylines,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: true,
                              compassEnabled: true,
                              onMapCreated: (controller) {
                                _mapController = controller;
                                final pending = _pendingFocusStation;
                                if (pending != null) {
                                  _fitMapToSelection(pending);
                                  _pendingFocusStation = null;
                                }
                              },
                            ),
                            if (_routeLoading)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: const [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('جاري تحديث المسار'),
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
