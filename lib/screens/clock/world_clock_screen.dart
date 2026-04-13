import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../config/config_service.dart';
import '../../data/city_list.dart';

class WorldClockScreen extends StatefulWidget {
  final ConfigService config_service;
  const WorldClockScreen({super.key, required this.config_service});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  late DateTime _utc_now;
  late Timer _timer;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _utc_now = DateTime.now().toUtc();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _utc_now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  List<ZoneConfig> get _zones =>
      widget.config_service.config.world_clocks;

  void _reorder(int old_index, int new_index) {
    final zones = List<ZoneConfig>.from(_zones);
    if (new_index > old_index) new_index--;
    zones.insert(new_index, zones.removeAt(old_index));
    widget.config_service.setWorldClocks(zones);
  }

  void _delete(int index) {
    final zones = List<ZoneConfig>.from(_zones)..removeAt(index);
    widget.config_service.setWorldClocks(zones);
  }

  Future<void> _addZone() async {
    final result = await showDialog<ZoneConfig>(
      context: context,
      builder: (_) => const _CityPickerDialog(),
    );
    if (result != null) {
      widget.config_service.setWorldClocks([..._zones, result]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              _header(),
              Expanded(child: _editing ? _editList() : _readList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'World Clock',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: Colors.white.withAlpha(128),
                ),
              ),
            ),
            if (_editing)
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white54, size: 20),
                onPressed: _addZone,
                tooltip: 'Add city',
              ),
            IconButton(
              icon: Icon(
                _editing ? Icons.check : Icons.edit_outlined,
                color: Colors.white54,
                size: 18,
              ),
              onPressed: () => setState(() => _editing = !_editing),
              tooltip: _editing ? 'Done' : 'Edit',
            ),
          ],
        ),
      );

  Widget _readList() => ListenableBuilder(
        listenable: widget.config_service,
        builder: (ctx, child) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _zones.length,
          itemBuilder: (ctx, i) =>
              _ZoneRow(zone: _zones[i], utc_now: _utc_now),
        ),
      );

  Widget _editList() => ListenableBuilder(
        listenable: widget.config_service,
        builder: (ctx, child) => ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _zones.length,
          onReorder: _reorder,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, i, a) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (ctx, i) => _EditZoneRow(
            key: ValueKey('${_zones[i].city}${_zones[i].tz_id}'),
            index: i,
            zone: _zones[i],
            utc_now: _utc_now,
            on_delete: () => _delete(i),
          ),
        ),
      );
}

// ── helpers ──────────────────────────────────────────────────────────────────

/// Custom zones store their offset as 'offset:N' where N is total minutes.
bool _is_custom(String tz_id) => tz_id.startsWith('offset:');

int _custom_minutes(String tz_id) =>
    int.tryParse(tz_id.substring('offset:'.length)) ?? 0;

String _format_offset(int total_minutes) {
  final sign  = total_minutes >= 0 ? '+' : '-';
  final abs_h = (total_minutes.abs() ~/ 60);
  final abs_m = (total_minutes.abs() % 60);
  if (abs_m == 0) return 'UTC$sign$abs_h';
  return 'UTC$sign$abs_h:${abs_m.toString().padLeft(2, '0')}';
}

String _timeString(ZoneConfig zone, DateTime utc_now) {
  try {
    final DateTime local;
    if (_is_custom(zone.tz_id)) {
      local = utc_now.add(Duration(minutes: _custom_minutes(zone.tz_id)));
    } else {
      local = tz.TZDateTime.from(utc_now, tz.getLocation(zone.tz_id));
    }
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '--:--';
  }
}

String _offsetLabel(ZoneConfig zone, DateTime utc_now) {
  try {
    if (_is_custom(zone.tz_id)) {
      return _format_offset(_custom_minutes(zone.tz_id));
    }
    final local = tz.TZDateTime.from(utc_now, tz.getLocation(zone.tz_id));
    return _format_offset(local.timeZoneOffset.inMinutes);
  } catch (_) {
    return zone.tz_id;
  }
}

// ── read-only row ─────────────────────────────────────────────────────────────

class _ZoneRow extends StatelessWidget {
  final ZoneConfig zone;
  final DateTime utc_now;

  const _ZoneRow({required this.zone, required this.utc_now});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.city,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white)),
                Text(_offsetLabel(zone, utc_now),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(102),
                        letterSpacing: 1)),
              ],
            ),
          ),
          Text(_timeString(zone, utc_now),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ── edit-mode row ─────────────────────────────────────────────────────────────

class _EditZoneRow extends StatelessWidget {
  final int index;
  final ZoneConfig zone;
  final DateTime utc_now;
  final VoidCallback on_delete;

  const _EditZoneRow({
    super.key,
    required this.index,
    required this.zone,
    required this.utc_now,
    required this.on_delete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.city,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white)),
                Text(_offsetLabel(zone, utc_now),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(102),
                        letterSpacing: 1)),
              ],
            ),
          ),
          Text(_timeString(zone, utc_now),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color: Colors.white)),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.redAccent, size: 18),
            onPressed: on_delete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ── city picker dialog ────────────────────────────────────────────────────────

class _CityPickerDialog extends StatefulWidget {
  const _CityPickerDialog();

  @override
  State<_CityPickerDialog> createState() => _CityPickerDialogState();
}

class _CityPickerDialogState extends State<_CityPickerDialog> {
  final _search_ctrl = TextEditingController();
  final _city_ctrl   = TextEditingController();
  List<(String, String)> _filtered = city_list;
  bool _custom_mode = false;
  int  _offset_mins = 0;

  @override
  void initState() {
    super.initState();
    _search_ctrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search_ctrl.dispose();
    _city_ctrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _search_ctrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? city_list
          : city_list.where((e) => e.$1.toLowerCase().contains(q)).toList();
    });
  }

  void _toggleCustom() {
    setState(() {
      _custom_mode = !_custom_mode;
      if (_custom_mode) _search_ctrl.clear();
    });
  }

  void _submitCustom() {
    final city = _city_ctrl.text.trim();
    if (city.isEmpty) return;
    Navigator.pop(
      context,
      ZoneConfig(city: city, tz_id: 'offset:$_offset_mins'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          _dialogHeader(),
          const Divider(color: Colors.white12, height: 1),
          Expanded(child: _custom_mode ? _customForm() : _cityList()),
        ],
      ),
    );
  }

  // Header switches between search bar and "Custom city" title
  Widget _dialogHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
        child: Row(
          children: [
            if (_custom_mode)
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Colors.white54, size: 18),
                onPressed: _toggleCustom,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Expanded(
              child: _custom_mode
                  ? const Text('Custom city',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w300))
                  : TextField(
                      controller: _search_ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search cities…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white38, size: 20),
                        suffixIcon: _search_ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white38, size: 18),
                                onPressed: () => _search_ctrl.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
            ),
            if (!_custom_mode)
              TextButton(
                onPressed: _toggleCustom,
                child: const Text('Custom',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
          ],
        ),
      );

  // Searchable city list
  Widget _cityList() {
    final utc_now = DateTime.now().toUtc();
    return _filtered.isEmpty
        ? const Center(
            child: Text('No cities found',
                style: TextStyle(color: Colors.white38)))
        : ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final (city, tz_id) = _filtered[i];
              final zone = ZoneConfig(city: city, tz_id: tz_id);
              return ListTile(
                dense: true,
                title: Text(city,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15)),
                subtitle: Text(_offsetLabel(zone, utc_now),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                trailing: Text(_timeString(zone, utc_now),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 1)),
                onTap: () => Navigator.pop(context, zone),
              );
            },
          );
  }

  // Custom city form
  Widget _customForm() {
    final sign      = _offset_mins >= 0 ? '+' : '-';
    final abs_h     = (_offset_mins.abs() ~/ 60);
    final abs_m     = (_offset_mins.abs() % 60);
    final label     = abs_m == 0
        ? 'UTC$sign$abs_h'
        : 'UTC$sign$abs_h:${abs_m.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _city_ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City name',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54)),
            ),
            onSubmitted: (_) => _submitCustom(),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('UTC offset',
                  style: TextStyle(
                      color: Colors.white.withAlpha(128), fontSize: 14)),
              const Spacer(),
              // − / + in 30-minute steps; hold boundaries at −12h / +14h
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white54, size: 18),
                onPressed: _offset_mins > -720
                    ? () => setState(() => _offset_mins -= 30)
                    : null,
              ),
              SizedBox(
                width: 80,
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15)),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white54, size: 18),
                onPressed: _offset_mins < 840
                    ? () => setState(() => _offset_mins += 30)
                    : null,
              ),
            ],
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: _city_ctrl,
            builder: (ctx, child) => TextButton(
              onPressed:
                  _city_ctrl.text.trim().isNotEmpty ? _submitCustom : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add city'),
            ),
          ),
        ],
      ),
    );
  }
}
