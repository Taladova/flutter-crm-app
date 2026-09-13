import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../data/models/deliverable_model.dart';
import '../../data/models/deliverable_version_model.dart';

String validationOpenLabel(DeliverableVersionModel? version) {
  if (version == null || version.previewUrl.trim().isEmpty) {
    return 'Aucun fichier associé';
  }
  if (version.storageUrl.trim().isEmpty &&
      version.externalUrl.trim().isNotEmpty) {
    return 'Ouvrir le lien';
  }
  return 'Voir le document';
}

Future<void> openValidationVersionFile({
  required BuildContext context,
  required DeliverableModel deliverable,
  required DeliverableVersionModel version,
}) async {
  final url = version.previewUrl.trim();
  // ignore: avoid_print
  print(
    '[validation][open]\n'
    'validationId=${deliverable.id}\n'
    'versionId=${version.id}\n'
    'fileName=${version.fileName}\n'
    'mimeType=${version.mimeType}\n'
    'downloadUrlPresent=${version.storageUrl.trim().isNotEmpty}\n'
    'storagePath=\n'
    'externalUrl=${version.externalUrl}',
  );

  if (url.isEmpty) return;

  if (version.mimeType.startsWith('image/')) {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _ValidationImagePreviewPage(
          imageUrl: url,
          title: version.fileName.isEmpty
              ? deliverable.title
              : version.fileName,
        ),
      ),
    );
    return;
  }

  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class _ValidationImagePreviewPage extends StatelessWidget {
  const _ValidationImagePreviewPage({
    required this.imageUrl,
    required this.title,
  });

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, _, _) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossible d’afficher ce document.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
