import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/config_service.dart';
import '../../data/emoji_shortcodes.dart';

// ── timer status ──────────────────────────────────────────────────────────────

enum _TStatus { idle, running, paused }

// ── per-timer runtime state ───────────────────────────────────────────────────

class _TState {
  Duration total;
  Duration remaining;
  _TStatus status;

  _TState(this.total)
      : remaining = total,
        status = _TStatus.idle;

  bool get is_idle    => status == _TStatus.idle;
  bool get is_running => status == _TStatus.running;
}

// ── screen ────────────────────────────────────────────────────────────────────

class TimerScreen extends StatefulWidget {
  final ConfigService config_service;
  const TimerScreen({super.key, required this.config_service});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  static const _scratch = '_scratch';
  static const _pill_delay = Duration(seconds: 3);

  // per-timer runtime: keyed by saved-timer id or '_scratch'
  final Map<String, _TState> _states = {
    _scratch: _TState(const Duration(minutes: 5)),
  };
  String _active_id = _scratch;

  Timer? _tick;

  // scroll input for the scratch timer
  late FixedExtentScrollController _h_ctrl, _m_ctrl, _s_ctrl;
  int _input_h = 0, _input_m = 5, _input_s = 0;

  // pill fade
  late AnimationController _pill_ctrl;
  Timer? _pill_hide;

  @override
  void initState() {
    super.initState();
    _h_ctrl = FixedExtentScrollController(initialItem: 0);
    _m_ctrl = FixedExtentScrollController(initialItem: 5);
    _s_ctrl = FixedExtentScrollController(initialItem: 0);
    _pill_ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    widget.config_service.addListener(_onConfig);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pill_hide?.cancel();
    _h_ctrl.dispose();
    _m_ctrl.dispose();
    _s_ctrl.dispose();
    _pill_ctrl.dispose();
    widget.config_service.removeListener(_onConfig);
    super.dispose();
  }

  void _onConfig() => setState(() {});

  // ── pill visibility ────────────────────────────────────────────────────────

  void _touchPills() {
    _pill_ctrl.forward();
    _pill_hide?.cancel();
    _pill_hide = Timer(_pill_delay, () => _pill_ctrl.reverse());
  }

  // ── timer management ───────────────────────────────────────────────────────

  _TState get _active => _states[_active_id] ?? _states[_scratch]!;

  void _ensureTick() {
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      bool any = false;
      setState(() {
        for (final s in _states.values) {
          if (s.is_running) {
            any = true;
            if (s.remaining.inSeconds <= 1) {
              s.remaining = Duration.zero;
              s.status = _TStatus.idle;
            } else {
              s.remaining -= const Duration(seconds: 1);
            }
          }
        }
      });
      if (!any) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }

  void _loadSaved(SavedTimer saved) {
    _states.putIfAbsent(
        saved.id, () => _TState(Duration(seconds: saved.seconds)));
    // tapping the active pill deselects back to scratch
    setState(
        () => _active_id = _active_id == saved.id ? _scratch : saved.id);
  }

  void _startOrResume() {
    final s = _active;
    if (s.is_idle && _active_id == _scratch) {
      final d =
          Duration(hours: _input_h, minutes: _input_m, seconds: _input_s);
      if (d == Duration.zero) return;
      s.total = d;
      s.remaining = d;
    }
    if (s.remaining == Duration.zero) return;
    setState(() => s.status = _TStatus.running);
    _ensureTick();
  }

  void _pause() => setState(() => _active.status = _TStatus.paused);

  void _reset() => setState(() {
        final s = _active;
        s.remaining = s.total;
        s.status = _TStatus.idle;
      });

  void _addMinute() => setState(() {
        final s = _active;
        const one_min = Duration(minutes: 1);
        s.remaining += one_min;
        s.total     += one_min;
      });

  // ── saved-timer CRUD ───────────────────────────────────────────────────────

  Future<void> _addSaved() async {
    final result = await _showTimerSheet(context);
    if (result != null) {
      await widget.config_service.addSavedTimer(result);
    }
  }

  Future<void> _editSaved(SavedTimer t) async {
    final result = await _showTimerSheet(context, timer: t);
    if (result == null) return;
    if (result.id == '__delete__') {
      _states.remove(t.id);
      if (_active_id == t.id) setState(() => _active_id = _scratch);
      await widget.config_service.deleteSavedTimer(t.id);
    } else {
      await widget.config_service.updateSavedTimer(result);
      final existing = _states[t.id];
      if (existing != null && existing.is_idle) {
        setState(() {
          existing.total = Duration(seconds: result.seconds);
          existing.remaining = existing.total;
        });
      }
    }
  }

  // ── format helpers ─────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fmtSecs(int total) {
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0 && m == 0) return '${h}h';
    if (h > 0) return '${h}h ${m}m';
    if (s == 0) return '${m}m';
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final edge = widget.config_service.config.timer_pill_edge;
    final is_side = edge == 'left' || edge == 'right';

    final pills = FadeTransition(
      opacity: _pill_ctrl,
      child: _pillStrip(is_side),
    );

    final Widget positioned;
    switch (edge) {
      case 'right':
        positioned = Positioned(right: 0, top: 0, bottom: 0, child: pills);
      case 'bottom':
        positioned = Positioned(left: 0, right: 0, bottom: 0, child: pills);
      default: // 'left'
        positioned = Positioned(left: 0, top: 0, bottom: 0, child: pills);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _touchPills(),
      child: SafeArea(
        child: Stack(
          children: [
            _body(edge),
            positioned,
          ],
        ),
      ),
    );
  }

  Widget _body(String edge) {
    final s           = _active;
    final show_picker = s.is_idle && _active_id == _scratch;
    final saved_name  = _active_id != _scratch
        ? widget.config_service.config.saved_timers
            .where((t) => t.id == _active_id)
            .firstOrNull
            ?.name
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (saved_name != null) ...[
          Text(
            saved_name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
              color: Colors.white.withAlpha(120),
            ),
          ),
          const SizedBox(height: 10),
        ],
        show_picker ? _picker() : _displayText(s),
        const SizedBox(height: 48),
        _controls(s),
        if (edge == 'bottom') const SizedBox(height: 80),
      ],
    );
  }

  Widget _displayText(_TState s) => Text(
        _fmt(s.remaining),
        style: const TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w100,
          letterSpacing: 4,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );

  // ── scroll picker ──────────────────────────────────────────────────────────

  Widget _picker() {
    const item_h = 52.0;
    const picker_h = item_h * 5;

    Widget drum(
      FixedExtentScrollController ctrl,
      int count,
      ValueChanged<int> cb,
    ) =>
        SizedBox(
          width: 80,
          height: picker_h,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.2, 0.8, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: item_h,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: cb,
              perspective: 0.003,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (ctx, i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w100,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    Widget sep() => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w100,
              color: Colors.white54,
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        drum(_h_ctrl, 24, (v) => setState(() => _input_h = v)),
        sep(),
        drum(_m_ctrl, 60, (v) => setState(() => _input_m = v)),
        sep(),
        drum(_s_ctrl, 60, (v) => setState(() => _input_s = v)),
      ],
    );
  }

  // ── controls ───────────────────────────────────────────────────────────────

  Widget _controls(_TState s) {
    final show_picker = s.is_idle && _active_id == _scratch;

    // Fixed-width flanking slots keep the centre button visually centred.
    Widget left_slot() => SizedBox(
          width: 64,
          child: s.is_idle
              ? null
              : Center(
                  child: _IconBtn(
                      icon: Icons.refresh, onTap: _reset, size: 28)),
        );

    Widget right_slot() => SizedBox(
          width: 64,
          child: show_picker
              ? null
              : Center(child: _PillBtn(label: '+1m', onTap: _addMinute)),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        left_slot(),
        const SizedBox(width: 16),
        _BigBtn(
          icon: s.is_running ? Icons.pause : Icons.play_arrow,
          onTap: s.is_running ? _pause : _startOrResume,
        ),
        const SizedBox(width: 16),
        right_slot(),
      ],
    );
  }

  // ── pill strip ─────────────────────────────────────────────────────────────

  /// [is_side] = left or right edge → vertical strip; false = bottom → horizontal.
  Widget _pillStrip(bool is_side) {
    final saved = widget.config_service.config.saved_timers;

    if (is_side) {
      return SizedBox(
        width: 80,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          children: [
            ...saved.map((t) => _vPill(t)),
            _vAddPill(),
          ],
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          ...saved.map((t) => _hPill(t)),
          _hAddPill(),
        ],
      ),
    );
  }

  // ── vertical pill (left / right edge) ────────────────────────────────────

  Widget _vPill(SavedTimer t) {
    final state      = _states[t.id];
    final is_active  = _active_id == t.id;
    final is_running = state?.is_running ?? false;
    final is_live    = state != null && !state.is_idle;

    final time_str = is_live
        ? _fmt(state.remaining)
        : _fmtSecs(t.seconds);

    return GestureDetector(
      onTap: () { _touchPills(); _loadSaved(t); },
      onLongPress: () => _editSaved(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withAlpha(
              is_active ? (is_running ? 50 : 30) : (is_running ? 25 : 12)),
          border: Border.all(
            color: Colors.white
                .withAlpha(is_active ? 100 : (is_running ? 60 : 30)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white
                    .withAlpha(is_active ? 230 : (is_running ? 200 : 160)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time_str,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 0.5,
                color: Colors.white
                    .withAlpha(is_active ? 180 : (is_running ? 150 : 100)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vAddPill() => GestureDetector(
        onTap: () { _touchPills(); _addSaved(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Icon(Icons.add, color: Colors.white.withAlpha(100), size: 16),
        ),
      );

  // ── horizontal pill (bottom edge) ─────────────────────────────────────────

  Widget _hPill(SavedTimer t) {
    final state      = _states[t.id];
    final is_active  = _active_id == t.id;
    final is_running = state?.is_running ?? false;
    final is_live    = state != null && !state.is_idle;

    final label = is_live
        ? '${t.name}  ${_fmt(state.remaining)}'
        : '${t.name}  ${_fmtSecs(t.seconds)}';

    return GestureDetector(
      onTap: () { _touchPills(); _loadSaved(t); },
      onLongPress: () => _editSaved(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withAlpha(
              is_active ? (is_running ? 50 : 30) : (is_running ? 25 : 12)),
          border: Border.all(
            color: Colors.white
                .withAlpha(is_active ? 100 : (is_running ? 60 : 30)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white
                .withAlpha(is_active ? 230 : (is_running ? 180 : 140)),
          ),
        ),
      ),
    );
  }

  Widget _hAddPill() => GestureDetector(
        onTap: () { _touchPills(); _addSaved(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Icon(Icons.add, color: Colors.white.withAlpha(100), size: 16),
        ),
      );
}

// ── saved-timer sheet ─────────────────────────────────────────────────────────

Future<SavedTimer?> _showTimerSheet(
  BuildContext context, {
  SavedTimer? timer,
}) =>
    showModalBottomSheet<SavedTimer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedTimerSheet(timer: timer),
    );

class _SavedTimerSheet extends StatefulWidget {
  final SavedTimer? timer;
  const _SavedTimerSheet({this.timer});

  @override
  State<_SavedTimerSheet> createState() => _SavedTimerSheetState();
}

class _SavedTimerSheetState extends State<_SavedTimerSheet> {
  late TextEditingController _name_ctrl;
  late FixedExtentScrollController _h_ctrl, _m_ctrl, _s_ctrl;
  int _h = 0, _m = 5, _s = 0;

  bool get _is_edit => widget.timer != null;

  @override
  void initState() {
    super.initState();
    final t = widget.timer;
    _name_ctrl = TextEditingController(text: t?.name ?? '');
    if (t != null) {
      _h = t.seconds ~/ 3600;
      _m = (t.seconds % 3600) ~/ 60;
      _s = t.seconds % 60;
    }
    _h_ctrl = FixedExtentScrollController(initialItem: _h);
    _m_ctrl = FixedExtentScrollController(initialItem: _m);
    _s_ctrl = FixedExtentScrollController(initialItem: _s);
  }

  @override
  void dispose() {
    _name_ctrl.dispose();
    _h_ctrl.dispose();
    _m_ctrl.dispose();
    _s_ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final total = _h * 3600 + _m * 60 + _s;
    if (total == 0) return;
    final raw_name = _name_ctrl.text.trim();
    final name = resolveShortcodes(raw_name.isEmpty ? '⏱' : raw_name);
    Navigator.pop(
      context,
      SavedTimer(id: widget.timer?.id ?? '0', name: name, seconds: total),
    );
  }

  void _delete() => Navigator.pop(
        context,
        const SavedTimer(id: '__delete__', name: '', seconds: 0),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 16),
            _nameField(),
            const SizedBox(height: 4),
            _shortcodeHint(),
            const SizedBox(height: 24),
            _timePicker(),
            const SizedBox(height: 32),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _nameField() => TextField(
        controller: _name_ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: 'Name or emoji',
          hintStyle: TextStyle(color: Colors.white30),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54)),
        ),
      );

  Widget _shortcodeHint() => Text(
        ':tea:  :coffee:  :pomodoro:  :workout:  :todo:  :focus:  …',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withAlpha(60),
          letterSpacing: 0.3,
        ),
      );

  Widget _timePicker() {
    const item_h = 44.0;
    const picker_h = item_h * 5;

    Widget drum(
      FixedExtentScrollController ctrl,
      int count,
      ValueChanged<int> cb,
    ) =>
        SizedBox(
          width: 72,
          height: picker_h,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.2, 0.8, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: item_h,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: cb,
              perspective: 0.003,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (ctx, i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w100,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    Widget sep() => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w100,
              color: Colors.white54,
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        drum(_h_ctrl, 24, (v) => setState(() => _h = v)),
        sep(),
        drum(_m_ctrl, 60, (v) => setState(() => _m = v)),
        sep(),
        drum(_s_ctrl, 60, (v) => setState(() => _s = v)),
      ],
    );
  }

  Widget _actions() => Row(
        children: [
          if (_is_edit)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 22),
              onPressed: _delete,
              tooltip: 'Delete timer',
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_is_edit ? 'Save' : 'Add'),
          ),
        ],
      );
}

// ── shared control widgets ────────────────────────────────────────────────────

class _PillBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PillBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(77)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(178),
            ),
          ),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _IconBtn({required this.icon, required this.onTap, this.size = 24});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: Colors.white.withAlpha(178), size: size),
      );
}

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BigBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withAlpha(102), width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      );
}
