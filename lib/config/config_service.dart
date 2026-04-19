import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xdg_directories/xdg_directories.dart';
import 'noctua_config.dart';

export 'noctua_config.dart';

class ConfigService extends ChangeNotifier {
  static const _filename = 'noctua_config.json';

  NoctuaConfig _config = NoctuaConfig.defaults;
  NoctuaConfig get config => _config;

  // ── I/O ──────────────────────────────────────────────────────────────────

  Future<File> _file() async {
    final Directory dir;
    if (Platform.isLinux) {
      dir = Directory('${configHome.path}/noctua');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    await dir.create(recursive: true);
    return File('${dir.path}/$_filename');
  }

  /// Load config from disk; falls back to defaults on missing file or parse
  /// error so the app always starts cleanly.
  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _config = NoctuaConfig.fromJson(json);
      }
    } catch (_) {
      _config = NoctuaConfig.defaults;
    }
    notifyListeners();
  }

  /// Write current config to disk as indented JSON.
  Future<void> save() async {
    final file = await _file();
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(_config.toJson()));
  }

  // ── Mutations (notify + persist on every change) ──────────────────────────

  // ── Alarm helpers ─────────────────────────────────────────────────────────

  /// Generate the next unused integer alarm ID.
  String _next_alarm_id() {
    if (_config.alarms.isEmpty) return '1';
    final max_id = _config.alarms
        .map((a) => int.tryParse(a.id) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return '${max_id + 1}';
  }

  Future<void> addAlarm(AlarmConfig alarm) async {
    final with_id = alarm.copyWith(id: _next_alarm_id());
    _config = _config.copyWith(alarms: [..._config.alarms, with_id]);
    notifyListeners();
    await save();
  }

  Future<void> updateAlarm(AlarmConfig alarm) async {
    final updated = _config.alarms.map((a) => a.id == alarm.id ? alarm : a).toList();
    _config = _config.copyWith(alarms: updated);
    notifyListeners();
    await save();
  }

  Future<void> deleteAlarm(String id) async {
    _config = _config.copyWith(
        alarms: _config.alarms.where((a) => a.id != id).toList());
    notifyListeners();
    await save();
  }

  // ── SavedTimer helpers ────────────────────────────────────────────────────

  String _next_timer_id() {
    if (_config.saved_timers.isEmpty) return '1';
    final max_id = _config.saved_timers
        .map((t) => int.tryParse(t.id) ?? 0)
        .reduce(max);
    return '${max_id + 1}';
  }

  Future<void> addSavedTimer(SavedTimer timer) async {
    final with_id = SavedTimer(
        id: _next_timer_id(), name: timer.name, seconds: timer.seconds);
    _config = _config.copyWith(
        saved_timers: [..._config.saved_timers, with_id]);
    notifyListeners();
    await save();
  }

  Future<void> updateSavedTimer(SavedTimer timer) async {
    _config = _config.copyWith(
      saved_timers: _config.saved_timers
          .map((t) => t.id == timer.id ? timer : t)
          .toList(),
    );
    notifyListeners();
    await save();
  }

  // ── Screen helpers ────────────────────────────────────────────────────────

  Future<void> setScreens(List<ScreenSlot> screens) async {
    _config = _config.copyWith(screens: screens);
    notifyListeners();
    await save();
  }

  Future<void> setScreenEnabled(String id, bool enabled) async {
    final updated = _config.screens
        .map((s) => s.id == id ? s.copyWith(enabled: enabled) : s)
        .toList();
    _config = _config.copyWith(screens: updated);
    notifyListeners();
    await save();
  }

  Future<void> setScreenScheme(String id, String scheme) async {
    final updated = _config.screens
        .map((s) => s.id == id ? s.copyWith(scheme: scheme) : s)
        .toList();
    _config = _config.copyWith(screens: updated);
    notifyListeners();
    await save();
  }

  Future<void> setScreenLightScheme(String id, String scheme) async {
    final updated = _config.screens
        .map((s) => s.id == id ? s.copyWith(light_scheme: scheme) : s)
        .toList();
    _config = _config.copyWith(screens: updated);
    notifyListeners();
    await save();
  }

  Future<void> setKeyBindings(KeyBindings kb) async {
    _config = _config.copyWith(key_bindings: kb);
    notifyListeners();
    await save();
  }

  Future<void> setTimerPillEdge(String edge) async {
    _config = _config.copyWith(timer_pill_edge: edge);
    notifyListeners();
    await save();
  }

  Future<void> deleteSavedTimer(String id) async {
    _config = _config.copyWith(
        saved_timers: _config.saved_timers.where((t) => t.id != id).toList());
    notifyListeners();
    await save();
  }

  Future<void> setWorldClocks(List<ZoneConfig> zones) async {
    _config = _config.copyWith(world_clocks: zones);
    notifyListeners();
    await save();
  }

  Future<void> setAlarmSound(String uri) async {
    _config = _config.copyWith(alarm_sound: uri);
    notifyListeners();
    await save();
  }

  Future<void> setTimerSound(String uri) async {
    _config = _config.copyWith(timer_sound: uri);
    notifyListeners();
    await save();
  }

  Future<void> setTimeFormat(String fmt) async {
    _config = _config.copyWith(time_format: fmt);
    notifyListeners();
    await save();
  }

  Future<void> setColorMode(String mode) async {
    _config = _config.copyWith(color_mode: mode);
    notifyListeners();
    await save();
  }

  Future<void> setShowLocalTime(bool value) async {
    _config = _config.copyWith(show_local_time: value);
    notifyListeners();
    await save();
  }

  Future<void> setNightMode(bool value) async {
    _config = _config.copyWith(night_mode: value);
    notifyListeners();
    await save();
  }

  Future<void> setFont(String font) async {
    _config = _config.copyWith(font: font);
    notifyListeners();
    await save();
  }

  Future<void> setAnimation(String animation) async {
    _config = _config.copyWith(animation: animation);
    notifyListeners();
    await save();
  }

  /// Update params and notify listeners without writing to disk — use during
  /// slider drag for a live preview.  Call [setAnimationParams] on drag end.
  void setAnimationParamsLive(String animation, AnimationParams params) {
    _config = _config.copyWith(
      animation_params_map: {..._config.animation_params_map, animation: params},
    );
    notifyListeners();
  }

  Future<void> setAnimationParams(String animation, AnimationParams params) async {
    _config = _config.copyWith(
      animation_params_map: {..._config.animation_params_map, animation: params},
    );
    notifyListeners();
    await save();
  }
}
