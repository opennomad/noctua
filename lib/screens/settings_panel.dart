import 'package:flutter/material.dart';
import '../config/config_service.dart';
import '../theme/color_schemes.dart';
import '../theme/fonts.dart';

void showSettingsPanel(BuildContext context, ConfigService svc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsPanel(svc: svc),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SettingsPanel extends StatefulWidget {
  final ConfigService svc;
  const _SettingsPanel({required this.svc});

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late String        _animation;
  late double        _speed;
  late double        _density;
  late double        _amplitude;
  late List<String>  _schemes;
  late String        _font;

  @override
  void initState() {
    super.initState();
    final cfg  = widget.svc.config;
    _animation = cfg.animation;
    _speed     = cfg.animation_params.speed;
    _density   = cfg.animation_params.density;
    _amplitude = cfg.animation_params.amplitude;
    _schemes   = cfg.columns.map((c) => c.scheme).toList();
    _font      = cfg.font;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  AnimationParams get _params => AnimationParams(
        speed: _speed, density: _density, amplitude: _amplitude);

  void _liveParams(AnimationParams p) => widget.svc.setAnimationParamsLive(p);
  void _saveParams(AnimationParams p) => widget.svc.setAnimationParams(p);

  void _setAnimation(String val) {
    setState(() => _animation = val);
    widget.svc.setAnimation(val);
  }

  void _setFont(String val) {
    setState(() => _font = val);
    widget.svc.setFont(val);
  }

  void _setScheme(int col, String scheme) {
    setState(() => _schemes[col] = scheme);
    widget.svc.setColumnScheme(col, scheme);
  }

  /// Extract the hue from a scheme key — either a named preset or 'hue:NNN'.
  double _hueOf(String scheme) {
    if (scheme.startsWith('hue:')) {
      return double.tryParse(scheme.substring(4)) ?? 215.0;
    }
    return preset_hues[scheme] ?? 215.0;
  }

  // ── build ──────────────────────────────────────────────────────────────────

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
            const SizedBox(height: 8),
            _sectionLabel('Animation'),
            const SizedBox(height: 10),
            _animationChips(),
            const SizedBox(height: 20),
            _sectionLabel('Speed'),
            _slider(
              value: _speed, min: 0.2, max: 3.0,
              onChanged: (v) { setState(() => _speed = v);   _liveParams(_params); },
              onChangeEnd: (v) => _saveParams(_params),
            ),
            _sectionLabel('Density'),
            _slider(
              value: _density, min: 0.2, max: 2.0,
              onChanged: (v) { setState(() => _density = v); _liveParams(_params); },
              onChangeEnd: (v) => _saveParams(_params),
            ),
            _sectionLabel('Amplitude'),
            _slider(
              value: _amplitude, min: 0.2, max: 2.0,
              onChanged: (v) { setState(() => _amplitude = v); _liveParams(_params); },
              onChangeEnd: (v) => _saveParams(_params),
            ),
            const SizedBox(height: 8),
            _sectionLabel('Font'),
            const SizedBox(height: 10),
            _fontChips(),
            const SizedBox(height: 20),
            _sectionLabel('Colors'),
            const SizedBox(height: 10),
            _schemeRow(0, 'Clock'),
            const SizedBox(height: 12),
            _schemeRow(1, 'Alarm'),
            const SizedBox(height: 12),
            _schemeRow(2, 'Timer'),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ── sub-widgets ────────────────────────────────────────────────────────────

  Widget _handle() => Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static const _anim_options = [
    ('lava_lamp', 'Lava Lamp'),
    ('raindrops', 'Rain'),
    ('wave',      'Wave'),
    ('pulse',     'Pulse'),
    ('none',      'None'),
  ];

  Widget _animationChips() => Wrap(
        spacing: 8,
        children: [
          for (final (val, label) in _anim_options)
            _styledChip(label: label, selected: _animation == val,
                onTap: () => _setAnimation(val)),
        ],
      );

  Widget _fontChips() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (key, label) in font_options)
            _styledChip(
              label: label,
              selected: _font == key,
              labelStyle: fontPreviewStyle(
                key,
                TextStyle(
                  fontSize: 13,
                  color: _font == key ? Colors.white : Colors.white54,
                ),
              ),
              onTap: () => _setFont(key),
            ),
        ],
      );

  Widget _styledChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    TextStyle? labelStyle,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.white38 : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: labelStyle ??
                TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.white54,
                ),
          ),
        ),
      );

  Widget _slider({
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) =>
      Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white54,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white70,
                overlayColor: Colors.white12,
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value, min: min, max: max,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      );

  // Per-column row: preset circles + hue gradient slider
  Widget _schemeRow(int col, String label) => Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: _HueSlider(
              hue: _hueOf(_schemes[col]),
              onChanged: (h) => _setScheme(col, 'hue:${h.toStringAsFixed(1)}'),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hue gradient slider
// ─────────────────────────────────────────────────────────────────────────────

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.hue, required this.onChanged});

  void _update(Offset local, BoxConstraints bc) {
    final pct = (local.dx / bc.maxWidth).clamp(0.0, 1.0);
    onChanged(pct * 360);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, bc) => GestureDetector(
        onTapDown:             (d) => _update(d.localPosition, bc),
        onHorizontalDragUpdate:(d) => _update(d.localPosition, bc),
        child: CustomPaint(
          painter: _HuePainter(hue),
          size: const Size(double.infinity, 28),
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

    // Rainbow gradient track
    final gradient = LinearGradient(colors: [
      for (int i = 0; i <= 6; i++)
        HSLColor.fromAHSL(1, i * 60.0, 0.75, 0.50).toColor(),
    ]);
    canvas.drawRRect(
      rect,
      Paint()..shader =
          gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Thumb
    final x  = (hue / 360) * size.width;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(x, cy), 10,
        Paint()..color = Colors.black45);
    canvas.drawCircle(Offset(x, cy), 9,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, cy), 7,
        Paint()..color =
            HSLColor.fromAHSL(1, hue, 0.80, 0.55).toColor());
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
