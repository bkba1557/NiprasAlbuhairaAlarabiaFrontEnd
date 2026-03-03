import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:order_tracker/models/task_model.dart';
import 'package:order_tracker/providers/task_provider.dart';

class TaskTrackingMapScreen extends StatefulWidget {
  final String taskId;
  final List<TaskTrackingPoint> initialPoints;

  const TaskTrackingMapScreen({
    super.key,
    required this.taskId,
    required this.initialPoints,
  });

  @override
  State<TaskTrackingMapScreen> createState() => _TaskTrackingMapScreenState();
}

class _TaskTrackingMapScreenState extends State<TaskTrackingMapScreen> {
  late List<TaskTrackingPoint> _points;
  Timer? _timer;
  bool _loading = false;
  late final MapZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _points = widget.initialPoints;
    _zoomPanBehavior = MapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      zoomLevel: 13,
    );
    _refreshPoints();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshPoints());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPoints() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final provider = context.read<TaskProvider>();
      final points = await provider.fetchTrackingPoints(widget.taskId, limit: 100);
      if (!mounted) return;
      setState(() {
        _points = points;
        if (_points.isNotEmpty) {
          final last = _points.first;
          _zoomPanBehavior.focalLatLng = MapLatLng(last.latitude, last.longitude);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPoints = _points.isNotEmpty;
    final first = hasPoints ? _points.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة التتبع الحي'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'تحديث الآن',
              onPressed: _refreshPoints,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final mapHeight = constraints.maxHeight - 32;
          final effectiveHeight = mapHeight < 320 ? 320.0 : mapHeight;

          if (!hasPoints) {
            return Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF6F8FF), Color(0xFFF1F5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Text('لا توجد نقاط تتبع'),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6F8FF), Color(0xFFF1F5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1100 : double.infinity),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: effectiveHeight,
                        child: SfMaps(
                          layers: [
                            MapTileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              initialFocalLatLng:
                                  MapLatLng(first!.latitude, first.longitude),
                              initialZoomLevel: 13,
                              zoomPanBehavior: _zoomPanBehavior,
                              initialMarkersCount: _points.length,
                              markerBuilder: (context, index) {
                                final point = _points[index];
                                final isLatest = index == 0;
                                return MapMarker(
                                  latitude: point.latitude,
                                  longitude: point.longitude,
                                  size:
                                      isLatest ? const Size(22, 22) : const Size(16, 16),
                                  child: Icon(
                                    Icons.location_on,
                                    color: isLatest ? Colors.red : Colors.orange,
                                  ),
                                );
                              },
                              markerTooltipBuilder: (context, index) {
                                final point = _points[index];
                                return Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(point.userName ?? 'الموظف'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
