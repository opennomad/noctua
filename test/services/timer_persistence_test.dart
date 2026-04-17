import 'package:flutter_test/flutter_test.dart';
import 'package:noctua/services/timer_persistence.dart';

void main() {
  // ── TimerSnapshot ──────────────────────────────────────────────────────────

  group('TimerSnapshot', () {
    test('fromJson / toJson round-trip — running', () {
      const snap = TimerSnapshot(
        id:            'abc',
        total_seconds: 600,
        status:        'running',
        deadline_ms:   1_700_000_000_000,
      );
      final restored = TimerSnapshot.fromJson(snap.toJson());
      expect(restored.id,            'abc');
      expect(restored.total_seconds, 600);
      expect(restored.status,        'running');
      expect(restored.deadline_ms,   1_700_000_000_000);
      expect(restored.remaining_s,   isNull);
    });

    test('fromJson / toJson round-trip — paused', () {
      const snap = TimerSnapshot(
        id:            '1',
        total_seconds: 300,
        status:        'paused',
        remaining_s:   120,
      );
      final restored = TimerSnapshot.fromJson(snap.toJson());
      expect(restored.status,      'paused');
      expect(restored.remaining_s, 120);
      expect(restored.deadline_ms, isNull);
    });

    test('fromJson / toJson round-trip — done', () {
      const snap = TimerSnapshot(
        id:            '2',
        total_seconds: 60,
        status:        'done',
        remaining_s:   0,
      );
      final restored = TimerSnapshot.fromJson(snap.toJson());
      expect(restored.status,      'done');
      expect(restored.remaining_s, 0);
    });

    test('fromJson: missing fields fall back to defaults', () {
      final snap = TimerSnapshot.fromJson({});
      expect(snap.id,            '');
      expect(snap.total_seconds, 0);
      expect(snap.status,        'paused');
      expect(snap.deadline_ms,   isNull);
      expect(snap.remaining_s,   isNull);
    });

    test('toJson omits null optional fields', () {
      const snap = TimerSnapshot(
          id: '1', total_seconds: 60, status: 'paused', remaining_s: 30);
      final j = snap.toJson();
      expect(j.containsKey('deadline_ms'), isFalse);
      expect(j['remaining_s'], 30);
    });

    test('toJson includes deadline_ms when set', () {
      const snap = TimerSnapshot(
          id: '1', total_seconds: 60, status: 'running', deadline_ms: 999);
      final j = snap.toJson();
      expect(j['deadline_ms'], 999);
      expect(j.containsKey('remaining_s'), isFalse);
    });
  });

  // ── TimerSession ───────────────────────────────────────────────────────────

  group('TimerSession', () {
    test('fromJson / toJson round-trip with multiple timers', () {
      const session = TimerSession(
        active_id: '3',
        input_h:   0,
        input_m:   5,
        input_s:   30,
        timers: [
          TimerSnapshot(
              id: '_scratch', total_seconds: 330, status: 'running',
              deadline_ms: 1_700_000_000_000),
          TimerSnapshot(
              id: '3', total_seconds: 600, status: 'paused',
              remaining_s: 240),
        ],
      );

      final restored = TimerSession.fromJson(session.toJson());
      expect(restored.active_id, '3');
      expect(restored.input_h,   0);
      expect(restored.input_m,   5);
      expect(restored.input_s,   30);
      expect(restored.timers,    hasLength(2));
      expect(restored.timers[0].id,          '_scratch');
      expect(restored.timers[0].deadline_ms, 1_700_000_000_000);
      expect(restored.timers[1].id,          '3');
      expect(restored.timers[1].remaining_s, 240);
    });

    test('fromJson: missing fields fall back to defaults', () {
      final session = TimerSession.fromJson({});
      expect(session.active_id, '_scratch');
      expect(session.input_h,   0);
      expect(session.input_m,   5);
      expect(session.input_s,   0);
      expect(session.timers,    isEmpty);
    });

    test('fromJson: empty timers list', () {
      final session = TimerSession.fromJson({'timers': []});
      expect(session.timers, isEmpty);
    });

    test('toJson contains all keys', () {
      const session = TimerSession(active_id: '_scratch', timers: []);
      final j = session.toJson();
      expect(j.keys, containsAll(
          ['active_id', 'input_h', 'input_m', 'input_s', 'timers']));
    });
  });

  // ── remaining calculation logic ────────────────────────────────────────────
  //
  // The screen reconstructs remaining from deadline_ms at restore time.
  // These tests validate the arithmetic directly.

  group('remaining from deadline_ms', () {
    test('future deadline gives positive remaining', () {
      final now_ms      = DateTime.now().millisecondsSinceEpoch;
      final deadline_ms = now_ms + 30 * 1000; // 30 seconds from now
      final remaining   = Duration(milliseconds: deadline_ms - now_ms);
      expect(remaining.inSeconds, closeTo(30, 1));
    });

    test('past deadline gives non-positive remaining → done', () {
      final now_ms      = DateTime.now().millisecondsSinceEpoch;
      final deadline_ms = now_ms - 5 * 1000; // 5 seconds ago
      final remaining_ms = deadline_ms - now_ms;
      expect(remaining_ms, isNegative);
    });

    test('deadline exactly at now gives zero remaining → done', () {
      final now_ms      = DateTime.now().millisecondsSinceEpoch;
      final remaining_ms = now_ms - now_ms;
      expect(remaining_ms <= 0, isTrue);
    });
  });
}
