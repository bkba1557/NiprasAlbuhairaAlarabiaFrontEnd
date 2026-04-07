import 'package:flutter/material.dart';

/// لوحة قابلة للسحب وإعادة التحجيم مع مظهر حديث.
class DraggableResizablePanel extends StatefulWidget {
  final Widget child;
  final Offset initialPosition;
  final Size initialSize;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<Size> onSizeChanged;
  final double minWidth;
  final double minHeight;

  const DraggableResizablePanel({
    super.key,
    required this.child,
    required this.initialPosition,
    required this.initialSize,
    required this.onPositionChanged,
    required this.onSizeChanged,
    this.minWidth = 280,
    this.minHeight = 300,
  });

  @override
  State<DraggableResizablePanel> createState() => _DraggableResizablePanelState();
}

class _DraggableResizablePanelState extends State<DraggableResizablePanel> {
  /* ---------- الحالة ---------- */
  late Offset _position; // موضع اللوحة داخل الـ Stack
  late Size _size;       // حجم اللوحة
  Offset? _dragStartPosition;
  Size? _dragStartSize;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _size = widget.initialSize;
  }

  /* ---------- سحب الرأس ---------- */
  void _onHeaderPointerDown(PointerDownEvent event) => _dragStartPosition = _position;
  void _onHeaderPointerMove(PointerMoveEvent event) {
    if (_dragStartPosition == null) return;
    final newPos = _dragStartPosition! + event.delta;
    setState(() => _position = newPos);
    widget.onPositionChanged(newPos);
  }
  void _onHeaderPointerUp(PointerUpEvent event) => _dragStartPosition = null;

  /* ---------- تحجيم الزاوية ---------- */
  void _onResizePointerDown(PointerDownEvent event) => _dragStartSize = _size;
  void _onResizePointerMove(PointerMoveEvent event) {
    if (_dragStartSize == null) return;
    final newWidth = (_dragStartSize!.width + event.delta.dx)
        .clamp(widget.minWidth, double.infinity);
    final newHeight = (_dragStartSize!.height + event.delta.dy)
        .clamp(widget.minHeight, double.infinity);
    final newSize = Size(newWidth, newHeight);
    setState(() => _size = newSize);
    widget.onSizeChanged(newSize);
  }
  void _onResizePointerUp(PointerUpEvent event) => _dragStartSize = null;

  @override
  Widget build(BuildContext context) {
    // ★★★ نزيل اللون الصلب هنا ★★★
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: SizedBox(
        width: _size.width,
        height: _size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ---------- الحاوية الخلفية ----------
            Container(
              // الآن لون الخلفية شفاف (أو يمكنك إعطاء لون شبه شفاف إذا رغبت)
              decoration: BoxDecoration(
                color: Colors.transparent,               // <-- حذف الخلفية الصلبة
                borderRadius: BorderRadius.circular(12),
                // إذا أردت ظلًا خفيفًا فقط (اختياري)
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: widget.child,                     // محتوى الـ QuickNotesPanel
            ),

            // ---------- رأس السحب ----------
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 48,
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onHeaderPointerDown,
                  onPointerMove: _onHeaderPointerMove,
                  onPointerUp: _onHeaderPointerUp,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColorLight
                          .withOpacity(0.12), // خلفية شفافة خفيفة للرأس
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black.withOpacity(0.08),
                          width: 0.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            // ---------- مقبض التحجيم ----------
            Positioned(
              bottom: 0,
              right: 0,
              width: 28,
              height: 28,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownLeft,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onResizePointerDown,
                  onPointerMove: _onResizePointerMove,
                  onPointerUp: _onResizePointerUp,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 16,
                      color: Colors.blue,
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