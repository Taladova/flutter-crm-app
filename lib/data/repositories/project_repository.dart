import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../mock/mock_projects.dart';
import '../models/project_model.dart';

class ProjectRepository {
  const ProjectRepository();

  static const String _projectsKey = 'projects';

  Future<List<ProjectModel>> getProjects() async {
    await Future.delayed(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    final projectsString = prefs.getString(_projectsKey);

    if (projectsString == null) {
      await saveProjects(mockProjects);
      return mockProjects;
    }

    final List<dynamic> decoded = jsonDecode(projectsString);

    return decoded
        .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProjects(List<ProjectModel> projects) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      projects.map((project) => project.toJson()).toList(),
    );

    await prefs.setString(_projectsKey, encoded);
  }

  Future<ProjectModel?> getProjectById(String id) async {
    final projects = await getProjects();

    try {
      return projects.firstWhere((project) => project.id == id);
    } catch (_) {
      return null;
    }
  }
}