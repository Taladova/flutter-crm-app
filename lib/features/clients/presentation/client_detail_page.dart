import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/currency_text.dart';
import '../../../core/utils/french_text.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/client_document_model.dart';
import '../../../data/models/client_note_model.dart';
import '../../../data/models/document_request_model.dart';
import '../providers/client_providers.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_filter_tabs.dart';
import '../../projects/providers/project_providers.dart';
import '../../../data/models/project_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../documents/providers/document_request_providers.dart';
import 'client_portal_access_card.dart';

class ClientDetailPage extends ConsumerStatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage> {
  String selectedTab = 'Vue d’ensemble';

  static const tabs = [
    'Vue d’ensemble',
    'Projets',
    'Documents',
    'Espace client',
  ];

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientByIdProvider(widget.clientId));
    final projectsAsync = ref.watch(projectControllerProvider);
    final actions = ref.watch(projectActionControllerProvider).value ?? [];
    final pendingActionsCount = client == null
        ? 0
        : actions
              .where(
                (action) =>
                    action.clientId == client.id && action.status == 'pending',
              )
              .length;
    final clientProjects = client == null
        ? const <ProjectModel>[]
        : (projectsAsync.value ?? const <ProjectModel>[])
              .where((project) => _projectBelongsToClient(project, client))
              .toList();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: client == null
            ? const Center(child: Text('Client introuvable'))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailHeader(
                      client: client,
                      onEdit: () => context.push('/clients/${client.id}/edit'),
                      onDelete: () => _confirmDelete(context, ref, client),
                    ),
                    const SizedBox(height: 16),
                    _ClientCompactInfo(client: client),
                    const SizedBox(height: 18),
                    AppFilterTabs(
                      labels: tabs,
                      selectedLabel: selectedTab,
                      onSelected: (tab) => setState(() => selectedTab = tab),
                    ),
                    const SizedBox(height: 20),
                    _ClientTabContent(
                      selectedTab: selectedTab,
                      client: client,
                      projectsAsync: projectsAsync,
                      clientProjects: clientProjects,
                      pendingActionsCount: pendingActionsCount,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ClientTabContent extends ConsumerWidget {
  const _ClientTabContent({
    required this.selectedTab,
    required this.client,
    required this.projectsAsync,
    required this.clientProjects,
    required this.pendingActionsCount,
  });

  final String selectedTab;
  final ClientModel client;
  final AsyncValue<List<ProjectModel>> projectsAsync;
  final List<ProjectModel> clientProjects;
  final int pendingActionsCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (selectedTab) {
      case 'Projets':
        return _ClientProjectsTab(
          client: client,
          projectsAsync: projectsAsync,
          clientProjects: clientProjects,
        );
      case 'Documents':
        return _ClientDocumentsCard(client: client);
      case 'Espace client':
        return _ClientPortalTab(client: client);
      default:
        return _ClientOverviewTab(
          client: client,
          clientProjects: clientProjects,
          pendingActionsCount: pendingActionsCount,
        );
    }
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ClientModel client,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer ce client ?'),
      content: Text(
        'Cette action supprimera définitivement "${client.name}". Elle est irréversible.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Supprimer',
            style: TextStyle(color: Color(0xFFDC2626)),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(clientControllerProvider.notifier).deleteClient(client.id);

  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Client supprimé.')));

  context.pop();
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.client,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientModel client;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Détail client',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(client.name, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Plus d’options',
          icon: Icon(
            Icons.more_horiz_rounded,
            color: AppTheme.mainTextColor(context),
          ),
          color: AppTheme.cardColor(context),
          onSelected: (value) async {
            if (value == 'edit') {
              onEdit();
              return;
            }
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: _HeaderMenuItem(
                icon: Icons.edit_rounded,
                label: 'Modifier le client',
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: _HeaderMenuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer le client',
                isDestructive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderMenuItem extends StatelessWidget {
  const _HeaderMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppTheme.errorColor
        : AppTheme.mainTextColor(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ClientCompactInfo extends StatelessWidget {
  const _ClientCompactInfo({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.company.isEmpty ? 'Coordonnées' : client.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Informations de contact',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(status: client.status),
            ],
          ),
          const SizedBox(height: 12),
          if (client.email.isNotEmpty)
            _CompactContactLine(icon: Icons.email_rounded, value: client.email),
          if (client.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CompactContactLine(icon: Icons.phone_rounded, value: client.phone),
          ],
        ],
      ),
    );
  }
}

class _CompactContactLine extends StatelessWidget {
  const _CompactContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.secondaryTextColor(context), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientOverviewTab extends StatelessWidget {
  const _ClientOverviewTab({
    required this.client,
    required this.clientProjects,
    required this.pendingActionsCount,
  });

  final ClientModel client;
  final List<ProjectModel> clientProjects;
  final int pendingActionsCount;

  @override
  Widget build(BuildContext context) {
    final totalBudget = _clientProjectsTotalBudget(clientProjects);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Résumé'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Statut', value: client.status),
              const SizedBox(height: 10),
              _SummaryRow(
                label: 'Projets',
                value: frPlural(clientProjects.length, 'projet', 'projets'),
              ),
              if (totalBudget > 0) ...[
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Valeur projets',
                  value: _formatClientBudget(totalBudget),
                ),
              ],
              if (pendingActionsCount > 0) ...[
                const SizedBox(height: 10),
                _SummaryRow(
                  label: 'Actions',
                  value:
                      '${frPlural(pendingActionsCount, 'action', 'actions')} en attente',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: _SectionTitle(title: 'Notes')),
            _AddNoteButton(client: client),
          ],
        ),
        const SizedBox(height: 10),
        _NotesCard(client: client),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientProjectsTab extends StatelessWidget {
  const _ClientProjectsTab({
    required this.client,
    required this.projectsAsync,
    required this.clientProjects,
  });

  final ClientModel client;
  final AsyncValue<List<ProjectModel>> projectsAsync;
  final List<ProjectModel> clientProjects;

  @override
  Widget build(BuildContext context) {
    return projectsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Erreur',
        description: 'Impossible de charger les projets du client.',
      ),
      data: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  title: 'Projets',
                  count: clientProjects.length,
                ),
              ),
              _CreateProjectButton(client: client),
            ],
          ),
          const SizedBox(height: 14),
          if (clientProjects.isEmpty)
            const AppEmptyState(
              icon: Icons.work_off_rounded,
              title: 'Aucun projet',
              description: 'Ce client n’a pas encore de projet associé.',
            )
          else
            _ClientProjects(projects: clientProjects),
        ],
      ),
    );
  }
}

class _ClientPortalTab extends StatelessWidget {
  const _ClientPortalTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Espace client'),
        const SizedBox(height: 8),
        Text(
          'Permettez à votre client de suivre ses projets, messages, documents et validations.',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ClientPortalAccessCard(client: client),
      ],
    );
  }
}

class _ClientDocumentsCard extends ConsumerWidget {
  const _ClientDocumentsCard({required this.client});

  final ClientModel client;

  Future<void> _sendDocument(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final pickerResult = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    final file = pickerResult?.files.single;
    if (file == null || file.bytes == null) return;

    final nameController = TextEditingController(text: file.name);
    final commentController = TextEditingController();

    if (!context.mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
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
              Text(
                'Envoyer un document',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Text(
                file.name,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(sheetContext),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom affiché'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Commentaire',
                  hintText: 'Ex: Document à consulter, version finale...',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Envoyer au client'),
                ),
              ),
            ],
          ),
        );
      },
    );

    final name = nameController.text.trim();
    final comment = commentController.text.trim();
    nameController.dispose();
    commentController.dispose();

    if (confirmed != true || name.isEmpty) return;

    try {
      await ref
          .read(clientPortalServiceProvider)
          .uploadProfessionalDocumentForClient(
            professionalId: uid,
            clientId: client.id,
            clientName: client.name,
            clientEmail: client.email,
            name: name,
            comment: comment,
            fileName: file.name,
            bytes: file.bytes!,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document envoyé au client.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’envoyer le document pour le moment.'),
        ),
      );
    }
  }

  Future<void> _createDocumentRequest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final projects = (ref.read(projectControllerProvider).value ?? [])
        .where((project) => project.clientName == client.name)
        .toList();
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Créez d’abord un projet pour ce client.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedProject = projects.first;
    var required = true;
    DateTime? dueDate;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demander un document',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ProjectModel>(
                      initialValue: selectedProject,
                      items: projects
                          .map(
                            (project) => DropdownMenuItem(
                              value: project,
                              child: Text(project.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedProject = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Projet'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Document demandé',
                        hintText: 'Ex : Logo HD, photos, mentions légales...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Ajoutez les consignes utiles au client.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: required,
                      onChanged: (value) =>
                          setSheetState(() => required = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Document obligatoire'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: sheetContext,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (selected != null) {
                          setSheetState(() => dueDate = selected);
                        }
                      },
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        dueDate == null
                            ? 'Ajouter une échéance'
                            : _formatDocumentRequestDate(dueDate!),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Créer la demande'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();

    if (confirmed != true || title.isEmpty) return;

    final requestId = 'doc_req_${DateTime.now().millisecondsSinceEpoch}';
    await ref
        .read(documentRequestControllerProvider.notifier)
        .addRequest(
          DocumentRequestModel(
            id: requestId,
            professionalUid: uid,
            clientId: client.id,
            projectId: selectedProject.id,
            title: title,
            description: description,
            status: 'requested',
            required: required,
            dueDate: dueDate,
          ),
        );
  }

  Future<void> _validateRequest(
    WidgetRef ref,
    DocumentRequestModel request,
  ) async {
    await ref
        .read(documentRequestControllerProvider.notifier)
        .updateRequest(request.copyWith(status: 'validated'));
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    DocumentRequestModel request,
  ) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser le document'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Commentaire requis',
            hintText: 'Expliquez ce qui doit être corrigé.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (comment == null || comment.isEmpty) return;
    await ref
        .read(documentRequestControllerProvider.notifier)
        .updateRequest(
          request.copyWith(
            status: 'rejected',
            rejectionComment: comment,
            clearUploadedDocumentId: true,
          ),
        );
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    ClientDocumentModel document,
  ) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text(
          'Le document "${document.name}" sera supprimé côté pro et côté client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(clientPortalServiceProvider)
        .deleteProfessionalDocument(
          document: document,
          professionalId: uid,
          clientId: client.id,
          clientName: client.name,
          clientEmail: client.email,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Document supprimé.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final requests = ref.watch(documentRequestsByClientProvider(client.id));
    final projects = (ref.watch(projectControllerProvider).value ?? [])
        .where((project) => project.clientName == client.name)
        .toList();
    final projectNames = {
      for (final project in projects) project.id: project.title,
    };

    return StreamBuilder<List<ClientDocumentModel>>(
      stream: ref
          .watch(clientPortalServiceProvider)
          .professionalDocumentsStream(
            professionalId: uid,
            clientId: client.id,
            clientName: client.name,
            clientEmail: client.email,
          ),
      builder: (context, snapshot) {
        final documents = snapshot.data ?? const <ClientDocumentModel>[];
        final receivedDocuments = documents
            .where((document) => document.uploadedBy == 'client')
            .toList();
        final sentDocuments = documents
            .where((document) => document.uploadedBy != 'client')
            .toList();
        final receivedDocumentsByRequestId = {
          for (final document in receivedDocuments)
            if (document.requestId.isNotEmpty) document.requestId: document,
        };
        final displayedRequests = requests.map((request) {
          final receivedDocument = receivedDocumentsByRequestId[request.id];
          if (receivedDocument == null ||
              request.isReceived ||
              request.isValidated) {
            return request;
          }
          return request.copyWith(
            status: 'received',
            uploadedDocumentId: receivedDocument.id,
            updatedAt: receivedDocument.updatedAt ?? receivedDocument.createdAt,
          );
        }).toList();
        var selectedTab = 'Reçus du client';

        return StatefulBuilder(
          builder: (context, setTabState) {
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
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Documents',
                              style: TextStyle(
                                color: AppTheme.mainTextColor(context),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Suivez les fichiers reçus et ceux envoyés au client.',
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DocumentActionButton(
                          icon: Icons.upload_file_rounded,
                          label: 'Envoyer un document',
                          filled: true,
                          onTap: () => _sendDocument(context, ref),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DocumentActionButton(
                          icon: Icons.add_task_rounded,
                          label: 'Demander un document',
                          onTap: () => _createDocumentRequest(context, ref),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppFilterTabs(
                    labels: const ['Reçus du client', 'Envoyés au client'],
                    selectedLabel: selectedTab,
                    counts: {
                      'Reçus du client': receivedDocuments.length,
                      'Envoyés au client': sentDocuments.length,
                    },
                    onSelected: (tab) => setTabState(() => selectedTab = tab),
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (selectedTab == 'Reçus du client') ...[
                    if (displayedRequests.isNotEmpty) ...[
                      _DocumentsSubheading(
                        title: 'Demandes de documents',
                        count: displayedRequests.length,
                      ),
                      const SizedBox(height: 8),
                      ...displayedRequests.map(
                        (request) => _DocumentRequestTile(
                          request: request,
                          projectName:
                              projectNames[request.projectId] ??
                              'Projet non renseigné',
                          onValidate: request.isReceived
                              ? () => _validateRequest(ref, request)
                              : null,
                          onReject: request.isReceived
                              ? () => _rejectRequest(context, ref, request)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (receivedDocuments.isEmpty)
                      _DocumentsEmptyState(
                        icon: Icons.move_to_inbox_rounded,
                        title: 'Aucun document reçu',
                        description:
                            'Les fichiers envoyés par ${client.name} apparaîtront ici.',
                      )
                    else ...[
                      _DocumentsSubheading(
                        title: 'Fichiers reçus',
                        count: receivedDocuments.length,
                      ),
                      const SizedBox(height: 8),
                      ...receivedDocuments.map(
                        (document) => _ProfessionalDocumentTile(
                          document: document,
                          clientName: client.name,
                          projectName:
                              projectNames[document.projectId] ??
                              'Projet non renseigné',
                          directionLabel: 'Reçu du client',
                          onDelete: () =>
                              _deleteDocument(context, ref, document),
                        ),
                      ),
                    ],
                  ] else if (sentDocuments.isEmpty)
                    const _DocumentsEmptyState(
                      icon: Icons.outbox_rounded,
                      title: 'Aucun document envoyé',
                      description:
                          'Envoyez un fichier au client pour le retrouver ici.',
                    )
                  else
                    ...sentDocuments.map(
                      (document) => _ProfessionalDocumentTile(
                        document: document,
                        clientName: client.name,
                        projectName:
                            projectNames[document.projectId] ??
                            'Projet non renseigné',
                        directionLabel: 'Envoyé au client',
                        onDelete: () => _deleteDocument(context, ref, document),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DocumentActionButton extends StatelessWidget {
  const _DocumentActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : AppTheme.primaryColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: filled
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
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

class _DocumentsSubheading extends StatelessWidget {
  const _DocumentsSubheading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DocumentsEmptyState extends StatelessWidget {
  const _DocumentsEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.secondaryTextColor(context), size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRequestTile extends StatelessWidget {
  const _DocumentRequestTile({
    required this.request,
    required this.projectName,
    required this.onValidate,
    required this.onReject,
  });

  final DocumentRequestModel request;
  final String projectName;
  final VoidCallback? onValidate;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final color = _documentRequestColor(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _documentRequestIcon(request.status),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${request.required ? 'Obligatoire' : 'Optionnel'} • $projectName'
                      '${request.dueDate == null ? '' : ' • ${_formatDocumentRequestDate(request.dueDate!)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _documentRequestLabel(request.status),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (request.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.description,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (request.rejectionComment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Refus : ${request.rejectionComment}',
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (onValidate != null || onReject != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onValidate,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfessionalDocumentTile extends StatelessWidget {
  const _ProfessionalDocumentTile({
    required this.document,
    required this.clientName,
    required this.projectName,
    required this.directionLabel,
    required this.onDelete,
  });

  final ClientDocumentModel document;
  final String clientName;
  final String projectName;
  final String directionLabel;
  final VoidCallback onDelete;

  Future<void> _open() async {
    if (document.url.isEmpty) return;
    await launchUrl(
      Uri.parse(document.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromClient = document.uploadedBy == 'client';
    final hasFile = document.url.isNotEmpty;
    final dateLabel = _formatDocumentDate(document.createdAt);
    final statusLabel = document.status.trim().isEmpty
        ? null
        : document.status.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: hasFile ? _open : null,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: fromClient
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : AppTheme.secondarySurface(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: fromClient
                    ? AppTheme.primaryColor.withValues(alpha: 0.18)
                    : AppTheme.borderColor(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      fromClient
                          ? Icons.download_done_rounded
                          : Icons.upload_file_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.mainTextColor(context),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$clientName • $projectName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _DocumentMetaChip(
                                icon: fromClient
                                    ? Icons.call_received_rounded
                                    : Icons.call_made_rounded,
                                label: directionLabel,
                              ),
                              _DocumentMetaChip(
                                icon: Icons.event_rounded,
                                label: dateLabel,
                              ),
                              if (statusLabel != null)
                                _DocumentMetaChip(
                                  icon: Icons.verified_rounded,
                                  label: statusLabel,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Supprimer',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                if (document.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    document.comment,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (hasFile)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _open,
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Ouvrir le document'),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: AppTheme.secondaryTextColor(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Aucun fichier joint à cet élément.',
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

class _DocumentMetaChip extends StatelessWidget {
  const _DocumentMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.secondaryTextColor(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateProjectButton extends StatelessWidget {
  const _CreateProjectButton({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Créer un projet pour ce client',
      visualDensity: VisualDensity.compact,
      onPressed: () {
        context.push(
          '/projects/add?client=${Uri.encodeComponent(client.name)}',
        );
      },
      icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
    );
  }
}

class _ClientProjects extends StatelessWidget {
  const _ClientProjects({required this.projects});

  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: projects
          .map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProjectMiniCard(project: project),
            ),
          )
          .toList(),
    );
  }
}

class _ProjectMiniCard extends StatelessWidget {
  const _ProjectMiniCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final progress = _normalizedProjectProgress(project.progress);
    final percent = _projectProgressPercent(project.progress);
    final hasDeadline = project.deadline.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/projects/${project.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.mainTextColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasDeadline
                              ? '${project.status} • Échéance ${project.deadline}'
                              : project.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryTextColor(context),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppTheme.borderColor(context),
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: AppTheme.mainTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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

class _AddNoteButton extends ConsumerWidget {
  const _AddNoteButton({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Ajouter une note',
      visualDensity: VisualDensity.compact,
      onPressed: () => _showNoteDialog(context, ref),
      icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
    );
  }

  Future<void> _showNoteDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _NoteDialog(title: 'Nouvelle note'),
    );

    if (result == null || result.trim().isEmpty) return;

    await ref
        .read(clientNoteControllerProvider.notifier)
        .addNote(
          ClientNoteModel(
            id: 'note_${DateTime.now().microsecondsSinceEpoch}',
            clientId: client.id,
            content: result.trim(),
          ),
        );
  }
}

class _NotesCard extends ConsumerWidget {
  const _NotesCard({required this.client});

  final ClientModel client;

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    ClientNoteModel note,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _NoteDialog(title: 'Modifier la note', initialValue: note.content),
    );

    if (result == null || result.trim().isEmpty) return;

    await ref
        .read(clientNoteControllerProvider.notifier)
        .updateNote(note.copyWith(content: result.trim()));
  }

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    ClientNoteModel note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        content: const Text('Cette action supprimera uniquement cette note.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(clientNoteControllerProvider.notifier).deleteNote(note.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(clientNoteControllerProvider);
    final notes = ref.watch(clientNotesByClientProvider(client.id));

    if (notes.isEmpty && client.notes.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(clientNoteControllerProvider.notifier)
            .migrateLegacyNote(client);
      });
    }

    if (notesState.isLoading && !notesState.hasValue) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (notesState.hasError) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Notes indisponibles',
        description: 'Impossible de charger les notes du client.',
        onRetry: () => ref.invalidate(clientNoteControllerProvider),
      );
    }

    if (notes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Text(
          'Aucune note',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      children: notes
          .map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoteListItem(
                note: note,
                onEdit: () => _editNote(context, ref, note),
                onDelete: () => _deleteNote(context, ref, note),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, this.initialValue = ''});

  final String title;
  final String initialValue;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Ajoutez une note sur ce client...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _NoteListItem extends StatelessWidget {
  const _NoteListItem({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientNoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notes_rounded,
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
                  note.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatNoteDate(note.updatedAt ?? note.createdAt),
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options de la note',
            icon: Icon(
              Icons.more_horiz_rounded,
              color: AppTheme.secondaryTextColor(context),
            ),
            color: AppTheme.cardColor(context),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

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
          _InlineCountBadge(count: count!),
        ],
      ],
    );
  }
}

class _InlineCountBadge extends StatelessWidget {
  const _InlineCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'Actif':
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        break;
      case 'En attente':
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        break;
      default:
        backgroundColor = const Color(0xFFEFF6FF);
        textColor = AppTheme.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

double _clientProjectsTotalBudget(List<ProjectModel> projects) {
  return projects.fold<double>(
    0,
    (total, project) => total + _parseClientBudgetAmount(project.budget),
  );
}

double _parseClientBudgetAmount(String budget) {
  final normalized = budget
      .toLowerCase()
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.k]'), '');
  if (normalized.isEmpty) return 0;

  final multiplier = normalized.contains('k') ? 1000 : 1;
  final number = double.tryParse(normalized.replaceAll('k', '')) ?? 0;
  return number * multiplier;
}

String _formatClientBudget(double amount) {
  return formatCurrencyAmount(amount);
}

bool _projectBelongsToClient(ProjectModel project, ClientModel client) {
  if (project.clientId.isNotEmpty) {
    return project.clientId == client.id;
  }

  return project.clientName.trim().toLowerCase() ==
      client.name.trim().toLowerCase();
}

int _projectProgressPercent(double progress) {
  return (_normalizedProjectProgress(progress) * 100).round();
}

double _normalizedProjectProgress(double progress) {
  final normalized = progress > 1 ? progress / 100 : progress;
  return normalized.clamp(0.0, 1.0);
}

String _formatNoteDate(DateTime? date) {
  if (date == null) return 'Date inconnue';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final noteDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(noteDay).inDays;

  if (diff == 0) {
    return 'Aujourd’hui à ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return 'Hier';

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDocumentRequestDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDocumentDate(DateTime? date) {
  if (date == null) return 'Date inconnue';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _documentRequestLabel(String status) {
  switch (status) {
    case 'received':
      return 'Reçu';
    case 'validated':
      return 'Validé';
    case 'rejected':
      return 'Refusé';
    default:
      return 'Demandé';
  }
}

IconData _documentRequestIcon(String status) {
  switch (status) {
    case 'received':
      return Icons.mark_email_read_rounded;
    case 'validated':
      return Icons.verified_rounded;
    case 'rejected':
      return Icons.error_rounded;
    default:
      return Icons.radio_button_unchecked_rounded;
  }
}

Color _documentRequestColor(String status) {
  switch (status) {
    case 'received':
      return const Color(0xFFD97706);
    case 'validated':
      return const Color(0xFF16A34A);
    case 'rejected':
      return const Color(0xFFDC2626);
    default:
      return AppTheme.primaryColor;
  }
}
