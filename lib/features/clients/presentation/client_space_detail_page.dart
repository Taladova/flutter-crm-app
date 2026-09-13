import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/french_text.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/client_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../client_portal/providers/client_portal_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/client_providers.dart';
import 'client_portal_access_card.dart';

/// Manage one client's portal access. Reuses [ClientPortalAccessCard] — the
/// same client_invitations / client_accounts / shared_clients logic as the
/// client detail page's "Espace client" tab.
class ClientSpaceDetailPage extends ConsumerWidget {
  const ClientSpaceDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientByIdProvider(clientId));
    final projects = ref.watch(projectControllerProvider).value ?? [];

    if (client == null) {
      return Scaffold(
        backgroundColor: AppTheme.pageBackground(context),
        body: const SafeArea(child: Center(child: Text('Client introuvable'))),
      );
    }

    final sharedProjects = projects
        .where(
          (project) =>
              project.clientName.trim().toLowerCase() ==
              client.name.trim().toLowerCase(),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.borderColor(context),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppTheme.mainTextColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClientPortalAccessCard(client: client),
              const SizedBox(height: 18),
              _SectionTitle(
                title: frPlural(
                  sharedProjects.length,
                  'Projet partagé',
                  'Projets partagés',
                ),
              ),
              const SizedBox(height: 10),
              if (sharedProjects.isEmpty)
                _EmptyRow(
                  text: 'Aucun projet associé à ce client pour le moment.',
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: sharedProjects
                        .map(
                          (project) => ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.work_outline_rounded,
                              color: AppTheme.primary(context),
                            ),
                            title: Text(
                              project.title,
                              style: TextStyle(
                                color: AppTheme.mainTextColor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(project.status),
                            onTap: () =>
                                context.push('/projects/${project.id}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Dernière connexion'),
              const SizedBox(height: 10),
              _LastLoginRow(client: client),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastLoginRow extends ConsumerWidget {
  const _LastLoginRow({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    if (!client.isShared || uid == null) {
      return _EmptyRow(text: 'Non disponible — aucun accès actif.');
    }

    return FutureBuilder(
      future: ref
          .read(clientPortalServiceProvider)
          .findClientAccountFor(
            professionalId: uid,
            clientId: client.id,
            clientName: client.name,
            clientEmail: client.email,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _EmptyRow(text: 'Chargement…');
        }
        final account = snapshot.data;
        final lastLoginAt = account?.lastLoginAt;
        if (account == null || lastLoginAt == null) {
          return _EmptyRow(text: 'Le client ne s’est pas encore connecté.');
        }
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppTheme.primary(context)),
              const SizedBox(width: 10),
              Text(
                _formatLastLogin(lastLoginAt),
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.mainTextColor(context),
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.secondaryTextColor(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatLastLogin(DateTime date) {
  return '${date.day} ${_monthName(date.month)} ${date.year} à '
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _monthName(int month) {
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
  return months[month - 1];
}
