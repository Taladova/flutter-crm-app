import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_filter_tabs.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/task_providers.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final TextEditingController searchController = TextEditingController();
  final Set<String> expandedProjectIds = {};

  String selectedStatus = 'Toutes';
  String? selectedClientName;
  String? selectedProjectId;
  String? selectedPriority;

  static const List<String> statusFilters = [
    'Toutes',
    'À faire',
    'En cours',
    'Terminées',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool get hasSecondaryFilters {
    return selectedClientName != null ||
        selectedProjectId != null ||
        selectedPriority != null;
  }

  bool get hasActiveFilters {
    return selectedStatus != 'Toutes' ||
        hasSecondaryFilters ||
        searchController.text.trim().isNotEmpty;
  }

  void resetFilters() {
    setState(() {
      selectedStatus = 'Toutes';
      selectedClientName = null;
      selectedProjectId = null;
      selectedPriority = null;
      searchController.clear();
    });
  }

  void resetSecondaryFilters() {
    setState(() {
      selectedClientName = null;
      selectedProjectId = null;
      selectedPriority = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskControllerProvider);
    final projects = ref.watch(projectControllerProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-task-fab',
        tooltip: 'Ajouter une tâche',
        onPressed: () => context.push('/tasks/add'),
        backgroundColor: AppTheme.primary(context),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Erreur de chargement',
              description: 'Impossible de charger les tâches pour le moment.',
              onRetry: () => ref.invalidate(taskControllerProvider),
            ),
          ),
          data: (tasks) {
            final filteredTasks = _filterTasks(tasks, projects);
            final groups = _buildTaskGroups(filteredTasks, projects);
            final openCount = tasks.where((task) => !_isTaskDone(task)).length;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TasksHeader(),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppSearchField(
                                controller: searchController,
                                onChanged: (_) => setState(() {}),
                                hintText: 'Rechercher une tâche…',
                              ),
                            ),
                            const SizedBox(width: 10),
                            _FilterIconButton(
                              isActive: hasSecondaryFilters,
                              onTap: () => _openFilterSheet(projects),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppFilterTabs(
                          labels: statusFilters,
                          selectedLabel: selectedStatus,
                          counts: _statusCounts(tasks),
                          onSelected: (status) {
                            setState(() {
                              selectedStatus = status;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _TasksListHeader(
                          total: tasks.length,
                          open: openCount,
                          visible: filteredTasks.length,
                        ),
                      ],
                    ),
                  ),
                ),
                if (filteredTasks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: AppEmptyState(
                        icon: hasActiveFilters
                            ? Icons.search_off_rounded
                            : Icons.task_alt_rounded,
                        title: hasActiveFilters
                            ? 'Aucun résultat'
                            : 'Aucune tâche',
                        description: hasActiveFilters
                            ? 'Essayez de modifier vos filtres.'
                            : 'Vos prochaines tâches apparaîtront ici.',
                        onRetry: hasActiveFilters ? resetFilters : null,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    sliver: SliverList.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final isExpanded = expandedProjectIds.contains(
                          group.projectId,
                        );

                        return _TaskProjectGroupCard(
                          group: group,
                          isCollapsed: !isExpanded,
                          onToggleCollapsed: () {
                            setState(() {
                              if (isExpanded) {
                                expandedProjectIds.remove(group.projectId);
                              } else {
                                expandedProjectIds.add(group.projectId);
                              }
                            });
                          },
                          onOpenProject: group.projectId.isEmpty
                              ? null
                              : () => context.push(
                                  '/projects/${group.projectId}',
                                ),
                          onOpenTask: (task) =>
                              context.push('/tasks/${task.id}'),
                          onToggleTask: (task) {
                            ref
                                .read(taskControllerProvider.notifier)
                                .toggleTaskStatus(task);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<TaskModel> _filterTasks(
    List<TaskModel> tasks,
    List<ProjectModel> projects,
  ) {
    final query = searchController.text.trim().toLowerCase();

    return tasks.where((task) {
      final project = _projectForTask(task, projects);
      final clientName = project?.clientName ?? '';
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.projectName.toLowerCase().contains(query) ||
          clientName.toLowerCase().contains(query);

      final matchesStatus = switch (selectedStatus) {
        'À faire' => task.status == 'À faire',
        'En cours' => task.status == 'En cours',
        'Terminées' => _isTaskDone(task),
        _ => true,
      };

      final matchesClient =
          selectedClientName == null || clientName == selectedClientName;
      final matchesProject =
          selectedProjectId == null || task.projectId == selectedProjectId;
      final matchesPriority =
          selectedPriority == null || task.priority == selectedPriority;

      return matchesSearch &&
          matchesStatus &&
          matchesClient &&
          matchesProject &&
          matchesPriority;
    }).toList();
  }

  List<_TaskProjectGroup> _buildTaskGroups(
    List<TaskModel> tasks,
    List<ProjectModel> projects,
  ) {
    final grouped = <String, List<TaskModel>>{};

    for (final task in tasks) {
      final key = task.projectId.isEmpty ? task.projectName : task.projectId;
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final groups = grouped.entries.map((entry) {
      final project = projects
          .where((project) => project.id == entry.key)
          .cast<ProjectModel?>()
          .firstOrNull;
      final tasks = [...entry.value]..sort(_compareTasks);
      final fallbackProjectName = tasks.first.projectName;

      return _TaskProjectGroup(
        projectId:
            project?.id ?? (entry.key.startsWith('project_') ? entry.key : ''),
        projectName: project?.title ?? fallbackProjectName,
        clientName: project?.clientName ?? 'Client non renseigné',
        tasks: tasks,
      );
    }).toList();

    groups.sort(_compareGroups);
    return groups;
  }

  Map<String, int> _statusCounts(List<TaskModel> tasks) {
    return {
      'Toutes': tasks.length,
      'À faire': tasks.where((task) => task.status == 'À faire').length,
      'En cours': tasks.where((task) => task.status == 'En cours').length,
      'Terminées': tasks.where(_isTaskDone).length,
    };
  }

  void _showClientPicker(List<ProjectModel> projects) {
    final clientNames =
        projects
            .map((project) => project.clientName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _showPickerSheet<String?>(
      title: 'Filtrer par client',
      values: [null, ...clientNames],
      labelFor: (value) => value ?? 'Tous les clients',
      selectedValue: selectedClientName,
      onSelected: (value) {
        setState(() {
          selectedClientName = value;
          if (value == null) {
            selectedProjectId = null;
          } else {
            final selectedProject = _projectById(projects, selectedProjectId);
            if (selectedProject?.clientName != value) {
              selectedProjectId = null;
            }
          }
        });
      },
    );
  }

  void _showProjectPicker(List<ProjectModel> projects) {
    final availableProjects = _availableProjects(projects);

    _showPickerSheet<String?>(
      title: 'Filtrer par projet',
      values: [null, ...availableProjects.map((project) => project.id)],
      labelFor: (value) {
        final project = _projectById(projects, value);
        return project?.title ?? 'Tous les projets';
      },
      selectedValue: selectedProjectId,
      onSelected: (value) {
        setState(() {
          selectedProjectId = value;
        });
      },
    );
  }

  void _showPriorityPicker() {
    const priorities = ['Haute', 'Moyenne', 'Basse'];

    _showPickerSheet<String?>(
      title: 'Filtrer par priorité',
      values: [null, ...priorities],
      labelFor: (value) => value ?? 'Toutes les priorités',
      selectedValue: selectedPriority,
      onSelected: (value) {
        setState(() {
          selectedPriority = value;
        });
      },
    );
  }

  void _openFilterSheet(List<ProjectModel> projects) {
    final project = _projectById(projects, selectedProjectId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(sheetContext),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtres',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    if (hasSecondaryFilters)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          resetSecondaryFilters();
                        },
                        child: const Text('Réinitialiser'),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _FilterSelectButton(
                  icon: Icons.person_outline_rounded,
                  label: selectedClientName ?? 'Tous les clients',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showClientPicker(projects);
                  },
                ),
                const SizedBox(height: 10),
                _FilterSelectButton(
                  icon: Icons.folder_outlined,
                  label: project?.title ?? 'Tous les projets',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showProjectPicker(projects);
                  },
                ),
                const SizedBox(height: 10),
                _FilterSelectButton(
                  icon: Icons.flag_outlined,
                  label: selectedPriority ?? 'Toutes les priorités',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPriorityPicker();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ProjectModel> _availableProjects(List<ProjectModel> projects) {
    final filtered = selectedClientName == null
        ? projects
        : projects
              .where((project) => project.clientName == selectedClientName)
              .toList();
    return [...filtered]..sort((a, b) => a.title.compareTo(b.title));
  }

  void _showPickerSheet<T>({
    required String title,
    required List<T> values,
    required String Function(T value) labelFor,
    required T selectedValue,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(sheetContext),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 14),
                ...values.map((value) {
                  final isSelected = value == selectedValue;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      labelFor(value),
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primary(sheetContext)
                            : AppTheme.mainTextColor(sheetContext),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: AppTheme.primary(sheetContext),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSelected(value);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TasksHeader extends StatelessWidget {
  const _TasksHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organisation',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vos tâches',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filtres',
      child: Material(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: AppTheme.mainTextColor(context),
                  size: 22,
                ),
                if (isActive)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primary(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.cardColor(context),
                          width: 1.5,
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

class _FilterSelectButton extends StatelessWidget {
  const _FilterSelectButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.secondarySurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.secondaryTextColor(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.secondaryTextColor(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TasksListHeader extends StatelessWidget {
  const _TasksListHeader({
    required this.total,
    required this.open,
    required this.visible,
  });

  final int total;
  final int open;
  final int visible;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Liste des tâches',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(
          '${frPlural(visible, 'affichée', 'affichées')} • ${frPlural(open, 'ouverte', 'ouvertes')}',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TaskProjectGroupCard extends StatelessWidget {
  const _TaskProjectGroupCard({
    required this.group,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onOpenProject,
    required this.onOpenTask,
    required this.onToggleTask,
  });

  final _TaskProjectGroup group;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onOpenProject;
  final ValueChanged<TaskModel> onOpenTask;
  final ValueChanged<TaskModel> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final progress = group.tasks.isEmpty
        ? 0.0
        : group.completedCount / group.tasks.length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.024),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              onTap: onOpenProject,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            group.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.mainTextColor(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 5,
                                    color: AppTheme.primary(context),
                                    backgroundColor: AppTheme.secondarySurface(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${group.completedCount} / ${group.tasks.length} ${frCountLabel(group.completedCount, 'terminée', 'terminées')}',
                                style: TextStyle(
                                  color: AppTheme.secondaryTextColor(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleCollapsed,
                      icon: Icon(
                        isCollapsed
                            ? Icons.chevron_right_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.secondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            Divider(height: 1, color: AppTheme.borderColor(context)),
            ...group.tasks.map(
              (task) => _CompactTaskRow(
                task: task,
                onOpen: () => onOpenTask(task),
                onToggle: () => onToggleTask(task),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactTaskRow extends StatelessWidget {
  const _CompactTaskRow({
    required this.task,
    required this.onOpen,
    required this.onToggle,
  });

  final TaskModel task;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDone = _isTaskDone(task);
    final dateInfo = _taskDateInfo(task.deadline);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : task.status == 'En cours'
                        ? Icons.play_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isDone
                        ? AppTheme.primary(context)
                        : task.status == 'En cours'
                        ? AppTheme.secondary(context)
                        : AppTheme.secondaryTextColor(context),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDone
                            ? AppTheme.secondaryTextColor(context)
                            : AppTheme.mainTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          dateInfo.label,
                          style: TextStyle(
                            color: dateInfo.isOverdue
                                ? AppTheme.errorColor
                                : AppTheme.secondaryTextColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _PriorityText(priority: task.priority),
                        if (task.status == 'En cours')
                          Text(
                            'En cours',
                            style: TextStyle(
                              color: AppTheme.secondary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryTextColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityText extends StatelessWidget {
  const _PriorityText({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    return Text(
      priority,
      style: TextStyle(
        color: _priorityColor(context, priority),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TaskProjectGroup {
  const _TaskProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.clientName,
    required this.tasks,
  });

  final String projectId;
  final String projectName;
  final String clientName;
  final List<TaskModel> tasks;

  int get completedCount => tasks.where(_isTaskDone).length;
}

class _TaskDateInfo {
  const _TaskDateInfo({required this.label, required this.rank, this.date});

  final String label;
  final int rank;
  final DateTime? date;

  bool get isOverdue => rank == 0;
}

ProjectModel? _projectForTask(TaskModel task, List<ProjectModel> projects) {
  return _projectById(projects, task.projectId);
}

ProjectModel? _projectById(List<ProjectModel> projects, String? projectId) {
  if (projectId == null || projectId.isEmpty) return null;
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
}

bool _isTaskDone(TaskModel task) {
  final status = task.status.trim().toLowerCase();
  return status == 'terminé' || status == 'termine';
}

int _compareGroups(_TaskProjectGroup a, _TaskProjectGroup b) {
  final aRank = _groupRank(a.tasks);
  final bRank = _groupRank(b.tasks);
  if (aRank != bRank) return aRank.compareTo(bRank);
  return a.projectName.compareTo(b.projectName);
}

int _groupRank(List<TaskModel> tasks) {
  if (tasks.any(
    (task) => _taskDateInfo(task.deadline).isOverdue && !_isTaskDone(task),
  )) {
    return 0;
  }
  if (tasks.any(
    (task) => _taskDateInfo(task.deadline).rank == 1 && !_isTaskDone(task),
  )) {
    return 1;
  }
  if (tasks.any((task) => !_isTaskDone(task))) return 2;
  return 3;
}

int _compareTasks(TaskModel a, TaskModel b) {
  final aDone = _isTaskDone(a);
  final bDone = _isTaskDone(b);
  if (aDone != bDone) return aDone ? 1 : -1;

  final aDate = _taskDateInfo(a.deadline);
  final bDate = _taskDateInfo(b.deadline);
  if (aDate.rank != bDate.rank) return aDate.rank.compareTo(bDate.rank);

  final priorityCompare = _priorityRank(
    b.priority,
  ).compareTo(_priorityRank(a.priority));
  if (priorityCompare != 0) return priorityCompare;

  final dateCompare = (aDate.date ?? DateTime(9999)).compareTo(
    bDate.date ?? DateTime(9999),
  );
  if (dateCompare != 0) return dateCompare;

  return a.title.compareTo(b.title);
}

_TaskDateInfo _taskDateInfo(String rawDeadline) {
  final deadline = rawDeadline.trim();
  if (deadline.isEmpty) {
    return const _TaskDateInfo(label: 'Sans échéance', rank: 4);
  }

  final lower = deadline.toLowerCase();
  final parsed = _parseDeadline(deadline);
  if (parsed == null) {
    if (lower.contains('aujourd')) {
      return const _TaskDateInfo(label: 'Aujourd’hui', rank: 1);
    }
    if (lower == 'demain') return const _TaskDateInfo(label: 'Demain', rank: 2);
    return _TaskDateInfo(label: deadline, rank: 3);
  }

  final today = _dateOnly(DateTime.now());
  final day = _dateOnly(parsed);
  final diff = day.difference(today).inDays;

  if (diff < 0) {
    final days = diff.abs();
    return _TaskDateInfo(
      label: 'En retard de $days jour${days > 1 ? 's' : ''}',
      rank: 0,
      date: day,
    );
  }
  if (diff == 0) return _TaskDateInfo(label: 'Aujourd’hui', rank: 1, date: day);
  if (diff == 1) return _TaskDateInfo(label: 'Demain', rank: 2, date: day);

  return _TaskDateInfo(label: _formatShortDate(day), rank: 3, date: day);
}

DateTime? _parseDeadline(String deadline) {
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(deadline);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatShortDate(DateTime date) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

int _priorityRank(String priority) {
  switch (priority) {
    case 'Haute':
      return 3;
    case 'Moyenne':
      return 2;
    case 'Basse':
      return 1;
    default:
      return 0;
  }
}

Color _priorityColor(BuildContext context, String priority) {
  switch (priority) {
    case 'Haute':
      return AppTheme.errorColor;
    case 'Moyenne':
      return AppTheme.warningColor;
    case 'Basse':
      return AppTheme.secondary(context);
    default:
      return AppTheme.secondaryTextColor(context);
  }
}
