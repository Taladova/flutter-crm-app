import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import 'client_portal_theme.dart';
import 'client_documents_page.dart';
import 'client_home_page.dart';
import 'client_messages_page.dart';
import 'client_profile_page.dart';
import 'client_progress_page.dart';

class ClientNavigationPage extends StatelessWidget {
  const ClientNavigationPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  static const paths = [
    '/client/home',
    '/client/progress',
    '/client/messages',
    '/client/documents',
    '/client/profile',
  ];

  static const pages = [
    ClientHomePage(),
    ClientProgressPage(),
    ClientMessagesPage(),
    ClientDocumentsPage(),
    ClientProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = initialIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == currentIndex) return;
          context.go(paths[index]);
        },
        backgroundColor: AppTheme.cardColor(context),
        indicatorColor: ClientPortalColors.softSurface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'Avancement',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
