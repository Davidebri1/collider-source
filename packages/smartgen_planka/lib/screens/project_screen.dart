import 'package:easy_localization/easy_localization.dart';
import 'package:floating_action_bubble/floating_action_bubble.dart';
import 'package:flutter/material.dart';
import 'package:planka_app/providers/project_provider.dart';
import 'package:planka_app/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/project_list.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, this.onHostClose, this.onOpenLiveSurfaces});
  final VoidCallback? onHostClose;
  final VoidCallback? onOpenLiveSurfaces;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> with SingleTickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _animationController;
  Future<void>? _projectsFuture;

  void _refreshProjects() {
    setState(() {
      _projectsFuture = Provider.of<ProjectProvider>(context, listen: false).fetchProjects();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _projectsFuture ??= Provider.of<ProjectProvider>(context, listen: false).fetchProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_name'.tr()),
        actions: [
          if (widget.onHostClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  widget.onHostClose?.call();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionBubble(
        items: <Bubble>[
          Bubble(
            title: 'settings'.tr(),
            iconColor: Colors.white,
            bubbleColor: Colors.indigo,
            icon: Icons.settings,
            titleStyle: const TextStyle(fontSize: 16, color: Colors.white),
            onPress: () {
              _animationController.reverse();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          // Logout removed — needs Planka server session.
        ],
        animation: _animation,
        onPress: () => _animationController.isCompleted
            ? _animationController.reverse()
            : _animationController.forward(),
        iconColor: Colors.white,
        iconData: Icons.menu_rounded,
        backGroundColor: Colors.indigo,
      ),
      body: FutureBuilder(
        future: _projectsFuture,
        builder: (ctx, snapshot) => snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : Consumer<ProjectProvider>(
                builder: (ctx, projectProvider, _) =>
                    ProjectList(projectProvider.projects, onRefresh: _refreshProjects),
              ),
      ),
    );
  }
}
