import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../data/models/client_action_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/timeline_event_model.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';

class ClientProgressPage extends ConsumerStatefulWidget {
  const ClientProgressPage({super.key});

  @override
  ConsumerState<ClientProgressPage> createState() => _ClientProgressPageState();
}

class _ClientProgressPageState extends ConsumerState<ClientProgressPage> {
  List<ProjectModel>? _lastProjects;
  List<ClientActionModel>? _lastActions;
  List<TaskModel>? _lastTasks;
  String? _loggedProjectId;
  int? _loggedActionsCount;
  bool _loggedCompleted = false;
  bool _isTimelineExpanded = false;

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('[client-progress] page started');
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(clientProgressProjectsProvider);
    final actionsAsync = ref.watch(clientProgressActionsProvider);
    final tasksAsync = ref.watch(clientProgressTasksProvider);
    final latestProjects = projectsAsync.value;
    final latestActions = actionsAsync.value;
    final latestTasks = tasksAsync.value;

    if (latestProjects != null) _lastProjects = latestProjects;
    if (latestActions != null) _lastActions = latestActions;
    if (latestTasks != null) _lastTasks = latestTasks;

    final projects = latestProjects ?? _lastProjects;
    final actionsState =
        latestActions ?? _lastActions ?? const <ClientActionModel>[];
    final tasksState = latestTasks ?? _lastTasks ?? const <TaskModel>[];
    final hasInitialProjects = projects != null;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: !hasInitialProjects && projectsAsync.isLoading
              ? const _ProgressLoadingView()
              : !hasInitialProjects && projectsAsync.hasError
              ? AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Avancement indisponible',
                  description:
                      'Impossible de charger les informations du projet.',
                  onRetry: () {
                    ref.invalidate(clientProgressProjectsProvider);
                    ref.invalidate(clientProgressActionsProvider);
                  },
                )
              : Builder(
                  builder: (context) {
                    final visibleProjects = projects ?? const <ProjectModel>[];
                    if (visibleProjects.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.timeline_rounded,
                        title: 'Aucun avancement',
                        description:
                            'Le suivi du projet apparaîtra ici dès qu’il sera partagé.',
                      );
                    }

                    final project = visibleProjects.first;
                    if (_loggedProjectId != project.id) {
                      _loggedProjectId = project.id;
                      // ignore: avoid_print
                      print('[client-progress] projectId=${project.id}');
                      // ignore: avoid_print
                      print('[client-progress] project loaded');
                    }
                    final timelineAsync = ref.watch(
                      clientPortalTimelineProvider(project.id),
                    );
                    final actions =
                        actionsState
                            .where((action) => action.projectId == project.id)
                            .toList()
                          ..sort((a, b) {
                            if (a.status == b.status) {
                              return a.title.compareTo(b.title);
                            }
                            return a.status == 'pending' ? -1 : 1;
                          });
                    if (_loggedActionsCount != actions.length) {
                      _loggedActionsCount = actions.length;
                      // ignore: avoid_print
                      print(
                        '[client-progress] actions count=${actions.length}',
                      );
                    }
                    final visibleTasks = tasksState;
                    if (!_loggedCompleted) {
                      _loggedCompleted = true;
                      // ignore: avoid_print
                      print('[client-progress] completed');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: ClientPortalColors.subtleIconSurface(),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.timeline_rounded,
                                color: ClientPortalColors.sage,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Suivi projet',
                                    style: TextStyle(
                                      color: AppTheme.secondaryTextColor(
                                        context,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    project.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        timelineAsync.when(
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              _CountedTitle(title: 'Votre projet'),
                              SizedBox(height: 12),
                              _InlineLoadingTile(),
                            ],
                          ),
                          error: (_, _) => const AppEmptyState(
                            icon: Icons.error_outline_rounded,
                            title: 'Étapes indisponibles',
                            description: 'Impossible de charger les étapes.',
                          ),
                          data: (events) {
                            if (events.isEmpty) {
                              return const AppEmptyState(
                                icon: Icons.route_rounded,
                                title: 'Aucune étape',
                                description:
                                    'Les étapes visibles du projet apparaîtront ici.',
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _CountedTitle(title: 'Votre projet'),
                                const SizedBox(height: 12),
                                _TimelineRail(
                                  events: events,
                                  isExpanded: _isTimelineExpanded,
                                  onToggle: () => setState(
                                    () => _isTimelineExpanded =
                                        !_isTimelineExpanded,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _ClientCompletedActionsSection(actions: actions),
                        const SizedBox(height: 24),
                        _ClientTasksSection(
                          projects: visibleProjects,
                          tasks: visibleTasks,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Read-only history of completed actions, already filtered upstream to
/// visibleToClient == true — internal actions never reach this list. The
/// "À faire de votre côté" list (still-pending, interactive actions) was
/// removed from this page: it's already shown, and completable, from
/// Accueil. "Réalisé" isn't duplicated anywhere else, so it stays here.
class _ClientCompletedActionsSection extends StatefulWidget {
  const _ClientCompletedActionsSection({required this.actions});

  final List<ClientActionModel> actions;

  @override
  State<_ClientCompletedActionsSection> createState() =>
      _ClientCompletedActionsSectionState();
}

class _ClientCompletedActionsSectionState
    extends State<_ClientCompletedActionsSection> {
  static const _maxVisible = 3;

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final done = widget.actions.where((action) => action.isCompleted).toList()
      ..sort((a, b) {
        final aDate = a.completedAt ?? a.updatedAt ?? DateTime(0);
        final bDate = b.completedAt ?? b.updatedAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
    final visible = _isExpanded ? done : done.take(_maxVisible).toList();
    final canToggle = done.length > _maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountedTitle(title: 'Réalisé', count: done.length),
        const SizedBox(height: 12),
        if (done.isEmpty)
          const AppEmptyState(
            icon: Icons.history_rounded,
            title: 'Rien de terminé pour l’instant',
            description: 'Les actions terminées apparaîtront ici.',
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...visible.map(
                  (action) =>
                      _ClientActionRow(action: action, interactive: false),
                ),
                if (canToggle) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                      foregroundColor: ClientPortalColors.deep,
                    ),
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                    label: Text(
                      _isExpanded
                          ? 'Réduire'
                          : 'Voir les ${done.length} éléments réalisés',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ClientActionRow extends ConsumerStatefulWidget {
  const _ClientActionRow({required this.action, required this.interactive});

  final ClientActionModel action;
  final bool interactive;

  @override
  ConsumerState<_ClientActionRow> createState() => _ClientActionRowState();
}

class _ClientActionRowState extends ConsumerState<_ClientActionRow> {
  bool isSubmitting = false;

  Future<void> _complete() async {
    if (isSubmitting) return;
    setState(() => isSubmitting = true);
    try {
      await ref
          .read(clientPortalServiceProvider)
          .completeCurrentClientAction(widget.action);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de marquer cette action comme terminée.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final isDone = action.isCompleted;
    final color = isDone ? ClientPortalColors.cta : ClientPortalColors.sage;
    // The check mark + the "Réalisé" section title already say this is
    // done — no need to repeat "Terminé" under every row. Show the
    // completion date instead when it's available.
    final subtitle = isDone
        ? _completedDateLabel(action)
        : _clientActionStateLabel(action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.interactive)
            GestureDetector(
              onTap: isSubmitting ? null : _complete,
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: color,
                      size: 22,
                    ),
            )
          else
            Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
              size: 22,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _completedDateLabel(ClientActionModel action) {
  final date = action.completedAt ?? action.updatedAt;
  return date == null ? null : _formatClientTimelineDate(date);
}

String _clientActionStateLabel(ClientActionModel action) {
  if (action.isCompleted) return 'Terminé';
  final due = action.dueDate;
  return due == null
      ? 'En attente'
      : 'En attente — ${_formatClientTimelineDate(due)}';
}

class _ClientTasksSection extends StatelessWidget {
  const _ClientTasksSection({required this.projects, required this.tasks});

  final List<ProjectModel> projects;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final authorizedProjectIds = projects.map((project) => project.id).toSet();
    final visibleTasks =
        tasks
            .where(
              (task) =>
                  task.isVisibleInClientPortal &&
                  authorizedProjectIds.contains(task.projectId),
            )
            .toList()
          ..sort(_compareClientTasks);
    final tasksByProject = <String, List<TaskModel>>{};

    for (final task in visibleTasks) {
      tasksByProject.putIfAbsent(task.projectId, () => []).add(task);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountedTitle(title: 'Mes tâches', count: visibleTasks.length),
        const SizedBox(height: 10),
        _TaskStatusSummary(tasks: visibleTasks),
        const SizedBox(height: 12),
        if (visibleTasks.isEmpty)
          const AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'Aucune tâche visible',
            description:
                'Les tâches internes de votre prestataire ne sont pas affichées.',
          )
        else
          ...tasksByProject.entries.map((entry) {
            final project = _findProject(projects, entry.key);
            return _ProjectTaskGroup(
              projectTitle:
                  project?.title ??
                  (entry.value.first.projectName.trim().isEmpty
                      ? 'Projet'
                      : entry.value.first.projectName),
              tasks: entry.value,
            );
          }),
      ],
    );
  }
}

class _TaskStatusSummary extends StatelessWidget {
  const _TaskStatusSummary({required this.tasks});

  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final todo = tasks.where((task) => task.status == 'À faire').length;
    final inProgress = tasks.where((task) => task.status == 'En cours').length;
    final done = tasks.where((task) => task.status == 'Terminé').length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TaskStatusPill(label: 'À faire', count: todo),
        _TaskStatusPill(label: 'En cours', count: inProgress),
        _TaskStatusPill(label: 'Terminées', count: done),
      ],
    );
  }
}

class _TaskStatusPill extends StatelessWidget {
  const _TaskStatusPill({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ClientPortalColors.softSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClientPortalColors.border),
      ),
      child: Text(
        '$label $count',
        style: const TextStyle(
          color: ClientPortalColors.deep,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProjectTaskGroup extends StatefulWidget {
  const _ProjectTaskGroup({required this.projectTitle, required this.tasks});

  final String projectTitle;
  final List<TaskModel> tasks;

  @override
  State<_ProjectTaskGroup> createState() => _ProjectTaskGroupState();
}

class _ProjectTaskGroupState extends State<_ProjectTaskGroup> {
  static const _maxVisible = 3;

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final prioritized = _prioritizedClientTasks(widget.tasks);
    final visibleTasks = _isExpanded
        ? prioritized
        : prioritized.take(_maxVisible).toList();
    final canToggle = prioritized.length > _maxVisible;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.projectTitle,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...visibleTasks.map((task) => _ClientTaskRow(task: task)),
          if (canToggle) ...[
            const SizedBox(height: 2),
            TextButton.icon(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                foregroundColor: ClientPortalColors.deep,
              ),
              icon: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _isExpanded
                    ? 'Réduire'
                    : 'Voir les ${prioritized.length} tâches',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Display order: À faire, then En cours, then Terminées — most recently
/// due first as the best available proxy for "most recent" since tasks
/// don't carry a completion timestamp. Used both to pick the compact
/// 3-task default and to order the fully expanded list.
List<TaskModel> _prioritizedClientTasks(List<TaskModel> tasks) {
  final todo = tasks.where((task) => task.status == 'À faire').toList()
    ..sort(_byDeadlineAscending);
  final inProgress = tasks.where((task) => task.status == 'En cours').toList()
    ..sort(_byDeadlineAscending);
  final done = tasks.where((task) => task.status == 'Terminé').toList()
    ..sort(_byDeadlineDescending);
  final other = tasks
      .where(
        (task) =>
            task.status != 'À faire' &&
            task.status != 'En cours' &&
            task.status != 'Terminé',
      )
      .toList();

  return [...todo, ...inProgress, ...done, ...other];
}

int _byDeadlineAscending(TaskModel a, TaskModel b) {
  final aDate = _parseClientTaskDeadline(a.deadline) ?? DateTime(9999);
  final bDate = _parseClientTaskDeadline(b.deadline) ?? DateTime(9999);
  return aDate.compareTo(bDate);
}

int _byDeadlineDescending(TaskModel a, TaskModel b) {
  final aDate = _parseClientTaskDeadline(a.deadline) ?? DateTime(0);
  final bDate = _parseClientTaskDeadline(b.deadline) ?? DateTime(0);
  return bDate.compareTo(aDate);
}

class _ClientTaskRow extends StatelessWidget {
  const _ClientTaskRow({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'Terminé';
    final color = isDone ? ClientPortalColors.cta : ClientPortalColors.sage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDone ? 'Terminé' : _taskDeadlineLabel(task.deadline),
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
      ),
    );
  }
}

class _CountedTitle extends StatelessWidget {
  const _CountedTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: ClientPortalColors.subtleIconSurface(),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: ClientPortalColors.sage,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.events,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<TimelineEventModel> events;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = isExpanded ? events : _compactTimelineEvents(events);
    final canToggle = events.length > visibleEvents.length || isExpanded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < visibleEvents.length; index++)
            _TimelineRailItem(
              event: visibleEvents[index],
              isLast: index == visibleEvents.length - 1,
            ),
          if (canToggle) ...[
            const SizedBox(height: 2),
            TextButton.icon(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                foregroundColor: ClientPortalColors.deep,
              ),
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                isExpanded
                    ? 'Réduire'
                    : 'Voir toutes les étapes (${events.length})',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Picks at most 3 relevant steps for the collapsed view: the current step,
/// the next one, and a contextual third — the immediately preceding step by
/// default, or a second upcoming step when there's nothing before the
/// current one (e.g. it's the very first step).
List<TimelineEventModel> _compactTimelineEvents(
  List<TimelineEventModel> events,
) {
  const maxVisible = 3;
  if (events.length <= maxVisible) return events;

  final currentIndex = events.indexWhere((event) => event.isCurrent);
  final anchorIndex = currentIndex >= 0
      ? currentIndex
      : events.indexWhere((event) => !event.isCompleted);
  final safeAnchorIndex = anchorIndex >= 0 ? anchorIndex : events.length - 1;

  final selectedIndexes = <int>{safeAnchorIndex};
  final hasPrevious = safeAnchorIndex - 1 >= 0;
  final hasNext = safeAnchorIndex + 1 < events.length;

  if (hasNext) selectedIndexes.add(safeAnchorIndex + 1);
  if (hasPrevious) selectedIndexes.add(safeAnchorIndex - 1);

  if (selectedIndexes.length < maxVisible) {
    if (hasNext && safeAnchorIndex + 2 < events.length) {
      selectedIndexes.add(safeAnchorIndex + 2);
    } else if (hasPrevious && safeAnchorIndex - 2 >= 0) {
      selectedIndexes.add(safeAnchorIndex - 2);
    }
  }

  final orderedIndexes = selectedIndexes.toList()..sort();
  return orderedIndexes.map((index) => events[index]).toList();
}

class _TimelineRailItem extends StatefulWidget {
  const _TimelineRailItem({required this.event, required this.isLast});

  final TimelineEventModel event;
  final bool isLast;

  @override
  State<_TimelineRailItem> createState() => _TimelineRailItemState();
}

class _TimelineRailItemState extends State<_TimelineRailItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.86,
      upperBound: 1,
    );
    if (widget.event.isCurrent) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _TimelineRailItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event.isCurrent && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.event.isCurrent && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final color = event.isCompleted || event.isCurrent
        ? ClientPortalColors.sage
        : AppTheme.secondaryTextColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            ScaleTransition(
              scale: event.isCurrent
                  ? _controller
                  : const AlwaysStoppedAnimation(1),
              child: Icon(
                event.isCompleted
                    ? Icons.check_circle_rounded
                    : event.isCurrent
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 24,
              ),
            ),
            if (!widget.isLast)
              Container(
                width: 2,
                height: 34,
                color: AppTheme.borderColor(context),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (event.description.isNotEmpty || event.date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (event.description.isNotEmpty) event.description,
                      if (event.date != null)
                        _formatClientTimelineDate(event.date!),
                    ].join(' • '),
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _TimelineStatusLabel(event: event),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStatusLabel extends StatelessWidget {
  const _TimelineStatusLabel({required this.event});

  final TimelineEventModel event;

  @override
  Widget build(BuildContext context) {
    final color = event.isCompleted || event.isCurrent
        ? ClientPortalColors.sage
        : AppTheme.secondaryTextColor(context);
    final label = event.isCompleted
        ? '✓ Terminée'
        : event.isCurrent
        ? '● En cours'
        : '○ À venir';

    return Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
    );
  }
}

String _formatClientTimelineDate(DateTime date) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _ProgressLoadingView extends StatelessWidget {
  const _ProgressLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LoadingHeader(),
        SizedBox(height: 22),
        _LoadingHero(),
        SizedBox(height: 24),
        _LoadingBar(width: 120, height: 22),
        SizedBox(height: 12),
        _InlineLoadingTile(),
        SizedBox(height: 10),
        _InlineLoadingTile(),
      ],
    );
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: ClientPortalColors.softSurface,
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoadingBar(width: 100, height: 14),
              SizedBox(height: 8),
              _LoadingBar(width: 190, height: 28),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _InlineLoadingTile extends StatelessWidget {
  const _InlineLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.borderColor(context),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

ProjectModel? _findProject(List<ProjectModel> projects, String projectId) {
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
}

int _compareClientTasks(TaskModel a, TaskModel b) {
  final projectCompare = a.projectName.compareTo(b.projectName);
  if (projectCompare != 0) return projectCompare;

  final statusCompare = _taskStatusRank(
    a.status,
  ).compareTo(_taskStatusRank(b.status));
  if (statusCompare != 0) return statusCompare;

  final aDate = _parseClientTaskDeadline(a.deadline);
  final bDate = _parseClientTaskDeadline(b.deadline);
  final dateCompare = (aDate ?? DateTime(9999)).compareTo(
    bDate ?? DateTime(9999),
  );
  if (dateCompare != 0) return dateCompare;

  return a.title.compareTo(b.title);
}

int _taskStatusRank(String status) {
  switch (status) {
    case 'À faire':
      return 0;
    case 'En cours':
      return 1;
    case 'Terminé':
      return 2;
    default:
      return 3;
  }
}

DateTime? _parseClientTaskDeadline(String deadline) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(deadline.trim());
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _taskDeadlineLabel(String deadline) {
  if (deadline.trim().isEmpty) return 'Sans échéance';
  final date = _parseClientTaskDeadline(deadline);
  if (date == null) return deadline;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;

  if (diff == 0) return 'Aujourd’hui';
  if (diff == 1) return 'Demain';
  if (diff < 0) return 'En retard';
  return deadline;
}
