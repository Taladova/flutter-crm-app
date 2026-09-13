import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../data/models/client_document_model.dart';
import '../../../data/models/document_request_model.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';

class ClientDocumentsPage extends ConsumerWidget {
  const ClientDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(clientPortalDocumentsProvider);
    final requestsAsync = ref.watch(clientPortalDocumentRequestsProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: documentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Documents indisponibles',
              description: 'Impossible de charger les documents.',
            ),
            data: (documents) {
              final requests =
                  requestsAsync.value ?? const <DocumentRequestModel>[];
              final summary = DocumentPreparationSummary.fromRequests(requests);
              final hasDocuments = documents.isNotEmpty;
              final hasRequests = requests.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DocumentsHeader(
                    documentsCount: documents.length,
                    missingCount: summary.missingCount,
                    showAddButton: hasDocuments,
                    onAdd: () => _showAddDocumentSheet(context, ref),
                  ),
                  const SizedBox(height: 18),
                  if (hasRequests) ...[
                    _DocumentRequestsCard(
                      requests: requests,
                      summary: summary,
                      onUpload: (request) =>
                          _showAddDocumentSheet(context, ref, request: request),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (!hasDocuments && !hasRequests)
                    _EmptyDocumentsCard(
                      onAdd: () => _showAddDocumentSheet(context, ref),
                    )
                  else if (hasDocuments)
                    Column(
                      children: [
                        _Section(
                          title: 'À fournir',
                          documents: documents
                              .where(
                                (document) => document.status == 'À fournir',
                              )
                              .toList(),
                          onDelete: (document) =>
                              _confirmDeleteDocument(context, ref, document),
                        ),
                        _Section(
                          title: 'Envoyés',
                          documents: documents
                              .where((document) => document.status == 'Reçu')
                              .toList(),
                          onDelete: (document) =>
                              _confirmDeleteDocument(context, ref, document),
                        ),
                        _Section(
                          title: 'Validés',
                          documents: documents
                              .where((document) => document.status == 'Validé')
                              .toList(),
                          onDelete: (document) =>
                              _confirmDeleteDocument(context, ref, document),
                        ),
                        _Section(
                          title: 'Autres documents',
                          documents: documents
                              .where(
                                (document) =>
                                    document.status != 'À fournir' &&
                                    document.status != 'Reçu' &&
                                    document.status != 'Validé',
                              )
                              .toList(),
                          onDelete: (document) =>
                              _confirmDeleteDocument(context, ref, document),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDocumentSheet(
    BuildContext context,
    WidgetRef ref, {
    DocumentRequestModel? request,
  }) async {
    final nameController = TextEditingController(text: request?.title ?? '');
    final commentController = TextEditingController(
      text: request?.description ?? '',
    );
    PlatformFile? selectedFile;

    final result = await showModalBottomSheet<bool>(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ClientPortalColors.subtleIconSurface(),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: ClientPortalColors.sage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request == null
                                  ? 'Nouveau document'
                                  : 'Envoyer ${request.title}',
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              request == null
                                  ? 'Ajoutez un fichier et une note courte.'
                                  : 'Ce fichier répondra à la demande du prestataire.',
                              style: TextStyle(
                                color: AppTheme.secondaryTextColor(
                                  sheetContext,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController,
                    decoration: _sheetInputDecoration(
                      sheetContext,
                      icon: Icons.description_rounded,
                      labelText: 'Nom du document',
                      hintText: 'Ex: Logo, contrat, contenu page accueil...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _sheetInputDecoration(
                      sheetContext,
                      icon: Icons.notes_rounded,
                      labelText: 'Commentaire',
                      hintText: 'Ajoutez une précision pour votre prestataire',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FilePickerTile(
                    fileName: selectedFile?.name,
                    onPick: () async {
                      final result = await FilePicker.platform.pickFiles(
                        withData: true,
                        allowMultiple: false,
                      );
                      final file = result?.files.single;
                      if (file == null) return;
                      // ignore: avoid_print
                      print(
                        '[document-upload][client] step1 fichier sélectionné '
                        'fileName=${file.name} fileSize=${file.size}',
                      );
                      setSheetState(() => selectedFile = file);
                      if (nameController.text.trim().isEmpty) {
                        nameController.text = file.name;
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Envoyer au prestataire'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      commentController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final comment = commentController.text.trim();
    final file = selectedFile;
    nameController.dispose();
    commentController.dispose();

    if (name.isEmpty || file?.bytes == null) return;

    try {
      await ref
          .read(clientPortalServiceProvider)
          .uploadClientDocument(
            name: name,
            comment: comment,
            fileName: file!.name,
            bytes: file.bytes!,
            requestId: request?.id,
            projectId: request?.projectId,
          );
      ref.invalidate(clientPortalDocumentsProvider);
      ref.invalidate(clientPortalDocumentRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document envoyé au prestataire.')),
      );
    } on FirebaseException catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] UI catch — Impossible d\'envoyer\n'
        '  code=${e.code}\n'
        '  message=${e.message}\n'
        '  plugin=${e.plugin}\n'
        '  stackTrace=$stackTrace',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’envoyer le document pour le moment.'),
        ),
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print(
        '[document-upload][client] UI catch — Impossible d\'envoyer '
        '(non-Firebase) error=$e\n  stackTrace=$stackTrace',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’envoyer le document pour le moment.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteDocument(
    BuildContext context,
    WidgetRef ref,
    ClientDocumentModel document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text(
          'Le document "${document.name}" sera supprimé de votre espace client.',
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
        .deleteCurrentClientDocument(document);
    ref.invalidate(clientPortalDocumentsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Document supprimé.')));
  }
}

InputDecoration _sheetInputDecoration(
  BuildContext context, {
  required IconData icon,
  required String labelText,
  required String hintText,
}) {
  return InputDecoration(
    prefixIcon: Icon(icon, color: AppTheme.secondaryTextColor(context)),
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: AppTheme.pageBackground(context),
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
      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
    ),
  );
}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({required this.fileName, required this.onPick});

  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null && fileName!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasFile
                ? ClientPortalColors.softSurface
                : AppTheme.pageBackground(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasFile
                  ? ClientPortalColors.sage.withValues(alpha: 0.35)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  hasFile ? Icons.check_rounded : Icons.attach_file_rounded,
                  color: ClientPortalColors.sage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFile ? 'Fichier sélectionné' : 'Joindre un fichier',
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasFile ? fileName! : 'PDF, image ou document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondaryTextColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentRequestsCard extends StatelessWidget {
  const _DocumentRequestsCard({
    required this.requests,
    required this.summary,
    required this.onUpload,
  });

  final List<DocumentRequestModel> requests;
  final DocumentPreparationSummary summary;
  final ValueChanged<DocumentRequestModel> onUpload;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.progress * 100).round();

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
          Text(
            'Documents à fournir',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            frPlural(
              summary.missingCount,
              'document manquant',
              'documents manquants',
            ),
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: summary.progress,
                    minHeight: 9,
                    backgroundColor: ClientPortalColors.subtleIconSurface(),
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Préparation du projet, uniquement sur les documents requis.',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...requests.map(
            (request) => _DocumentRequestClientTile(
              request: request,
              onUpload: () => onUpload(request),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRequestClientTile extends StatelessWidget {
  const _DocumentRequestClientTile({
    required this.request,
    required this.onUpload,
  });

  final DocumentRequestModel request;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final canUpload = request.isRequested || request.isRejected;
    final color = _requestColor(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(_requestIcon(request.status), color: color),
          const SizedBox(width: 12),
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
                if (request.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (request.rejectionComment.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Correction demandée : ${request.rejectionComment}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          canUpload
              ? IconButton.filled(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file_rounded),
                )
              : Text(
                  _requestLabel(request.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ],
      ),
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({
    required this.documentsCount,
    required this.missingCount,
    required this.showAddButton,
    required this.onAdd,
  });

  final int documentsCount;
  final int missingCount;
  final bool showAddButton;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ClientPortalColors.subtleIconSurface(),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.folder_rounded,
              color: ClientPortalColors.sage,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Documents',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(count: documentsCount),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  missingCount > 0
                      ? '${frPlural(missingCount, 'document à fournir', 'documents à fournir')} à votre prestataire.'
                      : 'Fichiers reçus et envoyés avec votre prestataire.',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (showAddButton) ...[
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: onAdd,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDocumentsCard extends StatelessWidget {
  const _EmptyDocumentsCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: ClientPortalColors.softSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: ClientPortalColors.sage,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun document',
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier fichier pour le partager avec votre prestataire.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _AttachDocumentButton(onPressed: onAdd),
        ],
      ),
    );
  }
}

class _AttachDocumentButton extends StatelessWidget {
  const _AttachDocumentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.attach_file_rounded),
        label: const Text('Joindre un document'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.documents,
    required this.onDelete,
  });

  final String title;
  final List<ClientDocumentModel> documents;
  final ValueChanged<ClientDocumentModel> onDelete;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              _CountBadge(count: documents.length),
            ],
          ),
          const SizedBox(height: 12),
          ...documents.map(
            (document) => _DocumentTile(document: document, onDelete: onDelete),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onDelete});

  final ClientDocumentModel document;
  final ValueChanged<ClientDocumentModel> onDelete;

  Future<void> _open() async {
    if (document.url.isEmpty) return;
    await launchUrl(
      Uri.parse(document.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClientUpload = document.uploadedBy == 'client';
    final hasFile = document.url.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasFile ? _open : null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Icon(
                  isClientUpload
                      ? Icons.upload_file_rounded
                      : Icons.description_rounded,
                  color: ClientPortalColors.sage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (document.comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          document.comment,
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (!hasFile) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Aucun fichier joint',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => onDelete(document),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Supprimer',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                    ),
                    Text(
                      document.status,
                      style: const TextStyle(
                        color: ClientPortalColors.sage,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasFile) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _open,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Ouvrir'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _requestLabel(String status) {
  switch (status) {
    case 'received':
      return 'Envoyé';
    case 'validated':
      return 'Validé';
    case 'rejected':
      return 'À corriger';
    default:
      return 'À fournir';
  }
}

IconData _requestIcon(String status) {
  switch (status) {
    case 'received':
      return Icons.schedule_rounded;
    case 'validated':
      return Icons.check_circle_rounded;
    case 'rejected':
      return Icons.error_rounded;
    default:
      return Icons.radio_button_unchecked_rounded;
  }
}

Color _requestColor(String status) {
  switch (status) {
    case 'received':
      return const Color(0xFFD97706);
    case 'validated':
      return const Color(0xFF16A34A);
    case 'rejected':
      return const Color(0xFFDC2626);
    default:
      return ClientPortalColors.sage;
  }
}
