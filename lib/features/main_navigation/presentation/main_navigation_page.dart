import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../clients/presentation/clients_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../messages/presentation/messages_page.dart';
import '../../projects/presentation/projects_page.dart';
import '../../tasks/presentation/tasks_page.dart';

class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  late int currentIndex = widget.initialIndex.clamp(0, 4);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _pulseKey = GlobalKey();
  final _actionsKey = GlobalKey();

  @override
  void didUpdateWidget(MainNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialIndex != oldWidget.initialIndex) {
      currentIndex = widget.initialIndex.clamp(0, 4);
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userDisplayNameProvider).value ?? 'Utilisateur';
    final userEmail =
        ref.watch(firebaseAuthProvider).currentUser?.email ?? 'Compte Deskly';

    final pages = [
      DashboardPage(
        pulseKey: _pulseKey,
        actionsKey: _actionsKey,
        openDrawer: _openDrawer,
      ),
      const ClientsPage(),
      const ProjectsPage(),
      const TasksPage(),
      const MessagesPage(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(userName: userName, userEmail: userEmail),
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 10),
          child: NavigationBar(
            selectedIndex: currentIndex,
            height: 72,
            elevation: 0,
            backgroundColor: AppTheme.cardColor(context),
            indicatorColor: AppTheme.primary(context).withValues(alpha: 0.12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded),
                label: 'Clients',
              ),
              NavigationDestination(
                icon: Icon(Icons.work_outline_rounded),
                selectedIcon: Icon(Icons.work_rounded),
                label: 'Projets',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist_rounded),
                label: 'Tâches',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Messages',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
