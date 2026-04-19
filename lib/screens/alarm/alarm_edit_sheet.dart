import 'package:flutter/material.dart';
import '../../config/config_service.dart';
import '../../data/emoji_shortcodes.dart';
import '../../services/alarm_service.dart';

/// Opens the add/edit bottom sheet.  Pass [alarm] to edit an existing one;
/// omit (or pass null) to create a new one.
Future<void> showAlarmEditSheet(
  BuildContext context,
  ConfigService svc, {
  AlarmConfig? alarm,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlarmEditSheet(svc: svc, alarm: alarm),
    );

// ─────────────────────────────────────────────────────────────────────────────

class _AlarmEditSheet extends StatefulWidget {
  final ConfigService svc;
  final AlarmConfig? alarm;

  const _AlarmEditSheet({required this.svc, this.alarm});

  @override
  State<_AlarmEditSheet> createState() => _AlarmEditSheetState();
}

class _AlarmEditSheetState extends State<_AlarmEditSheet> {
  late int           _hour;
  late int           _minute;
  late String        _label;
  late List<int>     _repeat_days;
  late TextEditingController _label_ctrl;
  List<MapEntry<String, String>> _suggestions = const [];

  // Regex: open colon + 2+ word chars at end of string (no closing colon yet).
  static final _partial_re = RegExp(r':([a-zA-Z0-9_]{2,})$');

  bool get _is_edit => widget.alarm != null;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _hour        = a?.hour   ?? TimeOfDay.now().hour;
    _minute      = a?.minute ?? TimeOfDay.now().minute;
    _label       = a?.label  ?? '';
    _repeat_days = List<int>.from(a?.repeat_days ?? []);
    _label_ctrl  = TextEditingController(text: _label);
    _label_ctrl.addListener(_onLabelChanged);
  }

  @override
  void dispose() {
    _label_ctrl.removeListener(_onLabelChanged);
    _label_ctrl.dispose();
    super.dispose();
  }

  void _onLabelChanged() {
    final cursor = _label_ctrl.selection.baseOffset;
    // Slice to cursor so the $ anchor finds a partial shortcode anywhere.
    final before = cursor >= 0 ? _label_ctrl.text.substring(0, cursor) : '';
    final match  = _partial_re.firstMatch(before);
    if (match == null) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    final partial = match.group(1)!.toLowerCase();
    final results = shortcodes.entries
        .where((e) => e.key.startsWith(partial))
        .take(8)
        .toList();
    setState(() => _suggestions = results);
  }

  void _applySuggestion(String name) {
    final text   = _label_ctrl.text;
    final cursor = _label_ctrl.selection.baseOffset;
    if (cursor < 0) return;
    final before = text.substring(0, cursor);
    final match  = _partial_re.firstMatch(before);
    if (match == null) return;
    // Stitch: text before the ':partial' + ':name: ' + text after cursor
    final new_text   = '${before.substring(0, match.start)}:$name: ${text.substring(cursor)}';
    final new_cursor = match.start + name.length + 3; // len(':') + name + len(': ')
    _label_ctrl.value = TextEditingValue(
      text:      new_text,
      selection: TextSelection.collapsed(offset: new_cursor),
    );
    setState(() => _suggestions = const []);
  }

  Future<void> _pickTime() async {
    final use_24h = widget.svc.config.time_format == '24h';
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: use_24h),
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white70,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _hour   = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      _repeat_days.contains(day)
          ? _repeat_days.remove(day)
          : _repeat_days.add(day);
    });
  }

  Future<void> _save() async {
    final raw   = _label_ctrl.text.trim();
    final alarm = AlarmConfig(
      id:          widget.alarm?.id ?? '0', // ConfigService assigns real ID on add
      hour:        _hour,
      minute:      _minute,
      label:       resolveShortcodes(raw),
      enabled:     widget.alarm?.enabled ?? true,
      repeat_days: List<int>.from(_repeat_days),
    );

    if (_is_edit) {
      await widget.svc.updateAlarm(alarm);
    } else {
      await widget.svc.addAlarm(alarm);
    }
    // Sync the updated list with the Android alarm manager.
    await AlarmService.syncAll(widget.svc.config.alarms);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await widget.svc.deleteAlarm(widget.alarm!.id);
    await AlarmService.syncAll(widget.svc.config.alarms);
    if (mounted) Navigator.pop(context);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              const SizedBox(height: 16),
              _timePicker(),
              const SizedBox(height: 24),
              _labelField(),
              const SizedBox(height: 4),
              _hintOrSuggestions(),
              const SizedBox(height: 20),
              _dayRow(),
              const SizedBox(height: 32),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _timePicker() => GestureDetector(
        onTap: _pickTime,
        child: Text(
          formatTime(_hour, _minute, widget.svc.config.time_format),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w100,
            letterSpacing: 4,
            color: Colors.white,
          ),
        ),
      );

  Widget _labelField() => TextField(
        controller: _label_ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Label (optional)',
          hintStyle: TextStyle(color: Colors.white30),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54)),
        ),
      );

  Widget _hintOrSuggestions() {
    if (_suggestions.isEmpty) return _shortcodeHint();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.symmetric(horizontal: 4),
        itemCount:        _suggestions.length,
        separatorBuilder: (_, sep) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = _suggestions[i];
          return GestureDetector(
            onTap: () => _applySuggestion(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${e.value} ${e.key}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shortcodeHint() => const SizedBox(
        height: 36,
        child: Center(
          child: Text(
            ':alarm:  :bell:  :star:  :fire:  :todo:  :coffee:  …',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:     11,
              color:        Colors.white38,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );

  static const _day_labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Widget _dayRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final on = _repeat_days.contains(i);
          return GestureDetector(
            onTap: () => _toggleDay(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? Colors.white24 : Colors.transparent,
                border: Border.all(
                    color: on ? Colors.white54 : Colors.white24, width: 1),
              ),
              child: Center(
                child: Text(
                  _day_labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: on ? Colors.white : Colors.white38,
                    fontWeight: on ? FontWeight.w500 : FontWeight.w300,
                  ),
                ),
              ),
            ),
          );
        }),
      );

  Widget _actions() => Row(
        children: [
          if (_is_edit)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 22),
              onPressed: _delete,
              tooltip: 'Delete alarm',
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_is_edit ? 'Save' : 'Add'),
          ),
        ],
      );
}
