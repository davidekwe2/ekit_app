import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class LiveWaveform extends StatelessWidget {
  const LiveWaveform({
    super.key,
    required this.level,
    this.color,
    this.barCount = 24,
  });

  final ValueListenable<double> level; // 0.0–1.0
  final Color? color;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: level,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(level.value,
            color ?? Colors.teal.shade900, barCount),
        child: const SizedBox(height: 28), // top slim strip
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.level, this.color, this.count);
  final double level;
  final Color color;
  final int count;

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = color..strokeCap = StrokeCap.round;
    final w = s.width / (count * 2 - 1);
    final maxH = s.height;
    final h = (maxH * (0.12 + 0.88 * level)).clamp(2, maxH); // min height

    for (int i = 0; i < count; i++) {
      final x = i * w * 2 + w / 2;
      paint.strokeWidth = w;
      c.drawLine(Offset(x, (maxH - h) / 2), Offset(x, (maxH + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.level != level || old.color != color || old.count != count;
}
