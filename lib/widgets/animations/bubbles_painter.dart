import 'dart:ui';
import 'package:flutter/material.dart';

/// GPU fragment-shader bubbles: soft glowing circles rise from the bottom of
/// the screen to the top, looping seamlessly.  Three layers at different
/// cell sizes and rise rates produce natural variation in size and speed.
///
/// [program] must be pre-loaded with [FragmentProgram.fromAsset] by the
/// parent state ([animated_background.dart]) before this painter is used.
class BubblesPainter extends CustomPainter {
  final FragmentProgram program;
  final double t;         // fractional cycle count (0→1 = one screen crossing)
  final Color  bg;
  final Color  color_a;
  final Color  color_b;
  final double amplitude;
  final double density;

  BubblesPainter(
    this.program, this.t, this.bg, this.color_a, this.color_b, {
    this.amplitude = 1.0,
    this.density   = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    var idx = 0;

    void setF(double v) => shader.setFloat(idx++, v);
    void setC(Color c) {
      setF(c.r);
      setF(c.g);
      setF(c.b);
      setF(c.a);
    }

    setF(t);               // u_time   — fractional cycle, drives seamless rise
    setF(size.width);      // u_width
    setF(size.height);     // u_height
    setC(bg);              // u_color_bg
    setC(color_a);         // u_color_a
    setC(color_b);         // u_color_b
    setF(amplitude);       // u_amplitude
    setF(density);         // u_density

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(BubblesPainter old) =>
      old.t != t || old.amplitude != amplitude || old.density != density;
}
