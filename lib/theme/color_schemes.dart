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

// ── InheritedWidget scope ─────────────────────────────────────────────────────

/// Propagates the active [NoctuaColorScheme] down the widget tree so screens
/// can read the text colour without knowing the current scheme directly.
class NoctuaSchemeScope extends InheritedWidget {
  final NoctuaColorScheme scheme;

  const NoctuaSchemeScope({
    super.key,
    required this.scheme,
    required super.child,
  });

  static NoctuaColorScheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NoctuaSchemeScope>()?.scheme;

  @override
  bool updateShouldNotify(NoctuaSchemeScope old) => scheme != old.scheme;
}

/// Returns the text colour for the current [NoctuaSchemeScope], falling back
/// to [Colors.white] when no scope is found (e.g. in modal sheets).
Color noctuaText(BuildContext context) =>
    NoctuaSchemeScope.maybeOf(context)?.text ?? Colors.white;

// ── Dark presets ──────────────────────────────────────────────────────────────

const blueScheme = NoctuaColorScheme(
  name: 'blue',
  primary: Color(0xFF0A1628),   // hue 215, sat 65%, light 10%
  secondary: Color(0xFF1565C0),
  accent: Color(0xFF64B5F6),
  text: Colors.white,
);

const purpleScheme = NoctuaColorScheme(
  name: 'purple',
  primary: Color(0xFF170A28),   // hue 270, sat 60%, light 10%
  secondary: Color(0xFF6A1B9A),
  accent: Color(0xFFCE93D8),
  text: Colors.white,
);

const greenScheme = NoctuaColorScheme(
  name: 'green',
  primary: Color(0xFF081A0C),   // hue 135, sat 60%, light 10%
  secondary: Color(0xFF1B5E20),
  accent: Color(0xFF81C784),
  text: Colors.white,
);

// ── All named preset schemes ──────────────────────────────────────────────────

/// All named preset schemes.
const scheme_names = ['blue', 'purple', 'green'];

/// Approximate hues for the preset schemes (used to seed the hue slider).
const preset_hues = {'blue': 215.0, 'purple': 275.0, 'green': 130.0};

// ── Scheme generators ─────────────────────────────────────────────────────────

/// Generate a [NoctuaColorScheme] from any hue (0–360).
///
/// [light] selects the light-mode variant: pale tinted background, medium
/// secondary, darker accent, near-black text.
NoctuaColorScheme schemeFromHue(double hue, {bool light = false}) {
  if (light) {
    final primary   = HSLColor.fromAHSL(1, hue,              0.40, 0.93).toColor();
    final secondary = HSLColor.fromAHSL(1, hue,              0.55, 0.50).toColor();
    final accent    = HSLColor.fromAHSL(1, (hue + 25) % 360, 0.70, 0.40).toColor();
    return NoctuaColorScheme(
      name: 'hue:$hue',
      primary: primary,
      secondary: secondary,
      accent: accent,
      text: const Color(0xFF1A1A2E),
    );
  }
  final primary   = HSLColor.fromAHSL(1, hue,             0.65, 0.11).toColor();
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
/// Unknown keys fall back to [blueScheme] / its light variant.
NoctuaColorScheme schemeByName(String name, {bool light = false}) {
  if (name.startsWith('hue:')) {
    final h = double.tryParse(name.substring(4));
    if (h != null) return schemeFromHue(h, light: light);
  }
  if (light) {
    return switch (name) {
      'purple' => schemeFromHue(275, light: true),
      'green'  => schemeFromHue(130, light: true),
      _        => schemeFromHue(215, light: true),
    };
  }
  return switch (name) {
    'purple' => purpleScheme,
    'green'  => greenScheme,
    _        => blueScheme,
  };
}
