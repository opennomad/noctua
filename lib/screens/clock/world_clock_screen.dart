import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/color_schemes.dart';
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
      builder: (_) => _CityPickerDialog(
            time_format: widget.config_service.config.time_format),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'World Clock',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: noctuaText(context).withAlpha(128),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                _editing ? Icons.check : Icons.edit_outlined,
                color: noctuaText(context).withAlpha(138),
                size: 18,
              ),
              onPressed: () => setState(() => _editing = !_editing),
              tooltip: _editing ? 'Done' : 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            if (_editing) ...[
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(Icons.add, color: noctuaText(context).withAlpha(138), size: 20),
                onPressed: _addZone,
                tooltip: 'Add city',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      );

  Widget _readList() => ListenableBuilder(
        listenable: widget.config_service,
        builder: (ctx, child) {
          final fmt = widget.config_service.config.time_format;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _zones.length,
            itemBuilder: (ctx, i) =>
                _ZoneRow(zone: _zones[i], utc_now: _utc_now, time_format: fmt),
          );
        },
      );

  Widget _editList() => ListenableBuilder(
        listenable: widget.config_service,
        builder: (ctx, child) {
          final fmt = widget.config_service.config.time_format;
          return ReorderableListView.builder(
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
              time_format: fmt,
              on_delete: () => _delete(i),
            ),
          );
        },
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

String _timeString(ZoneConfig zone, DateTime utc_now, String time_format) {
  try {
    final DateTime local;
    if (_is_custom(zone.tz_id)) {
      local = utc_now.add(Duration(minutes: _custom_minutes(zone.tz_id)));
    } else {
      local = tz.TZDateTime.from(utc_now, tz.getLocation(zone.tz_id));
    }
    return formatTime(local.hour, local.minute, time_format);
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
  final String time_format;

  const _ZoneRow({required this.zone, required this.utc_now, required this.time_format});

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
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: noctuaText(context))),
                Text(_offsetLabel(zone, utc_now),
                    style: TextStyle(
                        fontSize: 11,
                        color: noctuaText(context).withAlpha(102),
                        letterSpacing: 1)),
              ],
            ),
          ),
          Text(_timeString(zone, utc_now, time_format),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color: noctuaText(context),
                  fontFeatures: [FontFeature.tabularFigures()])),
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
  final String time_format;
  final VoidCallback on_delete;

  const _EditZoneRow({
    super.key,
    required this.index,
    required this.zone,
    required this.utc_now,
    required this.time_format,
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
            child: Icon(Icons.drag_handle, color: noctuaText(context).withAlpha(61), size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.city,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: noctuaText(context))),
                Text(_offsetLabel(zone, utc_now),
                    style: TextStyle(
                        fontSize: 11,
                        color: noctuaText(context).withAlpha(102),
                        letterSpacing: 1)),
              ],
            ),
          ),
          Text(_timeString(zone, utc_now, time_format),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color: noctuaText(context),
                  fontFeatures: [FontFeature.tabularFigures()])),
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
  final String time_format;
  const _CityPickerDialog({required this.time_format});

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
      insetPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: MediaQuery.of(context).size.height < 500 ? 16 : 48,
      ),
      child: Column(
        children: [
          _dialogHeader(),
          Divider(color: noctuaText(context).withAlpha(31), height: 1),
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
                icon: Icon(Icons.arrow_back,
                    color: noctuaText(context).withAlpha(138), size: 18),
                onPressed: _toggleCustom,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Expanded(
              child: _custom_mode
                  ? Text('Custom city',
                      style: TextStyle(
                          color: noctuaText(context).withAlpha(178),
                          fontSize: 15,
                          fontWeight: FontWeight.w300))
                  : TextField(
                      controller: _search_ctrl,
                      autofocus: true,
                      style: TextStyle(color: noctuaText(context)),
                      decoration: InputDecoration(
                        hintText: 'Search cities…',
                        hintStyle: TextStyle(color: noctuaText(context).withAlpha(97)),
                        prefixIcon: Icon(Icons.search,
                            color: noctuaText(context).withAlpha(97), size: 20),
                        suffixIcon: _search_ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: noctuaText(context).withAlpha(97), size: 18),
                                onPressed: () => _search_ctrl.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: noctuaText(context).withAlpha(26),
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
                child: Text('Custom',
                    style: TextStyle(color: noctuaText(context).withAlpha(97), fontSize: 13)),
              ),
          ],
        ),
      );

  // Searchable city list
  Widget _cityList() {
    final utc_now = DateTime.now().toUtc();
    return _filtered.isEmpty
        ? Center(
            child: Text('No cities found',
                style: TextStyle(color: noctuaText(context).withAlpha(97))))
        : ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final (city, tz_id) = _filtered[i];
              final zone = ZoneConfig(city: city, tz_id: tz_id);
              return ListTile(
                dense: true,
                title: Text(city,
                    style: TextStyle(
                        color: noctuaText(context), fontSize: 15)),
                subtitle: Text(_offsetLabel(zone, utc_now),
                    style: TextStyle(
                        color: noctuaText(context).withAlpha(97), fontSize: 11)),
                trailing: Text(_timeString(zone, utc_now, widget.time_format),
                    style: TextStyle(
                        color: noctuaText(context).withAlpha(178),
                        fontSize: 16,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 1,
                        fontFeatures: [FontFeature.tabularFigures()])),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _city_ctrl,
            autofocus: true,
            style: TextStyle(color: noctuaText(context)),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'City name',
              labelStyle: TextStyle(color: noctuaText(context).withAlpha(138)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: noctuaText(context).withAlpha(61))),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: noctuaText(context).withAlpha(138))),
            ),
            onSubmitted: (_) => _submitCustom(),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('UTC offset',
                  style: TextStyle(
                      color: noctuaText(context).withAlpha(128), fontSize: 14)),
              const Spacer(),
              // − / + in 30-minute steps; hold boundaries at −12h / +14h
              IconButton(
                icon: Icon(Icons.remove, color: noctuaText(context).withAlpha(138), size: 18),
                onPressed: _offset_mins > -720
                    ? () => setState(() => _offset_mins -= 30)
                    : null,
              ),
              SizedBox(
                width: 80,
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: noctuaText(context), fontSize: 15)),
              ),
              IconButton(
                icon: Icon(Icons.add, color: noctuaText(context).withAlpha(138), size: 18),
                onPressed: _offset_mins < 840
                    ? () => setState(() => _offset_mins += 30)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: _city_ctrl,
            builder: (ctx, child) => TextButton(
              onPressed:
                  _city_ctrl.text.trim().isNotEmpty ? _submitCustom : null,
              style: TextButton.styleFrom(
                foregroundColor: noctuaText(context).withAlpha(178),
                backgroundColor: noctuaText(context).withAlpha(26),
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
