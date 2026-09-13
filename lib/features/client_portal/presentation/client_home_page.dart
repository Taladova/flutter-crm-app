import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_notification_bell.dart';
import '../../../data/models/client_account_model.dart';
import '../../../data/models/client_action_model.dart';
import '../../../data/models/document_request_model.dart';
import '../../../data/models/project_model.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';

class ClientHomePage extends ConsumerStatefulWidget {
  const ClientHomePage({super.key});

  @override
  ConsumerState<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends ConsumerState<ClientHomePage> {
  ClientAccountModel? _lastAccount;
  List<ProjectModel>? _lastProjects;
  List<ClientActionModel>? _lastActions;
  List<DocumentRequestModel>? _lastDocumentRequests;

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(clientHomeAccountProvider);
    final projectsAsync = ref.watch(clientHomeProjectsProvider);
    final actionsAsync = ref.watch(clientHomeActionsProvider);
    final documentRequestsAsync = ref.watch(
      clientPortalDocumentRequestsProvider,
    );
    final latestAccount = accountAsync.value;
    final latestProjects = projectsAsync.value;
    final latestActions = actionsAsync.value;
    final latestDocumentRequests = documentRequestsAsync.value;

    if (latestAccount != null) _lastAccount = latestAccount;
    if (latestProjects != null) _lastProjects = latestProjects;
    if (latestActions != null) _lastActions = latestActions;
    if (latestDocumentRequests != null) {
      _lastDocumentRequests = latestDocumentRequests;
    }

    final projects = latestProjects ?? _lastProjects;
    final hasInitialProjects = projects != null;

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: ClientPortalColors.cta,
          onRefresh: () async {
            ref.invalidate(clientHomeAccountProvider);
            ref.invalidate(clientHomeProjectsProvider);
            ref.invalidate(clientHomeActionsProvider);
            ref.invalidate(clientPortalDocumentRequestsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            child: !hasInitialProjects && projectsAsync.isLoading
                ? const _ClientLoadingView()
                : !hasInitialProjects && projectsAsync.hasError
                ? _ClientErrorView(
                    onRetry: () {
                      ref.invalidate(clientHomeAccountProvider);
                      ref.invalidate(clientHomeProjectsProvider);
                    },
                  )
                : Builder(
                    builder: (context) {
                      final visibleProjects =
                          projects ?? const <ProjectModel>[];
                      final project = visibleProjects.isEmpty
                          ? null
                          : visibleProjects.first;
                      final actions = latestActions ?? _lastActions ?? [];
                      final authorizedProjectIds = visibleProjects
                          .map((project) => project.id)
                          .toSet();
                      final clientPendingActions =
                          actions
                              .where(
                                (action) =>
                                    action.assignedTo == 'client' &&
                                    action.visibleToClient &&
                                    action.status == 'pending' &&
                                    authorizedProjectIds.contains(
                                      action.projectId,
                                    ),
                              )
                              .toList()
                            ..sort(_compareClientActions);
                      final documentRequests =
                          latestDocumentRequests ??
                          _lastDocumentRequests ??
                          const <DocumentRequestModel>[];
                      final missingDocumentRequests =
                          documentRequests
                              .where(
                                (request) =>
                                    authorizedProjectIds.contains(
                                      request.projectId,
                                    ) &&
                                    (request.isRequested || request.isRejected),
                              )
                              .toList()
                            ..sort(_compareDocumentRequests);
                      final displayedProgress = project?.progress;
                      final accountName =
                          (_lastAccount?.displayName.trim().isNotEmpty == true)
                          ? _lastAccount!.displayName.trim()
                          : 'client';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClientHeader(name: accountName),
                          const SizedBox(height: 20),
                          if (project == null)
                            const AppEmptyState(
                              icon: Icons.work_outline_rounded,
                              title: 'Aucun projet partagé',
                              description:
                                  'Les projets autorisés par votre prestataire apparaîtront ici.',
                            )
                          else ...[
                            _ProjectHero(
                              project: project,
                              progress: displayedProgress ?? project.progress,
                              onOpenProgress: () =>
                                  context.go('/client/progress'),
                            ),
                            const SizedBox(height: 16),
                            _ClientTodoSection(
                              actions: clientPendingActions,
                              projects: visibleProjects,
                            ),
                            const SizedBox(height: 20),
                            _ClientDocumentsSection(
                              requests: missingDocumentRequests,
                              onOpenDocuments: () =>
                                  context.go('/client/documents'),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour $name',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Votre suivi',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const AppNotificationBell(portal: NotificationPortal.client),
      ],
    );
  }
}

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({
    required this.project,
    required this.progress,
    required this.onOpenProgress,
  });

  final ProjectModel project;
  final double progress;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round().clamp(0, 100);
    final currentStep = project.currentStep.trim();
    final nextStep = project.nextStep.trim();
    final deadline = project.deadline.trim();
    final hasCurrentStep = currentStep.isNotEmpty;
    final hasNextStep = nextStep.isNotEmpty;

    return Material(
      color: ClientPortalColors.deep,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onOpenProgress,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (!AppTheme.isDark(context))
                BoxShadow(
                  color: ClientPortalColors.deep.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Projet principal',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'terminé',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  color: ClientPortalColors.cta,
                ),
              ),
              const SizedBox(height: 14),
              if (hasCurrentStep || hasNextStep) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ClientPortalColors.deepInnerSurface(),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      if (hasCurrentStep)
                        _ProjectStepRow(
                          label: 'Étape actuelle',
                          value: currentStep,
                          icon: Icons.play_arrow_rounded,
                        ),
                      if (hasCurrentStep && hasNextStep)
                        const SizedBox(height: 10),
                      if (hasNextStep)
                        _ProjectStepRow(
                          label: 'Prochaine étape',
                          value: deadline.isEmpty
                              ? nextStep
                              : '$nextStep • $deadline',
                          icon: Icons.flag_rounded,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ClientPortalColors.deep,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Voir le projet',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectStepRow extends StatelessWidget {
  const _ProjectStepRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClientDocumentsSection extends StatelessWidget {
  const _ClientDocumentsSection({
    required this.requests,
    required this.onOpenDocuments,
  });

  final List<DocumentRequestModel> requests;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final count = requests.length;
    final visibleRequests = requests.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ClientPortalColors.subtleIconSurface(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: ClientPortalColors.sage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documents à fournir',
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count == 0
                          ? 'Aucun document demandé'
                          : frPlural(
                              count,
                              'document encore demandé',
                              'documents encore demandés',
                            ),
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (visibleRequests.isEmpty)
            Text(
              'Aucun document à envoyer pour le moment.',
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            )
          else
            ...visibleRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentRequestPreviewTile(request: request),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenDocuments,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Voir tous les documents'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRequestPreviewTile extends StatelessWidget {
  const _DocumentRequestPreviewTile({required this.request});

  final DocumentRequestModel request;

  @override
  Widget build(BuildContext context) {
    final isRejected = request.isRejected;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Icon(
            isRejected
                ? Icons.error_outline_rounded
                : Icons.description_rounded,
            color: isRejected
                ? const Color(0xFFDC2626)
                : ClientPortalColors.sage,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (request.dueDate != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _dueDateLabel(request.dueDate!),
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

class _ClientTodoSection extends StatelessWidget {
  const _ClientTodoSection({required this.actions, required this.projects});

  final List<ClientActionModel> actions;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    final count = actions.length;
    final visibleActions = actions.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          if (!AppTheme.isDark(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ClientPortalColors.subtleIconSurface(),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: ClientPortalColors.sage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'À faire de votre côté',
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count == 0
                          ? 'Aucune action ne vous attend'
                          : '${frPlural(count, 'action', 'actions')} vous attend${count > 1 ? 'ent' : ''}',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (actions.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tout est à jour',
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Vous n'avez aucune action à réaliser pour le moment.",
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ],
            )
          else
            ...visibleActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClientActionTile(action: action, projects: projects),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientActionTile extends ConsumerWidget {
  const _ClientActionTile({required this.action, required this.projects});

  final ClientActionModel action;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectTitle = _projectTitleForAction(action, projects);
    final priorityColor = _priorityColor(action.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openClientAction(context, ref, action, projects),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.secondarySurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _actionTypeColor(
                        action.type,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _actionTypeIcon(action.type),
                      color: _actionTypeColor(action.type),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryTextColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _ClientActionTag(
                    icon: Icons.flag_rounded,
                    label: _priorityLabel(action.priority),
                    color: priorityColor,
                  ),
                  if (action.dueDate != null)
                    _ClientActionTag(
                      icon: Icons.event_rounded,
                      label: _dueDateLabel(action.dueDate!),
                      color: _isOverdue(action.dueDate!)
                          ? const Color(0xFFDC2626)
                          : ClientPortalColors.sage,
                    ),
                  _ClientActionTag(
                    icon: Icons.work_rounded,
                    label: projectTitle,
                    color: AppTheme.secondaryTextColor(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _ctaLabelForType(action.type),
                  style: const TextStyle(
                    color: ClientPortalColors.deep,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientActionTag extends StatelessWidget {
  const _ClientActionTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
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
      ),
    );
  }
}

class _ClientLoadingView extends StatelessWidget {
  const _ClientLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LoadingBar(width: 150, height: 18),
        const SizedBox(height: 10),
        const _LoadingBar(width: 220, height: 34),
        const SizedBox(height: 22),
        Container(
          height: 178,
          decoration: BoxDecoration(
            color: ClientPortalColors.softSurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: _LoadingCard()),
            SizedBox(width: 12),
            Expanded(child: _LoadingCard()),
          ],
        ),
        const SizedBox(height: 20),
        const _LoadingBar(width: 120, height: 22),
        const SizedBox(height: 12),
        const _LoadingTile(),
        const SizedBox(height: 10),
        const _LoadingTile(),
      ],
    );
  }
}

class _ClientErrorView extends StatelessWidget {
  const _ClientErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Espace indisponible',
      description:
          'Impossible de charger votre espace client pour le moment. Vérifiez votre connexion puis réessayez.',
      onRetry: onRetry,
    );
  }
}

int _compareClientActions(ClientActionModel a, ClientActionModel b) {
  final overdueCompare = _overdueRank(b).compareTo(_overdueRank(a));
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

int _overdueRank(ClientActionModel action) {
  final dueDate = action.dueDate;
  if (dueDate == null) return 0;
  return _isOverdue(dueDate) ? 1 : 0;
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

int _compareDocumentRequests(DocumentRequestModel a, DocumentRequestModel b) {
  final statusCompare = _documentRequestRank(
    b,
  ).compareTo(_documentRequestRank(a));
  if (statusCompare != 0) return statusCompare;

  final aDate = a.dueDate ?? DateTime(9999);
  final bDate = b.dueDate ?? DateTime(9999);
  final dateCompare = aDate.compareTo(bDate);
  if (dateCompare != 0) return dateCompare;

  return a.title.compareTo(b.title);
}

int _documentRequestRank(DocumentRequestModel request) {
  if (request.isRejected) return 2;
  if (request.isRequested) return 1;
  return 0;
}

bool _isOverdue(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(date.year, date.month, date.day);
  return dueDay.isBefore(today);
}

String _formatActionDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _dueDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(date.year, date.month, date.day);
  final delta = dueDay.difference(today).inDays;

  if (delta < 0) return 'En retard';
  if (delta == 0) return 'Aujourd’hui';
  if (delta == 1) return 'Demain';
  return _formatActionDate(date);
}

String _priorityLabel(String priority) {
  switch (priority) {
    case 'high':
      return 'Priorité haute';
    case 'low':
      return 'Priorité basse';
    default:
      return 'Priorité moyenne';
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'high':
      return const Color(0xFFDC2626);
    case 'low':
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFFD97706);
  }
}

IconData _actionTypeIcon(String type) {
  switch (type) {
    case 'validation':
      return Icons.verified_rounded;
    case 'document':
      return Icons.attach_file_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'information':
      return Icons.info_rounded;
    default:
      return Icons.bolt_rounded;
  }
}

Color _actionTypeColor(String type) {
  switch (type) {
    case 'validation':
      return const Color(0xFF7C3AED);
    case 'document':
      return const Color(0xFF2563EB);
    case 'task':
      return ClientPortalColors.sage;
    case 'information':
      return const Color(0xFFD97706);
    default:
      return ClientPortalColors.sage;
  }
}

String _ctaLabelForType(String type) {
  switch (type) {
    case 'validation':
      return 'Voir et valider';
    case 'document':
      return 'Envoyer le document';
    case 'task':
      return 'Voir l’action';
    case 'information':
      return 'Marquer comme lu';
    default:
      return 'Voir l’action';
  }
}

String _projectTitleForAction(
  ClientActionModel action,
  List<ProjectModel> projects,
) {
  for (final project in projects) {
    if (project.id == action.projectId) return project.title;
  }
  return 'Projet';
}

void _openClientAction(
  BuildContext context,
  WidgetRef ref,
  ClientActionModel action,
  List<ProjectModel> projects,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final projectTitle = _projectTitleForAction(action, projects);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _actionTypeColor(
                      action.type,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _actionTypeIcon(action.type),
                    color: _actionTypeColor(action.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ctaLabelForType(action.type),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              action.title,
              style: TextStyle(
                color: AppTheme.mainTextColor(sheetContext),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (action.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                action.description,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(sheetContext),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ClientActionTag(
                  icon: Icons.work_rounded,
                  label: projectTitle,
                  color: ClientPortalColors.sage,
                ),
                _ClientActionTag(
                  icon: Icons.flag_rounded,
                  label: _priorityLabel(action.priority),
                  color: _priorityColor(action.priority),
                ),
                if (action.dueDate != null)
                  _ClientActionTag(
                    icon: Icons.event_rounded,
                    label: _dueDateLabel(action.dueDate!),
                    color: _isOverdue(action.dueDate!)
                        ? const Color(0xFFDC2626)
                        : ClientPortalColors.sage,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  if (action.type == 'document') {
                    context.go('/client/documents');
                    return;
                  }
                  if (action.type == 'validation') {
                    context.go(_clientProjectValidationPath(action.projectId));
                    return;
                  }
                  if (action.type == 'task') {
                    await _completeClientAction(context, ref, action);
                    return;
                  }
                  if (action.type == 'information') {
                    await _completeClientAction(context, ref, action);
                  }
                },
                icon: Icon(
                  action.type == 'document'
                      ? Icons.folder_rounded
                      : action.type == 'validation'
                      ? Icons.verified_rounded
                      : Icons.check_rounded,
                ),
                label: Text(_primaryButtonLabelForType(action.type)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _primaryButtonLabelForType(String type) {
  switch (type) {
    case 'validation':
      return 'Voir et valider';
    case 'document':
      return 'Envoyer le document';
    case 'information':
      return 'Marquer comme lu';
    case 'task':
      return 'Marquer comme terminé';
    default:
      return 'Terminer l’action';
  }
}

Future<void> _completeClientAction(
  BuildContext context,
  WidgetRef ref,
  ClientActionModel action,
) async {
  try {
    await ref
        .read(clientPortalServiceProvider)
        .completeCurrentClientAction(action);
    ref.invalidate(clientHomeActionsProvider);
    ref.invalidate(clientHomeProjectsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Action terminée.')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible de terminer cette action.')),
    );
  }
}

String _clientProjectValidationPath(String projectId) {
  final encodedProjectId = Uri.encodeComponent(projectId);
  return '/client/projects/$encodedProjectId?tab=validations';
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
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
