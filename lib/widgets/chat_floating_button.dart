import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:order_tracker/providers/chat_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatFloatingButton extends StatefulWidget {
  final String heroTag;
  final bool mini;
  final bool enableBadge;
  final bool draggable;

  /// Distance from the chosen edges (see [initialAlignment]).
  final EdgeInsets initialMargin;

  /// Determines which edges [initialMargin] is applied to.
  /// Defaults to bottom-left to match the requested behavior.
  final Alignment initialAlignment;

  /// If set, the drag position is stored as a normalized fraction and restored
  /// on next app launch.
  final String? persistKey;

  /// Optional override to navigate without relying on a Navigator in context.
  final VoidCallback? onPressed;

  const ChatFloatingButton({
    super.key,
    required this.heroTag,
    this.mini = false,
    this.enableBadge = true,
    this.draggable = false,
    this.initialMargin = const EdgeInsets.only(left: 16, bottom: 16),
    this.initialAlignment = Alignment.bottomLeft,
    this.persistKey,
    this.onPressed,
  });

  @override
  State<ChatFloatingButton> createState() => _ChatFloatingButtonState();
}

class _ChatFloatingButtonState extends State<ChatFloatingButton> {
  static const double _dragBoundaryMargin = 0;
  static const double _badgeRoom = 12;

  Offset? _positionPx;
  Offset? _positionNormalized;

  double get _buttonExtent => widget.mini ? 40 : 56;
  double get _itemExtent => _buttonExtent + _badgeRoom;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  @override
  void didUpdateWidget(covariant ChatFloatingButton oldWidget) {
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
        if (nx == null || ny == null) return;
        if (!mounted) return;
        setState(() => _positionNormalized = Offset(nx, ny));
      } catch (_) {
        // Ignore persistence errors (restricted FS, locked prefs, etc).
      }
    }());
  }

  double _maxDx(Size size) {
    final raw = size.width - _itemExtent - _dragBoundaryMargin;
    return raw < _dragBoundaryMargin ? _dragBoundaryMargin : raw;
  }

  double _maxDy(Size size) {
    final raw = size.height - _itemExtent - _dragBoundaryMargin;
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
        : size.width - _itemExtent - widget.initialMargin.right;
    final dy = widget.initialAlignment.y <= 0
        ? widget.initialMargin.top
        : size.height - _itemExtent - widget.initialMargin.bottom;

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
    final explicit = _positionPx;
    if (explicit != null) return _clamp(explicit, size);

    final normalized = _positionNormalized;
    if (normalized != null) return _fromNormalized(size, normalized);

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
    final unread = context.watch<ChatProvider>().totalUnread;
    final onPressed =
        widget.onPressed ??
        () {
          Navigator.of(context, rootNavigator: true).pushNamed(AppRoutes.chat);
        };

    return SizedBox(
      width: _itemExtent,
      height: _itemExtent,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Badge(
          isLabelVisible: widget.enableBadge && unread > 0,
          label: Text(unread > 99 ? '99+' : unread.toString()),
          child: FloatingActionButton(
            heroTag: widget.heroTag,
            mini: widget.mini,
            onPressed: onPressed,
            child: const Icon(Icons.chat_bubble_outline),
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
