import 'package:flutter_test/flutter_test.dart';
import 'package:noctua/data/emoji_shortcodes.dart';

void main() {
  // ── shortcodes map ────────────────────────────────────────────────────────

  group('shortcodes map', () {
    test('contains at least 400 entries', () {
      expect(shortcodes.length, greaterThanOrEqualTo(400));
    });

    test('all keys are lowercase', () {
      for (final key in shortcodes.keys) {
        expect(key, key.toLowerCase(), reason: 'key "$key" is not lowercase');
      }
    });

    test('no duplicate values for distinct canonical names', () {
      // A few spot-checks that aliases resolve to the same emoji
      expect(shortcodes['sunny'],    shortcodes['sun']);
      expect(shortcodes['thinking'], shortcodes['thinking_face']);
    });

    test('new shortcodes from expanded categories resolve', () {
      expect(shortcodes['hamburger'], '🍔');
      expect(shortcodes['rocket'],    '🚀');
      expect(shortcodes['guitar'],    '🎸');
      expect(shortcodes['koala'],     '🐨');
      expect(shortcodes['rainbow'],   '🌈');
      expect(shortcodes['us'],        '🇺🇸');
    });
  });

  group('resolveShortcodes', () {
    // ── known codes ───────────────────────────────────────────────────────────

    test('resolves basic shortcodes', () {
      expect(resolveShortcodes(':tea:'),      '🍵');
      expect(resolveShortcodes(':coffee:'),   '☕');
      expect(resolveShortcodes(':pomodoro:'), '🍅');
      expect(resolveShortcodes(':workout:'),  '💪');
      expect(resolveShortcodes(':todo:'),     '✅');
    });

    // ── case insensitivity ────────────────────────────────────────────────────

    test('lookup is case-insensitive', () {
      expect(resolveShortcodes(':TEA:'),      '🍵');
      expect(resolveShortcodes(':Coffee:'),   '☕');
      expect(resolveShortcodes(':POMODORO:'), '🍅');
      expect(resolveShortcodes(':WoRkOuT:'),  '💪');
    });

    // ── unknown codes pass through ────────────────────────────────────────────

    test('unknown shortcode is left unchanged', () {
      expect(resolveShortcodes(':unknown:'), ':unknown:');
      expect(resolveShortcodes(':xyzzy:'),   ':xyzzy:');
    });

    // ── text with shortcodes ──────────────────────────────────────────────────

    test('shortcode at start of string', () {
      expect(resolveShortcodes(':todo: review PR'), '✅ review PR');
    });

    test('shortcode in the middle of text', () {
      expect(resolveShortcodes('drink :tea: now'), 'drink 🍵 now');
    });

    test('shortcode at end of string', () {
      expect(resolveShortcodes('time for :coffee:'), 'time for ☕');
    });

    test('multiple shortcodes in one string', () {
      expect(resolveShortcodes(':tea: and :coffee:'), '🍵 and ☕');
    });

    test('mixed known and unknown shortcodes', () {
      expect(resolveShortcodes(':tea: :nope:'), '🍵 :nope:');
    });

    // ── edge cases ────────────────────────────────────────────────────────────

    test('empty string returns empty string', () {
      expect(resolveShortcodes(''), '');
    });

    test('string with no shortcodes is returned unchanged', () {
      expect(resolveShortcodes('hello world'), 'hello world');
    });

    test('partial shortcode without closing colon is not matched', () {
      expect(resolveShortcodes(':tea'), ':tea');
    });

    test('partial shortcode without opening colon is not matched', () {
      expect(resolveShortcodes('tea:'), 'tea:');
    });

    test('colons around a space do not form a shortcode', () {
      // spaces are not in [a-zA-Z0-9_] so ': :' should not match
      expect(resolveShortcodes(': :'), ': :');
    });

    test('existing emoji in text is preserved', () {
      expect(resolveShortcodes('🍵 :coffee:'), '🍵 ☕');
    });

    test('adjacent shortcodes without spacing', () {
      expect(resolveShortcodes(':tea::coffee:'), '🍵☕');
    });

    test('underscores are valid inside shortcode names', () {
      // 'world_clock' is not a shortcode but the regex should still parse it
      expect(resolveShortcodes(':world_clock:'), ':world_clock:');
    });

    // ── specific shortcode spot-checks ────────────────────────────────────────

    test('all drink shortcodes resolve', () {
      final drinks = {
        ':tea:':      '🍵',
        ':coffee:':   '☕',
        ':water:':    '💧',
        ':beer:':     '🍺',
        ':wine:':     '🍷',
        ':juice:':    '🧃',
        ':milk:':     '🥛',
        ':cocktail:': '🍸',
      };
      drinks.forEach((code, emoji) {
        expect(resolveShortcodes(code), emoji, reason: '$code → $emoji');
      });
    });

    test('productivity shortcodes resolve', () {
      expect(resolveShortcodes(':focus:'),  '🎯');
      expect(resolveShortcodes(':code:'),   '💻');
      expect(resolveShortcodes(':study:'),  '📚');
      expect(resolveShortcodes(':note:'),   '📝');
    });

    // ── position-independent resolution (used by alarm labels & timer names) ──

    test('shortcode embedded before existing text resolves', () {
      expect(resolveShortcodes(':fire: morning run'), '🔥 morning run');
    });

    test('shortcode embedded after existing text resolves', () {
      expect(resolveShortcodes('morning run :fire:'), 'morning run 🔥');
    });

    test('shortcode in the middle of existing text resolves', () {
      expect(resolveShortcodes('wake :alarm: up'), 'wake ⏰ up');
    });

    test('multiple shortcodes mixed with plain text all resolve', () {
      expect(
        resolveShortcodes(':bell: stand up :coffee: break'),
        '🔔 stand up ☕ break',
      );
    });
  });
}
