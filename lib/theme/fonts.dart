import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Curated font options for the clock UI.
/// Each entry is (config_key, display_label).
const font_options = [
  ('default',         'Default'),
  ('orbitron',        'Orbitron'),
  ('raleway',         'Raleway'),
  ('oxanium',         'Oxanium'),
  ('share_tech_mono', 'Mono'),
  ('exo_2',           'Exo 2'),
];

/// Apply a font selection to an entire [TextTheme].
TextTheme applyFont(String font, TextTheme base) => switch (font) {
      'orbitron'        => GoogleFonts.orbitronTextTheme(base),
      'raleway'         => GoogleFonts.ralewayTextTheme(base),
      'oxanium'         => GoogleFonts.oxaniumTextTheme(base),
      'share_tech_mono' => GoogleFonts.shareTechMonoTextTheme(base),
      'exo_2'           => GoogleFonts.exo2TextTheme(base),
      _                 => base,
    };

/// Return a [TextStyle] using a specific font for preview rendering.
TextStyle fontPreviewStyle(String font, TextStyle base) => switch (font) {
      'orbitron'        => GoogleFonts.orbitron(textStyle: base),
      'raleway'         => GoogleFonts.raleway(textStyle: base),
      'oxanium'         => GoogleFonts.oxanium(textStyle: base),
      'share_tech_mono' => GoogleFonts.shareTechMono(textStyle: base),
      'exo_2'           => GoogleFonts.exo2(textStyle: base),
      _                 => base,
    };
