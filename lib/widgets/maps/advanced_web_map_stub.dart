import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdvancedWebMap extends StatelessWidget {
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
