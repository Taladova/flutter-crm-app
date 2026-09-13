import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/project_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/client_providers.dart';

/// Single source of truth for creating, displaying and revoking a client's
/// portal access (client_invitations / client_accounts / shared_clients).
/// Reused as-is by the client detail page's "Espace client" tab and by the
/// "Espaces clients" list's detail page — never duplicate this logic.
class ClientPortalAccessCard extends ConsumerWidget {
  const ClientPortalAccessCard({super.key, required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
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
                  color: AppTheme.primary(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  client.isShared
                      ? Icons.verified_user_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: AppTheme.primary(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  client.isShared ? 'Accès actif' : 'Aucun accès',
                  style: TextStyle(
                    color: AppTheme.mainTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (client.isShared)
                _PortalStatusBadge(
                  label: 'Actif',
                  color: AppTheme.primary(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            client.isShared
                ? 'Ce code est utilisé uniquement lors de la première connexion. Ensuite, le client retrouve directement son espace Deskly.'
                : 'Créez un code d’invitation pour permettre au client de créer son accès personnel.',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (client.isShared)
            _ActivePortalAccess(
              token: client.shareToken,
              onCopyCode: () =>
                  _copyAccessValue(context, 'Code copié', client.shareToken),
              onCopyLink: () => _copyAccessValue(
                context,
                'Lien copié',
                _invitationLink(client.shareToken),
              ),
              onRevoke: () => _revokeAccess(context, ref),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _createAccess(context, ref),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Créer l’accès'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createAccess(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final projects =
        ref
            .read(projectControllerProvider)
            .value
            ?.where((project) => project.clientName == client.name)
            .toList() ??
        <ProjectModel>[];

    try {
      final token = await ref
          .read(clientPortalServiceProvider)
          .createInvitation(
            professionalId: uid,
            client: client,
            projects: projects,
          );

      await ref
          .read(clientControllerProvider.notifier)
          .updateClient(client.copyWith(shareToken: token));

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Accès client créé.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer l’accès client.')),
      );
    }
  }

  Future<void> _copyAccessValue(
    BuildContext context,
    String label,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Future<void> _revokeAccess(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Révoquer l’accès ?'),
        content: const Text(
          'Le code d’invitation ne pourra plus être utilisé par ce client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Révoquer',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(clientPortalServiceProvider)
          .revokeInvitation(client.shareToken);
      await ref
          .read(clientControllerProvider.notifier)
          .updateClient(client.copyWith(shareToken: ''));

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Accès client révoqué.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de révoquer l’accès client.')),
      );
    }
  }
}

class _ActivePortalAccess extends StatelessWidget {
  const _ActivePortalAccess({
    required this.token,
    required this.onCopyCode,
    required this.onCopyLink,
    required this.onRevoke,
  });

  final String token;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.primary(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primary(context).withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            token,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.primary(context),
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopyCode,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copier le code'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopyLink,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Copier le lien'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRevoke,
          icon: const Icon(Icons.link_off_rounded, size: 18),
          label: const Text('Révoquer l’accès'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
        ),
      ],
    );
  }
}

class _PortalStatusBadge extends StatelessWidget {
  const _PortalStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _invitationLink(String token) => '/client/invite?code=$token';
