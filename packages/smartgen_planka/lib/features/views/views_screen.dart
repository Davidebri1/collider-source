import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:trina_grid/trina_grid.dart';

String _fmtDue(dynamic raw) {
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty) return '';
  // ISO yyyy-MM-dd → dd.MM.yyyy (same as card chips)
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m != null) return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
  return s;
}

/// Board / Table / Calendar / Timeline over the same PlankaStore cards.
/// Titles are Trello's exact view names.
class ViewsScreen extends StatefulWidget {
  const ViewsScreen({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<ViewsScreen> createState() => _ViewsScreenState();
}

class _ViewsScreenState extends State<ViewsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final i = widget.initialIndex.clamp(0, 3);
    _tabs = TabController(length: 4, vsync: this, initialIndex: i);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final cards = store.cards.where((c) => !store.archivedCardIds.contains(c['id'])).toList();
    return Scaffold(
      
      appBar: AppBar(
        
        
        title: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFF5E6C84),
          indicatorColor: const Color(0xFF5C6BC0),
          tabs: const [
            Tab(text: 'Board'),
            Tab(text: 'Table'),
            Tab(text: 'Calendar'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Board — back to lists of first board
          Center(
            child: IconButton(
              icon: const Icon(Icons.view_column, size: 48),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          _TableView(cards: cards),
          _CalendarView(cards: cards),
          _TimelineView(cards: cards),
        ],
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.cards});
  final List<Map<String, dynamic>> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const Center(child: Icon(Icons.inbox_outlined));
    final store = PlankaStore.instance;
    final listName = {
      for (final l in store.lists) l['id'] as String: '${l['name'] ?? ''}',
    };
    // Fit Name + List + Due inside 440 (or pan with no scrollbar).
    final cols = [
      TrinaColumn(title: 'Name', field: 'name', type: TrinaColumnType.text(), width: 160, minWidth: 120, titleTextAlign: TrinaColumnTextAlign.center),
      TrinaColumn(title: 'List', field: 'listId', type: TrinaColumnType.text(), width: 96, minWidth: 72, titleTextAlign: TrinaColumnTextAlign.center),
      TrinaColumn(title: 'Due', field: 'dueDate', type: TrinaColumnType.text(), width: 120, minWidth: 110, titleTextAlign: TrinaColumnTextAlign.center),
    ];
    final rows = [
      for (final c in cards)
        TrinaRow(cells: {
          'name': TrinaCell(value: '${c['name'] ?? ''}'),
          'listId': TrinaCell(value: listName['${c['listId']}'] ?? ''),
          'dueDate': TrinaCell(value: _fmtDue(c['dueDate'])),
        }),
    ];
    return ScrollConfiguration(
      behavior: const _NoBarScroll(),
      child: InteractiveViewer(
        constrained: false,
        scaleEnabled: false,
        child: SizedBox(
          width: 440,
          height: MediaQuery.sizeOf(context).height - kToolbarHeight - 48,
          child: TrinaGrid(
            columns: cols,
            rows: rows,
            configuration: const TrinaGridConfiguration(
              style: TrinaGridStyleConfig(gridBorderColor: Colors.transparent),
              columnSize: TrinaGridColumnSizeConfig(autoSizeMode: TrinaAutoSizeMode.scale),
              scrollbar: TrinaGridScrollbarConfig(isAlwaysShown: false, thumbVisible: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView({required this.cards});
  final List<Map<String, dynamic>> cards;
  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  List<Map<String, dynamic>> _eventsFor(DateTime day) {
    final key = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return widget.cards.where((c) {
      final d = '${c['dueDate'] ?? ''}';
      return d.startsWith(key);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focused,
          selectedDayPredicate: (d) => _selected != null && isSameDay(_selected, d),
          eventLoader: _eventsFor,
          onDaySelected: (sel, foc) => setState(() {
            _selected = sel;
            _focused = foc;
          }),
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          headerStyle: const HeaderStyle(formatButtonVisible: false),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final c in _eventsFor(_selected ?? _focused))
                ListTile(title: Text('${c['name']}', style: const TextStyle(color: Colors.black87))),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.cards});
  final List<Map<String, dynamic>> cards;

  @override
  Widget build(BuildContext context) {
    final sorted = [...cards]..sort((a, b) => '${a['dueDate'] ?? '9999'}'.compareTo('${b['dueDate'] ?? '9999'}'));
    if (sorted.isEmpty) return const Center(child: Icon(Icons.inbox_outlined));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final c = sorted[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 88, child: Text(_fmtDue(c['dueDate']).isEmpty ? '—' : _fmtDue(c['dueDate']), style: const TextStyle(fontSize: 12))),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x28FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${c['name']}', style: const TextStyle(color: Colors.black87)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _NoBarScroll extends ScrollBehavior {
  const _NoBarScroll();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}
