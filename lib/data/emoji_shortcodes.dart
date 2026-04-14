/// Resolves `:shortcode:` patterns inside [text] to emoji.
///
/// Unknown shortcodes are left unchanged so the user can see the typo.
/// Lookup is case-insensitive.
///
/// Examples:
///   resolveShortcodes(':tea:')        → '🍵'
///   resolveShortcodes(':todo: work')  → '✅ work'
///   resolveShortcodes(':unknown:')    → ':unknown:'
String resolveShortcodes(String text) => text.replaceAllMapped(
      RegExp(r':([a-zA-Z0-9_]+):'),
      (m) => _codes[m.group(1)!.toLowerCase()] ?? m.group(0)!,
    );

const Map<String, String> _codes = {
  // ── drinks ────────────────────────────────────────────────────────────────
  'tea':        '🍵',
  'coffee':     '☕',
  'water':      '💧',
  'beer':       '🍺',
  'wine':       '🍷',
  'juice':      '🧃',
  'milk':       '🥛',
  'cocktail':   '🍹',

  // ── food ──────────────────────────────────────────────────────────────────
  'pizza':      '🍕',
  'bread':      '🍞',
  'cake':       '🎂',
  'cookie':     '🍪',
  'lunch':      '🥗',
  'dinner':     '🍽️',
  'eat':        '🍽️',
  'cook':       '👨‍🍳',
  'apple':      '🍎',
  'salad':      '🥗',

  // ── productivity ──────────────────────────────────────────────────────────
  'todo':       '✅',
  'check':      '✔️',
  'done':       '✅',
  'work':       '💼',
  'focus':      '🎯',
  'study':      '📚',
  'read':       '📖',
  'write':      '✍️',
  'code':       '💻',
  'meeting':    '👥',
  'call':       '📞',
  'email':      '📧',
  'think':      '🤔',
  'idea':       '💡',
  'plan':       '📋',
  'task':       '📌',
  'note':       '📝',

  // ── rest & wellness ───────────────────────────────────────────────────────
  'break':      '⏸️',
  'rest':       '😌',
  'nap':        '💤',
  'sleep':      '🛌',
  'meditate':   '🧘',
  'breathe':    '🌬️',

  // ── fitness ───────────────────────────────────────────────────────────────
  'workout':    '💪',
  'gym':        '🏋️',
  'run':        '🏃',
  'walk':       '🚶',
  'bike':       '🚴',
  'swim':       '🏊',
  'yoga':       '🧘',
  'stretch':    '🤸',

  // ── home ──────────────────────────────────────────────────────────────────
  'clean':      '🧹',
  'laundry':    '👕',
  'dishes':     '🍴',
  'garden':     '🌱',
  'shop':       '🛒',

  // ── timers ────────────────────────────────────────────────────────────────
  'timer':      '⏱️',
  'clock':      '⏰',
  'alarm':      '⏰',
  'pomodoro':   '🍅',
  'tomato':     '🍅',
  'stopwatch':  '⏱',

  // ── symbols ───────────────────────────────────────────────────────────────
  'star':       '⭐',
  'fire':       '🔥',
  'heart':      '❤️',
  'bolt':       '⚡',
  'rocket':     '🚀',
  'flag':       '🏁',
  'trophy':     '🏆',
  'medal':      '🥇',
  'target':     '🎯',
  'bell':       '🔔',
  'pin':        '📌',
  'lock':       '🔒',
  'key':        '🔑',

  // ── fun & misc ────────────────────────────────────────────────────────────
  'music':      '🎵',
  'game':       '🎮',
  'party':      '🎉',
  'gift':       '🎁',
  'movie':      '🎬',
  'book':       '📚',
  'art':        '🎨',
  'photo':      '📷',
  'phone':      '📱',
  'sun':        '☀️',
  'moon':       '🌙',
  'rain':       '🌧️',
  'snow':       '❄️',

  // ── animals ───────────────────────────────────────────────────────────────
  'dog':        '🐕',
  'cat':        '🐈',
  'pet':        '🐾',
  'bird':       '🐦',
  'fish':       '🐟',
};
