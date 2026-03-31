import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/utils/app_navigation.dart';
import 'package:order_tracker/widgets/whatsapp_brand_icon.dart';
import 'package:order_tracker/widgets/whatsapp_compose_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsAppFloatingButton extends StatefulWidget {
  final String heroTag;
  final bool mini;
  final bool draggable;
  final EdgeInsets initialMargin;
  final Alignment initialAlignment;
  final String? persistKey;
  final VoidCallback? onPressed;

  const WhatsAppFloatingButton({
    super.key,
    required this.heroTag,
    this.mini = false,
    this.draggable = false,
    this.initialMargin = const EdgeInsets.only(right: 16, bottom: 16),
    this.initialAlignment = Alignment.bottomRight,
    this.persistKey,
    this.onPressed,
  });

  @override
  State<WhatsAppFloatingButton> createState() => _WhatsAppFloatingButtonState();
}

class _WhatsAppFloatingButtonState extends State<WhatsAppFloatingButton> {
  static const double _dragBoundaryMargin = 0;

  Offset? _positionPx;
  Offset? _positionNormalized;

  double get _buttonExtent => widget.mini ? 40 : 56;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  @override
  void didUpdateWidget(covariant WhatsAppFloatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.persistKey != widget.persistKey) {
      _positionPx = null;
      _positionNormalized = null;
      _loadPersisted();
    }
  }

  void _loadPersisted() {
    final key = widget.persistKey;
    if (key == null || key.trim().isEmpty) return;

    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final nx = prefs.getDouble('${key}_nx');
        final ny = prefs.getDouble('${key}_ny');
        if (nx == null || ny == null || !mounted) return;
        setState(() => _positionNormalized = Offset(nx, ny));
      } catch (_) {
        // Ignore persistence errors.
      }
    }());
  }

  double _maxDx(Size size) {
    final raw = size.width - _buttonExtent - _dragBoundaryMargin;
    return raw < _dragBoundaryMargin ? _dragBoundaryMargin : raw;
  }

  double _maxDy(Size size) {
    final raw = size.height - _buttonExtent - _dragBoundaryMargin;
    return raw < _dragBoundaryMargin ? _dragBoundaryMargin : raw;
  }

  Offset _clamp(Offset position, Size size) {
    return Offset(
      position.dx.clamp(_dragBoundaryMargin, _maxDx(size)),
      position.dy.clamp(_dragBoundaryMargin, _maxDy(size)),
    );
  }

  Offset _defaultPosition(Size size) {
    final dx = widget.initialAlignment.x <= 0
        ? widget.initialMargin.left
        : size.width - _buttonExtent - widget.initialMargin.right;
    final dy = widget.initialAlignment.y <= 0
        ? widget.initialMargin.top
        : size.height - _buttonExtent - widget.initialMargin.bottom;

    return _clamp(Offset(dx, dy), size);
  }

  Offset _fromNormalized(Size size, Offset normalized) {
    final minX = _dragBoundaryMargin;
    final minY = _dragBoundaryMargin;
    final maxX = _maxDx(size);
    final maxY = _maxDy(size);
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final nx = normalized.dx.clamp(0.0, 1.0);
    final ny = normalized.dy.clamp(0.0, 1.0);

    final dx = minX + (rangeX <= 0 ? 0 : rangeX * nx);
    final dy = minY + (rangeY <= 0 ? 0 : rangeY * ny);
    return _clamp(Offset(dx, dy), size);
  }

  Offset _currentPosition(Size size) {
    if (_positionPx != null) {
      return _clamp(_positionPx!, size);
    }
    if (_positionNormalized != null) {
      return _fromNormalized(size, _positionNormalized!);
    }
    return _defaultPosition(size);
  }

  void _handleDragUpdate(DragUpdateDetails details, Size size) {
    final nextPosition = _clamp(_currentPosition(size) + details.delta, size);
    setState(() => _positionPx = nextPosition);
  }

  void _persist(Size size) {
    final key = widget.persistKey;
    if (key == null || key.trim().isEmpty) return;

    final position = _currentPosition(size);
    final minX = _dragBoundaryMargin;
    final minY = _dragBoundaryMargin;
    final maxX = _maxDx(size);
    final maxY = _maxDy(size);
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final nx = rangeX <= 0 ? 0.0 : ((position.dx - minX) / rangeX);
    final ny = rangeY <= 0 ? 0.0 : ((position.dy - minY) / rangeY);
    final normalized = Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));

    _positionNormalized = normalized;

    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('${key}_nx', normalized.dx);
        await prefs.setDouble('${key}_ny', normalized.dy);
      } catch (_) {
        // Ignore persistence errors.
      }
    }());
  }

  Widget _buildButton(BuildContext context) {
    final onPressed =
        widget.onPressed ??
        () {
          final navigatorContext = appNavigatorKey.currentContext;
          if (navigatorContext == null) return;
          WhatsAppComposeDialog.show(
            navigatorContext,
            folderKey: 'global-${DateTime.now().millisecondsSinceEpoch}',
          );
        };

    final radius = BorderRadius.circular(widget.mini ? 12 : 16);

    return Tooltip(
      message: 'واتساب',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Container(
            width: _buttonExtent,
            height: _buttonExtent,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Hero(
              tag: widget.heroTag,
              child: WhatsAppBrandIcon(
                size: _buttonExtent,
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.draggable) {
      return _buildButton(context);
    }

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final position = _currentPosition(size);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    dragStartBehavior: DragStartBehavior.down,
                    onPanUpdate: (details) => _handleDragUpdate(details, size),
                    onPanEnd: (_) => _persist(size),
                    onPanCancel: () => _persist(size),
                    child: _buildButton(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
