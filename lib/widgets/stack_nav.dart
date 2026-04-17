import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../config/noctua_config.dart';
import '../theme/color_schemes.dart';
import 'animated_background.dart';

/// Exposes programmatic forward / backward navigation for a [StackNav].
class StackNavController {
  VoidCallback? _go_next;
  VoidCallback? _go_prev;

  void goNext() => _go_next?.call();
  void goPrev() => _go_prev?.call();
}

class StackNav extends StatefulWidget {
  final List<ScreenSlot> slots;
  final String animation;
  final AnimationParams animation_params;
  final String color_mode;
  final StackNavController? controller;
  final Widget Function(String id) screenBuilder;

  const StackNav({
    super.key,
    required this.slots,
    required this.animation,
    required this.animation_params,
    required this.screenBuilder,
    this.color_mode = 'dark',
    this.controller,
  });

  @override
  State<StackNav> createState() => _StackNavState();
}

class _StackNavState extends State<StackNav> with TickerProviderStateMixin {
  // ── animation time (shared across both backgrounds) ───────────────────────
  final _anim_t = ValueNotifier<double>(0.0);
  late Ticker _anim_ticker;

  // ── navigation controller ─────────────────────────────────────────────────
  late AnimationController _ctrl;

  // Background flip-flop ── two ABs always alive and in phase.
  int  _a_page     = 0;
  int  _b_page     = 0;
  bool _a_is_front = true;

  // Foreground.
  int _front_page  = 0;
  int _target_page = 0;

  // Per-id GlobalKeys: screen State survives tree restructuring.
  final _screen_keys = <String, GlobalKey>{};

  // Crossfade animations (shared easeInOut base keeps them symmetric).
  late final CurvedAnimation _eased =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  late final Animation<double> _fg_out = ReverseAnimation(_eased);
  late final Animation<double> _fg_in  = _eased;

  // ── pills controller ──────────────────────────────────────────────────────
  late AnimationController _pills_ctrl;
  late CurvedAnimation     _pills_fade;
  Timer? _pills_timer;

  static const _pills_hide_delay = Duration(seconds: 3);
  static const _pills_fade_ms    = Duration(milliseconds: 300);

  static const _icons = <String, IconData>{
    'clock':       Icons.access_time,
    'world_clock': Icons.language,
    'alarm':       Icons.alarm,
    'night_clock': Icons.bedtime,
    'timer':       Icons.timer,
    'stopwatch':   Icons.av_timer,
  };

  // ── drag tracking ─────────────────────────────────────────────────────────
  double _drag_origin  = 0;
  bool?  _drag_forward;

  List<ScreenSlot> get _active =>
      widget.slots.where((s) => s.enabled).toList();

  GlobalKey _keyFor(String id) =>
      _screen_keys.putIfAbsent(id, () => GlobalKey());

  Widget _keyedScreen(String id) => KeyedSubtree(
        key: _keyFor(id),
        child: widget.screenBuilder(id),
      );

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _anim_ticker = createTicker(
        (elapsed) => _anim_t.value = elapsed.inMicroseconds / 1e6)
      ..start();
    _ctrl = AnimationController(vsync: this);
    _pills_ctrl = AnimationController(vsync: this, duration: _pills_fade_ms);
    _pills_fade = CurvedAnimation(parent: _pills_ctrl, curve: Curves.easeInOut);
    _registerController();
  }

  @override
  void didUpdateWidget(StackNav old) {
    super.didUpdateWidget(old);
    _registerController();
    final n = _active.length;
    if (n > 0) {
      _front_page  = _front_page.clamp(0, n - 1);
      _target_page = _target_page.clamp(0, n - 1);
      _a_page      = _a_page.clamp(0, n - 1);
      _b_page      = _b_page.clamp(0, n - 1);
    }
  }

  void _registerController() {
    widget.controller?._go_next = _goNext;
    widget.controller?._go_prev = _goPrev;
  }

  @override
  void dispose() {
    _anim_ticker.dispose();
    _anim_t.dispose();
    _pills_timer?.cancel();
    _pills_fade.dispose();
    _pills_ctrl.dispose();
    _eased.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ── pills show / hide ─────────────────────────────────────────────────────

  void _onTouch(PointerDownEvent _) {
    _pills_ctrl.forward();
    _pills_timer?.cancel();
    _pills_timer = Timer(_pills_hide_delay, () {
      if (mounted) _pills_ctrl.reverse();
    });
  }

  // ── navigation ────────────────────────────────────────────────────────────

  void _goNext() {
    final n = _active.length;
    if (n < 2) return;
    _navigate((_front_page + 1) % n);
  }

  void _goPrev() {
    final n = _active.length;
    if (n < 2) return;
    _navigate((_front_page - 1 + n) % n);
  }

  void _navigate(int target) {
    if (_ctrl.isAnimating || target == _front_page) return;
    _prepareTransition(target);
    _ctrl
        .animateTo(1.0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.linear)
        .then((_) => _commitTransition(target));
  }

  // ── gesture handling ──────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails d) {
    if (_ctrl.isAnimating) return;
    _drag_origin  = d.localPosition.dx;
    _drag_forward = null;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_ctrl.isAnimating) return;
    final active = _active;
    if (active.length < 2) return;

    final delta = d.localPosition.dx - _drag_origin;
    if (_drag_forward == null && delta.abs() > 6) {
      _drag_forward = delta < 0;
      _prepareTransition(_drag_forward!
          ? (_front_page + 1) % active.length
          : (_front_page - 1 + active.length) % active.length);
    }
    if (_drag_forward != null) {
      final w = MediaQuery.of(context).size.width;
      _ctrl.value = (delta.abs() / w).clamp(0.0, 1.0);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_drag_forward == null) return;
    final vel    = d.primaryVelocity ?? 0;
    final commit = _ctrl.value > 0.4 ||
        (_drag_forward! && vel < -400) ||
        (!_drag_forward! && vel > 400);
    if (commit) {
      _ctrl
          .animateTo(1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut)
          .then((_) => _commitTransition(_target_page));
    } else {
      _ctrl
          .animateTo(0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut)
          .then((_) {
        if (!mounted) return;
        setState(() {
          _a_page = _b_page = _target_page = _front_page;
        });
      });
    }
  }

  // ── transition helpers ────────────────────────────────────────────────────

  void _prepareTransition(int target) {
    setState(() {
      _target_page = target;
      if (_a_is_front) { _b_page = target; } else { _a_page = target; }
    });
  }

  void _commitTransition(int target) {
    if (!mounted) return;
    setState(() {
      _front_page = _target_page = target;
      _a_is_front = !_a_is_front;
      _a_page = _b_page = target;
      _ctrl.value = 0;
    });
  }

  // ── pills overlay ─────────────────────────────────────────────────────────

  Widget _pillDot(int index, ScreenSlot slot) {
    final is_current = index == _front_page;
    final icon = _icons[slot.id] ?? Icons.circle_outlined;
    return GestureDetector(
      onTap: () => _navigate(index),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: is_current
              ? Colors.white.withAlpha(30)
              : Colors.transparent,
          border: Border.all(
            color: is_current
                ? Colors.white.withAlpha(180)
                : Colors.white.withAlpha(50),
            width: is_current ? 1.5 : 1.0,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: is_current
              ? Colors.white.withAlpha(220)
              : Colors.white.withAlpha(90),
        ),
      ),
    );
  }

  Widget _pillsOverlay(List<ScreenSlot> active) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 56,
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _pills_ctrl,
            builder: (context, child) => IgnorePointer(
              ignoring: _pills_ctrl.value < 0.01,
              child: FadeTransition(opacity: _pills_fade, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < active.length; i++)
                  _pillDot(i, active[i]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  bool _effectiveLight(BuildContext context) {
    switch (widget.color_mode) {
      case 'light':  return true;
      case 'system': return MediaQuery.platformBrightnessOf(context) == Brightness.light;
      default:       return false;
    }
  }

  Widget _bg(ScreenSlot slot, bool light) => AnimatedBackground(
        scheme: schemeByName(light ? slot.light_scheme : slot.scheme, light: light),
        animation: widget.animation,
        params: widget.animation_params,
        time: _anim_t,
      );

  /// Wraps the keyed screen with the correct [NoctuaSchemeScope] so all
  /// descendant widgets can read [noctuaText(context)].
  Widget _scopedScreen(ScreenSlot slot, bool light) => NoctuaSchemeScope(
        scheme: schemeByName(light ? slot.light_scheme : slot.scheme, light: light),
        child: _keyedScreen(slot.id),
      );

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active.isEmpty) return const SizedBox.shrink();

    final light  = _effectiveLight(context);
    final n      = active.length;
    final f_slot  = active[_front_page.clamp(0, n - 1)];
    final tg_slot = active[_target_page.clamp(0, n - 1)];
    final slot_a  = active[_a_page.clamp(0, n - 1)];
    final slot_b  = active[_b_page.clamp(0, n - 1)];

    final front_w  = _scopedScreen(f_slot, light);
    final target_w = _front_page != _target_page
        ? _scopedScreen(tg_slot, light)
        : null;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onTouch,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart:  _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd:    _onDragEnd,
        child: Stack(
          children: [
            // ── animated screens ────────────────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t    = _ctrl.value;
                final op_a = (_a_is_front ? 1.0 - t : t).clamp(0.0, 1.0);
                final op_b = (_a_is_front ? t : 1.0 - t).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Opacity(opacity: op_a, child: _bg(slot_a, light)),
                    Opacity(opacity: op_b, child: _bg(slot_b, light)),
                    if (target_w != null)
                      FadeTransition(opacity: _fg_in, child: target_w),
                    FadeTransition(opacity: _fg_out, child: front_w),
                  ],
                );
              },
            ),
            // ── navigation pills ────────────────────────────────────────
            _pillsOverlay(active),
          ],
        ),
      ),
    );
  }
}
