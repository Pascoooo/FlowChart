import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashboardBackground extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;

  const DashboardBackground({
    super.key,
    required this.animation,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _BackgroundPainter(
              animation: animation,
              primaryColor: primaryColor,
            ),
          );
        },
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final Color primaryColor;

  _BackgroundPainter({
    required this.animation,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    final path = Path();
    const waveHeight = 50;
    final waveLength = size.width / 4;
    final phase = animation.value * 2 * math.pi;

    path.moveTo(0, size.height * 0.8);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height * 0.8 +
          waveHeight * math.sin((x / waveLength) * 2 * math.pi + phase);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
