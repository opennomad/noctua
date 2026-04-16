import 'dart:io';
import 'package:flutter/services.dart';

/// A sound the user can select for alarms or timers.
class RingtoneEntry {
  final String title;

  /// On Android: a content URI string.
  /// On Linux:   an absolute file path.
  final String uri;

  const RingtoneEntry({required this.title, required this.uri});
}

/// Cross-platform sound catalogue.
///
/// On Android calls the native `noctua/ringtones` method channel.
/// On Linux    scans `/usr/share/sounds/freedesktop/stereo/`.
class RingtoneService {
  static const _channel = MethodChannel('noctua/ringtones');

  static const _linux_sound_dir =
      '/usr/share/sounds/freedesktop/stereo';

  /// Convert a freedesktop filename stem to a human-readable title.
  /// e.g. 'alarm-clock-elapsed' → 'Alarm Clock Elapsed'
  static String _stemToTitle(String stem) => stem
      .split('-')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Fetch the list of available sounds for [type] ('alarm' or 'notification').
  ///
  /// Returns an empty list if the platform has no sounds available.
  static Future<List<RingtoneEntry>> list({String type = 'alarm'}) async {
    if (Platform.isAndroid) {
      return _listAndroid(type);
    } else if (Platform.isLinux) {
      return _listLinux();
    }
    return [];
  }

  static Future<List<RingtoneEntry>> _listAndroid(String type) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
          'list', {'type': type});
      if (raw == null) return [];
      return raw
          .cast<Map>()
          .map((m) => RingtoneEntry(
                title: m['title'] as String,
                uri:   m['uri']   as String,
              ))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  static List<RingtoneEntry> _listLinux() {
    final dir = Directory(_linux_sound_dir);
    if (!dir.existsSync()) return [];

    final entries = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.oga') || f.path.endsWith('.wav'))
        .map((f) {
          final filename = f.uri.pathSegments.last;
          final stem = filename.contains('.')
              ? filename.substring(0, filename.lastIndexOf('.'))
              : filename;
          return RingtoneEntry(title: _stemToTitle(stem), uri: f.path);
        })
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return entries;
  }
}
