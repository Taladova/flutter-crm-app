import 'package:clientflow_pro/core/utils/french_text.dart';

import '../models/client_action_model.dart';
import '../models/project_model.dart';
import '../models/project_pulse_model.dart';
import '../models/task_model.dart';
import 'project_waiting_status_service.dart';

class ProjectPulseService {
  const ProjectPulseService({
    this.waitingStatusService = const ProjectWaitingStatusService(),
  });

  final ProjectWaitingStatusService waitingStatusService;

  ProjectPulseModel evaluate({
    required ProjectModel project,
    required List<ClientActionModel> actions,
    required List<TaskModel> tasks,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final waitingSummary = waitingStatusService.evaluate(
      actions: actions,
      now: today,
    );
    final openTasks = tasks.where((task) => !_isTaskCompleted(task)).toList();
    final overdueTasks = openTasks
        .where((task) => _isTaskOverdue(task, today))
        .toList();
    final pendingActions = actions.where((action) => action.isPending).toList();
    final overdueActions =
        waitingSummary.overdueClientActions +
        waitingSummary.overdueProfessionalActions;
    final nextDeadline = _nextDeadline(
      project,
      pendingActions,
      openTasks,
      today,
    );
    final lastActivity = _lastActivity(actions);
    final lastActivityLabel = _lastActivityLabel(actions);
    final progress = _normalizedProgress(project.progress);

    if (_isProjectCompleted(project, progress)) {
      return ProjectPulseModel(
        projectId: project.id,
        status: ProjectPulseStatus.completed,
        label: 'Projet terminé',
        reason: 'Toutes les étapes principales sont finalisées.',
        progress: progress,
        lastActivity: lastActivity,
        lastActivityLabel: lastActivityLabel,
        nextDeadline: nextDeadline,
        openTasks: openTasks.length,
        overdueTasks: overdueTasks.length,
        pendingActions: pendingActions.length,
        overdueActions: overdueActions,
      );
    }

    if (waitingSummary.state == ProjectWaitingState.blocked) {
      return ProjectPulseModel(
        projectId: project.id,
        status: ProjectPulseStatus.needsAttention,
        label: 'Nécessite votre attention',
        reason: _blockedReason(waitingSummary),
        progress: progress,
        lastActivity: lastActivity,
        lastActivityLabel: lastActivityLabel,
        nextDeadline: nextDeadline,
        blockingAction: waitingSummary.primaryAction,
        daysBlocked: waitingSummary.blockedDays,
        openTasks: openTasks.length,
        overdueTasks: overdueTasks.length,
        pendingActions: pendingActions.length,
        overdueActions: overdueActions,
      );
    }

    if (overdueTasks.isNotEmpty ||
        waitingSummary.overdueProfessionalActions > 0) {
      return ProjectPulseModel(
        projectId: project.id,
        status: ProjectPulseStatus.needsAttention,
        label: 'Nécessite votre attention',
        reason: _attentionReason(
          overdueTasks: overdueTasks.length,
          overdueProfessionalActions: waitingSummary.overdueProfessionalActions,
        ),
        progress: progress,
        lastActivity: lastActivity,
        lastActivityLabel: lastActivityLabel,
        nextDeadline: nextDeadline,
        blockingAction: waitingSummary.primaryAction,
        daysBlocked: waitingSummary.blockedDays,
        openTasks: openTasks.length,
        overdueTasks: overdueTasks.length,
        pendingActions: pendingActions.length,
        overdueActions: overdueActions,
      );
    }

    if (waitingSummary.state == ProjectWaitingState.waitingClient) {
      return ProjectPulseModel(
        projectId: project.id,
        status: ProjectPulseStatus.waitingClient,
        label: 'Attend le client',
        reason: waitingSummary.primaryAction?.title ?? 'Action client attendue',
        progress: progress,
        lastActivity: lastActivity,
        lastActivityLabel: lastActivityLabel,
        nextDeadline: nextDeadline,
        blockingAction: waitingSummary.primaryAction,
        daysBlocked: waitingSummary.blockedDays,
        openTasks: openTasks.length,
        overdueTasks: overdueTasks.length,
        pendingActions: pendingActions.length,
        overdueActions: overdueActions,
      );
    }

    if (waitingSummary.state == ProjectWaitingState.waitingProfessional) {
      return ProjectPulseModel(
        projectId: project.id,
        status: ProjectPulseStatus.needsAttention,
        label: 'Nécessite votre attention',
        reason: waitingSummary.primaryAction?.title ?? 'Action à traiter',
        progress: progress,
        lastActivity: lastActivity,
        lastActivityLabel: lastActivityLabel,
        nextDeadline: nextDeadline,
        blockingAction: waitingSummary.primaryAction,
        daysBlocked: waitingSummary.blockedDays,
        openTasks: openTasks.length,
        overdueTasks: overdueTasks.length,
        pendingActions: pendingActions.length,
        overdueActions: overdueActions,
      );
    }

    return ProjectPulseModel(
      projectId: project.id,
      status: ProjectPulseStatus.onTrack,
      label: 'Projet en bonne voie',
      reason: nextDeadline == null
          ? '${(progress * 100).round()} % terminé'
          : 'Prochaine échéance ${_formatShortDate(nextDeadline)}',
      progress: progress,
      lastActivity: lastActivity,
      lastActivityLabel: lastActivityLabel,
      nextDeadline: nextDeadline,
      openTasks: openTasks.length,
      overdueTasks: overdueTasks.length,
      pendingActions: pendingActions.length,
      overdueActions: overdueActions,
    );
  }

  ProjectPulseDashboardSummary summarize(List<ProjectPulseModel> pulses) {
    return ProjectPulseDashboardSummary(
      pulses: pulses,
      onTrack: pulses
          .where((pulse) => pulse.status == ProjectPulseStatus.onTrack)
          .length,
      waitingClient: pulses
          .where((pulse) => pulse.status == ProjectPulseStatus.waitingClient)
          .length,
      needsAttention: pulses
          .where((pulse) => pulse.status == ProjectPulseStatus.needsAttention)
          .length,
      completed: pulses
          .where((pulse) => pulse.status == ProjectPulseStatus.completed)
          .length,
    );
  }

  bool _isProjectCompleted(ProjectModel project, double progress) {
    return project.status == 'Terminé' || progress >= 1;
  }

  bool _isTaskCompleted(TaskModel task) {
    return task.status == 'Terminé';
  }

  bool _isTaskOverdue(TaskModel task, DateTime today) {
    final deadline = _parseDate(task.deadline, today);
    if (deadline == null) return false;
    return _dateOnly(deadline).isBefore(today);
  }

  DateTime? _nextDeadline(
    ProjectModel project,
    List<ClientActionModel> pendingActions,
    List<TaskModel> openTasks,
    DateTime today,
  ) {
    final deadlines = <DateTime>[
      for (final action in pendingActions)
        if (action.dueDate != null) action.dueDate!,
      for (final task in openTasks)
        if (_parseDate(task.deadline, today) != null)
          _parseDate(task.deadline, today)!,
      if (_parseDate(project.deadline, today) != null)
        _parseDate(project.deadline, today)!,
    ];

    if (deadlines.isEmpty) return null;
    deadlines.sort();
    return deadlines.first;
  }

  DateTime? _lastActivity(List<ClientActionModel> actions) {
    final dates = <DateTime>[
      for (final action in actions)
        if (action.completedAt != null) action.completedAt!,
      for (final action in actions)
        if (action.updatedAt != null) action.updatedAt!,
      for (final action in actions)
        if (action.createdAt != null) action.createdAt!,
    ];

    if (dates.isEmpty) return null;
    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }

  String? _lastActivityLabel(List<ClientActionModel> actions) {
    final datedActions = actions
        .where(
          (action) =>
              action.completedAt != null ||
              action.updatedAt != null ||
              action.createdAt != null,
        )
        .toList();

    if (datedActions.isEmpty) return null;
    datedActions.sort((a, b) {
      final aDate = a.completedAt ?? a.updatedAt ?? a.createdAt!;
      final bDate = b.completedAt ?? b.updatedAt ?? b.createdAt!;
      return bDate.compareTo(aDate);
    });
    return datedActions.first.title;
  }

  String _blockedReason(ProjectWaitingSummary summary) {
    final action = summary.primaryAction;
    if (action == null) return 'Action importante bloquée';

    final owner = action.assignedTo == 'client'
        ? 'En attente du client'
        : 'À faire par moi';
    return '$owner : ${action.title}';
  }

  String _attentionReason({
    required int overdueTasks,
    required int overdueProfessionalActions,
  }) {
    if (overdueTasks > 0 && overdueProfessionalActions > 0) {
      return '${frPlural(overdueTasks, 'tâche en retard', 'tâches en retard')} et '
          '${frPlural(overdueProfessionalActions, 'action à traiter', 'actions à traiter')}';
    }
    if (overdueTasks > 0) {
      return frPlural(overdueTasks, 'tâche en retard', 'tâches en retard');
    }
    return frPlural(
      overdueProfessionalActions,
      'action en retard',
      'actions en retard',
    );
  }

  DateTime? _parseDate(String value, DateTime now) {
    final clean = value.trim().toLowerCase();
    if (clean.isEmpty) return null;
    if (clean == 'aujourd’hui' || clean == "aujourd'hui") {
      return _dateOnly(now);
    }
    if (clean == 'demain') {
      return _dateOnly(now).add(const Duration(days: 1));
    }
    if (clean == 'hier') {
      return _dateOnly(now).subtract(const Duration(days: 1));
    }

    final slashMatch = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$',
    ).firstMatch(clean);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      var year = int.tryParse(slashMatch.group(3)!);
      if (year != null && year < 100) year += 2000;
      return _safeDate(year, month, day);
    }

    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(clean);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      return _safeDate(year, month, day);
    }

    final frenchMatch = RegExp(
      r'^(\d{1,2})\s+([a-zéû]+)\s*(\d{4})?$',
    ).firstMatch(clean);
    if (frenchMatch != null) {
      final day = int.tryParse(frenchMatch.group(1)!);
      final month = _monthNumber(frenchMatch.group(2)!);
      final year = int.tryParse(frenchMatch.group(3) ?? '${now.year}');
      return _safeDate(year, month, day);
    }

    return null;
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  int? _monthNumber(String value) {
    const months = {
      'janvier': 1,
      'février': 2,
      'fevrier': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'août': 8,
      'aout': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'décembre': 12,
      'decembre': 12,
    };
    return months[value];
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  double _normalizedProgress(double progress) {
    final normalized = progress > 1 ? progress / 100 : progress;
    return normalized.clamp(0.0, 1.0);
  }
}
