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
  final Set<String> _toasted = {};
  Timer? _notes;
  Timer? _hour;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _boot();
  }

  Future<void> _boot() async {
    await store.init();
    if (!mounted) return;
    final q = Uri.base.queryParameters;
    final sg = q['sg'];
    final surface = SgSurface.values.asNameMap()[sg ?? ''];
    if (surface != null) store.board!.surface = surface;
    if (sg == 'flip') _forceFlip = true;
    if (sg == 'editor') _openId = store.board!.cards.firstOrNull?.id;
    if (sg == 'search' || sg == 'stats' || sg == 'genie' || sg == 'create') _overlay = sg!;
    if (sg == 'menu') _menu = true;
    if (sg == 'multi') {
      _multi = true;
      _selected.addAll(store.board!.cards.take(3).map((c) => c.id));
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
      });

  @override
  Widget build(BuildContext context) {
    final b = store.board;
    return CPane(
      child: b == null
          ? const SizedBox.shrink()
          : Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _header(b),
                _viewChips(b),
                if (b.surface == SgSurface.canvas) _canvasChips(b),
                Expanded(child: _body(b)),
                if (_multi) _bulkBar(b),
              ]),
              if (_toast.isNotEmpty)
                Positioned(top: 8, left: 8, right: 8, child: _toastBar()),
            ]),
    );
  }

  Widget _icon(String tip, IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Tooltip(
      message: tip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 18),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      ),
    );
  }

  Widget _header(SgBoard b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: TextEditingController(text: b.name),
          style: appFont(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
          onSubmitted: (v) => store.touch(() => b.name = v.trim().isEmpty ? b.name : v.trim()),
        ),
        Row(children: [
          _icon(b.starred ? 'Unstar board' : 'Star board', b.starred ? Icons.star_rounded : Icons.star_outline_rounded, () => store.touch(() => b.starred = !b.starred), color: const Color(0xFFFFD56A)),
          _icon('Search', Icons.search_rounded, () => setState(() => _overlay = _overlay == 'search' ? '' : 'search')),
          _icon('Statistics', Icons.bar_chart_rounded, () => setState(() => _overlay = _overlay == 'stats' ? '' : 'stats')),
          _icon('Select cards', Icons.checklist_rounded, () => setState(() => _multi = !_multi)),
          _icon('New card', Icons.add_rounded, () => setState(() => _overlay = 'create')),
          _icon('Genie', Icons.auto_awesome_rounded, () => setState(() => _overlay = _overlay == 'genie' ? '' : 'genie')),
          _icon('Board menu', Icons.tune_rounded, () => setState(() => _menu = !_menu)),
        ]),
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
              child: ChoiceChip(
                label: Text(s.label, style: appFont(fontSize: 12, color: Colors.white)),
                selected: b.surface == s,
                onSelected: (_) => store.touch(() => b.surface = s),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
        ),
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
                  child: ChoiceChip(
                    label: Text('${i + 1} ${b.canvases[i].name}', style: appFont(fontSize: 11, color: Colors.white)),
                    selected: b.canvasIndex == i,
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
          Text('Board menu', style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
              ChoiceChip(
                label: Text(k.name, style: appFont(fontSize: 10, color: Colors.white)),
                selected: b.kind == k,
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
              ChoiceChip(label: Text(k.name, style: appFont(fontSize: 10, color: Colors.white)), selected: b.statusKind == k, onSelected: (_) => store.touch(() => b.statusKind = k)),
          ]),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Expanded(child: Text(label, style: appFont(fontSize: 11, color: Colors.white))),
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
    return SgSurfaceView(store: store, onOpen: _open, multi: _multi, selected: _selected, forceFlip: _forceFlip, onSelect: (c) => setState(() => _selected.contains(c.id) ? _selected.remove(c.id) : _selected.add(c.id)));
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
      Text('Pro unlocks agent actions. This engine runs locally.', style: appFont(fontSize: 10, color: Colors.white54)),
      Row(children: [
        Expanded(child: TextField(controller: _genieInput, style: appFont(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: 'set all priority to high', hintStyle: TextStyle(color: Colors.white38)))),
        Tooltip(message: 'Send', child: IconButton(onPressed: () {
          final t = _genieInput.text.trim();
          if (t.isEmpty) return;
          store.askGenie(t);
          _genieInput.clear();
        }, icon: const Icon(Icons.send_rounded, color: Colors.white))),
      ]),
    ]);
  }

  Widget _editor(SgBoard b, SgCard c) {
    return ScrollConfiguration(
      behavior: const SgScroll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          Row(children: [
            Tooltip(message: 'Back', child: IconButton(onPressed: () => setState(() => _openId = null), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))),
            Expanded(child: Text(c.type.label, style: appFont(fontSize: 12, color: Colors.white70))),
            if (c.hasHidden)
              Tooltip(message: 'Hidden fields', child: IconButton(onPressed: () => setState(() => _forceFlip = !_forceFlip), icon: const Icon(Icons.flip_rounded, color: Colors.white))),
          ]),
          if (_forceFlip) SgFace(card: c, board: b, back: true) else SgFace(card: c, board: b),
          _field('Title', c.title, (v) => store.touch(() => c.title = v)),
          _field('Description', c.description, (v) => store.touch(() => c.description = v), lines: 3),
          Text('Type', style: appFont(fontSize: 11, color: Colors.white70)),
          Wrap(spacing: 4, children: [
            for (final t in SgType.values)
              ChoiceChip(label: Text(t.label, style: appFont(fontSize: 10, color: Colors.white)), selected: c.type == t, onSelected: (_) => store.touch(() {
                c.type = t;
                c.color = t.argb;
              })),
          ]),
          _addNew('Column', b.orderedLists.map((l) => l.title).toList(), c.status, (name) {
            final list = b.lists.where((l) => l.title == name).firstOrNull;
            if (list != null) store.moveCard(c.id, list.id);
          }, (name) {
            store.addList(name);
            final list = b.lists.where((l) => l.title == name).firstOrNull;
            if (list != null) store.moveCard(c.id, list.id);
          }),
          _statusControl(b, c),
          _field('Assignee', c.assignee, (v) => store.touch(() => c.assignee = v)),
          _field('Due (ms is set by the clock; type a note)', c.dueMs == null ? '' : DateTime.fromMillisecondsSinceEpoch(c.dueMs!).toIso8601String(), (v) {
            final d = DateTime.tryParse(v);
            if (d != null) store.touch(() => c.dueMs = d.millisecondsSinceEpoch);
          }),
          _toggle('Urgent', c.urgent, (v) => store.touch(() => c.urgent = v)),
          _toggle('Inherit column status', c.inherit, (v) => store.touch(() => c.inherit = v)),
          _field('Tags', c.tags.join(', '), (v) => store.touch(() {
            c.tags
              ..clear()
              ..addAll(v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
          })),
          _field('Hidden notes', c.hiddenNotes, (v) => store.touch(() => c.hiddenNotes = v), lines: 2),
          _field('Notebook pages, separated by ---', c.notebook, (v) => store.touch(() => c.notebook = v), lines: 4),
          _field('Triggers (done-final, hourly)', c.triggers, (v) => store.touch(() => c.triggers = v)),
          TextButton(onPressed: () => store.markDone(c), child: Text('Mark done', style: appFont(color: Colors.white))),
          Text('Labels', style: appFont(fontSize: 11, color: Colors.white70)),
          Wrap(spacing: 4, children: [
            for (final l in b.labels)
              FilterChip(
                label: Text(l.title, style: appFont(fontSize: 10, color: Colors.white)),
                selected: c.labelIds.contains(l.id),
                onSelected: (on) => store.touch(() => on ? c.labelIds.add(l.id) : c.labelIds.remove(l.id)),
              ),
          ]),
          Text('Checklist', style: appFont(fontSize: 11, color: Colors.white70)),
          for (final k in c.checks)
            CheckboxListTile(
              dense: true,
              value: k.done,
              onChanged: (v) => store.touch(() => k.done = v ?? false),
              title: Text(k.text, style: appFont(fontSize: 12, color: Colors.white)),
            ),
          _field('Add checklist item', '', (v) {
            if (v.trim().isEmpty) return;
            store.touch(() => c.checks.add(SgCheck(id: 'k${c.checks.length}${v.hashCode}', text: v.trim())));
          }),
          Text('Members', style: appFont(fontSize: 11, color: Colors.white70)),
          Text(c.members.join(', '), style: appFont(fontSize: 12, color: Colors.white)),
          _field('Add member', '', (v) {
            if (v.trim().isEmpty) return;
            store.touch(() => c.members.add(v.trim()));
          }),
          if (c.type == SgType.job) ...[
            _field('Company', c.company, (v) => store.touch(() => c.company = v)),
            _field('Position', c.positionTitle, (v) => store.touch(() => c.positionTitle = v)),
            _field('Start', c.jobStart, (v) => store.touch(() => c.jobStart = v)),
            _field('End', c.jobEnd, (v) => store.touch(() => c.jobEnd = v)),
            _field('Responsibilities', c.responsibilities, (v) => store.touch(() => c.responsibilities = v), lines: 2),
            _field('Achievements', c.achievements, (v) => store.touch(() => c.achievements = v), lines: 2),
          ],
          Text('Custom fields', style: appFont(fontSize: 11, color: Colors.white70)),
          for (final f in b.fields) _custom(c, f),
          _field('New field name', '', (v) {
            if (v.trim().isNotEmpty) store.addField(v.trim(), SgFieldKind.text);
          }),
          Text('Embeds', style: appFont(fontSize: 11, color: Colors.white70)),
          for (final id in c.embeds)
            if (store.byId(id) != null)
              TextButton(onPressed: () => _open(store.byId(id)!), child: Text(store.byId(id)!.title, style: appFont(color: Colors.white, fontSize: 12))),
          _addNew('Embed a card', [for (final o in b.cards) if (o.id != c.id) o.title], '', (name) {
            final other = b.cards.where((o) => o.title == name).firstOrNull;
            if (other != null && !c.embeds.contains(other.id)) store.touch(() => c.embeds.add(other.id));
          }, (_) {}),
          Text('Files', style: appFont(fontSize: 11, color: Colors.white70)),
          for (final f in c.files) Text(f.name, style: appFont(fontSize: 12, color: Colors.white)),
          Text('Activity', style: appFont(fontSize: 11, color: Colors.white70)),
          for (final a in c.activity.reversed.take(6)) Text(a.text, style: appFont(fontSize: 11, color: Colors.white70)),
          _field('Comment', '', (v) {
            if (v.trim().isEmpty) return;
            store.touch(() => c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: v.trim())));
          }),
          TextButton(
            onPressed: () {
              store.removeCards([c.id]);
              setState(() => _openId = null);
            },
            child: Text('Delete card', style: appFont(color: const Color(0xFFFF8A80))),
          ),
        ],
      ),
    );
  }

  Widget _statusControl(SgBoard b, SgCard c) {
    return switch (b.statusKind) {
      SgStatusKind.dropdown => _addNew('Status', b.statuses, c.status, (name) => store.touch(() => c.status = name), (name) => store.addStatus(name)),
      SgStatusKind.toggle => _toggle('Status is ${c.status}', c.status == (b.statuses.isEmpty ? '' : b.statuses.last), (v) {
          if (b.statuses.isEmpty) return;
          store.touch(() => c.status = v ? b.statuses.last : b.statuses.first);
        }),
      SgStatusKind.input => _field('Status', c.status, (v) => store.touch(() => c.status = v)),
      SgStatusKind.color => Wrap(spacing: 4, children: [
          for (final t in SgType.values)
            GestureDetector(
              onTap: () => store.touch(() => c.color = t.argb),
              child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Color(t.argb), shape: BoxShape.circle, border: Border.all(color: c.color == t.argb ? Colors.white : Colors.transparent))),
            ),
        ]),
    };
  }

  Widget _custom(SgCard c, SgFieldDef f) {
    final value = c.custom[f.id] ?? '';
    return switch (f.kind) {
      SgFieldKind.checkbox => _toggle(f.name, value == 'true', (v) => store.touch(() => c.custom[f.id] = v.toString())),
      SgFieldKind.select || SgFieldKind.multi => _addNew(f.name, const ['open', 'doing', 'done'], value, (name) => store.touch(() => c.custom[f.id] = name), (name) => store.touch(() => c.custom[f.id] = name)),
      SgFieldKind.text || SgFieldKind.textarea || SgFieldKind.richtext || SgFieldKind.number || SgFieldKind.date || SgFieldKind.datetime || SgFieldKind.person || SgFieldKind.url || SgFieldKind.file => _field('${f.name} (${f.kind.label})', value, (v) => store.touch(() => c.custom[f.id] = v), lines: f.kind == SgFieldKind.textarea || f.kind == SgFieldKind.richtext ? 3 : 1),
    };
  }

  Widget _field(String label, String value, ValueChanged<String> onSubmit, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: TextEditingController(text: value),
        minLines: lines,
        maxLines: lines,
        style: appFont(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), isDense: true),
        onSubmitted: onSubmit,
      ),
    );
  }

  Widget _addNew(String label, List<String> options, String current, ValueChanged<String> onPick, ValueChanged<String> onCreate) {
    return _OptionRow(label: label, options: options, current: current, onPick: onPick, onCreate: onCreate);
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
  const _OptionRow({required this.label, required this.options, required this.current, required this.onPick, required this.onCreate});
  final String label;
  final List<String> options;
  final String current;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onCreate;
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
        Text(widget.label, style: appFont(fontSize: 11, color: Colors.white70)),
        Wrap(spacing: 4, children: [
          for (final o in widget.options)
            ChoiceChip(label: Text(o, style: appFont(fontSize: 10, color: Colors.white)), selected: o == widget.current, onSelected: (_) => widget.onPick(o)),
          ActionChip(label: Text('+ Add new…', style: appFont(fontSize: 10, color: Colors.white)), onPressed: () => setState(() => adding = true)),
        ]),
        if (adding)
          TextField(
            controller: t,
            style: appFont(color: Colors.white, fontSize: 13),
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
