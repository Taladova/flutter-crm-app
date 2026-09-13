import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_role_theme.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/role_choice_page.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/main_navigation/presentation/main_navigation_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/splash/presentation/splash_page.dart';
import '../features/clients/presentation/client_detail_page.dart';
import '../features/projects/presentation/project_detail_page.dart';
import '../features/clients/presentation/add_client_page.dart';
import '../features/projects/presentation/add_project_page.dart';
import '../features/tasks/presentation/add_task_page.dart';
import '../features/tasks/presentation/task_detail_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/settings/presentation/legal_page.dart';
import '../features/tracking/presentation/track_project_page.dart';
import '../features/projects/presentation/client_space_page.dart';
import '../features/clients/presentation/client_spaces_page.dart';
import '../features/clients/presentation/client_space_detail_page.dart';
import '../features/clients/presentation/client_chat_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/client_portal/presentation/client_invite_page.dart';
import '../features/client_portal/presentation/client_login_page.dart';
import '../features/client_portal/presentation/client_navigation_page.dart';
import '../features/client_portal/presentation/client_deliverables_page.dart';
import '../features/client_portal/presentation/client_project_detail_page.dart';

const _publicRoutes = [
  '/',
  '/onboarding',
  '/role-choice',
  '/login',
  '/register',
  '/track',
  '/client/login',
  '/client/invite',
];

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

CustomTransitionPage<T> buildSlideTransitionPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(curvedAnimation);

      final fadeAnimation = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}

/// Applies the Pro visual identity (see AppRoleTheme.professional) to one
/// of the main professional pages — structure, navigation and logic are
/// untouched, only the Theme this subtree resolves via Theme.of(context)
/// changes. Scoped to Dashboard/Clients/Projets/Tâches/Messages (via
/// MainNavigationPage), Détail client, Détail projet, and Espaces clients.
Widget _proThemed(Widget child) {
  return Theme(data: AppRoleTheme.professional.themeData, child: child);
}

/// Same principle as [_proThemed], for the client portal's main pages
/// (Accueil/Avancement/Messages/Documents/Profil via ClientNavigationPage,
/// Validations, and client-side Détail projet).
Widget _clientThemed(Widget child) {
  return Theme(data: AppRoleTheme.client.themeData, child: child);
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(
    ref.watch(authServiceProvider).authStateChanges,
  );

  ref.onDispose(refreshStream.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refreshStream,
    redirect: (context, state) async {
      final isLoggedIn = ref.read(firebaseAuthProvider).currentUser != null;
      final isPublicRoute = _publicRoutes.contains(state.matchedLocation);

      if (!isLoggedIn && !isPublicRoute) {
        if (state.matchedLocation == '/client' ||
            state.matchedLocation.startsWith('/client/')) {
          return '/client/login';
        }
        return '/login';
      }

      if (isLoggedIn &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/register')) {
        final role = await ref.read(authServiceProvider).currentUserRole();
        return role == 'client' ? '/client/home' : '/main';
      }

      if (isLoggedIn) {
        final role = await ref.read(authServiceProvider).currentUserRole();
        if (state.matchedLocation == '/' ||
            state.matchedLocation == '/role-choice' ||
            state.matchedLocation == '/onboarding') {
          return role == 'client' ? '/client/home' : '/main';
        }

        final isClientRoute =
            (state.matchedLocation == '/client' ||
                state.matchedLocation.startsWith('/client/')) &&
            state.matchedLocation != '/client/login' &&
            state.matchedLocation != '/client/invite';
        final isProfessionalRoute = !isClientRoute && !isPublicRoute;

        if (role == 'client' && isProfessionalRoute) {
          return '/client/home';
        }

        // Professional users may preview the client portal from invitations.
        // More importantly, newly-created client accounts must not be bounced
        // back to /main while Firestore role data is still settling.
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/role-choice',
        name: 'roleChoice',
        builder: (context, state) => const RoleChoicePage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return _proThemed(MainNavigationPage(initialIndex: tab));
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const SettingsPage(),
          );
        },
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        builder: (context, state) =>
            _proThemed(const MainNavigationPage(initialIndex: 4)),
      ),
      GoRoute(
        path: '/clients/add',
        name: 'addClient',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const AddClientPage(),
          );
        },
      ),
      GoRoute(
        path: '/clients/:clientId',
        name: 'clientDetail',
        pageBuilder: (context, state) {
          final clientId = state.pathParameters['clientId']!;

          return buildSlideTransitionPage(
            state: state,
            child: _proThemed(ClientDetailPage(clientId: clientId)),
          );
        },
      ),
      GoRoute(
        path: '/clients/:clientId/chat',
        name: 'clientChat',
        pageBuilder: (context, state) {
          final clientId = state.pathParameters['clientId']!;

          return buildSlideTransitionPage(
            state: state,
            child: ClientChatPage(clientId: clientId),
          );
        },
      ),
      GoRoute(
        path: '/clients/:clientId/edit',
        name: 'editClient',
        pageBuilder: (context, state) {
          final clientId = state.pathParameters['clientId']!;

          return buildSlideTransitionPage(
            state: state,
            child: AddClientPage(clientId: clientId),
          );
        },
      ),
      GoRoute(
        path: '/projects/add',
        name: 'addProject',
        pageBuilder: (context, state) {
          final clientName = state.uri.queryParameters['client'];

          return buildSlideTransitionPage(
            state: state,
            child: AddProjectPage(clientName: clientName),
          );
        },
      ),
      GoRoute(
        path: '/projects/:projectId',
        name: 'projectDetail',
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId']!;

          return buildSlideTransitionPage(
            state: state,
            child: _proThemed(ProjectDetailPage(projectId: projectId)),
          );
        },
      ),
      GoRoute(
        path: '/projects/:projectId/edit',
        name: 'editProject',
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId']!;

          return buildSlideTransitionPage(
            state: state,
            child: AddProjectPage(projectId: projectId),
          );
        },
      ),
      GoRoute(
        path: '/tasks/add',
        name: 'addTask',
        pageBuilder: (context, state) {
          final projectId = state.uri.queryParameters['projectId'];
          final projectName = state.uri.queryParameters['projectName'];

          return buildSlideTransitionPage(
            state: state,
            child: AddTaskPage(projectId: projectId, projectName: projectName),
          );
        },
      ),
      GoRoute(
        path: '/tasks/:taskId',
        name: 'taskDetail',
        pageBuilder: (context, state) {
          final taskId = state.pathParameters['taskId']!;

          return buildSlideTransitionPage(
            state: state,
            child: TaskDetailPage(taskId: taskId),
          );
        },
      ),
      GoRoute(
        path: '/tasks/:taskId/edit',
        name: 'editTask',
        pageBuilder: (context, state) {
          final taskId = state.pathParameters['taskId']!;

          return buildSlideTransitionPage(
            state: state,
            child: AddTaskPage(taskId: taskId),
          );
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const RegisterPage(),
          );
        },
      ),
      GoRoute(
        path: '/legal',
        name: 'legal',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const LegalPage(),
          );
        },
      ),
      GoRoute(
        path: '/track',
        name: 'track',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const TrackProjectPage(),
          );
        },
      ),
      GoRoute(
        path: '/client-space',
        name: 'clientSpace',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const ClientSpacePage(),
          );
        },
      ),
      GoRoute(
        path: '/client-spaces',
        name: 'clientSpaces',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: _proThemed(const ClientSpacesPage()),
          );
        },
      ),
      GoRoute(
        path: '/client-spaces/:clientId',
        name: 'clientSpaceDetail',
        pageBuilder: (context, state) {
          final clientId = state.pathParameters['clientId']!;

          return buildSlideTransitionPage(
            state: state,
            child: _proThemed(ClientSpaceDetailPage(clientId: clientId)),
          );
        },
      ),
      GoRoute(
        path: '/client/invite',
        name: 'clientInvite',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['code'];
          return buildSlideTransitionPage(
            state: state,
            child: ClientInvitePage(initialToken: token),
          );
        },
      ),
      GoRoute(
        path: '/client/login',
        name: 'clientLogin',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: const ClientLoginPage(),
          );
        },
      ),
      GoRoute(path: '/client', redirect: (_, _) => '/client/home'),
      GoRoute(
        path: '/client/home',
        name: 'clientHome',
        builder: (context, state) => _clientThemed(
          const ClientNavigationPage(key: ValueKey('client-home')),
        ),
      ),
      GoRoute(
        path: '/client/progress',
        name: 'clientProgress',
        builder: (context, state) => _clientThemed(
          const ClientNavigationPage(
            key: ValueKey('client-progress'),
            initialIndex: 1,
          ),
        ),
      ),
      GoRoute(
        path: '/client/messages',
        name: 'clientMessages',
        builder: (context, state) => _clientThemed(
          const ClientNavigationPage(
            key: ValueKey('client-messages'),
            initialIndex: 2,
          ),
        ),
      ),
      GoRoute(
        path: '/client/documents',
        name: 'clientDocuments',
        builder: (context, state) => _clientThemed(
          const ClientNavigationPage(
            key: ValueKey('client-documents'),
            initialIndex: 3,
          ),
        ),
      ),
      GoRoute(
        path: '/client/validations',
        name: 'clientValidations',
        pageBuilder: (context, state) {
          return buildSlideTransitionPage(
            state: state,
            child: _clientThemed(const ClientDeliverablesPage()),
          );
        },
      ),
      GoRoute(
        path: '/client/projects/:projectId',
        name: 'clientProjectDetail',
        pageBuilder: (context, state) {
          final initialTabIndex =
              state.uri.queryParameters['tab'] == 'validations' ? 2 : 0;
          return buildSlideTransitionPage(
            state: state,
            child: _clientThemed(
              ClientProjectDetailPage(
                projectId: state.pathParameters['projectId'] ?? '',
                initialTabIndex: initialTabIndex,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/client/profile',
        name: 'clientProfile',
        builder: (context, state) => _clientThemed(
          const ClientNavigationPage(
            key: ValueKey('client-profile'),
            initialIndex: 4,
          ),
        ),
      ),
    ],
  );

  return router;
});
