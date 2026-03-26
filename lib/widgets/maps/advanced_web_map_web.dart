import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:order_tracker/widgets/maps/web_view_registry.dart';

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdvancedWebMap extends StatefulWidget {
  final LatLng center;
  final double zoom;
  final LatLng? primaryMarker;
  final LatLng? secondaryMarker;
  final String? primaryMarkerIcon;
  final String? secondaryMarkerIcon;
  final List<LatLng>? polylineOutline;
  final List<LatLng>? polyline;
  final ValueChanged<LatLng>? onTap;
  final bool useMapId;

  const AdvancedWebMap({
    super.key,
    required this.center,
    required this.zoom,
    this.primaryMarker,
    this.secondaryMarker,
    this.primaryMarkerIcon,
    this.secondaryMarkerIcon,
    this.polylineOutline,
    this.polyline,
    this.onTap,
    this.useMapId = true,
  });

  @override
  State<AdvancedWebMap> createState() => _AdvancedWebMapState();
}

class _AdvancedWebMapState extends State<AdvancedWebMap> {
  late final String _viewType;
  html.DivElement? _element;
  dynamic _map;
  dynamic _primaryMarker;
  dynamic _secondaryMarker;
  dynamic _polylineOutline;
  dynamic _polyline;
  dynamic _tapListener;
  bool _mapReady = false;
  bool _initScheduled = false;
  String? _initError;
  String? _mapId;
  dynamic _advancedMarkerCtor;
  String? _lastPolylineSignature;

  @override
  void initState() {
    super.initState();
    _viewType =
        'advanced-web-map-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';
    _element = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%';
    registerViewFactory(_viewType, (int viewId) => _element!);
    _scheduleEnsureMap();
  }

  @override
  void didUpdateWidget(covariant AdvancedWebMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady) {
      if (oldWidget.onTap != widget.onTap) {
        _detachTapListener();
        _attachTapListener();
      }
      _syncCamera();
      _syncMarkers();
      _syncPolyline();
    } else {
      _scheduleEnsureMap();
    }
  }

  @override
  void dispose() {
    _detachTapListener();
    _map = null;
    _primaryMarker = null;
    _secondaryMarker = null;
    _polylineOutline = null;
    _polyline = null;
    super.dispose();
  }

  void _scheduleEnsureMap() {
    if (_initScheduled) return;
    _initScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScheduled = false;
      _ensureMap();
    });
  }

  void _ensureMap() {
    if (_mapReady || _element == null || _initError != null) return;
    final loadError = _loadError();
    if (loadError != null) {
      _setInitError(loadError);
      return;
    }
    final maps = _getMaps();
    if (maps == null) {
      return;
    }

    if (!js_util.hasProperty(maps, 'Map')) {
      _setInitError(
        'Google Maps failed to load. Check your API key, Map ID, and billing.',
      );
      return;
    }
    if (widget.useMapId) {
      _mapId = _resolveMapId();
    } else {
      _mapId = null;
    }
    _advancedMarkerCtor =
        widget.useMapId ? _resolveAdvancedMarkerCtor(maps) : null;
    final options = <String, dynamic>{
      'center': _toJsLatLng(widget.center),
      'zoom': widget.zoom,
      'mapTypeId': 'roadmap',
    };
    if (_mapId != null) {
      options['mapId'] = _mapId;
    }
    final mapOptions = js_util.jsify(options);
    try {
      _map = js_util.callConstructor(js_util.getProperty(maps, 'Map'), [
        _element,
        mapOptions,
      ]);
      _mapReady = true;
      _attachTapListener();
      _syncMarkers();
      _syncPolyline();
    } catch (error) {
      _initError = error.toString();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _attachTapListener() {
    if (!_mapReady || widget.onTap == null) return;
    _tapListener = js_util.callMethod(_map, 'addListener', [
      'click',
      js_util.allowInterop((dynamic event) {
        final latLng = js_util.getProperty(event, 'latLng');
        if (latLng == null) return;
        final lat = js_util.callMethod(latLng, 'lat', const []);
        final lng = js_util.callMethod(latLng, 'lng', const []);
        widget.onTap?.call(LatLng(lat as double, lng as double));
      }),
    ]);
  }

  void _detachTapListener() {
    if (_tapListener == null) return;
    js_util.callMethod(_tapListener, 'remove', const []);
    _tapListener = null;
  }

  void _syncCamera() {
    if (!_mapReady) return;
    js_util.callMethod(_map, 'setCenter', [
      js_util.jsify(_toJsLatLng(widget.center)),
    ]);
    js_util.callMethod(_map, 'setZoom', [widget.zoom]);
  }

  void _syncMarkers() {
    if (!_mapReady) return;
    _primaryMarker = _setMarker(
      _primaryMarker,
      widget.primaryMarker,
      'primary',
      widget.primaryMarkerIcon,
    );
    _secondaryMarker = _setMarker(
      _secondaryMarker,
      widget.secondaryMarker,
      'secondary',
      widget.secondaryMarkerIcon,
    );
  }

  dynamic _setMarker(
    dynamic marker,
    LatLng? position,
    String title,
    String? iconUrl,
  ) {
    if (position == null) {
      if (marker != null) {
        js_util.setProperty(marker, 'map', null);
      }
      return marker;
    }

    final jsPosition = _toJsLatLng(position);
    if (marker == null) {
      marker = _createMarker(jsPosition, title, iconUrl);
    }
    if (marker != null) {
      js_util.setProperty(marker, 'position', js_util.jsify(jsPosition));
      js_util.setProperty(marker, 'map', _map);
    }
    return marker;
  }

  dynamic _createMarker(dynamic jsPosition, String title, String? iconUrl) {
    if (_advancedMarkerCtor == null) {
      final maps = _getMaps();
      if (maps == null || !js_util.hasProperty(maps, 'Marker')) {
        _setInitError(
          'Google Maps marker library is unavailable. Check your API key and '
          'Map ID.',
        );
        return null;
      }
      final markerCtor = js_util.getProperty(maps, 'Marker');
      final options = <String, dynamic>{
        'map': _map,
        'position': jsPosition,
        'title': title,
      };
      if (iconUrl != null && iconUrl.isNotEmpty) {
        options['icon'] = iconUrl;
      }
      return js_util.callConstructor(markerCtor, [js_util.jsify(options)]);
    }
    final options = <String, dynamic>{
      'map': _map,
      'position': jsPosition,
      'title': title,
    };
    if (iconUrl != null && iconUrl.isNotEmpty) {
      options['content'] = _buildMarkerContent(iconUrl);
    }
    return js_util.callConstructor(_advancedMarkerCtor, [
      js_util.jsify(options),
    ]);
  }

  html.DivElement _buildMarkerContent(String iconUrl) {
    final element = html.DivElement()
      ..style.width = '56px'
      ..style.height = '56px'
      ..style.backgroundImage = 'url($iconUrl)'
      ..style.backgroundSize = 'contain'
      ..style.backgroundRepeat = 'no-repeat'
      ..style.backgroundPosition = 'center';
    return element;
  }

  void _syncPolyline() {
    if (!_mapReady) return;
    final points = widget.polyline;
    final outlinePoints = widget.polylineOutline ?? points;
    if ((points == null || points.isEmpty) &&
        (outlinePoints == null || outlinePoints.isEmpty)) {
      if (_polylineOutline != null) {
        js_util.setProperty(_polylineOutline, 'map', null);
      }
      if (_polyline != null) {
        js_util.setProperty(_polyline, 'map', null);
      }
      return;
    }

    try {
      _polylineOutline = _setPolyline(
        polyline: _polylineOutline,
        points: outlinePoints,
        color: '#1B33B7',
        width: 8,
        opacity: 0.82,
      );
      _polyline = _setPolyline(
        polyline: _polyline,
        points: points,
        color: '#5B7CFF',
        width: 5,
        opacity: 0.96,
      );

      final fitPoints = points ?? outlinePoints;
      if (fitPoints == null || fitPoints.isEmpty) return;
      final signature = _polylineSignature(fitPoints);
      if (signature != _lastPolylineSignature) {
        _lastPolylineSignature = signature;
        _fitBounds(fitPoints);
      }
    } catch (_) {
      _setInitError('Failed to render map elements. Check Maps JS settings.');
    }
  }

  dynamic _setPolyline({
    required dynamic polyline,
    required List<LatLng>? points,
    required String color,
    required int width,
    required double opacity,
  }) {
    if (points == null || points.isEmpty) {
      if (polyline != null) {
        js_util.setProperty(polyline, 'map', null);
      }
      return polyline;
    }

    final jsPath = js_util.jsify(points.map(_toJsLatLng).toList());
    if (polyline == null) {
      final maps = _getMaps();
      if (maps == null || !js_util.hasProperty(maps, 'Polyline')) {
        return null;
      }
      final polylineCtor = js_util.getProperty(maps, 'Polyline');
      return js_util.callConstructor(polylineCtor, [
        js_util.jsify({
          'path': jsPath,
          'strokeColor': color,
          'strokeOpacity': opacity,
          'strokeWeight': width,
          'map': _map,
        }),
      ]);
    }

    js_util.callMethod(polyline, 'setPath', [jsPath]);
    js_util.setProperty(polyline, 'map', _map);
    return polyline;
  }

  String _polylineSignature(List<LatLng> points) {
    final first = points.first;
    final last = points.last;
    return '${points.length}-'
        '${first.latitude.toStringAsFixed(4)}-'
        '${first.longitude.toStringAsFixed(4)}-'
        '${last.latitude.toStringAsFixed(4)}-'
        '${last.longitude.toStringAsFixed(4)}';
  }

  void _fitBounds(List<LatLng> points) {
    final maps = _getMaps();
    if (maps == null || !js_util.hasProperty(maps, 'LatLngBounds')) {
      return;
    }
    final boundsCtor = js_util.getProperty(maps, 'LatLngBounds');
    final bounds = js_util.callConstructor(boundsCtor, const []);
    for (final point in points) {
      js_util.callMethod(bounds, 'extend', [js_util.jsify(_toJsLatLng(point))]);
    }
    js_util.callMethod(_map, 'fitBounds', [bounds, 72]);
  }

  Map<String, double> _toJsLatLng(LatLng value) {
    return {'lat': value.latitude, 'lng': value.longitude};
  }

  String? _resolveMapId() {
    final mapId = js_util.getProperty(js_util.globalThis, 'GOOGLE_MAPS_MAP_ID');
    if (mapId is String && mapId.trim().isNotEmpty) {
      return mapId.trim();
    }
    return null;
  }

  String? _loadError() {
    try {
      final state = js_util.getProperty(
        js_util.globalThis,
        '__googleMapsLoadState',
      );
      final value = state?.toString() ?? '';
      if (value == 'auth_failure' || value == 'load_error') {
        final error = js_util.getProperty(
          js_util.globalThis,
          '__googleMapsLoadError',
        );
        final message = error?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Google Maps failed to load. Check API key and billing.';
      }
    } catch (_) {}
    return null;
  }

  dynamic _resolveAdvancedMarkerCtor(dynamic maps) {
    if (_mapId == null) {
      return null;
    }
    if (maps == null || !js_util.hasProperty(maps, 'marker')) {
      return null;
    }
    final markerLib = js_util.getProperty(maps, 'marker');
    if (markerLib == null ||
        !js_util.hasProperty(markerLib, 'AdvancedMarkerElement')) {
      return null;
    }
    return js_util.getProperty(markerLib, 'AdvancedMarkerElement');
  }

  dynamic _getMaps() {
    try {
      final google = js_util.getProperty(js_util.globalThis, 'google');
      if (google == null || !js_util.hasProperty(google, 'maps')) {
        return null;
      }
      final maps = js_util.getProperty(google, 'maps');
      if (maps == null) return null;
      return maps;
    } catch (_) {
      return null;
    }
  }

  void _setInitError(String message) {
    if (_initError != null) return;
    _initError = message;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Container(
        color: const Color(0xFFF2F3F5),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          _initError ??
              'Unable to load Google Maps. Ensure the Maps JavaScript API is '
                  'enabled and set GOOGLE_MAPS_MAP_ID for Advanced Markers.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (!_mapReady) {
      _scheduleEnsureMap();
    }
    return HtmlElementView(viewType: _viewType);
  }
}
