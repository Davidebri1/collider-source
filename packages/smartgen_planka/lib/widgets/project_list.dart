import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:planka_app/models/planka_project.dart';
import 'package:planka_app/providers/project_provider.dart';
import 'package:planka_app/screens/board_screen.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/planka_user.dart';
import '../providers/user_provider.dart';

class ProjectList extends StatefulWidget {
  final List<PlankaProject> projects;
  final VoidCallback? onRefresh;

  const ProjectList(this.projects, {super.key, this.onRefresh});

  @override
  ProjectListState createState() => ProjectListState();
}

class ProjectListState extends State<ProjectList> {

  late TextEditingController _newProjectController;

  @override
  void initState() {
    super.initState();
    _newProjectController = TextEditingController();
  }

  @override
  void dispose() {
    _newProjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Empty store is a real empty state (offline Collider): show Create Project
    // only — never spinner forever, never sample projects/cards.
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 0),
      child: ListView.builder(
        itemCount: widget.projects.length + 1,
        itemBuilder: (ctx, index) {
          if (index == widget.projects.length) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
              color: Colors.indigo,
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('create_project'.tr(), style: const TextStyle(color: Colors.white)),
                  ],
                ),
                onTap: () {
                  _showCreateProjectDialog(context);
                },
              ),
            );
          } else {
            final project = widget.projects[index];
            final users = project.users;
            final backgroundImageUrl = project.backgroundImage?['url'];

            return Card(
              color: Colors.grey[700],
              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Container(
                decoration: BoxDecoration(
                  image: backgroundImageUrl != null
                      ? DecorationImage(
                    image: NetworkImage(backgroundImageUrl),
                    fit: BoxFit.cover,
                  )
                      : null,
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: ListTile(
                  title: Text(
                    project.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show user avatars, limit overflow
                      if (users.isNotEmpty)
                        ...users.take(3).map((user) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null ? Text(user.name[0]) : null,
                            ),
                          );
                        }).toList(),
                      if (users.length > 3)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child: Text(
                            '...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => BoardScreen(project: project,)
                      ),
                    );
                  },
                  onLongPress: () {
                    _showEditProjectDialog(context, project);
                  },
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, PlankaProject project) {
    final editBoardController = TextEditingController(text: project.name);

    List<PlankaUser> selectedUsers = [];

    /// Check if users are assigned to the board
    // selectedUsers = widget.usersPerBoard[board.id] ?? [];

    /// Fetch all users using UserProvider before showing the dialog
    Provider.of<UserProvider>(context, listen: false).fetchUsers().then((_) {
      showDialog(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
                builder: (context, setState) {
                  final allUsers = Provider.of<UserProvider>(ctx, listen: true).users;
                  return AlertDialog(
                    title: Text('edit_board'.tr()),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Board Name Input
                        TextField(
                          autofocus: true,
                          controller: editBoardController,
                          decoration: InputDecoration(labelText: 'board_name'
                              .tr()),
                          onSubmitted: (value) {
                            if (editBoardController.text.isNotEmpty &&
                                editBoardController.text != "") {
                              Provider.of<ProjectProvider>(ctx, listen: false).updateProjectName(project.id, value, context).then((_) {
                                // Call the onRefresh callback if it exists
                                if (widget.onRefresh != null) {
                                  widget.onRefresh!();
                                }
                              });
                            } else {
                              showTopSnackBar(
                                Overlay.of(ctx),
                                CustomSnackBar.error(
                                  message:
                                  'not_empty_name'.tr(),
                                ),
                              );
                            }

                            Navigator.of(ctx).pop();
                          },
                        ),
                        const SizedBox(height: 20),

                        // Members removed (needs Planka server).

                        // SizedBox(
                        //   width: double.maxFinite,
                        //   height: 200,
                        //   child: ListView.builder(
                        //     shrinkWrap: true,
                        //     itemCount: allUsers.length,
                        //     itemBuilder: (context, index) {
                        //       final user = allUsers[index];
                        //       /// Check if user is in "selectedUsers"
                        //       final bool isSelected = selectedUsers.any((selectedUser) => selectedUser.id == user.id);
                        //
                        //       return CheckboxListTile(
                        //         title: Text(user.name),
                        //         value: isSelected,
                        //         onChanged: (bool? value) {
                        //           setState(() {
                        //             if (value == true) {
                        //               // Add user when selected
                        //               selectedUsers.add(user);
                        //               Provider.of<ProjectProvider>(ctx, listen: false).addBoardMember(
                        //                 boardId: board.id,
                        //                 userId: user.id,
                        //                 context: context,
                        //               );
                        //
                        //               Navigator.pop(context);
                        //             } else {
                        //               print('Checking for user ID: ${user.id}');
                        //               // Debugging: Print out the board memberships for this board
                        //               if (widget.boardMembershipMap.containsKey(board.id)) {
                        //                 final boardMemberships = widget.boardMembershipMap[board.id];
                        //
                        //                 print('Board Memberships for board ${board.id}:');
                        //                 for (var membership in boardMemberships!) {
                        //                   print('Membership ID: ${membership.id}, User ID: ${membership.userId}');
                        //                 }
                        //
                        //                 final membership = boardMemberships.firstWhere(
                        //                       (membership) => membership.userId == user.id,
                        //                   orElse: () => BoardMembership(id: "invalid", userId: "invalid", boardId: "invalid", role: "invalid"),
                        //                 );
                        //
                        //                 if (membership.id != "invalid") {
                        //                   setState(() {
                        //                     selectedUsers.removeWhere((selectedUser) => selectedUser.id == user.id); // Use removeWhere by id
                        //                   });
                        //
                        //                   // Remove user after state change
                        //                   Provider.of<BoardProvider>(ctx, listen: false).removeBoardMember(
                        //                     context: context,
                        //                     id: membership.id, // Use the correct membership ID here
                        //                   );
                        //
                        //                   Navigator.pop(context);
                        //                 } else {
                        //                   print('No matching membership found for user ${user.id}');
                        //                 }
                        //               } else {
                        //                 print('No memberships found for board ${board.id}');
                        //               }
                        //             }
                        //           });
                        //         },
                        //       );
                        //     },
                        //   ),
                        // )
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          _showDeleteConfirmationDialog(ctx, project.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('delete'.tr(),
                            style: const TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: Text('cancel'.tr()),
                      ),
                    ],
                  );
                }
            );
          }
      );
    });
  }

  void _showDeleteConfirmationDialog(BuildContext context, String projectId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_project_confirmation.0'.tr()),
        content: Text('delete_project_confirmation.1'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ProjectProvider>(ctx, listen: false).deleteProject(projectId, context).then((_) {
                /// Call the onRefresh callback if it exists
                if (widget.onRefresh != null) {
                  widget.onRefresh!();
                }

                Navigator.of(ctx).pop();
              });

              Navigator.of(ctx).pop();
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    // Stay inside PlankaNavigator (providers). Root navigator is outside MultiProvider.
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('create_project_dialog.create_new_project'.tr()),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'create_project_dialog.project_name'.tr(),
              hintText: 'create_project_dialog.enter_project_name'.tr(),
            ),
            onSubmitted: (value) {
              final name = value.trim().isEmpty ? nameController.text.trim() : value.trim();
              if (name.isEmpty) return;
              Provider.of<ProjectProvider>(ctx, listen: false).createProject(name, ctx).then((_) {
                widget.onRefresh?.call();
                Navigator.of(ctx).pop();
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Provider.of<ProjectProvider>(ctx, listen: false).createProject(name, ctx).then((_) {
                  widget.onRefresh?.call();
                  Navigator.of(ctx).pop();
                });
              },
              child: Text('create'.tr()),
            ),
          ],
        );
      },
    );
  }

}
