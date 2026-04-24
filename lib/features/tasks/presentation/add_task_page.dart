import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/task_model.dart';
import '../providers/task_providers.dart';
import '../../../data/models/project_model.dart';
import '../../projects/providers/project_providers.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final String? projectId;
  final String? projectName;

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final deadlineController = TextEditingController();
  String? selectedProjectId;
  String? selectedProjectName;

  String selectedPriority = 'Moyenne';

  final priorities = const ['Haute', 'Moyenne', 'Basse'];

  @override
  void initState() {
    super.initState();

    selectedProjectId = widget.projectId;
    selectedProjectName = widget.projectName;
  }

  @override
  void dispose() {
    titleController.dispose();
    deadlineController.dispose();
    super.dispose();
  }

  Future<void> submitForm() async {
    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return; // ⛔ stop si erreur
    }

    if (selectedProjectId == null || selectedProjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de sélectionner un projet.')),
      );
      return;
    }

    final newTask = TaskModel(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      projectName: selectedProjectName!,
      projectId: selectedProjectId!,
      status: 'À faire',
      priority: selectedPriority,
      deadline: deadlineController.text.trim(),
    );

    await ref.read(taskControllerProvider.notifier).addTask(newTask);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tâche ajoutée')));

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectControllerProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Nouvelle tâche',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SectionTitle(title: 'Projet associé'),
                const SizedBox(height: 12),
                projectsAsync.when(
                  loading: () => const AppCard(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => const AppCard(
                    child: Text('Impossible de charger les projets.'),
                  ),
                  data: (projects) {
                    return _ProjectSelector(
                      projects: projects,
                      selectedProjectId: selectedProjectId,
                      onChanged: (project) {
                        setState(() {
                          selectedProjectId = project.id;
                          selectedProjectName = project.title;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Informations tâche'),
                const SizedBox(height: 12),

                AppCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Titre'),
                        validator: (value) =>
                            value!.isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: deadlineController,
                        decoration: const InputDecoration(
                          labelText: 'Deadline',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Champ obligatoire' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const SectionTitle(title: 'Priorité'),
                const SizedBox(height: 12),

                AppCard(
                  child: Row(
                    children: priorities.map((p) {
                      final isSelected = p == selectedPriority;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPriority = p;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitForm,
                    child: const Text('Ajouter la tâche'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectSelector extends StatelessWidget {
  const _ProjectSelector({
    required this.projects,
    required this.selectedProjectId,
    required this.onChanged,
  });

  final List<ProjectModel> projects;
  final String? selectedProjectId;
  final ValueChanged<ProjectModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: DropdownButtonFormField<String>(
        value: selectedProjectId,
        decoration: const InputDecoration(
          labelText: 'Sélectionner un projet',
          border: OutlineInputBorder(),
        ),
        items: projects.map((project) {
          return DropdownMenuItem<String>(
            value: project.id,
            child: Text(project.title),
          );
        }).toList(),
        onChanged: (projectId) {
          if (projectId == null) return;

          final selectedProject = projects.firstWhere(
            (project) => project.id == projectId,
          );

          onChanged(selectedProject);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Le projet est obligatoire';
          }
          return null;
        },
      ),
    );
  }
}
