import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/models/planka_board.dart';
import 'package:planka_app/models/planka_project.dart';
import 'package:planka_app/providers/auth_provider.dart';
import 'package:planka_app/screens/list_screen.dart';
import 'package:provider/provider.dart';

/// Smart Gen boards hub — Collider look, same wording as the live SgPane
/// boards home ("Boards" / "Add board title" / "Create board" / "No boards yet").
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, this.onHostClose, this.onOpenLiveSurfaces});
  final VoidCallback? onHostClose;
  final VoidCallback? onOpenLiveSurfaces;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final TextEditingController _newBoardName = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _newBoardName.dispose();
    super.dispose();
  }

  void _createBoard() {
    final name = _newBoardName.text.trim();
    if (name.isEmpty) return;
    final store = PlankaStore.instance;
    final proj = store.projects.isEmpty
        ? store.createProject(name)
        : store.projects.first;
    final board = store.createBoard(
      projectId: proj['id'] as String,
      name: name,
      position: (store.boards.length + 1) * 65535,
    );
    final bid = board['id'] as String;
    store.createList(boardId: bid, name: 'To Do', position: 65535);
    store.createList(boardId: bid, name: 'Doing', position: 131070);
    store.createList(boardId: bid, name: 'Done', position: 196605);
    _newBoardName.clear();
    setState(() {});
    _openBoard(bid);
  }

  void _openBoard(String boardId) {
    final store = PlankaStore.instance;
    Map<String, dynamic>? raw;
    for (final b in store.boards) {
      if (b['id'] == boardId) {
        raw = b;
        break;
      }
    }
    final detail = store.boardDetailPayload(boardId);
    final board = PlankaBoard.fromJson(
      Map<String, dynamic>.from(detail['item'] as Map),
      Map<String, dynamic>.from(detail['included'] as Map),
    );
    PlankaProject? project;
    final pid = raw == null ? null : '${raw['projectId'] ?? ''}';
    if (pid != null && pid.isNotEmpty) {
      final pd = store.projectDetailPayload(pid);
      project = PlankaProject.fromJson(
        Map<String, dynamic>.from(pd['item'] as Map),
        Map<String, dynamic>.from(pd['included'] as Map),
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListScreen(
          currentProject: project,
          currentBoard: board,
          onHostClose: widget.onHostClose,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    // Flat board list (old Smart Gen had boards, not a blank projects hub).
    final boards = List<Map<String, dynamic>>.from(store.boards);

    return ColoredBox(
      color: const Color(0xFF0E1016),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Boards',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: widget.onHostClose != null
                          ? IconButton(
                              tooltip: 'Close',
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: widget.onHostClose,
                            )
                          : const SizedBox.shrink(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onOpenLiveSurfaces != null)
                            IconButton(
                              icon: const Icon(Icons.auto_stories_outlined, color: Colors.white),
                              onPressed: widget.onOpenLiveSurfaces,
                            ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () => Navigator.pushNamed(context, '/search'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newBoardName,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add board title',
                  hintStyle: const TextStyle(fontSize: 15, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0x28FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _createBoard(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _createBoard,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Create board',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (boards.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No boards yet',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: boards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final b = boards[i];
                      final name = '${b['name'] ?? 'Board'}';
                      return Material(
                        color: const Color(0x18FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openBoard(b['id'] as String),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0079BF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
