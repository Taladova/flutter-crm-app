import 'client_action_model.dart';

enum ProjectPulseStatus { onTrack, waitingClient, needsAttention, completed }

class ProjectPulseModel {
  const ProjectPulseModel({
    required this.projectId,
    required this.status,
    required this.label,
    required this.reason,
    required this.progress,
    this.lastActivity,
    this.lastActivityLabel,
    this.nextDeadline,
    this.blockingAction,
    this.daysBlocked = 0,
    this.openTasks = 0,
    this.overdueTasks = 0,
    this.pendingActions = 0,
    this.overdueActions = 0,
  });

  final String projectId;
  final ProjectPulseStatus status;
  final String label;
  final String reason;
  final DateTime? lastActivity;
  final String? lastActivityLabel;
  final DateTime? nextDeadline;
  final ClientActionModel? blockingAction;
  final int daysBlocked;
  final double progress;
  final int openTasks;
  final int overdueTasks;
  final int pendingActions;
  final int overdueActions;

  bool get isHealthy => status == ProjectPulseStatus.onTrack;
  bool get isCompleted => status == ProjectPulseStatus.completed;
  bool get isWaitingClient => status == ProjectPulseStatus.waitingClient;
  bool get needsAttention => status == ProjectPulseStatus.needsAttention;
}

class ProjectPulseDashboardSummary {
  const ProjectPulseDashboardSummary({
    required this.pulses,
    required this.onTrack,
    required this.waitingClient,
    required this.needsAttention,
    required this.completed,
  });

  final List<ProjectPulseModel> pulses;
  final int onTrack;
  final int waitingClient;
  final int needsAttention;
  final int completed;

  List<ProjectPulseModel> byStatus(ProjectPulseStatus status) {
    return pulses.where((pulse) => pulse.status == status).toList();
  }
}
