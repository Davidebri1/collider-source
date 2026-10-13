import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'materialize.dart';

/// v9.1 multi-select: long-press an item to start selecting, tap to add or
/// remove, then act on all of them from the floating bar.
class Selection<T> extends ChangeNotifier {
  final Set<T> _ids = {};
  bool get active => _ids.isNotEmpty;
  Set<T> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;
  bool has(T id) => _ids.contains(id);
  void toggle(T id) {
    _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
    notifyListeners();
  }
  void all(Iterable<T> ids) {
    _ids.addAll(ids);
    notifyListeners();
  }
  void clear() {
    _ids.clear();
    notifyListeners();
  }
}

class SelectionAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const SelectionAction(this.icon, this.label, this.onTap, {this.destructive = false});
}

/// Frosted floating bar: "N selected", actions, Done.
class SelectionBar extends StatelessWidget {
  final int count;
  final List<SelectionAction> actions;
  final VoidCallback onDone;
  final VoidCallback? onSelectAll;
  const SelectionBar({super.key, required this.count, required this.actions, required this.onDone, this.onSelectAll});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, String l, VoidCallback t, {Color c = Colors.white}) => Tooltip(
          message: l,
          child: InkResponse(
            onTap: t,
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(i, size: 20, color: c),
                const SizedBox(height: 2),
                Text(l, style: TextStyle(fontSize: 10, color: c.withValues(alpha: 0.85))),
              ]),
            ),
          ),
        );
    return Materialize(
      origin: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0x592A2A30),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$count selected', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 6),
              if (onSelectAll != null) btn(Icons.select_all_rounded, 'All', onSelectAll!),
              for (final a in actions) btn(a.icon, a.label, a.onTap, c: a.destructive ? const Color(0xFFFF6B6B) : Colors.white),
              btn(Icons.check_rounded, 'Done', onDone),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small frosted prompt for a bulk rename.
Future<String?> askName(BuildContext context, {String title = 'Rename', String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0x33000000),
    builder: (ctx) => Center(
      child: Materialize(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                color: const Color(0x662A2A30),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: c,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(isDense: true, filled: true, fillColor: Color(0x22FFFFFF), border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12)))),
                    onSubmitted: (v) => Navigator.pop(ctx, v),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                    TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save', style: TextStyle(color: Colors.white))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Local edits to server history: hidden sessions and renamed titles.
class HistoryEdits extends ChangeNotifier {
  HistoryEdits._();
  static final HistoryEdits instance = HistoryEdits._();
  final Set<String> hidden = {};
  final Map<String, String> titles = {};
  bool _loaded = false;
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      hidden.addAll(p.getStringList('hist_hidden_v1') ?? const []);
      for (final s in p.getStringList('hist_titles_v1') ?? const <String>[]) {
        final i = s.indexOf('\u0001');
        if (i > 0) titles[s.substring(0, i)] = s.substring(i + 1);
      }
      notifyListeners();
    } catch (_) {}
  }
  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('hist_hidden_v1', hidden.toList());
      await p.setStringList('hist_titles_v1', [for (final e in titles.entries) '${e.key}\u0001${e.value}']);
    } catch (_) {}
  }
  Future<void> hide(Iterable<String> ids) async {
    hidden.addAll(ids);
    notifyListeners();
    await _save();
  }
  Future<void> rename(Iterable<String> ids, String title) async {
    for (final id in ids) {
      titles[id] = title;
    }
    notifyListeners();
    await _save();
  }
}
