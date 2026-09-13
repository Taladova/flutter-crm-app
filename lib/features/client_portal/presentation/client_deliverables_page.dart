import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/utils/validation_file_opener.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../data/models/deliverable_annotation_model.dart';
import '../../../data/models/deliverable_model.dart';
import '../../../data/models/deliverable_version_model.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';
import 'widgets/client_deliverable_review_sheet.dart';

class ClientDeliverablesPage extends ConsumerWidget {
  const ClientDeliverablesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliverablesAsync = ref.watch(clientPortalDeliverablesProvider);
    final versionsAsync = ref.watch(clientPortalDeliverableVersionsProvider);
    final annotationsAsync = ref.watch(
      clientPortalDeliverableAnnotationsProvider,
    );

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: deliverablesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Validations indisponibles',
              description: 'Impossible de charger les livrables.',
            ),
            data: (deliverables) {
              final versions =
                  versionsAsync.value ?? const <DeliverableVersionModel>[];
              final annotations =
                  annotationsAsync.value ??
                  const <DeliverableAnnotationModel>[];
              final awaiting = deliverables
                  .where((deliverable) => deliverable.isAwaitingReview)
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClientDeliverablesHeader(
                    count: awaiting.length,
                    onBack: () => context.go('/client/home'),
                  ),
                  const SizedBox(height: 18),
                  if (deliverables.isEmpty)
                    const AppEmptyState(
                      icon: Icons.verified_rounded,
                      title: 'Aucun livrable',
                      description:
                          'Votre prestataire n’a pas encore envoyé de livrable à valider.',
                    )
                  else
                    ...deliverables.map((deliverable) {
                      final deliverableVersions =
                          versions
                              .where(
                                (version) =>
                                    version.deliverableId == deliverable.id,
                              )
                              .toList()
                            ..sort(
                              (a, b) =>
                                  b.versionNumber.compareTo(a.versionNumber),
                            );
                      final currentVersion = deliverableVersions.isEmpty
                          ? null
                          : deliverableVersions.first;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ClientDeliverableCard(
                          deliverable: deliverable,
                          version: currentVersion,
                          annotations: currentVersion == null
                              ? const <DeliverableAnnotationModel>[]
                              : annotations
                                    .where(
                                      (annotation) =>
                                          annotation.deliverableVersionId ==
                                          currentVersion.id,
                                    )
                                    .toList(),
                          onApprove:
                              currentVersion == null ||
                                  !deliverable.isAwaitingReview
                              ? null
                              : () => _reviewDeliverable(
                                  context,
                                  ref,
                                  deliverable,
                                  currentVersion,
                                  approved: true,
                                ),
                          onChanges:
                              currentVersion == null ||
                                  !deliverable.isAwaitingReview
                              ? null
                              : () => _reviewDeliverable(
                                  context,
                                  ref,
                                  deliverable,
                                  currentVersion,
                                  approved: false,
                                ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _reviewDeliverable(
    BuildContext context,
    WidgetRef ref,
    DeliverableModel deliverable,
    DeliverableVersionModel version, {
    required bool approved,
  }) async {
    final service = ref.read(clientPortalServiceProvider);
    final comment = await showClientDeliverableReviewSheet(
      context: context,
      approved: approved,
    );
    if (comment == null) return;

    try {
      await service.reviewDeliverableVersion(
        deliverable: deliverable,
        version: version,
        approved: approved,
        comment: comment,
      );
    } catch (error) {
      // ignore: avoid_print
      print('[validation][client][review-error] $error');
    }
  }
}

class _ClientDeliverablesHeader extends StatelessWidget {
  const _ClientDeliverablesHeader({required this.count, required this.onBack});

  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Validations',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            _CountBadge(count: count),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          count == 0
              ? 'Aucun livrable n’attend votre retour.'
              : '${frPlural(count, 'livrable attend', 'livrables attendent')} votre validation.',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ClientDeliverableCard extends StatelessWidget {
  const _ClientDeliverableCard({
    required this.deliverable,
    required this.version,
    required this.annotations,
    required this.onApprove,
    required this.onChanges,
  });

  final DeliverableModel deliverable;
  final DeliverableVersionModel? version;
  final List<DeliverableAnnotationModel> annotations;
  final VoidCallback? onApprove;
  final VoidCallback? onChanges;

  @override
  Widget build(BuildContext context) {
    final currentVersion = version;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor(
                    deliverable.status,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _kindIcon(deliverable.kind),
                  color: _statusColor(deliverable.status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deliverable.title,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        'V${deliverable.currentVersion}',
                        _statusLabel(deliverable.status),
                        if (_deliverableDate(deliverable, currentVersion)
                            case final date?)
                          _formatDeliverableDate(date),
                      ].join(' · '),
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (deliverable.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              deliverable.description,
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
          if (currentVersion != null) ...[
            const SizedBox(height: 14),
            _VersionPreview(
              deliverable: deliverable,
              version: currentVersion,
              annotations: annotations,
              canAnnotate: deliverable.isAwaitingReview,
            ),
          ],
          if (currentVersion?.clientComment?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ClientCommentBox(comment: currentVersion!.clientComment!),
          ],
          if (currentVersion == null ||
              currentVersion.previewUrl.trim().isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Aucun fichier associé',
              style: TextStyle(
                color: AppTheme.secondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (currentVersion != null &&
                  currentVersion.previewUrl.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openValidationVersionFile(
                      context: context,
                      deliverable: deliverable,
                      version: currentVersion,
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(validationOpenLabel(currentVersion)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChanges,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Valider'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionPreview extends ConsumerWidget {
  const _VersionPreview({
    required this.deliverable,
    required this.version,
    required this.annotations,
    required this.canAnnotate,
  });

  final DeliverableModel deliverable;
  final DeliverableVersionModel version;
  final List<DeliverableAnnotationModel> annotations;
  final bool canAnnotate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = version.previewUrl;
    final isImage = version.mimeType.startsWith('image/');

    if (url.isEmpty) {
      return _PreviewShell(
        icon: Icons.insert_drive_file_rounded,
        title: version.fileName,
        subtitle: 'Aucun aperçu disponible',
      );
    }

    if (isImage) {
      return _AnnotatableImagePreview(
        url: url,
        fileName: version.fileName,
        annotations: annotations,
        canAnnotate: canAnnotate,
        onAddAnnotation: (x, y) async {
          final comment = await _askAnnotationComment(context);
          if (comment == null || comment.trim().isEmpty) return;

          await ref
              .read(clientPortalServiceProvider)
              .addDeliverableAnnotation(
                deliverable: deliverable,
                version: version,
                x: x,
                y: y,
                comment: comment.trim(),
              );
          ref.invalidate(clientPortalDeliverableAnnotationsProvider);
        },
      );
    }

    if (version.mimeType == 'application/pdf') {
      return Column(
        children: [
          _PreviewShell(
            icon: Icons.picture_as_pdf_rounded,
            title: version.fileName,
            subtitle:
                'Ouvrir le PDF. Les annotations visuelles PDF arriveront plus tard.',
            onOpen: () => _openUrl(url),
          ),
          const SizedBox(height: 8),
          _PdfLimitationNotice(),
        ],
      );
    }

    return _PreviewShell(
      icon: Icons.open_in_new_rounded,
      title: version.fileName,
      subtitle: 'Ouvrir le livrable',
      onOpen: () => _openUrl(url),
    );
  }
}

class _AnnotatableImagePreview extends StatelessWidget {
  const _AnnotatableImagePreview({
    required this.url,
    required this.fileName,
    required this.annotations,
    required this.canAnnotate,
    required this.onAddAnnotation,
  });

  final String url;
  final String fileName;
  final List<DeliverableAnnotationModel> annotations;
  final bool canAnnotate;
  final Future<void> Function(double x, double y) onAddAnnotation;

  @override
  Widget build(BuildContext context) {
    final orderedAnnotations = [...annotations]
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1900);
        final bDate = b.createdAt ?? DateTime(1900);
        return aDate.compareTo(bDate);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: canAnnotate
                      ? (details) {
                          final x =
                              details.localPosition.dx / constraints.maxWidth;
                          final y =
                              details.localPosition.dy / constraints.maxHeight;
                          onAddAnnotation(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
                        }
                      : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _PreviewShell(
                          icon: Icons.broken_image_rounded,
                          title: fileName,
                          subtitle: 'Impossible d’afficher l’image',
                          onOpen: () => _openUrl(url),
                        ),
                      ),
                      ...orderedAnnotations.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final annotation = entry.value;
                        return Positioned(
                          left: annotation.x * constraints.maxWidth - 14,
                          top: annotation.y * constraints.maxHeight - 14,
                          child: _AnnotationMarker(
                            number: index,
                            resolved: annotation.resolved,
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          canAnnotate
              ? 'Touchez l’image pour ajouter un marqueur.'
              : 'Annotations de cette version.',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (orderedAnnotations.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...orderedAnnotations.asMap().entries.map(
            (entry) => _AnnotationCommentRow(
              number: entry.key + 1,
              annotation: entry.value,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnnotationMarker extends StatelessWidget {
  const _AnnotationMarker({required this.number, required this.resolved});

  final int number;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: resolved ? ClientPortalColors.cta : ClientPortalColors.sage,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AnnotationCommentRow extends StatelessWidget {
  const _AnnotationCommentRow({required this.number, required this.annotation});

  final int number;
  final DeliverableAnnotationModel annotation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnnotationMarker(number: number, resolved: annotation.resolved),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              annotation.comment,
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfLimitationNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Pour les PDF, utilisez le commentaire de demande de modification. '
      'Les marqueurs par page seront ajoutés avec un viewer PDF dédié.',
      style: TextStyle(
        color: AppTheme.secondaryTextColor(context),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onOpen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.pageBackground(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: ClientPortalColors.sage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.mainTextColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onOpen != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ClientCommentBox extends StatelessWidget {
  const _ClientCommentBox({required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        comment,
        style: const TextStyle(
          color: Color(0xFF92400E),
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ClientPortalColors.subtleIconSurface(),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: ClientPortalColors.sage,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

Future<String?> _askAnnotationComment(BuildContext context) async {
  final controller = TextEditingController();
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
              'Ajouter une annotation',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                hintText: 'Ex : Le bouton doit être plus visible',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(sheetContext, true);
                },
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Ajouter le marqueur'),
              ),
            ),
          ],
        ),
      );
    },
  );

  final comment = controller.text.trim();
  controller.dispose();
  return confirmed == true ? comment : null;
}

DateTime? _deliverableDate(
  DeliverableModel deliverable,
  DeliverableVersionModel? version,
) {
  return version?.uploadedAt ?? deliverable.updatedAt ?? deliverable.createdAt;
}

String _formatDeliverableDate(DateTime date) {
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

String _statusLabel(String status) {
  switch (status) {
    case 'approved':
      return 'Validé';
    case 'changesRequested':
      return 'Modifications demandées';
    default:
      return 'En attente de validation';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'approved':
      return const Color(0xFF16A34A);
    case 'changesRequested':
      return const Color(0xFFD97706);
    default:
      return ClientPortalColors.sage;
  }
}

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'image':
      return Icons.image_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'url':
      return Icons.link_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}
