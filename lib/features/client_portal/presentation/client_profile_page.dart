import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../data/models/client_account_model.dart';
import '../../../data/models/project_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/client_portal_providers.dart';
import 'client_portal_theme.dart';

/// [client-profile] state-management notes:
/// - accountAsync / projectsAsync are cached in State (_lastAccount /
///   _lastProjects) so a background refresh (the underlying providers are
///   shared with Accueil/Avancement and can re-emit at any time) never
///   blanks the page with a full-screen spinner — only the very first load,
///   before any value has ever arrived, does.
/// - Each section (profile card / projects list / professional name) tracks
///   its own loading state independently; none of them can block the others.
/// - clientHomeProjectsProvider is the SAME shared project provider used by
///   Accueil/Avancement — no second, independent project read here.
class ClientProfilePage extends ConsumerStatefulWidget {
  const ClientProfilePage({super.key});

  @override
  ConsumerState<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends ConsumerState<ClientProfilePage> {
  ClientAccountModel? _lastAccount;
  List<ProjectModel>? _lastProjects;

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(clientAccountProvider);
    final projectsAsync = ref.watch(clientHomeProjectsProvider);

    if (accountAsync.value != null) _lastAccount = accountAsync.value;
    if (projectsAsync.value != null) _lastProjects = projectsAsync.value;

    final account = accountAsync.value ?? _lastAccount;
    final projects = projectsAsync.value ?? _lastProjects;

    // TEMP DIAGNOSTIC LOG — see clientflow_pro "Profil client" loading audit.
    // ignore: avoid_print
    print(
      '[client-profile] build\n'
      '[client-profile] account state=${_asyncStateLabel(accountAsync)}\n'
      '[client-profile] projects state=${_asyncStateLabel(projectsAsync)}',
    );

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: ClientPortalColors.subtleIconSurface(),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: ClientPortalColors.sage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Profil',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Profile section: renders as soon as any account value exists
              // (fresh or cached) — a background refresh never blanks it.
              if (account != null)
                _ProfileCard(
                  name: account.displayName.isEmpty
                      ? 'Client'
                      : account.displayName,
                  email: account.email,
                  professionalId: account.professionalId,
                )
              else if (accountAsync.hasError)
                const Text('Impossible de charger le profil.')
              else
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              // Projects section: independent loading state, never blocks
              // the rest of the page.
              _CountedTitle(
                title: 'Projets accessibles',
                count: projects?.length ?? 0,
              ),
              const SizedBox(height: 12),
              if (projects != null)
                projects.isEmpty
                    ? Text(
                        'Aucun projet accessible',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: projects
                            .map((project) => _ProjectAccessTile(project))
                            .toList(),
                      )
              else if (projectsAsync.hasError)
                const Text('Impossible de charger les projets.')
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authServiceProvider).logout();
                    if (context.mounted) context.go('/client/login');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Déconnexion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _asyncStateLabel(AsyncValue<Object?> value) {
  if (value.hasError) return 'error';
  if (value.isLoading) {
    return value.hasValue ? 'loading (keeping previous value)' : 'loading';
  }
  return 'data';
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.professionalId,
  });

  final String name;
  final String email;
  final String professionalId;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'C'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: ClientPortalColors.subtleIconSurface(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: ClientPortalColors.deep,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.mainTextColor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.pageBackground(context),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: ClientPortalColors.sage,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Espace client connecté',
                        style: TextStyle(
                          color: AppTheme.mainTextColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _ProfessionalLinkLabel(professionalId: professionalId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolves the linked professional's name without ever showing a spinner:
/// a neutral label is shown immediately and upgraded in place once the name
/// resolves, and the last resolved name is kept during any background
/// refresh instead of reverting to the neutral label.
class _ProfessionalLinkLabel extends ConsumerStatefulWidget {
  const _ProfessionalLinkLabel({required this.professionalId});

  final String professionalId;

  @override
  ConsumerState<_ProfessionalLinkLabel> createState() =>
      _ProfessionalLinkLabelState();
}

class _ProfessionalLinkLabelState
    extends ConsumerState<_ProfessionalLinkLabel> {
  String? _lastName;

  @override
  Widget build(BuildContext context) {
    String label;

    if (widget.professionalId.isEmpty) {
      label = 'Professionnel associé';
      // ignore: avoid_print
      print('[client-profile] professional state=n/a (no professionalId)');
    } else {
      final nameAsync = ref.watch(
        clientPortalProfessionalNameProvider(widget.professionalId),
      );
      if (nameAsync.value != null) _lastName = nameAsync.value;
      final name = nameAsync.value ?? _lastName;

      // ignore: avoid_print
      print(
        '[client-profile] professional state=${_asyncStateLabel(nameAsync)}',
      );

      label = name == null ? 'Accès sécurisé à votre projet' : 'Lié à $name';
    }

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppTheme.secondaryTextColor(context),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ProjectAccessTile extends StatelessWidget {
  const _ProjectAccessTile(this.project);

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final title = project.title.trim().isEmpty
        ? 'Projet partagé'
        : project.title.trim();
    final subtitleParts = [
      if (project.type.trim().isNotEmpty) project.type.trim(),
      project.status.trim().isEmpty
          ? 'Suivi disponible'
          : project.status.trim(),
      '${(project.progress * 100).round().clamp(0, 100)} %',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: () => context.push('/client/projects/${project.id}'),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ClientPortalColors.softSurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.work_rounded,
                    color: ClientPortalColors.sage,
                    size: 20,
                  ),
                ),
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
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' • '),
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
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountedTitle extends StatelessWidget {
  const _CountedTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Container(
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
        ),
      ],
    );
  }
}
