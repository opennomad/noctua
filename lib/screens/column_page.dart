import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/animated_background.dart';
import '../theme/color_schemes.dart';
import '../config/noctua_config.dart';

/// Exposes programmatic vertical navigation for a [ColumnPage].
/// Assign one instance per column; pass it to [ColumnPage] and call
/// [goToPrimary] / [goToSecondary] from the keyboard handler.
class ColumnPageController {
  VoidCallback? _go_primary;
  VoidCallback? _go_secondary;

  void goToPrimary()   => _go_primary?.call();
  void goToSecondary() => _go_secondary?.call();
}

class ColumnPage extends StatefulWidget {
  final NoctuaColorScheme scheme;
  final Widget primaryScreen;
  final Widget secondaryScreen;
  final String animation;
  final AnimationParams animation_params;
  final ColumnPageController? controller;

  const ColumnPage({
    super.key,
    required this.scheme,
    required this.primaryScreen,
    required this.secondaryScreen,
    required this.animation,
    required this.animation_params,
    this.controller,
  });

  @override
  State<ColumnPage> createState() => _ColumnPageState();
}

class _ColumnPageState extends State<ColumnPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Offset _pointer_start = Offset.zero;
  bool? _is_vertical; // null = undecided, true = vertical, false = horizontal
  double _last_delta_y = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    widget.controller?._go_primary   = _goToPrimary;
    widget.controller?._go_secondary = _goToSecondary;
  }

  void _goToPrimary() => _controller.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  void _goToSecondary() => _controller.animateTo(
        1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointer_start = e.position;
    _is_vertical = null;
    _last_delta_y = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_is_vertical == null) {
      final dx = (e.position.dx - _pointer_start.dx).abs();
      final dy = (e.position.dy - _pointer_start.dy).abs();
      if (dx + dy > kTouchSlop) {
        _is_vertical = dy >= dx;
      }
    }

    if (_is_vertical == true) {
      final screen_h = MediaQuery.of(context).size.height;
      _controller.value =
          (_controller.value - e.delta.dy / screen_h).clamp(0.0, 1.0);
      _last_delta_y = e.delta.dy;
    }
  }

  void _snap() {
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeOut;
    if (_controller.value > 0.5 || _last_delta_y < -2) {
      _controller.animateTo(1.0, duration: duration, curve: curve);
    } else {
      _controller.animateTo(0.0, duration: duration, curve: curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary_offset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(_controller);

    final secondary_offset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(_controller);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _snap(),
      onPointerCancel: (_) => _snap(),
      child: Stack(
        children: [
          AnimatedBackground(
            scheme: widget.scheme,
            animation: widget.animation,
            params: widget.animation_params,
          ),
          SlideTransition(
            position: primary_offset,
            child: widget.primaryScreen,
          ),
          SlideTransition(
            position: secondary_offset,
            child: widget.secondaryScreen,
          ),
        ],
      ),
    );
  }
}
