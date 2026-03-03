import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:order_tracker/utils/api_service.dart';
import 'package:order_tracker/utils/constants.dart';
import 'package:order_tracker/widgets/maps/advanced_web_map.dart';

class TaskRouteScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;

  const TaskRouteScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  State<TaskRouteScreen> createState() => _TaskRouteScreenState();
}

class _TaskRouteScreenState extends State<TaskRouteScreen> {
  LatLng? _current;
  bool _loading = true;
  double? _distanceKm;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _currentIcon;
  String? _webDestinationIcon;
  String? _webCurrentIcon;
  List<LatLng> _routePoints = [];
  List<_RouteOption> _routes = [];
  int _selectedRouteIndex = 0;
  bool _routeLoading = false;
  String? _routeError;
  StreamSubscription<Position>? _positionSubscription;
  bool _isNavigating = false;
  DateTime? _lastRouteFetchAt;

  @override
  void initState() {
    super.initState();
    _prepareMarkerIcons();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _loading = false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _current = LatLng(pos.latitude, pos.longitude);
      _loading = false;
    });
    await _fetchRoute();
  }

  Future<void> _prepareMarkerIcons() async {
    final destinationBytes = await _buildDestinationMarkerBytes();
    final currentBytes = await _buildCurrentMarkerBytes();

    if (!mounted) return;
    setState(() {
      _destinationIcon = BitmapDescriptor.fromBytes(destinationBytes);
      _currentIcon = BitmapDescriptor.fromBytes(currentBytes);
      _webDestinationIcon =
          'data:image/png;base64,${base64Encode(destinationBytes)}';
      _webCurrentIcon = 'data:image/png;base64,${base64Encode(currentBytes)}';
    });
  }

  Future<Uint8List> _buildDestinationMarkerBytes({int size = 120}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFFE11D48);
    final center = Offset(size * 0.5, size * 0.42);
    final radius = size * 0.22;

    canvas.drawCircle(center, radius, paint);
    final pinPath = Path()
      ..moveTo(center.dx - radius * 0.6, center.dy + radius * 0.2)
      ..lineTo(center.dx + radius * 0.6, center.dy + radius * 0.2)
      ..lineTo(center.dx, size * 0.95)
      ..close();
    canvas.drawPath(pinPath, paint);

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.45, innerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildCurrentMarkerBytes({int size = 120}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size * 0.5, size * 0.5);

    final bgPaint = Paint()..color = const Color(0xFF0EA5E9);
    canvas.drawCircle(center, size * 0.26, bgPaint);

    final carPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_car.codePoint),
        style: TextStyle(
          fontSize: size * 0.34,
          fontFamily: Icons.directions_car.fontFamily,
          package: Icons.directions_car.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();
    carPainter.paint(
      canvas,
      Offset(
        center.dx - carPainter.width / 2,
        center.dy - carPainter.height / 2,
      ),
    );

    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final codec = await ui.instantiateImageCodec(
      logoBytes.buffer.asUint8List(),
      targetWidth: (size * 0.22).round(),
      targetHeight: (size * 0.22).round(),
    );
    final frame = await codec.getNextFrame();
    final logo = frame.image;

    final logoCenter = Offset(size * 0.72, size * 0.28);
    final logoRadius = size * 0.12;
    final logoBg = Paint()..color = Colors.white;
    canvas.drawCircle(logoCenter, logoRadius, logoBg);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: logoCenter, radius: logoRadius)));
    final logoOffset = Offset(
      logoCenter.dx - logoRadius,
      logoCenter.dy - logoRadius,
    );
    canvas.drawImage(
      logo,
      logoOffset,
      Paint(),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _refreshRoute() async {
    await _fetchRoute();
  }

  Future<void> _startNavigation() async {
    if (_isNavigating) {
      await _stopNavigation();
      return;
    }

    if (_current == null) {
      await _loadCurrentLocation();
      if (_current == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى السماح بالوصول للموقع أولاً')),
        );
        return;
      }
    }

    await _fetchRoute();

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _current = LatLng(pos.latitude, pos.longitude);
      });
      _maybeRefreshRoute();
    });

    if (mounted) {
      setState(() {
        _isNavigating = true;
      });
    }
  }

  Future<void> _stopNavigation() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _isNavigating = false;
      });
    }
  }

  void _maybeRefreshRoute() {
    final now = DateTime.now();
    if (_lastRouteFetchAt != null &&
        now.difference(_lastRouteFetchAt!).inSeconds < 12) {
      return;
    }
    _lastRouteFetchAt = now;
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_current == null) return;
    if (_routeLoading) return;
    setState(() {
      _routeLoading = true;
      _routeError = null;
    });
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.mapsDirections}')
          .replace(queryParameters: {
        'origin': '${_current!.latitude},${_current!.longitude}',
        'destination': '${widget.latitude},${widget.longitude}',
        'mode': 'driving',
        'language': 'ar',
        'alternatives': 'true',
      });
      final response = await http.get(uri, headers: ApiService.headers);
      if (response.statusCode != 200) {
        throw Exception('Failed to load directions');
      }
      final data = json.decode(response.body);
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) {
        throw Exception('No routes found');
      }
      final parsedRoutes = <_RouteOption>[];
      for (final item in routes) {
        if (item is! Map<String, dynamic>) continue;
        final pointsEncoded = item['polyline']?.toString();
        if (pointsEncoded == null || pointsEncoded.isEmpty) continue;
        final points = _decodePolyline(pointsEncoded);
        final distanceMeters = (item['distance'] as num?)?.toDouble() ?? 0;
        final durationSeconds = (item['duration'] as num?)?.toInt() ?? 0;
        parsedRoutes.add(
          _RouteOption(
            summary: item['summary']?.toString() ?? 'مسار',
            points: points,
            distanceKm: distanceMeters / 1000,
            durationMinutes: (durationSeconds / 60).round(),
          ),
        );
      }
      if (parsedRoutes.isEmpty) {
        throw Exception('Polyline missing');
      }
      final selected = parsedRoutes.first;
      if (!mounted) return;
      setState(() {
        _routes = parsedRoutes;
        _selectedRouteIndex = 0;
        _routePoints = selected.points;
        _distanceKm = selected.distanceKm;
        _routeLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _routeError = 'تعذر تحميل المسار';
        _routeLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(widget.latitude, widget.longitude);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
      ),
    };
    if (_current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: _current!,
          icon: _currentIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    final routeLine = _routePoints.isNotEmpty
        ? _routePoints
        : _current == null
            ? const <LatLng>[]
            : [_current!, destination];

    final polylines = <Polyline>{};
    if (routeLine.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routeLine,
          color: Colors.blue,
          width: 4,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المسار إلى المهمة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                kIsWeb
                    ? AdvancedWebMap(
                        center: destination,
                        zoom: 13,
                        primaryMarker: destination,
                        secondaryMarker: _current,
                        primaryMarkerIcon: _webDestinationIcon,
                        secondaryMarkerIcon: _webCurrentIcon,
                        polyline: routeLine.isEmpty ? null : routeLine,
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: destination,
                          zoom: 13,
                        ),
                        markers: markers,
                        polylines: polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.address?.isNotEmpty == true
                                ? widget.address!
                                : 'موقع المهمة',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _routeLoading
                                ? 'جاري حساب المسار...'
                                : _distanceKm == null
                                ? 'المسافة: غير متاحة'
                                : 'المسافة: ${_distanceKm!.toStringAsFixed(2)} كم',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (_routes.length > 1) ...[
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(_routes.length, (index) {
                                  final route = _routes[index];
                                  final isSelected = index == _selectedRouteIndex;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      selected: isSelected,
                                      label: Text(
                                        '${route.summary} • ${route.distanceKm.toStringAsFixed(1)} كم • ${route.durationMinutes} د',
                                      ),
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedRouteIndex = index;
                                          _routePoints = route.points;
                                          _distanceKm = route.distanceKm;
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                          if (_routeError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _routeError!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _routeLoading ? null : _refreshRoute,
                                  icon: const Icon(Icons.straighten),
                                  label: const Text('تحديث المسار'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _routeLoading ? null : _startNavigation,
                                  icon: const Icon(Icons.navigation),
                                  label: Text(
                                    _isNavigating ? 'إيقاف الانطلاق' : 'انطلاق للموقع',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RouteOption {
  final String summary;
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  const _RouteOption({
    required this.summary,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}
