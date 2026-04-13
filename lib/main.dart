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

class NoctuaHome extends StatelessWidget {
  final NoctuaConfig config;
  final ConfigService config_service;

  const NoctuaHome({
    super.key,
    required this.config,
    required this.config_service,
  });

  @override
  Widget build(BuildContext context) {
    final schemes = config.columns.map((c) => schemeByName(c.scheme)).toList();

    final base_theme = Theme.of(context);
    return Theme(
      data: base_theme.copyWith(
        textTheme: applyFont(config.font, base_theme.textTheme),
      ),
      child: Scaffold(
      body: SettingsOverlay(
        config_service: config_service,
        child: PageView(
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics(),
          children: [
            ColumnPage(
              scheme: schemes[0],
              animation: config.animation,
              animation_params: config.animation_params,
              primaryScreen: const ClockScreen(),
              secondaryScreen: WorldClockScreen(config_service: config_service),
            ),
            ColumnPage(
              scheme: schemes[1],
              animation: config.animation,
              animation_params: config.animation_params,
              primaryScreen: AlarmScreen(config_service: config_service),
              secondaryScreen: const NightClockScreen(),
            ),
            ColumnPage(
              scheme: schemes[2],
              animation: config.animation,
              animation_params: config.animation_params,
              primaryScreen: const TimerScreen(),
              secondaryScreen: const StopwatchScreen(),
            ),
          ],
        ),
      ),
    ));
  }
}
