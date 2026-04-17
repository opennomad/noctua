import 'package:flutter/material.dart';

/// A horizontal hue-picker gradient bar with a draggable thumb.
/// Fires [onChanged] with a value in [0, 360).
class HueSlider extends StatelessWidget {
  final double hue;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const HueSlider({
    super.key,
    required this.hue,
    required this.onChanged,
    this.enabled = true,
  });

  void _update(Offset local, BoxConstraints bc) {
    final pct = (local.dx / bc.maxWidth).clamp(0.0, 1.0);
    onChanged(pct * 360);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: LayoutBuilder(
        builder: (ctx, bc) => GestureDetector(
          onTapDown:              enabled ? (d) => _update(d.localPosition, bc) : null,
          onHorizontalDragUpdate: enabled ? (d) => _update(d.localPosition, bc) : null,
          child: CustomPaint(
            painter: _HuePainter(hue),
            size: const Size(double.infinity, 28),
          ),
        ),
      ),
    );
  }
}

class _HuePainter extends CustomPainter {
  final double hue;
  const _HuePainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, (size.height - 8) / 2, size.width, 8),
      const Radius.circular(4),
    );

    final gradient = LinearGradient(colors: [
      for (int i = 0; i <= 6; i++)
        HSLColor.fromAHSL(1, i * 60.0, 0.75, 0.50).toColor(),
    ]);
    canvas.drawRRect(
      rect,
      Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final x  = (hue / 360) * size.width;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(x, cy), 10, Paint()..color = Colors.black45);
    canvas.drawCircle(Offset(x, cy), 9,  Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, cy), 7,
        Paint()..color = HSLColor.fromAHSL(1, hue, 0.80, 0.55).toColor());
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
