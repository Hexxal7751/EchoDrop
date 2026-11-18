import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Animated bars styled after the logo. [level] (0..1) drives the height
/// when listening; without it the bars just animate.
class WaveBars extends StatefulWidget {
  const WaveBars({super.key, this.level, this.active = true});
  final ValueListenable<double>? level;
  final bool active;

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<WaveBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lvl = widget.level;
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, if (lvl != null) lvl]),
        builder: (_, __) => CustomPaint(
          painter: _WavePainter(_c.value, widget.active ? (lvl?.value ?? 0.6) : 0.05),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.level);
  final double t;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 23;
    final w = size.width / (bars * 1.6);
    final gap = w * 0.6;
    final total = bars * w + (bars - 1) * gap;
    final startX = (size.width - total) / 2;
    final paint = Paint()
      ..shader = Brand.gradient.createShader(Rect.fromLTWH(startX, 0, total, size.height));

    for (var i = 0; i < bars; i++) {
      final x = i / (bars - 1);
      final bell = 0.25 + 0.75 * sin(pi * x);
      final wobble = 0.55 + 0.45 * sin(2 * pi * t + i * 0.6);
      final h = size.height * bell * wobble * (0.25 + 0.75 * level.clamp(0.0, 1.0));
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(startX + i * (w + gap) + w / 2, size.height / 2),
          width: w,
          height: max(h, w),
        ),
        Radius.circular(w / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}