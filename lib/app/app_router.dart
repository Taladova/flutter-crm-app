import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
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

const _publicRoutes = ['/', '/onboarding', '/login', '/register', '/track'];

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

final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(
    ref.watch(authServiceProvider).authStateChanges,
  );

  ref.onDispose(refreshStream.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final isLoggedIn = ref.read(firebaseAuthProvider).currentUser != null;
      final isPublicRoute = _publicRoutes.contains(state.matchedLocation);

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }

      if (isLoggedIn &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/register')) {
        return '/main';
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
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return MainNavigationPage(initialIndex: tab);
        },
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
            child: ClientDetailPage(clientId: clientId),
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
            child: ProjectDetailPage(projectId: projectId),
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
    ],
  );

  return router;
});
