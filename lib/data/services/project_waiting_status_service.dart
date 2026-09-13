import '../models/client_action_model.dart';

enum ProjectWaitingState { ready, waitingProfessional, waitingClient, blocked }

class ProjectWaitingSummary {
  const ProjectWaitingSummary({
    required this.state,
    required this.professionalPendingActions,
    required this.clientPendingActions,
    required this.overdueProfessionalActions,
    required this.overdueClientActions,
    this.primaryAction,
    this.blockedDays = 0,
  });

  final ProjectWaitingState state;
  final int professionalPendingActions;
  final int clientPendingActions;
  final int overdueProfessionalActions;
  final int overdueClientActions;
  final ClientActionModel? primaryAction;
  final int blockedDays;

  bool get isReady => state == ProjectWaitingState.ready;
}

class ProjectWaitingStatusService {
  const ProjectWaitingStatusService({this.blockedAfterDays = 3});

  final int blockedAfterDays;

  ProjectWaitingSummary evaluate({
    required List<ClientActionModel> actions,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final pendingActions = actions
        .where((action) => action.status == 'pending')
        .toList();
    final professionalPending = pendingActions
        .where((action) => action.assignedTo == 'professional')
        .toList();
    final clientPending = pendingActions
        .where((action) => action.assignedTo == 'client')
        .toList();
    final overdueProfessional = professionalPending
        .where((action) => _isOverdue(action, today))
        .toList();
    final overdueClient = clientPending
        .where((action) => _isOverdue(action, today))
        .toList();
    final importantActions = pendingActions
        .where((action) => _isImportant(action, today))
        .toList();

    if (importantActions.isEmpty) {
      return ProjectWaitingSummary(
        state: ProjectWaitingState.ready,
        professionalPendingActions: professionalPending.length,
        clientPendingActions: clientPending.length,
        overdueProfessionalActions: overdueProfessional.length,
        overdueClientActions: overdueClient.length,
      );
    }

    importantActions.sort((a, b) => _compareActions(a, b, today));
    final primaryAction = importantActions.first;
    final blockedDays = _overdueDays(primaryAction, today);

    if (blockedDays >= blockedAfterDays) {
      return ProjectWaitingSummary(
        state: ProjectWaitingState.blocked,
        professionalPendingActions: professionalPending.length,
        clientPendingActions: clientPending.length,
        overdueProfessionalActions: overdueProfessional.length,
        overdueClientActions: overdueClient.length,
        primaryAction: primaryAction,
        blockedDays: blockedDays,
      );
    }

    return ProjectWaitingSummary(
      state: primaryAction.assignedTo == 'client'
          ? ProjectWaitingState.waitingClient
          : ProjectWaitingState.waitingProfessional,
      professionalPendingActions: professionalPending.length,
      clientPendingActions: clientPending.length,
      overdueProfessionalActions: overdueProfessional.length,
      overdueClientActions: overdueClient.length,
      primaryAction: primaryAction,
      blockedDays: blockedDays,
    );
  }

  bool _isImportant(ClientActionModel action, DateTime today) {
    if (action.priority == 'high') return true;
    if (_isOverdue(action, today)) return true;

    final dueDate = action.dueDate;
    if (dueDate == null) return action.priority == 'medium';

    final dueDay = _dateOnly(dueDate);
    final daysUntilDue = dueDay.difference(today).inDays;
    return daysUntilDue <= 7 || action.priority == 'medium';
  }

  int _compareActions(
    ClientActionModel a,
    ClientActionModel b,
    DateTime today,
  ) {
    final overdueCompare = _overdueDays(
      b,
      today,
    ).compareTo(_overdueDays(a, today));
    if (overdueCompare != 0) return overdueCompare;

    final priorityCompare = _priorityRank(
      b.priority,
    ).compareTo(_priorityRank(a.priority));
    if (priorityCompare != 0) return priorityCompare;

    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    final dateCompare = aDate.compareTo(bDate);
    if (dateCompare != 0) return dateCompare;

    return a.title.compareTo(b.title);
  }

  bool _isOverdue(ClientActionModel action, DateTime today) {
    return _overdueDays(action, today) > 0;
  }

  int _overdueDays(ClientActionModel action, DateTime today) {
    final dueDate = action.dueDate;
    if (dueDate == null) return 0;

    final dueDay = _dateOnly(dueDate);
    if (!dueDay.isBefore(today)) return 0;
    return today.difference(dueDay).inDays;
  }

  int _priorityRank(String priority) {
    switch (priority) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
