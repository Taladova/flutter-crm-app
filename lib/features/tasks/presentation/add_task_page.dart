import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/task_providers.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({
    super.key,
    this.projectId,
    this.projectName,
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

    if (!isValid) return;

    if (selectedProjectId == null || selectedProjectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de sélectionner un projet.'),
        ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tâche ajoutée avec succès.'),
      ),
    );

    context.go('/tasks');
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddTaskHeader(
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Projet associé'),
                const SizedBox(height: 14),
                projectsAsync.when(
                  loading: () => const AppCard(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
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
                const SectionTitle(title: 'Informations tâche'),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _AppTextField(
                        controller: titleController,
                        label: 'Titre de la tâche',
                        hint: 'Ex : Préparer la maquette',
                        icon: Icons.task_alt_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le titre est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: deadlineController,
                        label: 'Deadline',
                        hint: 'Ex : 30 mai 2026',
                        icon: Icons.event_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La deadline est obligatoire';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Priorité'),
                const SizedBox(height: 14),
                _PrioritySelector(
                  priorities: priorities,
                  selectedPriority: selectedPriority,
                  onChanged: (priority) {
                    setState(() {
                      selectedPriority = priority;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Ajouter la tâche',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _AddTaskHeader extends StatelessWidget {
  const _AddTaskHeader({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppTheme.borderColor(context),
              ),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Nouvelle tâche',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
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
        dropdownColor: AppTheme.cardColor(context),
        iconEnabledColor: AppTheme.secondaryTextColor(context),
        style: TextStyle(
          color: AppTheme.mainTextColor(context),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: 'Sélectionner un projet',
          labelStyle: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: AppTheme.isDark(context)
              ? const Color(0xFF000B27)
              : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppTheme.borderColor(context),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppTheme.borderColor(context),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 1.5,
            ),
          ),
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

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppTheme.isDark(context)
        ? const Color(0xFF000B27)
        : const Color(0xFFF8FAFC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              color: AppTheme.secondaryTextColor(context),
            ),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            hintStyle: TextStyle(
              color: AppTheme.secondaryTextColor(context).withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppTheme.borderColor(context),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppTheme.borderColor(context),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({
    required this.priorities,
    required this.selectedPriority,
    required this.onChanged,
  });

  final List<String> priorities;
  final String selectedPriority;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: priorities.map((priority) {
          final isSelected = priority == selectedPriority;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(priority),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.isDark(context)
                          ? const Color(0xFF000B27)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor(context),
                  ),
                ),
                child: Center(
                  child: Text(
                    priority,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.secondaryTextColor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}