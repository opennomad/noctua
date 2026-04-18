import 'dart:async';
import 'package:flutter/material.dart';
import '../config/config_service.dart';
import '../screens/settings_panel.dart';

/// Wraps any child and overlays a translucent gear icon that fades in on any
/// touch and hides itself after [_hide_delay] of inactivity.
///
/// Uses a [Listener] so the touch detection never enters the gesture arena and
/// never blocks swipe or tap events in the child widget tree.
class SettingsOverlay extends StatefulWidget {
  final Widget child;
  final ConfigService config_service;

  const SettingsOverlay({
    super.key,
    required this.child,
    required this.config_service,
  });

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay>
    with SingleTickerProviderStateMixin {
  static const _hide_delay = Duration(seconds: 3);
  static const _fade_ms    = Duration(milliseconds: 350);

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _fade_ms);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onTouch(_) {
    _ctrl.forward();
    _timer?.cancel();
    _timer = Timer(_hide_delay, () => _ctrl.reverse());
  }

  void _openSettings() {
    _timer?.cancel();
    _ctrl.reverse();
    showSettingsPanel(context, widget.config_service);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.config_service.config.color_mode;
    final is_light = mode == 'light' ||
        (mode == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final icon_color = is_light
        ? const Color(0xFF1A1A2E).withAlpha(200)
        : Colors.white.withAlpha(160);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onTouch,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: FadeTransition(
                opacity: _fade,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  iconSize: 22,
                  color: icon_color,
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
