import 'package:flutter/material.dart';
import '../local/planka_store.dart';
import '../models/planka_project.dart';
import 'auth_provider.dart';

class ProjectProvider with ChangeNotifier {
  List<PlankaProject> _projects = [];
  final AuthProvider authProvider;

  ProjectProvider(this.authProvider);

  List<PlankaProject> get projects => _projects;

  Future<void> fetchProjects() async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final payload = store.projectsIndexPayload();
    final projectsJson = payload['items'] as List<dynamic>;
    final includedData = Map<String, dynamic>.from(payload['included'] as Map);
    _projects = projectsJson
        .map((projectJson) => PlankaProject.fromJson(Map<String, dynamic>.from(projectJson as Map), includedData))
        .toList();
    notifyListeners();
  }

  Future<void> createProject(String newProjectName, BuildContext context) async {
    PlankaStore.instance.createProject(newProjectName);
    await fetchProjects();
  }

  Future<void> deleteProject(String projectId, BuildContext context) async {
    PlankaStore.instance.deleteProject(projectId);
    await fetchProjects();
  }

  Future<void> updateProjectName(String projectIdToUpdate, String newProjectName, BuildContext context) async {
    PlankaStore.instance.updateProjectName(projectIdToUpdate, newProjectName);
    await fetchProjects();
  }
}
