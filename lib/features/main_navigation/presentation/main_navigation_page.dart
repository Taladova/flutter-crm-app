import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../clients/presentation/clients_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../projects/presentation/projects_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../tasks/presentation/tasks_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    DashboardPage(),
    ClientsPage(),
    ProjectsPage(),
    TasksPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          border: const Border(
            top: BorderSide(
              color: Color(0xFFE2E8F0),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          height: 72,
          elevation: 0,
          backgroundColor: AppTheme.cardColor(context),
          indicatorColor: AppTheme.primaryColor.withOpacity(0.12),
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
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Réglages',
            ),
          ],
        ),
      ),
    );
  }
}