import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:planka_app/models/planka_project.dart';
import 'package:provider/provider.dart';
import '../providers/list_provider.dart';
import '../widgets/list_list.dart';
import '../models/planka_board.dart';

class ListScreen extends StatefulWidget {
  PlankaProject? currentProject;
  PlankaBoard? currentBoard;
  final VoidCallback? onHostClose;

  ListScreen({super.key, this.currentProject, this.currentBoard, this.onHostClose});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Future<void>? _listsFuture;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listsFuture ??= Provider.of<ListProvider>(context, listen: false)
        .fetchLists(boardId: widget.currentBoard!.id, context: context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _refreshLists() {
    setState(() {
      _listsFuture = Provider.of<ListProvider>(context, listen: false)
          .fetchLists(boardId: widget.currentBoard!.id, context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundImageUrl = widget.currentProject?.backgroundImage?['url'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              widget.onHostClose?.call();
            }
          },
        ),
        title: Text(
          '${'lists_for'.tr()} ${widget.currentBoard?.name}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _refreshLists,
            icon: const Icon(Icons.refresh, color: Colors.indigo),
          ),
          IconButton(
            tooltip: 'Board menu',
            onPressed: () =>
                Navigator.pushNamed(context, '/boardmenu', arguments: widget.currentBoard?.id),
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
          future: _listsFuture,
          builder: (ctx, snapshot) => snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
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
