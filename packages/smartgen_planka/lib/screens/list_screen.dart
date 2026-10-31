import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/models/planka_project.dart';
import 'package:provider/provider.dart';
import '../providers/list_provider.dart';
import '../widgets/list_list.dart';
import '../models/planka_board.dart';

class ListScreen extends StatefulWidget {
  PlankaProject? currentProject;
  PlankaBoard? currentBoard;
  /// Host embed close — AppBar leading only (never a Stack overlay on the title).
  final VoidCallback? onHostClose;

  ListScreen({super.key, this.currentProject, this.currentBoard, this.onHostClose});

  @override
  _ListScreenState createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _refreshLists() {
    setState(() {
      Provider.of<ListProvider>(context, listen: false)
          .fetchLists(boardId: widget.currentBoard!.id, context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final backgroundImageUrl = widget.currentProject?.backgroundImage?['url'];

    return Scaffold(
      backgroundColor: const Color(0xFF0079BF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0079BF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        // Close in leading so the board name stays centred.
        leading: widget.onHostClose != null
            ? IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: widget.onHostClose,
              )
            : null,
        title: Text(
          widget.currentBoard?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: store.canUndo ? () { store.undo(); _refreshLists(); } : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: store.canRedo ? () { store.redo(); _refreshLists(); } : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Filter',
            onPressed: () async {
              final ctrl = TextEditingController(text: store.filterQuery ?? '');
              await showModalBottomSheet(
                context: context,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list)),
                    onChanged: (q) {
                      store.filterQuery = q;
                      _refreshLists();
                    },
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.filter_list,
              color: (store.filterQuery ?? '').isNotEmpty ? Colors.indigo : null,
            ),
          ),
          // Align + Board/Table/Calendar/Timeline live in Board menu (avoid twin column icons).
          IconButton(
            tooltip: 'Board menu',
            onPressed: () => Navigator.pushNamed(context, '/boardmenu'),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: Container(
        decoration: backgroundImageUrl != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(backgroundImageUrl),
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: FutureBuilder(
          future: Provider.of<ListProvider>(context, listen: false)
              .fetchLists(boardId: widget.currentBoard!.id, context: context),
          builder: (ctx, snapshot) => snapshot.connectionState == ConnectionState.waiting
              ? const ColoredBox(color: Color(0xFF0079BF), child: SizedBox.expand())
              : Consumer<ListProvider>(
                  builder: (ctx, listProvider, _) => ListList(
                    listProvider.lists,
                    widget.currentBoard!,
                    onRefresh: _refreshLists,
                  ),
                ),
        ),
      ),
    );
  }
}
