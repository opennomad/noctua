import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:xdg_directories/xdg_directories.dart';

/// Snapshot of a single timer's runtime state for persistence.
class TimerSnapshot {
  final String id;
  final int    total_seconds;
  final String status;      // 'running' | 'paused' | 'done'
  final int?   deadline_ms; // epoch ms when timer fires — set when running
  final int?   remaining_s; // seconds remaining at save time — set when paused/done

  const TimerSnapshot({
    required this.id,
    required this.total_seconds,
    required this.status,
    this.deadline_ms,
    this.remaining_s,
  });

  factory TimerSnapshot.fromJson(Map<String, dynamic> j) => TimerSnapshot(
        id:            j['id']            as String? ?? '',
        total_seconds: j['total_seconds'] as int?    ?? 0,
        status:        j['status']        as String? ?? 'paused',
        deadline_ms:   j['deadline_ms']   as int?,
        remaining_s:   j['remaining_s']   as int?,
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'total_seconds': total_seconds,
        'status':        status,
        if (deadline_ms != null) 'deadline_ms': deadline_ms,
        if (remaining_s != null) 'remaining_s': remaining_s,
      };
}

/// Full timer screen session snapshot.
class TimerSession {
  final String            active_id;
  final int               input_h, input_m, input_s;
  final List<TimerSnapshot> timers;

  const TimerSession({
    required this.active_id,
    this.input_h = 0,
    this.input_m = 5,
    this.input_s = 0,
    required this.timers,
  });

  factory TimerSession.fromJson(Map<String, dynamic> j) => TimerSession(
        active_id: j['active_id'] as String? ?? '_scratch',
        input_h:   j['input_h']   as int?    ?? 0,
        input_m:   j['input_m']   as int?    ?? 5,
        input_s:   j['input_s']   as int?    ?? 0,
        timers: (j['timers'] as List<dynamic>? ?? [])
            .map((e) => TimerSnapshot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'active_id': active_id,
        'input_h':   input_h,
        'input_m':   input_m,
        'input_s':   input_s,
        'timers':    timers.map((t) => t.toJson()).toList(),
      };
}

/// Persists running/paused timer state across app restarts.
///
/// Stored alongside the main config:
///   Linux:   ~/.config/noctua/noctua_timers.json
///   Android: app documents directory / noctua_timers.json
class TimerPersistence {
  static const _filename = 'noctua_timers.json';

  static Future<File> _file() async {
    final Directory dir;
    if (Platform.isLinux) {
      dir = Directory('${configHome.path}/noctua');
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    await dir.create(recursive: true);
    return File('${dir.path}/$_filename');
  }

  /// Write the current session to disk.  Failures are silently swallowed so
  /// a write error never crashes the app.
  static Future<void> save(TimerSession session) async {
    try {
      final file = await _file();
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(session.toJson()));
    } catch (_) {}
  }

  /// Load the last saved session.  Returns null if no file exists or on parse
  /// error (app will simply start with a fresh timer screen).
  static Future<TimerSession?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return TimerSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
