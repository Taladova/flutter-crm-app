class ProjectTemplateModel {
  const ProjectTemplateModel({
    required this.id,
    required this.name,
    required this.projectType,
    required this.timeline,
    required this.tasks,
    required this.clientActions,
    required this.documentRequests,
    required this.startChecklist,
  });

  final String id;
  final String name;
  final String projectType;
  final List<TemplateTimelineStep> timeline;
  final List<TemplateTask> tasks;
  final List<TemplateClientAction> clientActions;
  final List<TemplateDocumentRequest> documentRequests;
  final List<String> startChecklist;

  bool get isCustom => id == 'custom';
}

class TemplateTimelineStep {
  const TemplateTimelineStep({
    required this.title,
    this.description = '',
    this.status = 'upcoming',
    this.daysOffset,
    this.visibleToClient = true,
  });

  final String title;
  final String description;
  final String status;
  final int? daysOffset;
  final bool visibleToClient;
}

class TemplateTask {
  const TemplateTask({
    required this.title,
    this.priority = 'Moyenne',
    this.daysOffset,
  });

  final String title;
  final String priority;
  final int? daysOffset;
}

class TemplateClientAction {
  const TemplateClientAction({
    required this.title,
    this.description = '',
    this.type = 'task',
    this.priority = 'medium',
    this.daysOffset,
    this.visibleToClient = true,
  });

  final String title;
  final String description;
  final String type;
  final String priority;
  final int? daysOffset;
  final bool visibleToClient;
}

class TemplateDocumentRequest {
  const TemplateDocumentRequest({
    required this.title,
    this.description = '',
    this.required = true,
    this.daysOffset,
  });

  final String title;
  final String description;
  final bool required;
  final int? daysOffset;
}
