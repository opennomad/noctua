import 'package:flutter/material.dart';
import '../config/config_service.dart';
import '../theme/color_schemes.dart';
import '../widgets/hue_slider.dart';

void showColourSchemeSheet(BuildContext context, ConfigService svc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ColourSchemeSheet(svc: svc),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ColourSchemeSheet extends StatefulWidget {
  final ConfigService svc;
  const _ColourSchemeSheet({required this.svc});

  @override
  State<_ColourSchemeSheet> createState() => _ColourSchemeSheetState();
}

class _ColourSchemeSheetState extends State<_ColourSchemeSheet> {
  late List<ScreenSlot> _screens;

  static const _screen_names = {
    'clock':       'Clock',
    'world_clock': 'World Clock',
    'alarm':       'Alarm',
    'night_clock': 'Night Clock',
    'timer':       'Timer',
    'stopwatch':   'Stopwatch',
  };

  @override
  void initState() {
    super.initState();
    _screens = List<ScreenSlot>.from(widget.svc.config.screens);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  double _hueOf(String scheme) {
    if (scheme.startsWith('hue:')) {
      return double.tryParse(scheme.substring(4)) ?? 215.0;
    }
    return preset_hues[scheme] ?? 215.0;
  }

  void _setDark(String id, double hue) {
    final key = 'hue:${hue.toStringAsFixed(1)}';
    setState(() {
      final i = _screens.indexWhere((s) => s.id == id);
      if (i >= 0) _screens[i] = _screens[i].copyWith(scheme: key);
    });
    widget.svc.setScreenScheme(id, key);
  }

  void _setLight(String id, double hue) {
    final key = 'hue:${hue.toStringAsFixed(1)}';
    setState(() {
      final i = _screens.indexWhere((s) => s.id == id);
      if (i >= 0) _screens[i] = _screens[i].copyWith(light_scheme: key);
    });
    widget.svc.setScreenLightScheme(id, key);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withAlpha(245),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 12, 24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            const SizedBox(height: 12),
            _sectionLabel('COLOUR SCHEMES'),
            const SizedBox(height: 20),
            _modeSection('Dark',  light: false, icon: Icons.dark_mode_outlined),
            const SizedBox(height: 28),
            _modeSection('Light', light: true,  icon: Icons.light_mode_outlined),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── sub-widgets ───────────────────────────────────────────────────────────

  Widget _handle() => Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _modeSection(String label, {required bool light, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final slot in _screens)
          _schemeRow(slot, light: light),
      ],
    );
  }

  Widget _schemeRow(ScreenSlot slot, {required bool light}) {
    final scheme_key = light ? slot.light_scheme : slot.scheme;
    final hue     = _hueOf(scheme_key);
    final preview = schemeFromHue(hue, light: light);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Swatch: primary fill, accent ring
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preview.primary,
              border: Border.all(color: preview.accent, width: 3),
            ),
          ),
          // Screen name
          SizedBox(
            width: 82,
            child: Text(
              _screen_names[slot.id] ?? slot.id,
              style: TextStyle(
                fontSize: 13,
                color: slot.enabled ? Colors.white60 : Colors.white24,
              ),
            ),
          ),
          // Hue slider
          Expanded(
            child: HueSlider(
              hue: hue,
              enabled: slot.enabled,
              onChanged: slot.enabled
                  ? (h) => light ? _setLight(slot.id, h) : _setDark(slot.id, h)
                  : (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
