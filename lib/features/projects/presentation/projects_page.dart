import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_filter_tabs.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/project_pulse_model.dart';
import '../../../data/models/task_model.dart';
import '../../clients/providers/client_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/project_providers.dart';
import '../providers/project_pulse_providers.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final TextEditingController searchController = TextEditingController();
  final Set<String> collapsedClientNames = {};

  String selectedStatus = 'Tous';
  String? selectedClientName;
  String? selectedType;

  static const List<String> statusFilters = [
    'Tous',
    'En cours',
    'En attente',
    'Terminés',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool get hasActiveFilters {
    return selectedStatus != 'Tous' ||
        selectedClientName != null ||
        selectedType != null ||
        searchController.text.trim().isNotEmpty;
  }

  bool get hasSecondaryFilters {
    return selectedClientName != null || selectedType != null;
  }

  void resetFilters() {
    setState(() {
      selectedStatus = 'Tous';
      selectedClientName = null;
      selectedType = null;
      searchController.clear();
    });
  }

  void resetSecondaryFilters() {
    setState(() {
      selectedClientName = null;
      selectedType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectControllerProvider);
    final tasksAsync = ref.watch(taskControllerProvider);
    final pulseAsync = ref.watch(projectPulseDashboardProvider);
    final clients = ref.watch(clientControllerProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-project-fab',
        tooltip: 'Ajouter un projet',
        onPressed: () => context.push('/projects/add'),
        backgroundColor: AppTheme.primary(context),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Erreur de chargement',
              description: 'Impossible de charger les projets pour le moment.',
              onRetry: () => ref.invalidate(projectControllerProvider),
            ),
          ),
          data: (projects) {
            final tasks = tasksAsync.value ?? const <TaskModel>[];
            final pulses = {
              for (final pulse
                  in pulseAsync.value?.pulses ?? const <ProjectPulseModel>[])
                pulse.projectId: pulse,
            };
            final filteredProjects = _filterProjects(projects, pulses);
            final sortedProjects = [...filteredProjects]
              ..sort(
                (a, b) => _compareProjects(a, b, pulses[a.id], pulses[b.id]),
              );
            final groups = _buildClientGroups(
              sortedProjects,
              tasks,
              pulses,
              clients,
            );
            final totalActive = projects.where(_isActiveProject).length;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _ProjectsHeader(),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppSearchField(
                                controller: searchController,
                                onChanged: (_) => setState(() {}),
                                hintText: 'Rechercher un projet…',
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
                          counts: _statusCounts(projects, pulses),
                          onSelected: (status) {
                            setState(() {
                              selectedStatus = status;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProjectsListHeader(
                          total: projects.length,
                          active: totalActive,
                          visible: filteredProjects.length,
                        ),
                      ],
                    ),
                  ),
                ),
                if (filteredProjects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: AppEmptyState(
                        icon: hasActiveFilters
                            ? Icons.search_off_rounded
                            : Icons.work_outline_rounded,
                        title: hasActiveFilters
                            ? 'Aucun résultat'
                            : 'Aucun projet',
                        description: hasActiveFilters
                            ? 'Essayez de modifier vos filtres.'
                            : 'Créez votre premier projet pour commencer.',
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
                        final isCollapsed = collapsedClientNames.contains(
                          group.clientName,
                        );

                        return _ClientProjectGroupCard(
                          group: group,
                          isCollapsed: isCollapsed,
                          onOpenClient: group.clientId == null
                              ? null
                              : () =>
                                    context.push('/clients/${group.clientId}'),
                          onToggleCollapsed: () {
                            setState(() {
                              if (isCollapsed) {
                                collapsedClientNames.remove(group.clientName);
                              } else {
                                collapsedClientNames.add(group.clientName);
                              }
                            });
                          },
                          onOpenProject: (project) {
                            context.push('/projects/${project.id}');
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

  List<ProjectModel> _filterProjects(
    List<ProjectModel> projects,
    Map<String, ProjectPulseModel> pulses,
  ) {
    final query = searchController.text.trim().toLowerCase();

    return projects.where((project) {
      final matchesSearch =
          query.isEmpty ||
          project.title.toLowerCase().contains(query) ||
          project.clientName.toLowerCase().contains(query) ||
          project.type.toLowerCase().contains(query);

      final pulse = pulses[project.id];
      final matchesStatus = switch (selectedStatus) {
        'En cours' => _isActiveProject(project) && !_isWaitingProject(pulse),
        'En attente' => _isWaitingProject(pulse) || _isWaitingStatus(project),
        'Terminés' => _isCompletedProject(project),
        _ => true,
      };

      final matchesClient =
          selectedClientName == null ||
          project.clientName == selectedClientName;
      final matchesType = selectedType == null || project.type == selectedType;

      return matchesSearch && matchesStatus && matchesClient && matchesType;
    }).toList();
  }

  List<_ClientProjectGroup> _buildClientGroups(
    List<ProjectModel> projects,
    List<TaskModel> tasks,
    Map<String, ProjectPulseModel> pulses,
    List<ClientModel> clients,
  ) {
    final grouped = <String, List<_ProjectListItem>>{};

    for (final project in projects) {
      final clientName = project.clientName.trim().isEmpty
          ? 'Client non renseigné'
          : project.clientName.trim();
      final projectTasks = tasks
          .where((task) => task.projectId == project.id)
          .toList();

      grouped
          .putIfAbsent(clientName, () => [])
          .add(
            _ProjectListItem(
              project: project,
              pulse: pulses[project.id],
              openTasks: projectTasks
                  .where((task) => !_isTaskDone(task))
                  .length,
            ),
          );
    }

    final groups = grouped.entries.map((entry) {
      final items = [...entry.value]
        ..sort(
          (a, b) => _compareProjects(a.project, b.project, a.pulse, b.pulse),
        );
      return _ClientProjectGroup(
        clientName: entry.key,
        clientId: _clientIdByName(entry.key, clients),
        projects: items,
      );
    }).toList();

    groups.sort((a, b) {
      final rankCompare = a.rank.compareTo(b.rank);
      if (rankCompare != 0) return rankCompare;
      return a.clientName.compareTo(b.clientName);
    });

    return groups;
  }

  Map<String, int> _statusCounts(
    List<ProjectModel> projects,
    Map<String, ProjectPulseModel> pulses,
  ) {
    return {
      'Tous': projects.length,
      'En cours': projects.where((project) {
        return _isActiveProject(project) &&
            !_isWaitingProject(pulses[project.id]);
      }).length,
      'En attente': projects.where((project) {
        return _isWaitingProject(pulses[project.id]) ||
            _isWaitingStatus(project);
      }).length,
      'Terminés': projects.where(_isCompletedProject).length,
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
        });
      },
    );
  }

  void _showTypePicker(List<ProjectModel> projects) {
    final types =
        projects
            .map((project) => project.type.trim())
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _showPickerSheet<String?>(
      title: 'Filtrer par type',
      values: [null, ...types],
      labelFor: (value) => value ?? 'Tous les types',
      selectedValue: selectedType,
      onSelected: (value) {
        setState(() {
          selectedType = value;
        });
      },
    );
  }

  void _openFilterSheet(List<ProjectModel> projects) {
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
                  icon: Icons.category_outlined,
                  label: selectedType ?? 'Tous les types de projet',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showTypePicker(projects);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suivi projets',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vos projets',
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

class _ProjectsListHeader extends StatelessWidget {
  const _ProjectsListHeader({
    required this.total,
    required this.active,
    required this.visible,
  });

  final int total;
  final int active;
  final int visible;

  @override
  Widget build(BuildContext context) {
    final activeText = active > 0 ? ' • $active en cours' : '';
    final visibleText = visible == total
        ? '$total projet${total > 1 ? 's' : ''}$activeText'
        : '$visible affiché${visible > 1 ? 's' : ''} sur $total$activeText';

    return Row(
      children: [
        Expanded(
          child: Text(
            'Liste des projets',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(
          visibleText,
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

class _ClientProjectGroupCard extends StatelessWidget {
  const _ClientProjectGroupCard({
    required this.group,
    required this.isCollapsed,
    required this.onOpenClient,
    required this.onToggleCollapsed,
    required this.onOpenProject,
  });

  final _ClientProjectGroup group;
  final bool isCollapsed;
  final VoidCallback? onOpenClient;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<ProjectModel> onOpenProject;

  @override
  Widget build(BuildContext context) {
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
              onTap: onOpenClient,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.business_center_outlined,
                        color: AppTheme.primary(context),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.mainTextColor(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            group.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
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
            ...group.projects.map(
              (item) => _CompactProjectRow(
                item: item,
                onOpen: () => onOpenProject(item.project),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactProjectRow extends StatelessWidget {
  const _CompactProjectRow({required this.item, required this.onOpen});

  final _ProjectListItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    final percent = (project.progress.clamp(0.0, 1.0) * 100).round();
    final deadlineInfo = _projectDeadlineInfo(project.deadline);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                project.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.mainTextColor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$percent%',
                              style: TextStyle(
                                color: AppTheme.mainTextColor(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _projectMeta(project),
                              style: TextStyle(
                                color: AppTheme.secondaryTextColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            _PulseText(pulse: item.pulse, project: project),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: project.progress.clamp(0.0, 1.0),
                                  minHeight: 4,
                                  color: _pulseColor(context, item.pulse),
                                  backgroundColor: AppTheme.secondarySurface(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.secondaryTextColor(context),
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              deadlineInfo.label,
                              style: TextStyle(
                                color: deadlineInfo.isOverdue
                                    ? AppTheme.errorColor
                                    : AppTheme.secondaryTextColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _openTasksLabel(item.openTasks),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseText extends StatelessWidget {
  const _PulseText({required this.pulse, required this.project});

  final ProjectPulseModel? pulse;
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final color = _pulseColor(context, pulse);
    final label = pulse == null
        ? _normalizedProjectStatus(project)
        : pulse!.label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProjectListItem {
  const _ProjectListItem({
    required this.project,
    required this.pulse,
    required this.openTasks,
  });

  final ProjectModel project;
  final ProjectPulseModel? pulse;
  final int openTasks;

  int get rank => _projectRank(project, pulse);
}

class _ClientProjectGroup {
  const _ClientProjectGroup({
    required this.clientName,
    required this.clientId,
    required this.projects,
  });

  final String clientName;
  final String? clientId;
  final List<_ProjectListItem> projects;

  int get activeCount =>
      projects.where((item) => _isActiveProject(item.project)).length;

  int get rank {
    if (projects.isEmpty) return 9;
    return projects.map((item) => item.rank).reduce((a, b) => a < b ? a : b);
  }

  String get subtitle {
    final projectCount = projects.length;
    final activeText = activeCount > 0
        ? ' • $activeCount actif${activeCount > 1 ? 's' : ''}'
        : '';
    return '$projectCount projet${projectCount > 1 ? 's' : ''}$activeText';
  }
}

class _ProjectDateInfo {
  const _ProjectDateInfo({required this.label, required this.rank, this.date});

  final String label;
  final int rank;
  final DateTime? date;

  bool get isOverdue => rank == 0;
}

bool _isActiveProject(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status != 'terminé' &&
      status != 'termine' &&
      status != 'en pause' &&
      status != 'pause' &&
      status != 'annulé' &&
      status != 'annule' &&
      status != 'archivé' &&
      status != 'archive';
}

bool _isCompletedProject(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status == 'terminé' || status == 'termine';
}

bool _isWaitingStatus(ProjectModel project) {
  final status = project.status.trim().toLowerCase();
  return status.contains('attente') || status.contains('validation');
}

bool _isWaitingProject(ProjectPulseModel? pulse) {
  return pulse?.status == ProjectPulseStatus.waitingClient;
}

bool _isTaskDone(TaskModel task) {
  final status = task.status.trim().toLowerCase();
  return status == 'terminé' || status == 'termine';
}

String? _clientIdByName(String clientName, List<ClientModel> clients) {
  final normalizedName = clientName.trim().toLowerCase();
  if (normalizedName.isEmpty) return null;

  for (final client in clients) {
    if (client.name.trim().toLowerCase() == normalizedName) {
      return client.id;
    }
  }
  return null;
}

int _compareProjects(
  ProjectModel a,
  ProjectModel b,
  ProjectPulseModel? aPulse,
  ProjectPulseModel? bPulse,
) {
  final rankCompare = _projectRank(
    a,
    aPulse,
  ).compareTo(_projectRank(b, bPulse));
  if (rankCompare != 0) return rankCompare;

  final aDate = _projectDeadlineInfo(a.deadline);
  final bDate = _projectDeadlineInfo(b.deadline);
  final dateCompare = (aDate.date ?? DateTime(9999)).compareTo(
    bDate.date ?? DateTime(9999),
  );
  if (dateCompare != 0) return dateCompare;

  return a.title.compareTo(b.title);
}

int _projectRank(ProjectModel project, ProjectPulseModel? pulse) {
  if (pulse?.status == ProjectPulseStatus.needsAttention) return 0;
  if (pulse?.status == ProjectPulseStatus.waitingClient) return 1;
  final deadline = _projectDeadlineInfo(project.deadline);
  if (deadline.isOverdue && !_isCompletedProject(project)) return 2;
  if (_isActiveProject(project)) return 3;
  if (_isCompletedProject(project)) return 4;
  return 5;
}

String _projectMeta(ProjectModel project) {
  final type = project.type.trim();
  final status = _normalizedProjectStatus(project);
  if (type.isEmpty) return status;
  return '$type • $status';
}

String _normalizedProjectStatus(ProjectModel project) {
  if (_isCompletedProject(project)) return 'Terminé';
  if (_isWaitingStatus(project)) return 'En attente';

  final status = project.status.trim();
  if (status.isEmpty || status.toLowerCase() == 'planifié') return 'En cours';
  return status;
}

String _openTasksLabel(int count) {
  if (count == 0) return 'Aucune tâche ouverte';
  return '$count tâche${count > 1 ? 's' : ''} ouverte${count > 1 ? 's' : ''}';
}

_ProjectDateInfo _projectDeadlineInfo(String rawDeadline) {
  final deadline = rawDeadline.trim();
  if (deadline.isEmpty) {
    return const _ProjectDateInfo(label: 'Échéance non définie', rank: 4);
  }

  final lower = deadline.toLowerCase();
  final parsed = _parseDeadline(deadline);
  if (parsed == null) {
    if (lower.contains('aujourd')) {
      return const _ProjectDateInfo(label: 'Échéance : aujourd’hui', rank: 1);
    }
    if (lower == 'demain') {
      return const _ProjectDateInfo(label: 'Échéance : demain', rank: 2);
    }
    return _ProjectDateInfo(label: 'Échéance : $deadline', rank: 3);
  }

  final today = _dateOnly(DateTime.now());
  final day = _dateOnly(parsed);
  final diff = day.difference(today).inDays;

  if (diff < 0) {
    final days = diff.abs();
    return _ProjectDateInfo(
      label: 'Échéance dépassée de $days jour${days > 1 ? 's' : ''}',
      rank: 0,
      date: day,
    );
  }
  if (diff == 0) {
    return _ProjectDateInfo(
      label: 'Échéance : aujourd’hui',
      rank: 1,
      date: day,
    );
  }
  if (diff == 1) {
    return _ProjectDateInfo(label: 'Échéance : demain', rank: 2, date: day);
  }

  return _ProjectDateInfo(
    label: 'Échéance : ${_formatShortDate(day)}',
    rank: 3,
    date: day,
  );
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

Color _pulseColor(BuildContext context, ProjectPulseModel? pulse) {
  switch (pulse?.status) {
    case ProjectPulseStatus.onTrack:
    case ProjectPulseStatus.completed:
      return AppTheme.successColor;
    case ProjectPulseStatus.waitingClient:
      return AppTheme.warningColor;
    case ProjectPulseStatus.needsAttention:
      return AppTheme.errorColor;
    case null:
      return AppTheme.secondary(context);
  }
}
