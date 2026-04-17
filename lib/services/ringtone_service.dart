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

/// Cross-platform sound catalogue + preview playback.
///
/// On Android calls the native `noctua/ringtones` method channel.
/// On Linux    scans `/usr/share/sounds/freedesktop/stereo/`.
class RingtoneService {
  static const _channel = MethodChannel('noctua/ringtones');

  static const _linux_sound_dir =
      '/usr/share/sounds/freedesktop/stereo';

  // Active paplay process for Linux preview.
  static Process? _linux_preview;

  /// Convert a freedesktop filename stem to a human-readable title.
  /// e.g. 'alarm-clock-elapsed' → 'Alarm Clock Elapsed'
  static String _stemToTitle(String stem) => stem
      .split('-')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  // ── catalogue ──────────────────────────────────────────────────────────────

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

  // ── preview ────────────────────────────────────────────────────────────────

  /// Play [uri] as a one-shot preview.  Stops any currently playing preview
  /// first.  Pass an empty [uri] to play the platform default alarm sound.
  static Future<void> preview(String uri) async {
    await stopPreview();
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('preview', {'uri': uri});
      } on PlatformException {
        // ignore — best-effort
      }
    } else if (Platform.isLinux) {
      final path = uri.isNotEmpty ? uri : _linuxDefaultSound();
      if (path != null) {
        _linux_preview = await Process.start('paplay', [path]);
        _linux_preview!.exitCode.then((_) => _linux_preview = null);
      }
    }
  }

  /// Stop any currently playing preview.
  static Future<void> stopPreview() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('stopPreview');
      } on PlatformException {
        // ignore
      }
    } else if (Platform.isLinux) {
      _linux_preview?.kill();
      _linux_preview = null;
    }
  }

  /// First .oga file in the Linux sound dir — fallback for "Default".
  static String? _linuxDefaultSound() {
    final dir = Directory(_linux_sound_dir);
    if (!dir.existsSync()) return null;
    final files = dir.listSync().whereType<File>()
        .where((f) => f.path.endsWith('.oga') || f.path.endsWith('.wav'))
        .toList()..sort((a, b) => a.path.compareTo(b.path));
    return files.isNotEmpty ? files.first.path : null;
  }
}
