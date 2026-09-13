import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/task_providers.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({super.key, this.projectId, this.projectName, this.taskId});

  final String? projectId;
  final String? projectName;
  final String? taskId;

  bool get isEditing => taskId != null;

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

    if (widget.taskId != null) {
      final task = ref.read(taskByIdProvider(widget.taskId!));

      if (task != null) {
        titleController.text = task.title;
        deadlineController.text = task.deadline;
        selectedPriority = task.priority;
        selectedProjectId = task.projectId;
        selectedProjectName = task.projectName;
      }
    }
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
        const SnackBar(content: Text('Merci de sélectionner un projet.')),
      );
      return;
    }

    final existingTask = widget.taskId != null
        ? ref.read(taskByIdProvider(widget.taskId!))
        : null;

    final task = TaskModel(
      id: widget.taskId ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      projectName: selectedProjectName!,
      projectId: selectedProjectId!,
      status: existingTask?.status ?? 'À faire',
      priority: selectedPriority,
      deadline: deadlineController.text.trim(),
      visibleToClient: existingTask?.visibleToClient ?? true,
      internal: existingTask?.internal ?? false,
      isPrivate: existingTask?.isPrivate ?? false,
      assignedTo: existingTask?.assignedTo ?? 'professional',
    );

    if (widget.isEditing) {
      await ref.read(taskControllerProvider.notifier).updateTask(task);
    } else {
      await ref.read(taskControllerProvider.notifier).addTask(task);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Tâche mise à jour avec succès.'
              : 'Tâche ajoutée avec succès.',
        ),
      ),
    );

    if (widget.isEditing) {
      context.pop();
    } else {
      context.go('/main?tab=3');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddTaskHeader(
                  onBack: () => context.pop(),
                  title: widget.isEditing
                      ? 'Modifier la tâche'
                      : 'Nouvelle tâche',
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormCardHeader(
                        icon: Icons.task_alt_rounded,
                        title: 'Informations tâche',
                        subtitle: 'Titre, échéance et priorité',
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 14),
                      _AppTextField(
                        controller: deadlineController,
                        label: 'Échéance',
                        hint: 'Ex : 30 mai 2026',
                        icon: Icons.event_rounded,
                        readOnly: true,
                        onTap: () => _pickDeadlineDate(context),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L’échéance est obligatoire';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PrioritySelector(
                  priorities: priorities,
                  selectedPriority: selectedPriority,
                  onChanged: (priority) {
                    setState(() {
                      selectedPriority = priority;
                    });
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
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
                    child: Text(
                      widget.isEditing ? 'Enregistrer' : 'Ajouter la tâche',
                      style: const TextStyle(
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

  Future<void> _pickDeadlineDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseFrenchDate(deadlineController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;
    setState(() {
      deadlineController.text = _formatFrenchDate(selected);
    });
  }
}

DateTime? _parseFrenchDate(String value) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatFrenchDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class _AddTaskHeader extends StatelessWidget {
  const _AddTaskHeader({required this.onBack, required this.title});

  final VoidCallback onBack;
  final String title;

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
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FormCardHeader(
            icon: Icons.folder_copy_rounded,
            title: 'Projet associé',
            subtitle: 'Choisissez où ranger cette tâche',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedProjectId,
            dropdownColor: AppTheme.cardColor(context),
            iconEnabledColor: AppTheme.secondaryTextColor(context),
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Sélectionner un projet',
              prefixIcon: Icon(
                Icons.work_rounded,
                color: AppTheme.secondaryTextColor(context),
              ),
              filled: true,
              fillColor: AppTheme.secondarySurface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.borderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: AppTheme.borderColor(context)),
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
        ],
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
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppTheme.secondarySurface(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            prefixIcon: onTap == null
                ? Icon(icon, color: AppTheme.secondaryTextColor(context))
                : IconButton(
                    onPressed: onTap,
                    icon: Icon(
                      icon,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                  ),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            hintStyle: TextStyle(
              color: AppTheme.secondaryTextColor(
                context,
              ).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FormCardHeader(
            icon: Icons.priority_high_rounded,
            title: 'Priorité',
            subtitle: 'Définissez le niveau d’urgence',
          ),
          const SizedBox(height: 14),
          Row(
            children: priorities.map((priority) {
              final isSelected = priority == selectedPriority;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(priority),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.secondarySurface(context),
                      borderRadius: BorderRadius.circular(14),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FormCardHeader extends StatelessWidget {
  const _FormCardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
