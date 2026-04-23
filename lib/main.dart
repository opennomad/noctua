import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'services/alarm_service.dart';
import 'config/config_service.dart';
import 'screens/alarm/alarm_dismiss_sheet.dart';
import 'screens/clock/clock_screen.dart';
import 'screens/clock/world_clock_screen.dart';
import 'screens/alarm/alarm_screen.dart';
import 'screens/timer/timer_screen.dart';
import 'screens/timer/stopwatch_screen.dart';
import 'theme/fonts.dart';
import 'widgets/settings_overlay.dart';
import 'widgets/stack_nav.dart';

// Global navigator key — lets the keyboard handler detect open modals/sheets.
final _nav_key = GlobalKey<NavigatorState>();

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  if (Platform.isAndroid) {
    final tz_info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tz_info.identifier));
  }
  final config_service = ConfigService();
  await config_service.load();

await AlarmService.init(
      alarm_sound:  config_service.config.alarm_sound,
      timer_sound:  config_service.config.timer_sound,
      snooze_mins:  config_service.config.alarm_snooze_minutes,
      add_mins:     config_service.config.timer_add_minutes,
      countdown:   config_service.config.alarm_countdown,
      countdown_within_hours: config_service.config.alarm_countdown_within_hours,
      alarms:       config_service.config.alarms,
    );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(NoctuaApp(config_service: config_service));
}

class NoctuaApp extends StatelessWidget {
  final ConfigService config_service;

  const NoctuaApp({super.key, required this.config_service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noctua',
      debugShowCheckedModeBanner: false,
      navigatorKey: _nav_key,
      theme: ThemeData.dark(useMaterial3: true),
      scrollBehavior: _DragScrollBehavior(),
      home: ListenableBuilder(
        listenable: config_service,
        builder: (context, _) => NoctuaHome(
          config: config_service.config,
          config_service: config_service,
        ),
      ),
    );
  }
}

// ── NoctuaHome ────────────────────────────────────────────────────────────────

class NoctuaHome extends StatefulWidget {
  final NoctuaConfig config;
  final ConfigService config_service;

  const NoctuaHome({
    super.key,
    required this.config,
    required this.config_service,
  });

  @override
  State<NoctuaHome> createState() => _NoctuaHomeState();
}

class _NoctuaHomeState extends State<NoctuaHome> with WidgetsBindingObserver {
  final _stack_ctrl = StackNavController();
  StreamSubscription<AlarmEvent>? _alarm_sub;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _alarm_sub = AlarmService.events.listen(_onAlarmEvent);
    widget.config_service.addListener(_onConfigChanged);
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: request runtime permissions, then check whether
    // AlarmRingtoneService is currently ringing (covers both cold-launch and
    // the case where the app was started by AlarmFireReceiver).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmService.requestPermissions();
      AlarmService.checkRinging();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On every warm resume: check if an alarm is ringing and show dismiss sheet.
    if (state == AppLifecycleState.resumed) AlarmService.checkRinging();
  }

  void _onConfigChanged() {
    final cfg = widget.config_service.config;
    AlarmService.updateSounds(
      alarm:        cfg.alarm_sound,
      timer:        cfg.timer_sound,
      snooze_mins:  cfg.alarm_snooze_minutes,
      add_mins:     cfg.timer_add_minutes,
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _alarm_sub?.cancel();
    widget.config_service.removeListener(_onConfigChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAlarmEvent(AlarmEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case AlarmEventType.tapped:
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => AlarmDismissSheet(label: event.label, notif_id: event.notif_id),
        );
      case AlarmEventType.dismissed:
        Navigator.of(context).maybePop();
      case AlarmEventType.snoozed:
        break;
    }
  }

  // Builds a modifier-aware key label: e.g. 'Ctrl+q', 'Arrow Right'.
  static String _buildKeyLabel(KeyEvent event) {
    final parts = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
    if (HardwareKeyboard.instance.isAltPressed)     parts.add('Alt');
    if (HardwareKeyboard.instance.isShiftPressed)   parts.add('Shift');
    final base = event.logicalKey.keyLabel;
    if (base.isNotEmpty) parts.add(base.toLowerCase());
    return parts.join('+');
  }

  void _quit() {
    if (Platform.isLinux) {
      exit(0);
    } else {
      SystemNavigator.pop();
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final kb    = widget.config.key_bindings;
    if (!kb.enabled) return false;

    final label = _buildKeyLabel(event);
    final key  = event.logicalKey;

    // Quit is handled before any focus guard — it always works.
    if (label == kb.quit || _matchesQuit(key)) { _quit(); return true; }

    // Don't navigate while a modal/sheet/dialog is in front.
    if (_nav_key.currentState?.canPop() ?? false) return false;

    // Don't navigate while a text field is active.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return false;
    }

    if (label == kb.nav_next || _matchesNavNext(key)) { _stack_ctrl.goNext(); return true; }
    if (label == kb.nav_prev || _matchesNavPrev(key)) { _stack_ctrl.goPrev(); return true; }
    return false;
  }

  static bool _matchesQuit(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.keyQ &&
      HardwareKeyboard.instance.isControlPressed;

  static bool _matchesNavNext(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowRight;

  static bool _matchesNavPrev(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowLeft;

  Widget _buildScreen(String id) => switch (id) {
    'clock'       => ClockScreen(config_service: widget.config_service),
    'world_clock' => WorldClockScreen(config_service: widget.config_service),
    'alarm'       => AlarmScreen(config_service: widget.config_service),
    'timer'       => TimerScreen(config_service: widget.config_service),
    'stopwatch'   => const StopwatchScreen(),
    _             => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    final cfg        = widget.config;
    final base_theme = Theme.of(context);
    return Theme(
      data: base_theme.copyWith(
        textTheme: applyFont(cfg.font, base_theme.textTheme),
      ),
      child: Scaffold(
        body: SettingsOverlay(
          config_service: widget.config_service,
          child: StackNav(
            controller:       _stack_ctrl,
            slots:            cfg.screens,
            animation:        cfg.animation,
            animation_params: cfg.paramsFor(cfg.animation),
            color_mode:       cfg.color_mode,
            screenBuilder:    _buildScreen,
          ),
        ),
      ),
    );
  }
}
