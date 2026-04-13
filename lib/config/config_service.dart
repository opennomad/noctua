import 'dart:convert';
import 'dart:io';
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

  Future<void> setWorldClocks(List<ZoneConfig> zones) async {
    _config = _config.copyWith(world_clocks: zones);
    notifyListeners();
    await save();
  }

  Future<void> setFont(String font) async {
    _config = _config.copyWith(font: font);
    notifyListeners();
    await save();
  }

  Future<void> setColumnScheme(int column_index, String scheme) async {
    final cols = List<ColumnConfig>.from(_config.columns);
    cols[column_index] = cols[column_index].copyWith(scheme: scheme);
    _config = _config.copyWith(columns: cols);
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
  void setAnimationParamsLive(AnimationParams params) {
    _config = _config.copyWith(animation_params: params);
    notifyListeners();
  }

  Future<void> setAnimationParams(AnimationParams params) async {
    _config = _config.copyWith(animation_params: params);
    notifyListeners();
    await save();
  }
}
