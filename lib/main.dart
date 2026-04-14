import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'services/alarm_service.dart';
import 'config/config_service.dart';
import 'screens/column_page.dart';
import 'screens/clock/clock_screen.dart';
import 'screens/clock/world_clock_screen.dart';
import 'screens/alarm/alarm_screen.dart';
import 'screens/alarm/night_clock_screen.dart';
import 'screens/timer/timer_screen.dart';
import 'screens/timer/stopwatch_screen.dart';
import 'theme/color_schemes.dart';
import 'theme/fonts.dart';
import 'widgets/settings_overlay.dart';

// Global navigator key — lets the keyboard handler detect open modals/sheets.
final _nav_key = GlobalKey<NavigatorState>();

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  await AlarmService.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final config_service = ConfigService();
  await config_service.load();

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

class _NoctuaHomeState extends State<NoctuaHome> {
  late final PageController _page_ctrl;
  final _col_ctrls = List.generate(3, (_) => ColumnPageController());

  @override
  void initState() {
    super.initState();
    _page_ctrl = PageController();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _page_ctrl.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final kb = widget.config.key_bindings;
    if (!kb.enabled) return false;

    // Don't navigate while a modal/sheet/dialog is in front.
    if (_nav_key.currentState?.canPop() ?? false) return false;

    // Don't navigate while a text field is active.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return false;
    }

    final label = event.logicalKey.keyLabel;
    final page  = _page_ctrl.page?.round() ?? 0;

    if (label == kb.nav_left) {
      _page_ctrl.animateToPage(
        (page - 1).clamp(0, 2),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return true;
    }
    if (label == kb.nav_right) {
      _page_ctrl.animateToPage(
        (page + 1).clamp(0, 2),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return true;
    }
    if (label == kb.nav_up) {
      _col_ctrls[page].goToPrimary();
      return true;
    }
    if (label == kb.nav_down) {
      _col_ctrls[page].goToSecondary();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cfg     = widget.config;
    final schemes = cfg.columns.map((c) => schemeByName(c.scheme)).toList();

    final base_theme = Theme.of(context);
    return Theme(
      data: base_theme.copyWith(
        textTheme: applyFont(cfg.font, base_theme.textTheme),
      ),
      child: Scaffold(
        body: SettingsOverlay(
          config_service: widget.config_service,
          child: PageView(
            controller: _page_ctrl,
            scrollDirection: Axis.horizontal,
            physics: const PageScrollPhysics(),
            children: [
              ColumnPage(
                controller: _col_ctrls[0],
                scheme: schemes[0],
                animation: cfg.animation,
                animation_params: cfg.animation_params,
                primaryScreen: const ClockScreen(),
                secondaryScreen:
                    WorldClockScreen(config_service: widget.config_service),
              ),
              ColumnPage(
                controller: _col_ctrls[1],
                scheme: schemes[1],
                animation: cfg.animation,
                animation_params: cfg.animation_params,
                primaryScreen:
                    AlarmScreen(config_service: widget.config_service),
                secondaryScreen: const NightClockScreen(),
              ),
              ColumnPage(
                controller: _col_ctrls[2],
                scheme: schemes[2],
                animation: cfg.animation,
                animation_params: cfg.animation_params,
                primaryScreen:
                    TimerScreen(config_service: widget.config_service),
                secondaryScreen: const StopwatchScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
