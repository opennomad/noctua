import 'package:flutter/material.dart';

class NoctuaColorScheme {
  final String name;
  final Color primary;   // deep background
  final Color secondary; // mid-tone blob
  final Color accent;    // bright blob / highlights
  final Color text;

  const NoctuaColorScheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.text,
  });
}

const blueScheme = NoctuaColorScheme(
  name: 'blue',
  primary: Color(0xFF050D1A),
  secondary: Color(0xFF1565C0),
  accent: Color(0xFF64B5F6),
  text: Colors.white,
);

const purpleScheme = NoctuaColorScheme(
  name: 'purple',
  primary: Color(0xFF0D0515),
  secondary: Color(0xFF6A1B9A),
  accent: Color(0xFFCE93D8),
  text: Colors.white,
);

const greenScheme = NoctuaColorScheme(
  name: 'green',
  primary: Color(0xFF021008),
  secondary: Color(0xFF1B5E20),
  accent: Color(0xFF81C784),
  text: Colors.white,
);

/// All named preset schemes.
const scheme_names = ['blue', 'purple', 'green'];

/// Approximate hues for the preset schemes (used to seed the hue slider).
const preset_hues = {'blue': 215.0, 'purple': 275.0, 'green': 130.0};

/// Generate a [NoctuaColorScheme] from any hue (0–360).
/// The background is a very dark tint of the hue; secondary and accent are
/// derived at higher lightness so animations stay rich and visible.
NoctuaColorScheme schemeFromHue(double hue) {
  final primary   = HSLColor.fromAHSL(1, hue,             0.55, 0.09).toColor();
  final secondary = HSLColor.fromAHSL(1, hue,             0.68, 0.40).toColor();
  final accent    = HSLColor.fromAHSL(1, (hue + 25) % 360, 0.80, 0.65).toColor();
  return NoctuaColorScheme(
    name: 'hue:$hue',
    primary: primary,
    secondary: secondary,
    accent: accent,
    text: Colors.white,
  );
}

/// Resolve a scheme key from config to a [NoctuaColorScheme].
/// Accepts named presets ('blue', 'purple', 'green') or 'hue:NNN.N'.
/// Unknown keys fall back to [blueScheme].
NoctuaColorScheme schemeByName(String name) {
  if (name.startsWith('hue:')) {
    final h = double.tryParse(name.substring(4));
    if (h != null) return schemeFromHue(h);
  }
  return switch (name) {
    'purple' => purpleScheme,
    'green'  => greenScheme,
    _        => blueScheme,
  };
}
