import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class SlideActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onSubmit;
  final bool enabled;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData knobIcon;

  const SlideActionButton({
    super.key,
    required this.label,
    required this.onSubmit,
    this.enabled = true,
    this.height = 52,
    this.backgroundColor = AppColors.primaryBlue,
    this.foregroundColor = Colors.white,
    this.knobIcon = Icons.arrow_forward_rounded,
  });

  @override
  State<SlideActionButton> createState() => _SlideActionButtonState();
}

class _SlideActionButtonState extends State<SlideActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = const AlwaysStoppedAnimation<double>(0);
    _controller.addListener(() {
      if (!mounted) return;
      setState(() {
        _dragOffset = _animation.value;
      });
    });
  }

  @override
  void didUpdateWidget(covariant SlideActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _reset(animated: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.stop();
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..value = 0
      ..forward();
  }

  void _reset({required bool animated}) {
    _submitted = false;
    if (animated) {
      _animateTo(0);
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  Future<void> _complete(double maxDrag) async {
    if (_submitted) return;
    _submitted = true;
    _animateTo(maxDrag);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    widget.onSubmit();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    _reset(animated: true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = widget.height;
          final knobSize = height - 10;
          final maxDrag =
              (constraints.maxWidth - knobSize - 5).clamp(0, 99999).toDouble();
          final current = _dragOffset.clamp(0, maxDrag);
          final completedThreshold = maxDrag * 0.86;

          return Semantics(
            button: true,
            enabled: widget.enabled,
            label: widget.label,
            onTap: widget.enabled ? () => _complete(maxDrag) : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: widget.enabled ? 1 : 0.55,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: widget.backgroundColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.foregroundColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      // `current` is a `num`; convert to double
                      left: 5 + current.toDouble(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: widget.enabled
                            ? (details) {
                                setState(() {
                                  _dragOffset =
                                      (_dragOffset + details.delta.dx).clamp(
                                        0,
                                        maxDrag,
                                      );
                                });
                              }
                            : null,
                        onHorizontalDragEnd: widget.enabled
                            ? (_) {
                                if (_dragOffset >= completedThreshold) {
                                  _complete(maxDrag);
                                } else {
                                  _reset(animated: true);
                                }
                              }
                            : null,
                        onTap: widget.enabled ? () => _complete(maxDrag) : null,
                        child: Container(
                          width: knobSize,
                          height: knobSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.knobIcon,
                            color: widget.backgroundColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


