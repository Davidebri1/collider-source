import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_font.dart';
import '../../core/vision/cpane.dart';
import '../../core/vision/vision_tokens.dart';
import 'sg_model.dart';
import 'sg_views.dart';

class SgPane extends StatefulWidget {
  const SgPane({super.key, required this.onClose, this.section = 'tasks'});
  final VoidCallback onClose;
  final String section;

  @override
  State<SgPane> createState() => _SgPaneState();
}

class _SgPaneState extends State<SgPane> {
  final SgStore store = SgStore.instance;
  String? _openId;
  bool _multi = false;
  bool _menu = false;
  bool _armedDelete = false;
  final Set<String> _selected = {};
  String _toast = '';
  bool _toastRed = false;
  Timer? _toastTimer;
  bool _forceFlip = false;
  String _overlay = '';
  double _kanbanPage = 0;
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _labelsKey = GlobalKey();
  final GlobalKey _membersKey = GlobalKey();
  final GlobalKey _checkKey = GlobalKey();
  final GlobalKey _filesKey = GlobalKey();
  final Set<String> _toasted = {};
  Timer? _notes;
  Timer? _hour;

  @override
  void initState() {
    super.initState();
    final kp = Uri.base.queryParameters['kpage'];
    if (kp != null && kp != 'last') _kanbanPage = double.tryParse(kp) ?? 0;
    store.addListener(_onStore);
    _boot();
  }

  Future<void> _boot() async {
    await store.init();
    if (!mounted) return;
    final q = Uri.base.queryParameters;
    // Capture-only harness: names come from the capture URL, never hard-coded seed.
    if (q['cap'] == '1') {
      final boardName = q['board'] ?? 'Board';
      final wantHome = q['sg'] == 'home';
      if (wantHome) {
        store.debugReset();
        store.atHome = true;
        store.loaded = true;
      } else {
        if (store.boards.isEmpty || q['fresh'] == '1') {
          store.debugReset();
          store.createBoard(boardName, goHome: false);
        } else if (store.atHome || store.board == null) {
          store.createBoard(boardName, goHome: false);
        }
        final b = store.board!;
        // Capture-only: seed labels so faces can show real pills (never persisted as app seed).
        if (q['rich'] == '1' || q['labels'] == '1') {
          store.touch(() {
            if (b.labels.isEmpty) {
              b.labels.addAll([
                SgLabel(id: 'cap-l1', title: 'Urgent', color: 0xFFEB5A46),
                SgLabel(id: 'cap-l2', title: 'Design', color: 0xFFC377E0),
                SgLabel(id: 'cap-l3', title: 'Ship', color: 0xFF61BD4F),
              ]);
            }
          });
        }
        for (final key in ['c1', 'c2', 'c3', 'c4', 'c5']) {
          final title = q[key];
          if (title == null || title.isEmpty) continue;
          final made = store.addCard(SgType.task);
          if (made != null) store.touch(() => made.title = title);
        }
        // rich=1 builds varied Trello-like card faces for captures only.
        if (q['rich'] == '1' && b.cards.isNotEmpty) {
          final lists = b.orderedLists;
          store.touch(() {
            // Card 0: green cover + labels + due + checklist + attachment + desc + member
            final c0 = b.cards[0];
            c0.color = 0xFF61BD4F;
            c0.description = 'Ship the board polish pass';
            c0.labelIds
              ..clear()
              ..addAll(['cap-l1', 'cap-l3']);
            c0.dueMs = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch;
            c0.urgent = false;
            c0.checks
              ..clear()
              ..addAll([
                SgCheck(id: 'ck1', text: 'Layout', done: true),
                SgCheck(id: 'ck2', text: 'Faces', done: false),
                SgCheck(id: 'ck3', text: 'Editor', done: false),
              ]);
            c0.files
              ..clear()
              ..add(SgFile(id: 'f1', name: 'spec.pdf', dataUrl: 'data:text/plain;base64,YQ=='));
            c0.members
              ..clear()
              ..add('Alex');
            // Card 1: blue cover + due urgent + label
            if (b.cards.length > 1) {
              final c1 = b.cards[1];
              c1.color = 0xFF0079BF;
              c1.labelIds
                ..clear()
                ..add('cap-l2');
              c1.dueMs = DateTime.now().add(const Duration(minutes: 25)).millisecondsSinceEpoch;
              c1.urgent = true;
              c1.description = 'Tighten list peek';
              if (lists.length > 1) {
                c1.listId = lists[1].id;
                c1.status = lists[1].title;
              }
            }
            // Card 2: red cover + checklist only
            if (b.cards.length > 2) {
              final c2 = b.cards[2];
              c2.color = 0xFFEB5A46;
              c2.checks
                ..clear()
                ..addAll([
                  SgCheck(id: 'ck4', text: 'A', done: true),
                  SgCheck(id: 'ck5', text: 'B', done: true),
                ]);
              c2.members.add('Sam');
            }
            // Card 3: purple + attachment
            if (b.cards.length > 3) {
              final c3 = b.cards[3];
              c3.color = 0xFFC377E0;
              c3.files.add(SgFile(id: 'f2', name: 'mock.png', dataUrl: 'data:text/plain;base64,YQ=='));
              c3.labelIds.add('cap-l2');
              if (lists.length > 1) {
                c3.listId = lists[1].id;
                c3.status = lists[1].title;
              }
            }
            // Card 4: no colour (neutral glass) so default state is visible
            if (b.cards.length > 4) {
              final c4 = b.cards[4];
              c4.color = 0;
              c4.description = 'Neutral glass default';
            }
          });
        }
        final due = q['due'];
        if (due != null && b.cards.isNotEmpty && q['rich'] != '1') {
          final mins = int.tryParse(due) ?? 30;
          store.touch(() {
            b.cards.first.dueMs = DateTime.now().add(Duration(minutes: mins)).millisecondsSinceEpoch;
            b.cards.first.urgent = true;
          });
        }
        final color = q['color'];
        if (color != null && b.cards.isNotEmpty) {
          final argb = int.tryParse(color.replaceFirst('#', ''), radix: 16);
          if (argb != null) store.touch(() => b.cards.first.color = 0xFF000000 | argb);
        }
        final hidden = q['hidden'];
        if (hidden != null && b.cards.isNotEmpty) {
          store.touch(() => b.cards.first.hiddenNotes = hidden);
        }
      }
    }
    final sg = q['sg'];
    final b = store.board;
    if (b != null) {
      final surface = SgSurface.values.asNameMap()[sg ?? ''];
      if (surface != null) b.surface = surface;
      if (sg == 'flip') {
        _forceFlip = true;
        _openId = b.cards.firstOrNull?.id;
      }
      if (sg == 'editor') _openId = b.cards.firstOrNull?.id;
      final cardId = q['card'];
      if (cardId != null && b.cards.any((c) => c.id == cardId)) _openId = cardId;
      if (sg == 'cover') {
        _openId ??= b.cards.firstOrNull?.id;
        _cover = true;
      }
      if (sg == 'search' || sg == 'stats' || sg == 'genie' || sg == 'create') _overlay = sg!;
      if (sg == 'menu') _menu = true;
      if (sg == 'multi') {
        _multi = true;
        _selected.addAll(b.cards.take(3).map((c) => c.id));
      }
      if (sg == 'home') store.goHome();
      if (sg == 'drag' && b.cards.isNotEmpty) {
        // Leave board open; capture script long-presses.
      }
      final kp = q['kpage'];
      if (kp == 'last') {
        _kanbanPage = b.orderedLists.length.toDouble();
      } else if (kp != null) {
        _kanbanPage = double.tryParse(kp) ?? 0;
      }
    }
    if (sg == 'home' || (q['cap'] != '1' && store.boards.isEmpty)) {
      store.atHome = true;
    }
    _checkNotes();
    _notes = Timer.periodic(const Duration(seconds: 30), (_) => _checkNotes());
    _hour = Timer.periodic(const Duration(hours: 1), (_) => store.applyHourly());
    setState(() {});
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _notes?.cancel();
    _hour?.cancel();
    _toastTimer?.cancel();
    _newBoardName.dispose();
    super.dispose();
  }

  void _showToast(String text, {required bool red}) {
    _toastTimer?.cancel();
    _toast = text;
    _toastRed = red;
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _toast = '');
    });
  }

  void _checkNotes() {
    final b = store.board;
    if (b == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in b.cards) {
      if (!c.urgent || c.dueMs == null) continue;
      final left = c.dueMs! - now;
      if (left <= 0 && _toasted.add('o${c.id}')) {
        _showToast('${c.title} is overdue', red: true);
      } else if (left > 0 && left < const Duration(hours: 1).inMilliseconds && _toasted.add('s${c.id}')) {
        _showToast('${c.title} is due within the hour', red: false);
      }
    }
    if (mounted) setState(() {});
  }

  void _open(SgCard c) => setState(() {
        _openId = c.id;
        _overlay = '';
        _forceFlip = false;
        _cover = false;
      });

  @override
  Widget build(BuildContext context) {
    final b = store.board;
    final showHome = store.atHome || b == null;
    return CPane(
      span: CPaneSpan.phoneBoard,
      fit: CPaneFit.fill,
      child: ScrollConfiguration(
        behavior: const SgScroll(),
        child: showHome
            ? _boardsHome()
            : Stack(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(b!),
                    _viewChips(b),
                    if (b.surface == SgSurface.canvas) _canvasChips(b),
                    Expanded(child: _body(b)),
                    if (_multi) _bulkBar(b),
                  ],
                ),
                if (_toast.isNotEmpty)
                  Positioned(top: 8, left: 8, right: 8, child: _toastBar()),
              ]),
      ),
    );
  }

  final TextEditingController _newBoardName = TextEditingController();

  Widget _boardsHome() {
    return ColoredBox(
      key: const ValueKey('sg-boards-home'),
      color: const Color(0xFF12141A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Boards', style: appFont(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
              _icon('Close', Icons.close, widget.onClose),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _newBoardName,
              style: appFont(fontSize: 15, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add board title',
                hintStyle: appFont(fontSize: 15, color: Colors.white54),
                filled: true,
                fillColor: const Color(0x33FFFFFF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _createBoard(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _createBoard,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5C6BC0), foregroundColor: Colors.white),
                child: Text('Create board', style: appFont(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            if (store.boards.isEmpty)
              Expanded(
                child: Center(
                  child: Text('No boards yet', style: appFont(fontSize: 15, color: Colors.white70)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: store.boards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final board = store.boards[i];
                    return Material(
                      color: Color(board.background == 0 ? 0xFF2A2F3A : board.background | 0xFF000000),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          store.openBoard(board.id);
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          child: Row(children: [
                            Expanded(child: Text(board.name, style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                            if (board.starred) const Icon(Icons.star_rounded, color: Color(0xFFFFD56A), size: 18),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _createBoard() {
    final name = _newBoardName.text.trim();
    store.createBoard(name.isEmpty ? 'Board' : name, goHome: false);
    _newBoardName.clear();
    setState(() {});
  }

  Widget _icon(String tip, IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Tooltip(
      message: tip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 24),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }

  /// Trello's board bar: the name, one star, and a "…" that holds the rest.
  Widget _header(SgBoard b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(text: b.name),
            style: appFont(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
            onSubmitted: (v) => store.touch(() => b.name = v.trim().isEmpty ? b.name : v.trim()),
          ),
        ),
        _icon('Boards', Icons.grid_view_rounded, () { store.goHome(); setState(() {}); }),
        _icon(b.starred ? 'Unstar board' : 'Star board', b.starred ? Icons.star_rounded : Icons.star_outline_rounded, () => store.touch(() => b.starred = !b.starred), color: const Color(0xFFFFD56A)),
        _icon('Board menu', Icons.more_horiz, () => setState(() => _menu = !_menu)),
      ]),
    );
  }

  Widget _toastBar() {
    return Material(
      color: _toastRed ? const Color(0xFF8A2A22) : const Color(0xFF3D5A40),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(_toast, style: appFont(fontSize: 12, color: Colors.white)),
      ),
    );
  }

  Widget _viewChips(SgBoard b) {
    return SizedBox(
      height: 40,
      child: ScrollConfiguration(
          behavior: const SgScroll(),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final s in SgSurface.values)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _glassChoice(
                    label: s.label,
                    selected: b.surface == s,
                    size: 11,
                    onSelected: (_) => store.touch(() => b.surface = s),
                  ),
                ),
            ],
          ),
      ),
    );
  }

  /// Selected is the solid chip. The others are an outline on the glass,
  /// the same reading as a settings section: the chosen one is the fill.
  Widget _glassChoice({required String label, required bool selected, required ValueChanged<bool> onSelected, double size = 12}) {
    final ink = selected ? const Color(0xFF1C1B19) : Colors.white;
    final style = appFont(fontSize: size, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: ink);
    // The chip's own material is an opaque dark slab on this theme. A
    // transparent canvas lets the pane's glass show through the outline.
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
      child: ChoiceChip(
        label: Text(label, style: style),
        labelStyle: style,
        selected: selected,
        showCheckmark: false,
        onSelected: onSelected,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        side: BorderSide(color: selected ? const Color(0xFFFFFFFF) : const Color(0xE6FFFFFF), width: 1),
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFFF2F4F7);
          return const Color(0x14FFFFFF);
        }),
      ),
    );
  }

  Widget _canvasChips(SgBoard b) {
    return SizedBox(
      height: 40,
      child: Row(children: [
        Expanded(
          child: sgScroll(
            axis: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < b.canvases.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _glassChoice(
                    label: '${i + 1} ${b.canvases[i].name}',
                    selected: b.canvasIndex == i,
                    size: 11,
                    onSelected: (_) => store.touch(() => b.canvasIndex = i),
                  ),
                ),
            ]),
          ),
        ),
        Tooltip(
          message: 'Add canvas',
          child: IconButton(
            onPressed: () {
              final ok = store.addCanvas('Canvas ${b.canvases.length + 1}', 'Glass');
              if (!ok) setState(() => _showToast(store.notice, red: false));
            },
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _menuBody(SgBoard b) {
    return ScrollConfiguration(
      behavior: const SgScroll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Row(children: [
            Expanded(child: Text('Board menu', style: appFont(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
            _icon('Close', Icons.close, () => setState(() => _menu = false)),
          ]),
          _menuAction(Icons.search_rounded, 'Search', () => setState(() { _menu = false; _overlay = 'search'; })),
          _menuAction(Icons.bar_chart_rounded, 'Statistics', () => setState(() { _menu = false; _overlay = 'stats'; })),
          _menuAction(Icons.checklist_rounded, _multi ? 'Stop selecting' : 'Select cards', () => setState(() { _menu = false; _multi = !_multi; })),
          _menuAction(Icons.add_rounded, 'New card', () => setState(() { _menu = false; _overlay = 'create'; })),
          _menuAction(Icons.auto_awesome_rounded, 'Genie', () => setState(() { _menu = false; _overlay = 'genie'; })),
          const SizedBox(height: 8),
          Text('Members', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(b.guests.join(', '), style: appFont(fontSize: 13, color: Colors.white)),
          const SizedBox(height: 10),
          Text('Background', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            for (final color in [0xFF0079BF, 0xFF519839, 0xFFB04632, 0xFF89609E])
              GestureDetector(
                onTap: () => store.touch(() => b.background = color),
                child: Container(width: 36, height: 24, decoration: BoxDecoration(color: Color(color), borderRadius: BorderRadius.circular(4), border: Border.all(color: b.background == color ? Colors.white : Colors.transparent))),
              ),
          ]),
          const SizedBox(height: 10),
          Text('Board kind', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Wrap(spacing: 4, children: [
            for (final k in SgBoardKind.values)
              _glassChoice(
                label: k.name,
                selected: b.kind == k,
                size: 10,
                onSelected: (_) => store.touch(() {
                  b.kind = k;
                  final surface = SgSurface.values.asNameMap()[k.name];
                  if (surface != null) b.surface = surface;
                }),
              ),
          ]),
          _toggle('Auto sort', b.autoSort, (v) => store.touch(() => b.autoSort = v)),
          _toggle('Hide complete', b.autoFilterComplete, (v) => store.touch(() => b.autoFilterComplete = v)),
          _toggle('Inherit column status', b.inheritColumnStatus, (v) => store.touch(() => b.inheritColumnStatus = v)),
          _toggle('Urgent on today', b.urgentAutoCalendar, (v) => store.touch(() => b.urgentAutoCalendar = v)),
          Text('Status control', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Wrap(spacing: 4, children: [
            for (final k in SgStatusKind.values)
              _glassChoice(label: _statusKindLabel(k), selected: b.statusKind == k, size: 10, onSelected: (_) => store.touch(() => b.statusKind = k)),
          ]),
        ],
      ),
    );
  }

  Widget _menuAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Text(label, style: appFont(fontSize: 16, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged, {Color color = Colors.white}) {
    return Row(children: [
      Expanded(child: Text(label, style: appFont(fontSize: 14, color: color))),
      Switch(value: value, onChanged: onChanged),
    ]);
  }

  Widget _body(SgBoard b) {
    final open = store.byId(_openId);
    if (_overlay == 'create') return _create();
    if (_overlay == 'search') return _search(b);
    if (_overlay == 'stats') return _stats(b);
    if (_overlay == 'genie') return _genie();
    if (_overlay == 'editor-bulk') return _bulkEdit(b);
    if (_menu) return _menuBody(b);
    if (open != null) return _editor(b, open);
    return SgSurfaceView(store: store, onOpen: _open, multi: _multi, selected: _selected, forceFlip: _forceFlip, kanbanPage: _kanbanPage, onSelect: (c) => setState(() => _selected.contains(c.id) ? _selected.remove(c.id) : _selected.add(c.id)));
  }

  Widget _create() {
    return sgScroll(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in SgType.values)
            GestureDetector(
              onTap: () {
                final c = store.addCard(t);
                if (c == null) {
                  setState(() => _showToast(store.notice, red: false));
                  return;
                }
                setState(() {
                  _overlay = '';
                  _openId = c.id;
                });
              },
              child: Container(
                width: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(t.argb), shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  Text(t.label, textAlign: TextAlign.center, style: appFont(fontSize: 11, color: Colors.white)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _search(SgBoard b) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        TextField(
          autofocus: true,
          style: appFont(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(hintText: 'Search cards', hintStyle: TextStyle(color: Colors.white54)),
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final c in store.search(_query))
                ListTile(
                  leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(c.color), shape: BoxShape.circle)),
                  title: Text(c.title, style: appFont(color: Colors.white, fontSize: 13)),
                  subtitle: Text('${c.type.label} · ${c.status}', style: appFont(color: Colors.white70, fontSize: 11)),
                  onTap: () => _open(c),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  String _query = '';

  Widget _stats(SgBoard b) {
    final urgent = b.cards.where((c) => c.urgent).length;
    final due = b.cards.where((c) => c.dueMs != null).length;
    final priority = b.cards.where((c) => c.priority > 0).length;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        _stat('Total', b.cards.length),
        _stat('Priority', priority),
        _stat('Urgent', urgent),
        _stat('With deadline', due),
        for (final list in b.orderedLists) _stat(list.title, b.cardsIn(list.id).length),
        for (final t in SgType.values)
          if (b.cards.any((c) => c.type == t)) _stat(t.label, b.cards.where((c) => c.type == t).length),
      ]),
    );
  }

  Widget _stat(String label, int n) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text('$n', style: appFont(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: appFont(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }

  final TextEditingController _genieInput = TextEditingController();

  Widget _genie() {
    return Column(children: [
      Row(children: [
        Text('Genie', style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        const Spacer(),
        Tooltip(
          message: 'New conversation',
          child: IconButton(onPressed: () => store.newConversation(), icon: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 18)),
        ),
      ]),
      Expanded(
        child: ListView(
          children: [
            for (final m in store.genie)
              Align(
                alignment: m.role == 'you' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(6),
                  color: m.role == 'you' ? const Color(0x553D7A6A) : const Color(0x33FFFFFF),
                  child: Text(m.attachment.isEmpty ? m.text : '${m.text}\n${m.attachment}', style: appFont(fontSize: 12, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
      Row(children: [
        Expanded(child: TextField(controller: _genieInput, style: appFont(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: 'Message Genie', hintStyle: TextStyle(color: Colors.white38)))),
        Tooltip(message: 'Send', child: IconButton(onPressed: () {
          final t = _genieInput.text.trim();
          if (t.isEmpty) return;
          store.askGenie(t);
          _genieInput.clear();
        }, icon: const Icon(Icons.send_rounded, color: Colors.white))),
      ]),
    ]);
  }

  static const Color _ink = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xB3FFFFFF);
  static const Color _paper = Color(0xFF1A1C22); // dense dark glass base
  static const Color _line = Color(0x40FFFFFF);
  static const Color _chip = Color(0x33FFFFFF);
  static const Color _chipOn = Color(0x55FFFFFF);
  bool _cover = false;

  Future<void> _pickDue(SgCard c) async {
    final initial = c.dueMs == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(c.dueMs!);
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (!mounted) return;
    final picked = time ?? TimeOfDay.fromDateTime(initial);
    final next = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
    store.touch(() => c.dueMs = next.millisecondsSinceEpoch);
  }

  Widget _quick(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: _ink),
        label: Text(label, style: appFont(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          backgroundColor: _chip,
          side: const BorderSide(color: _line),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 36),
        ),
      ),
    );
  }

  bool _hasTrigger(SgCard c, String token) => c.triggers.split(',').map((s) => s.trim()).contains(token);

  void _setTrigger(SgCard c, String token, bool on) {
    final parts = c.triggers.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty && s != token).toList();
    if (on) parts.add(token);
    c.triggers = parts.join(',');
  }

  void _reveal(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 240), alignment: 0.05);
  }

  Widget _section(IconData icon, String title, List<Widget> children, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: _ink),
          const SizedBox(width: 8),
          Text(title, style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  /// Light chips on the paper sheet. The app theme is dark, so an unstyled
  /// chip paints a near-black fill behind the dark label and the words
  /// disappear. Selected uses the same light fill.
  ChipThemeData _paperChips() {
    const fill = _chip;
    const selected = _chipOn;
    final label = appFont(fontSize: 13, color: _ink);
    return ChipThemeData(
      backgroundColor: fill,
      selectedColor: selected,
      disabledColor: fill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
      side: const BorderSide(color: _line),
      labelStyle: label,
      secondaryLabelStyle: label,
      checkmarkColor: _ink,
      brightness: Brightness.dark,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return selected;
        return fill;
      }),
    );
  }

  Color _sheet(SgCard c) => c.color == 0 ? _paper : Color.alphaBlend(Color(c.color).withValues(alpha: 0.35), _paper);

  static const List<int> _coverSwatches = [
    0xFF61BD4F,
    0xFFF2D600,
    0xFFFF9F1A,
    0xFFEB5A46,
    0xFFC377E0,
    0xFF0079BF,
    0xFF00C2E0,
    0xFF51E898,
    0xFFFF78CB,
    0xFF344563,
  ];

  Widget _coverSheet(SgCard c) {
    final sheet = _sheet(c);
    return Theme(
      data: Theme.of(context).copyWith(chipTheme: _paperChips(), iconTheme: const IconThemeData(color: _ink, size: 18)),
      child: ColoredBox(
        key: const ValueKey('sg-cover-sheet'),
        color: sheet,
        child: Material(
          color: sheet,
          child: ScrollConfiguration(
            behavior: const SgScroll(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Row(children: [
                  Tooltip(
                    message: 'Back',
                    child: IconButton(
                      onPressed: () => setState(() => _cover = false),
                      icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                    ),
                  ),
                  Expanded(child: Text('Cover', style: appFont(fontSize: 20, fontWeight: FontWeight.w700, color: _ink))),
                ]),
                SgCover(card: c, height: 120),
                const SizedBox(height: 16),
                Text('Colors', style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final argb in _coverSwatches)
                    GestureDetector(
                      onTap: () => store.touch(() => c.color = argb),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(argb),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c.color == argb ? _ink : _line, width: c.color == argb ? 2 : 1),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => store.touch(() => c.color = 0),
                    child: Text('None', style: appFont(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editor(SgBoard b, SgCard c) {
    if (_cover) return _coverSheet(c);
    final listTitle = b.lists.where((l) => l.id == c.listId).firstOrNull?.title ?? c.status;
    final sheet = _sheet(c);
    return Theme(
      data: Theme.of(context).copyWith(chipTheme: _paperChips(), iconTheme: const IconThemeData(color: _ink, size: 18)),
      child: ColoredBox(
      key: const ValueKey('sg-card-sheet'),
      color: sheet,
      child: Material(
      color: sheet,
      child: ScrollConfiguration(
        behavior: const SgScroll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Row(children: [
              Tooltip(message: 'Back', child: IconButton(onPressed: () => setState(() { _openId = null; _cover = false; }), icon: const Icon(Icons.arrow_back_rounded, color: _ink))),
              const Spacer(),
              if (c.hasHidden)
                Tooltip(message: 'Hidden fields', child: IconButton(onPressed: () => setState(() => _forceFlip = !_forceFlip), icon: Icon(_forceFlip ? Icons.flip_rounded : Icons.flip_to_back_rounded, color: _ink))),
            ]),
            if (_forceFlip) SgFace(card: c, board: b, back: true) else SgCover(card: c, height: 96),
            _field('Title', c.title, (v) => store.touch(() => c.title = v), color: _ink),
            Text('in $listTitle on ${b.name}', style: appFont(fontSize: 13, color: _muted)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.schedule, size: 16, color: _ink),
                label: Text(_dueLabel(c.dueMs), style: appFont(fontSize: 14, color: _ink, fontWeight: FontWeight.w600)),
                onPressed: () => _pickDue(c),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quick(Icons.image_outlined, 'Cover', () => setState(() => _cover = true)),
                    const SizedBox(width: 8),
                    _quick(Icons.swap_horiz_rounded, 'Move', () => _reveal(_listKey)),
                    const SizedBox(width: 8),
                    _quick(Icons.label_outline, 'Labels', () => _reveal(_labelsKey)),
                    const SizedBox(width: 8),
                    _quick(Icons.people_outline, 'Members', () => _reveal(_membersKey)),
                    const SizedBox(width: 8),
                    _quick(Icons.check_box_outlined, 'Checklist', () => _reveal(_checkKey)),
                    const SizedBox(width: 8),
                    _quick(Icons.attach_file, 'Attachment', () => _reveal(_filesKey)),
                    const SizedBox(width: 8),
                    _quick(Icons.flag_outlined, 'Done', () => store.markDone(c)),
                  ],
                ),
              ),
            ),
            _section(Icons.notes_rounded, 'Description', [
              _field('Description', c.description, (v) => store.touch(() => c.description = v), lines: 3, color: _ink),
            ]),
            _section(Icons.view_column_outlined, 'List', [
              _addNew('List', b.orderedLists.map((l) => l.title).toList(), c.status, (name) {
                final list = b.lists.where((l) => l.title == name).firstOrNull;
                if (list != null) store.moveCard(c.id, list.id);
              }, (name) {
                store.addList(name);
                final list = b.lists.where((l) => l.title == name).firstOrNull;
                if (list != null) store.moveCard(c.id, list.id);
              }, color: _ink),
              _statusControl(b, c, color: _ink),
            ], key: _listKey),
            _section(Icons.tune_rounded, 'Custom fields', [
              for (final f in b.fields) _custom(c, f, color: _ink),
              _field('New field', '', (v) {
                if (v.trim().isNotEmpty) store.addField(v.trim(), SgFieldKind.text);
              }, color: _ink),
            ]),
            _section(Icons.checklist_rounded, 'Checklist', [
              for (final k in c.checks)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: k.done,
                  onChanged: (v) => store.touch(() => k.done = v ?? false),
                  title: Text(k.text, style: appFont(fontSize: 14, color: _ink)),
                ),
              _field('Add an item', '', (v) {
                if (v.trim().isEmpty) return;
                store.touch(() => c.checks.add(SgCheck(id: 'k${c.checks.length}${v.hashCode}', text: v.trim())));
              }, color: _ink),
            ], key: _checkKey),
            _section(Icons.attach_file, 'Attachments', [
              for (final f in c.files) Text(f.name, style: appFont(fontSize: 14, color: _ink)),
              if (c.files.isEmpty) Text('No attachments', style: appFont(fontSize: 14, color: _muted)),
            ], key: _filesKey),
            _section(Icons.chat_bubble_outline, 'Activity', [
              for (final a in c.activity.reversed.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(a.text, style: appFont(fontSize: 14, color: _ink)),
                ),
              _field('Comment', '', (v) {
                if (v.trim().isEmpty) return;
                store.touch(() => c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: v.trim())));
              }, color: _ink),
            ]),
            _section(Icons.category_outlined, 'Type', [
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final t in SgType.values)
                  ChoiceChip(
                    label: Text(t.label, style: appFont(fontSize: 12, color: _ink)),
                    selected: c.type == t,
                    onSelected: (_) => store.touch(() {
                      final old = c.type;
                      c.type = t;
                      // Only migrate a previous type-default colour; leave None alone.
                      if (c.color != 0 && c.color == old.argb) c.color = t.argb;
                    }),
                  ),
              ]),
            ]),
            _section(Icons.label_outline, 'Labels', [
              Wrap(spacing: 4, children: [
                for (final l in b.labels)
                  FilterChip(
                    label: Text(l.title, style: appFont(fontSize: 12, color: _ink)),
                    selected: c.labelIds.contains(l.id),
                    onSelected: (on) => store.touch(() => on ? c.labelIds.add(l.id) : c.labelIds.remove(l.id)),
                  ),
              ]),
            ], key: _labelsKey),
            _section(Icons.people_outline, 'Members', [
              Text(c.members.isEmpty ? 'No members' : c.members.join(', '), style: appFont(fontSize: 14, color: c.members.isEmpty ? _muted : _ink)),
              _field('Add a member', '', (v) {
                if (v.trim().isEmpty) return;
                store.touch(() => c.members.add(v.trim()));
              }, color: _ink),
              _field('Assignee', c.assignee, (v) => store.touch(() => c.assignee = v), color: _ink),
            ], key: _membersKey),
            _section(Icons.bolt_outlined, 'Triggers', [
              _toggle('When the card is finished', _hasTrigger(c, 'done-final'), (v) => store.touch(() => _setTrigger(c, 'done-final', v)), color: _ink),
              _toggle('Each hour', _hasTrigger(c, 'hourly'), (v) => store.touch(() => _setTrigger(c, 'hourly', v)), color: _ink),
              _toggle('Urgent', c.urgent, (v) => store.touch(() => c.urgent = v), color: _ink),
              _toggle('Use the list name as the status', c.inherit, (v) => store.touch(() => c.inherit = v), color: _ink),
            ]),
            _section(Icons.dashboard_customize_outlined, 'Embeds', [
              for (final id in c.embeds)
                if (store.byId(id) != null)
                  TextButton(onPressed: () => _open(store.byId(id)!), child: Align(alignment: Alignment.centerLeft, child: Text(store.byId(id)!.title, style: appFont(color: _ink, fontSize: 14)))),
              _addNew('Add a card', [for (final o in b.cards) if (o.id != c.id) o.title], '', (name) {
                final other = b.cards.where((o) => o.title == name).firstOrNull;
                if (other != null && !c.embeds.contains(other.id)) store.touch(() => c.embeds.add(other.id));
              }, (_) {}, color: _ink),
            ]),
            if (c.hasHidden || c.hiddenNotes.isNotEmpty)
              _section(Icons.flip_to_back_rounded, 'Hidden notes', [
                _field('Private note', c.hiddenNotes, (v) => store.touch(() => c.hiddenNotes = v), lines: 2, color: _ink),
              ]),
            _section(Icons.menu_book_outlined, 'Pages', [
              _field('Pages', c.notebook.replaceAll('\n---\n', '\n\n'), (v) => store.touch(() => c.notebook = v.replaceAll('\n\n', '\n---\n')), lines: 4, color: _ink),
            ]),
            _section(Icons.sell_outlined, 'Tags', [
              _field('Tags', c.tags.join(', '), (v) => store.touch(() {
                c.tags
                  ..clear()
                  ..addAll(v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
              }), color: _ink),
            ]),
            if (c.type == SgType.job)
              _section(Icons.work_outline, 'Role', [
                _field('Company', c.company, (v) => store.touch(() => c.company = v), color: _ink),
                _field('Position', c.positionTitle, (v) => store.touch(() => c.positionTitle = v), color: _ink),
                _field('Start', c.jobStart, (v) => store.touch(() => c.jobStart = v), color: _ink),
                _field('End', c.jobEnd, (v) => store.touch(() => c.jobEnd = v), color: _ink),
                _field('Responsibilities', c.responsibilities, (v) => store.touch(() => c.responsibilities = v), lines: 2, color: _ink),
                _field('Achievements', c.achievements, (v) => store.touch(() => c.achievements = v), lines: 2, color: _ink),
              ]),
            TextButton(
              onPressed: () {
                store.removeCards([c.id]);
                setState(() => _openId = null);
              },
              child: Text('Delete card', style: appFont(color: const Color(0xFFB42318))),
            ),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Widget _statusControl(SgBoard b, SgCard c, {Color color = Colors.white}) {
    return switch (b.statusKind) {
      SgStatusKind.dropdown => _addNew('Status', b.statuses, c.status, (name) => store.touch(() => c.status = name), (name) => store.addStatus(name), color: color),
      SgStatusKind.toggle => _toggle('Status is ${c.status}', c.status == (b.statuses.isEmpty ? '' : b.statuses.last), (v) {
          if (b.statuses.isEmpty) return;
          store.touch(() => c.status = v ? b.statuses.last : b.statuses.first);
        }, color: color),
      SgStatusKind.input => _field('Status', c.status, (v) => store.touch(() => c.status = v), color: color),
      SgStatusKind.color => Wrap(spacing: 4, children: [
          for (final t in SgType.values)
            GestureDetector(
              onTap: () => store.touch(() => c.color = t.argb),
              child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Color(t.argb), shape: BoxShape.circle, border: Border.all(color: c.color == t.argb ? Colors.white : Colors.transparent))),
            ),
        ]),
    };
  }

  Widget _custom(SgCard c, SgFieldDef f, {Color color = Colors.white}) {
    final value = c.custom[f.id] ?? '';
    return switch (f.kind) {
      SgFieldKind.checkbox => _toggle(f.name, value == 'true', (v) => store.touch(() => c.custom[f.id] = v.toString()), color: color),
      SgFieldKind.select || SgFieldKind.multi => _addNew(f.name, const ['open', 'doing', 'done'], value, (name) => store.touch(() => c.custom[f.id] = name), (name) => store.touch(() => c.custom[f.id] = name), color: color),
      SgFieldKind.text || SgFieldKind.textarea || SgFieldKind.richtext || SgFieldKind.number || SgFieldKind.date || SgFieldKind.datetime || SgFieldKind.person || SgFieldKind.url || SgFieldKind.file => _field(f.name, value, (v) => store.touch(() => c.custom[f.id] = v), lines: f.kind == SgFieldKind.textarea || f.kind == SgFieldKind.richtext ? 3 : 1, color: color),
    };
  }

  Widget _field(String label, String value, ValueChanged<String> onSubmit, {int lines = 1, Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: TextEditingController(text: value),
        minLines: lines,
        maxLines: lines,
        style: appFont(fontSize: 15, color: color),
        decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: color.withValues(alpha: 0.55)), isDense: true),
        onSubmitted: onSubmit,
      ),
    );
  }

  Widget _addNew(String label, List<String> options, String current, ValueChanged<String> onPick, ValueChanged<String> onCreate, {Color color = Colors.white}) {
    return _OptionRow(label: label, options: options, current: current, onPick: onPick, onCreate: onCreate, color: color);
  }

  Widget _bulkEdit(SgBoard b) {
    final cards = b.cards.where((c) => _selected.contains(c.id)).toList();
    return sgScroll(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Edit ${cards.length}', style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(cards.map((c) => c.title).join(', '), style: appFont(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Status', style: appFont(fontSize: 11, color: Colors.white70)),
          Wrap(spacing: 4, children: [
            for (final s in b.statuses)
              ActionChip(
                label: Text(s, style: appFont(fontSize: 11, color: Colors.white)),
                onPressed: () => store.touch(() {
                  for (final c in cards) {
                    c.status = s;
                  }
                }),
              ),
          ]),
          _field('Assignee', '', (v) => store.touch(() {
                for (final c in cards) {
                  c.assignee = v;
                }
              })),
          const SizedBox(height: 8),
          Text('Priority', style: appFont(fontSize: 11, color: Colors.white70)),
          Wrap(spacing: 4, children: [
            for (final p in [0, 1, 2, 3])
              ActionChip(
                label: Text('$p', style: appFont(fontSize: 11, color: Colors.white)),
                onPressed: () => store.touch(() {
                  for (final c in cards) {
                    c.priority = p;
                  }
                }),
              ),
          ]),
          TextButton(onPressed: () => setState(() => _overlay = ''), child: Text('Done', style: appFont(color: Colors.white))),
        ]),
      ),
    );
  }

  Widget _bulkBar(SgBoard b) {
    return Container(
      color: const Color(0xCC1C1C1E),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Text('${_selected.length}', style: appFont(color: Colors.white, fontWeight: FontWeight.w700)),
        TextButton(onPressed: () => setState(() => _overlay = 'editor-bulk'), child: Text('Edit', style: appFont(color: Colors.white))),
        TextButton(
          onPressed: () {
            if (!_armedDelete) {
              setState(() => _armedDelete = true);
              return;
            }
            store.removeCards(_selected);
            setState(() {
              _selected.clear();
              _armedDelete = false;
              _multi = false;
            });
          },
          child: Text(_armedDelete ? 'Confirm delete' : 'Delete', style: appFont(color: const Color(0xFFFF8A80))),
        ),
        TextButton(onPressed: () => setState(() {
          _multi = false;
          _selected.clear();
          _armedDelete = false;
        }), child: Text('Cancel', style: appFont(color: Colors.white))),
      ]),
    );
  }
}

class _OptionRow extends StatefulWidget {
  const _OptionRow({required this.label, required this.options, required this.current, required this.onPick, required this.onCreate, this.color = Colors.white});
  final String label;
  final List<String> options;
  final String current;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onCreate;
  final Color color;
  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool adding = false;
  final TextEditingController t = TextEditingController();
  @override
  void dispose() {
    t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.label, style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: widget.color)),
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final o in widget.options)
            ChoiceChip(
              label: Text(o, style: appFont(fontSize: 13, color: widget.color)),
              selected: o == widget.current,
              onSelected: (_) => widget.onPick(o),
            ),
        ]),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            minimumSize: const Size(double.infinity, 44),
            alignment: Alignment.centerLeft,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => setState(() => adding = true),
          child: Text('+ Add new…', style: appFont(fontSize: 16, color: widget.color)),
        ),
        if (adding)
          TextField(
            controller: t,
            style: appFont(color: widget.color, fontSize: 13),
            decoration: const InputDecoration(hintText: 'New option', hintStyle: TextStyle(color: Colors.white38)),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              widget.onCreate(v.trim());
              setState(() => adding = false);
            },
          ),
      ]),
    );
  }
}

/// Quiet reference so the token import stays used if a caller wants spacing.
const double kSgPad = VSpace.sm;

const _dueMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _dueLabel(int? ms) {
  if (ms == null) return 'Add date';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  final min = d.minute.toString().padLeft(2, '0');
  return '${_dueMonths[d.month - 1]} ${d.day}, $hour:$min $ap';
}

String _statusKindLabel(SgStatusKind kind) => switch (kind) {
      SgStatusKind.dropdown => 'List',
      SgStatusKind.toggle => 'Switch',
      SgStatusKind.input => 'Text',
      SgStatusKind.color => 'Color',
    };
