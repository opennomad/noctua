import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late String            _animation;
  late double            _speed;
  late double            _density;
  late double            _amplitude;
  late List<ScreenSlot>  _screens;
  late String            _font;
  late String            _pill_edge;
  late KeyBindings       _kb;

  static const Map<String, String> _screen_names = {
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
    final cfg  = widget.svc.config;
    _animation = cfg.animation;
    _speed     = cfg.animation_params.speed;
    _density   = cfg.animation_params.density;
    _amplitude = cfg.animation_params.amplitude;
    _screens   = List<ScreenSlot>.from(cfg.screens);
    _font      = cfg.font;
    _pill_edge = cfg.timer_pill_edge;
    _kb        = cfg.key_bindings;
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

  void _setScreenEnabled(String id, bool enabled) {
    setState(() {
      final i = _screens.indexWhere((s) => s.id == id);
      if (i >= 0) _screens[i] = _screens[i].copyWith(enabled: enabled);
    });
    widget.svc.setScreenEnabled(id, enabled);
  }

  void _setScreenScheme(String id, String scheme) {
    setState(() {
      final i = _screens.indexWhere((s) => s.id == id);
      if (i >= 0) _screens[i] = _screens[i].copyWith(scheme: scheme);
    });
    widget.svc.setScreenScheme(id, scheme);
  }

  void _reorderScreens(int old_index, int new_index) {
    setState(() {
      if (new_index > old_index) new_index--;
      final item = _screens.removeAt(old_index);
      _screens.insert(new_index, item);
    });
    widget.svc.setScreens(List<ScreenSlot>.from(_screens));
  }

  void _setPillEdge(String val) {
    setState(() => _pill_edge = val);
    widget.svc.setTimerPillEdge(val);
  }

  void _setKeyBindings(KeyBindings kb) {
    setState(() => _kb = kb);
    widget.svc.setKeyBindings(kb);
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
            _keyboardSection(),
            const SizedBox(height: 20),
            _sectionLabel('Timer Pills'),
            const SizedBox(height: 10),
            _pillEdgeChips(),
            const SizedBox(height: 20),
            _sectionLabel('Screens'),
            const SizedBox(height: 6),
            _screenList(),
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

  // ── keyboard ───────────────────────────────────────────────────────────────

  Widget _keyboardSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionLabel('Keyboard')),
              Transform.scale(
                scale: 0.75,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: _kb.enabled,
                  onChanged: (v) => _setKeyBindings(_kb.copyWith(enabled: v)),
                  activeThumbColor: Colors.white70,
                  activeTrackColor: Colors.white24,
                  inactiveThumbColor: Colors.white24,
                  inactiveTrackColor: Colors.white12,
                ),
              ),
            ],
          ),
          if (_kb.enabled) ...[
            const SizedBox(height: 6),
            _keyRow('→  Next', _kb.nav_next, (k) => _setKeyBindings(_kb.copyWith(nav_next: k))),
            _keyRow('←  Prev', _kb.nav_prev, (k) => _setKeyBindings(_kb.copyWith(nav_prev: k))),
          ],
        ],
      );

  Widget _keyRow(String label, String key, ValueChanged<String> on_rebind) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            GestureDetector(
              onTap: () async {
                final captured = await _captureKey(context);
                if (captured != null) on_rebind(captured);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  key,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  static const _pill_edge_options = [
    ('left',   'Left',   Icons.border_left),
    ('right',  'Right',  Icons.border_right),
    ('bottom', 'Bottom', Icons.border_bottom),
  ];

  Widget _pillEdgeChips() => Wrap(
        spacing: 8,
        children: [
          for (final (val, label, icon) in _pill_edge_options)
            GestureDetector(
              onTap: () => _setPillEdge(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _pill_edge == val
                      ? Colors.white12
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _pill_edge == val
                        ? Colors.white38
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 14,
                        color: _pill_edge == val
                            ? Colors.white
                            : Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: _pill_edge == val
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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

  // ── screen list ───────────────────────────────────────────────────────────

  Widget _screenList() => ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: _reorderScreens,
        children: [
          for (int i = 0; i < _screens.length; i++)
            _screenRow(_screens[i], i),
        ],
      );

  Widget _screenRow(ScreenSlot slot, int i) {
    final name = _screen_names[slot.id] ?? slot.id;
    return Padding(
      key: ValueKey(slot.id),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.white24),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                color: slot.enabled ? Colors.white60 : Colors.white24,
              ),
            ),
          ),
          Expanded(
            child: _HueSlider(
              hue: _hueOf(slot.scheme),
              enabled: slot.enabled,
              onChanged: slot.enabled
                  ? (h) => _setScreenScheme(slot.id, 'hue:${h.toStringAsFixed(1)}')
                  : (_) {},
            ),
          ),
          Transform.scale(
            scale: 0.72,
            alignment: Alignment.centerRight,
            child: Switch(
              value: slot.enabled,
              onChanged: (v) => _setScreenEnabled(slot.id, v),
              activeThumbColor: Colors.white70,
              activeTrackColor: Colors.white24,
              inactiveThumbColor: Colors.white24,
              inactiveTrackColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hue gradient slider
// ─────────────────────────────────────────────────────────────────────────────

class _HueSlider extends StatelessWidget {
  final double hue;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _HueSlider({
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
          onTapDown:             enabled ? (d) => _update(d.localPosition, bc) : null,
          onHorizontalDragUpdate:enabled ? (d) => _update(d.localPosition, bc) : null,
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

// ── key-capture dialog ────────────────────────────────────────────────────────

Future<String?> _captureKey(BuildContext context) => showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _KeyCaptureDialog(),
    );

class _KeyCaptureDialog extends StatelessWidget {
  const _KeyCaptureDialog();

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // Escape = cancel without binding.
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        final label = event.logicalKey.keyLabel;
        if (label.isNotEmpty) {
          Navigator.pop(context, label);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard, color: Colors.white38, size: 36),
              const SizedBox(height: 16),
              const Text(
                'Press a key…',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Esc to cancel',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
