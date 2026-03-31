import 'dart:math' as math;

import 'package:flutter/material.dart';

class WhatsAppBrandIcon extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const WhatsAppBrandIcon({
    super.key,
    this.size = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.24);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2DE36A), Color(0xFF21B858)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: Size.square(size),
              painter: _WhatsAppBubblePainter(),
            ),
            Transform.rotate(
              angle: -math.pi / 9,
              child: Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: size * 0.28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final center = Offset(size.width * 0.52, size.height * 0.42);
    final radius = size.width * 0.23;
    canvas.drawCircle(center, radius, stroke);

    final tail = Path()
      ..moveTo(size.width * 0.36, size.height * 0.59)
      ..lineTo(size.width * 0.31, size.height * 0.72)
      ..lineTo(size.width * 0.43, size.height * 0.66);
    canvas.drawPath(tail, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
