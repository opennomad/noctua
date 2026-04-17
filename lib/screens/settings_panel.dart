import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/config_service.dart';
import '../services/ringtone_service.dart';
import '../theme/fonts.dart';
import 'colour_scheme_sheet.dart';

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
  late String            _time_format;
  late String            _alarm_sound;
  late String            _timer_sound;
  late String            _color_mode;
  List<RingtoneEntry>    _ringtones = [];
  bool                   _ringtones_loading = false;
  String?                _previewing;

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
    _pill_edge   = cfg.timer_pill_edge;
    _kb          = cfg.key_bindings;
    _time_format = cfg.time_format;
    _alarm_sound = cfg.alarm_sound;
    _timer_sound = cfg.timer_sound;
    _color_mode  = cfg.color_mode;
    _loadRingtones();
  }

  Future<void> _loadRingtones() async {
    setState(() => _ringtones_loading = true);
    final entries = await RingtoneService.list(type: 'alarm');
    if (mounted) setState(() { _ringtones = entries; _ringtones_loading = false; });
  }

  @override
  void dispose() {
    RingtoneService.stopPreview();
    super.dispose();
  }

  Future<void> _previewToggle(String uri) async {
    if (_previewing == uri) {
      await RingtoneService.stopPreview();
      if (mounted) setState(() => _previewing = null);
    } else {
      setState(() => _previewing = uri);
      await RingtoneService.preview(uri);
    }
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

  void _setTimeFormat(String fmt) {
    setState(() => _time_format = fmt);
    widget.svc.setTimeFormat(fmt);
  }

  void _setAlarmSound(String uri) {
    setState(() => _alarm_sound = uri);
    widget.svc.setAlarmSound(uri);
  }

  void _setTimerSound(String uri) {
    setState(() => _timer_sound = uri);
    widget.svc.setTimerSound(uri);
  }

  void _setColorMode(String mode) {
    setState(() => _color_mode = mode);
    widget.svc.setColorMode(mode);
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
            _sectionLabel('Time Format'),
            const SizedBox(height: 10),
            _timeFormatToggle(),
            const SizedBox(height: 20),
            _sectionLabel('Colour Mode'),
            const SizedBox(height: 10),
            _colorModeToggle(),
            const SizedBox(height: 20),
            _sectionLabel('Alarm Sound'),
            const SizedBox(height: 10),
            _soundPicker(_alarm_sound, _setAlarmSound),
            const SizedBox(height: 20),
            _sectionLabel('Timer Sound'),
            const SizedBox(height: 10),
            _soundPicker(_timer_sound, _setTimerSound),
            const SizedBox(height: 20),
            _keyboardSection(),
            const SizedBox(height: 20),
            _sectionLabel('Timer Pills'),
            const SizedBox(height: 10),
            _pillEdgeChips(),
            const SizedBox(height: 20),
            _sectionLabel('Colour Schemes'),
            const SizedBox(height: 10),
            _colourSchemesButton(),
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

  Widget _soundPicker(String current_uri, ValueChanged<String> on_select) {
    if (_ringtones_loading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
      );
    }

    final all = [
      const RingtoneEntry(title: 'Default', uri: ''),
      ..._ringtones,
    ];

    // Ensure current value is in the list (it might be a URI from a previous
    // install that no longer exists on this device).
    final valid_uri = all.any((e) => e.uri == current_uri) ? current_uri : '';
    final is_playing = _previewing == valid_uri;

    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            value:           valid_uri,
            dropdownColor:   const Color(0xFF1A1A2E),
            style:           const TextStyle(fontSize: 13, color: Colors.white),
            underline:       Container(height: 1, color: Colors.white12),
            isExpanded:      true,
            onChanged: (v) {
              if (v != null) {
                // Stop preview of old sound when selection changes.
                if (_previewing != null) {
                  RingtoneService.stopPreview();
                  setState(() => _previewing = null);
                }
                on_select(v);
              }
            },
            items: all
                .map((e) => DropdownMenuItem<String>(
                      value: e.uri,
                      child: Text(e.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: e.uri == valid_uri
                                  ? Colors.white
                                  : Colors.white70)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _previewToggle(valid_uri),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: is_playing
                  ? Colors.white.withAlpha(30)
                  : Colors.transparent,
              border: Border.all(
                color: is_playing ? Colors.white38 : Colors.white24,
                width: 1,
              ),
            ),
            child: Icon(
              is_playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 16,
              color: is_playing ? Colors.white70 : Colors.white38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeFormatToggle() => Wrap(
        spacing: 8,
        children: [
          for (final (val, label) in [('24h', '24h'), ('12h', '12 h AM/PM')])
            GestureDetector(
              onTap: () => _setTimeFormat(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _time_format == val
                      ? Colors.white12
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _time_format == val
                        ? Colors.white38
                        : Colors.white12,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: _time_format == val
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _colorModeToggle() => Wrap(
        spacing: 8,
        children: [
          for (final (val, label, icon) in [
            ('dark',   'Dark',   Icons.dark_mode_outlined),
            ('light',  'Light',  Icons.light_mode_outlined),
            ('system', 'System', Icons.brightness_auto_outlined),
          ])
            GestureDetector(
              onTap: () => _setColorMode(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _color_mode == val
                      ? Colors.white12
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _color_mode == val
                        ? Colors.white38
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 14,
                        color: _color_mode == val
                            ? Colors.white
                            : Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: _color_mode == val
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

  // ── colour schemes button ─────────────────────────────────────────────────

  Widget _colourSchemesButton() => GestureDetector(
        onTap: () => showColourSchemeSheet(context, widget.svc),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.palette_outlined, size: 16, color: Colors.white38),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Per-screen hues — dark & light',
                  style: TextStyle(fontSize: 13, color: Colors.white60),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
            ],
          ),
        ),
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
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                color: slot.enabled ? Colors.white60 : Colors.white24,
              ),
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
