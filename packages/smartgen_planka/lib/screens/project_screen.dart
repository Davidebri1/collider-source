import 'package:easy_localization/easy_localization.dart';
import 'package:floating_action_bubble/floating_action_bubble.dart';
import 'package:flutter/material.dart';
import 'package:planka_app/providers/project_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/project_list.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, this.onHostClose, this.onOpenLiveSurfaces});
  final VoidCallback? onHostClose;
  final VoidCallback? onOpenLiveSurfaces;

  @override
  _ProjectScreenState createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> with SingleTickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _animationController;

  void _refreshProjects() {
    setState(() {
      Provider.of<ProjectProvider>(context, listen: false).fetchProjects();
    });
  }

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final curvedAnimation = CurvedAnimation(curve: Curves.easeInOut, parent: _animationController);
    _animation = Tween<double>(begin: 0, end: 1).animate(curvedAnimation);
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('create_project'.tr(), textAlign: TextAlign.center),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'project_name'.tr()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text('create_project'.tr())),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await Provider.of<ProjectProvider>(context, listen: false).createProject(name, context);
      _refreshProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0079BF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0079BF),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: widget.onHostClose != null
            ? IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: widget.onHostClose,
              )
            : null,
        title: Text(
          'app_name'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.onOpenLiveSurfaces != null)
            IconButton(
              // Icon-only: no label/tooltip (wording rule — no invented chrome).
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: widget.onOpenLiveSurfaces,
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionBubble(
        items: <Bubble>[
          Bubble(
            title: 'create_project'.tr(),
            iconColor: Colors.white,
            bubbleColor: Colors.indigo,
            icon: Icons.add,
            titleStyle: const TextStyle(fontSize: 16, color: Colors.white),
            onPress: () {
              _animationController.reverse();
              _createProject();
            },
          ),
        ],
        animation: _animation,
        onPress: () => _animationController.isCompleted ? _animationController.reverse() : _animationController.forward(),
        iconColor: Colors.white,
        iconData: Icons.menu_rounded,
        backGroundColor: Colors.indigo,
      ),
      body: FutureBuilder(
        future: Provider.of<ProjectProvider>(context, listen: false).fetchProjects(),
        builder: (ctx, snapshot) => snapshot.connectionState == ConnectionState.waiting
            ? const ColoredBox(color: Colors.white, child: SizedBox.expand())
            : Consumer<ProjectProvider>(
                builder: (ctx, projectProvider, _) => ProjectList(projectProvider.projects, onRefresh: _refreshProjects),
              ),
      ),
    );
  }
}
