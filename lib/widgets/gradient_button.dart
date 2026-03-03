import 'package:flutter/material.dart';
import 'package:order_tracker/utils/constants.dart';

class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final Gradient? gradient;
  final bool isLoading;
  final double borderRadius;
  final double? width;
  final double? height;

  const GradientButton({
    super.key,
    this.onPressed,
    required this.text,
    this.gradient,
    this.isLoading = false,
    this.borderRadius = 16,
    this.width = 150,
    this.height = 50,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseGradient = widget.gradient ?? AppColors.buttonGradient;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final begin = Alignment.lerp(
          Alignment.topLeft,
          Alignment.bottomRight,
          t,
        )!;
        final end = Alignment.lerp(
          Alignment.bottomRight,
          Alignment.topLeft,
          t,
        )!;
        final gradient = baseGradient is LinearGradient
            ? LinearGradient(
                begin: begin,
                end: end,
                colors: baseGradient.colors,
                stops: baseGradient.stops,
              )
            : baseGradient;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              padding: EdgeInsets.zero,
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                    ),
                  ),
          ),
        );
      },
    );
  }
}
