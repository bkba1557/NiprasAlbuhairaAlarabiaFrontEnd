import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class DraggableResizablePanel extends StatefulWidget {
  final Widget child;
  final String title;
  final Offset initialPosition;
  final Size initialSize;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<Size> onSizeChanged;
  final VoidCallback? onClose;
  final double minWidth;
  final double minHeight;

  const DraggableResizablePanel({
    super.key,
    required this.child,
    required this.title,
    required this.initialPosition,
    required this.initialSize,
    required this.onPositionChanged,
    required this.onSizeChanged,
    this.onClose,
    this.minWidth = 300,
    this.minHeight = 360,
  });

  @override
  State<DraggableResizablePanel> createState() => _DraggableResizablePanelState();
}

class _DraggableResizablePanelState extends State<DraggableResizablePanel> {
  static const double _edgePadding = 12;
  static const double _headerHeight = 56;

  late Offset _position;
  late Size _size;

  Offset? _dragPointerDelta;
  Offset? _resizeStartGlobal;
  Size? _resizeStartSize;

  bool _isExpanded = false;
  Offset? _lastNormalPosition;
  Size? _lastNormalSize;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _size = widget.initialSize;
  }

  @override
  void didUpdateWidget(covariant DraggableResizablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragPointerDelta != null || _resizeStartGlobal != null) {
      return;
    }

    if (oldWidget.initialPosition != widget.initialPosition && !_isExpanded) {
      _position = widget.initialPosition;
    }
    if (oldWidget.initialSize != widget.initialSize && !_isExpanded) {
      _size = widget.initialSize;
    }
  }

  ({Size screen, EdgeInsets safe}) _viewport() {
    final mediaQuery = MediaQuery.of(context);
    return (screen: mediaQuery.size, safe: mediaQuery.padding);
  }

  Offset _clampPosition(Offset candidate, {Size? forSize}) {
    final viewport = _viewport();
    final size = forSize ?? _size;
    final minX = viewport.safe.left + _edgePadding;
    final minY = viewport.safe.top + _edgePadding;
    final maxX = (viewport.screen.width -
            viewport.safe.right -
            size.width -
            _edgePadding)
        .clamp(minX, double.infinity)
        .toDouble();
    final maxY = (viewport.screen.height -
            viewport.safe.bottom -
            size.height -
            _edgePadding)
        .clamp(minY, double.infinity)
        .toDouble();

    return Offset(
      candidate.dx.clamp(minX, maxX).toDouble(),
      candidate.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Size _clampSize(Size candidate, {Offset? position}) {
    final viewport = _viewport();
    final basePosition = position ?? _position;
    final maxWidth = (viewport.screen.width -
            viewport.safe.right -
            basePosition.dx -
            _edgePadding)
        .clamp(widget.minWidth, viewport.screen.width)
        .toDouble();
    final maxHeight = (viewport.screen.height -
            viewport.safe.bottom -
            basePosition.dy -
            _edgePadding)
        .clamp(widget.minHeight, viewport.screen.height)
        .toDouble();

    return Size(
      candidate.width.clamp(widget.minWidth, maxWidth).toDouble(),
      candidate.height.clamp(widget.minHeight, maxHeight).toDouble(),
    );
  }

  void _notifyGeometry() {
    widget.onPositionChanged(_position);
    widget.onSizeChanged(_size);
  }

  void _handleDragStart(DragStartDetails details) {
    _dragPointerDelta = details.globalPosition - _position;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragPointerDelta == null || _isExpanded) return;

    final next = _clampPosition(details.globalPosition - _dragPointerDelta!);
    setState(() => _position = next);
    widget.onPositionChanged(next);
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragPointerDelta = null;
  }

  void _handleResizeStart(DragStartDetails details) {
    _resizeStartGlobal = details.globalPosition;
    _resizeStartSize = _size;
  }

  void _handleResizeUpdate(DragUpdateDetails details) {
    if (_resizeStartGlobal == null || _resizeStartSize == null || _isExpanded) {
      return;
    }

    final delta = details.globalPosition - _resizeStartGlobal!;
    final next = _clampSize(
      Size(
        _resizeStartSize!.width + delta.dx,
        _resizeStartSize!.height + delta.dy,
      ),
    );

    setState(() => _size = next);
    widget.onSizeChanged(next);
  }

  void _handleResizeEnd(DragEndDetails details) {
    _resizeStartGlobal = null;
    _resizeStartSize = null;
  }

  void _toggleExpanded() {
    final viewport = _viewport();
    final expandedSize = Size(
      viewport.screen.width -
          viewport.safe.left -
          viewport.safe.right -
          (_edgePadding * 2),
      viewport.screen.height -
          viewport.safe.top -
          viewport.safe.bottom -
          (_edgePadding * 2),
    );
    final expandedPosition = Offset(
      viewport.safe.left + _edgePadding,
      viewport.safe.top + _edgePadding,
    );

    setState(() {
      if (_isExpanded) {
        _isExpanded = false;
        _size = _clampSize(_lastNormalSize ?? widget.initialSize);
        _position = _clampPosition(
          _lastNormalPosition ?? widget.initialPosition,
          forSize: _size,
        );
      } else {
        _lastNormalPosition = _position;
        _lastNormalSize = _size;
        _isExpanded = true;
        _size = _clampSize(expandedSize, position: expandedPosition);
        _position = _clampPosition(expandedPosition, forSize: _size);
      }
    });

    _notifyGeometry();
  }

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        foregroundColor: Colors.white,
        minimumSize: const Size(34, 34),
        maximumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _position,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: _size.width,
        height: _size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDarkBlue.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.92),
                          const Color(0xFFF4F8FF).withValues(alpha: 0.90),
                          const Color(0xFFEAF4FF).withValues(alpha: 0.88),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    child: Column(
                      children: [
                        MouseRegion(
                          cursor: _isExpanded
                              ? SystemMouseCursors.basic
                              : SystemMouseCursors.move,
                          child: GestureDetector(
                            onDoubleTap: _toggleExpanded,
                            onPanStart: _handleDragStart,
                            onPanUpdate: _handleDragUpdate,
                            onPanEnd: _handleDragEnd,
                            child: Container(
                              height: _headerHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.appBarWaterDeep.withValues(
                                      alpha: 0.94,
                                    ),
                                    AppColors.appBarWaterMid.withValues(
                                      alpha: 0.90,
                                    ),
                                    AppColors.appBarWaterBright.withValues(
                                      alpha: 0.82,
                                    ),
                                  ],
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _headerAction(
                                    icon: _isExpanded
                                        ? Icons.fit_screen_outlined
                                        : Icons.open_in_full_rounded,
                                    tooltip: _isExpanded
                                        ? 'استعادة الحجم'
                                        : 'تكبير اللوحة',
                                    onPressed: _toggleExpanded,
                                  ),
                                  if (widget.onClose != null) ...[
                                    const SizedBox(width: 6),
                                    _headerAction(
                                      icon: Icons.close_rounded,
                                      tooltip: 'إغلاق',
                                      onPressed: widget.onClose!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_isExpanded)
              Positioned(
                right: 10,
                bottom: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: GestureDetector(
                    onPanStart: _handleResizeStart,
                    onPanUpdate: _handleResizeUpdate,
                    onPanEnd: _handleResizeEnd,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.open_with_rounded,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
