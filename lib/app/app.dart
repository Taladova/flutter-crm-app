import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

class ClientFlowApp extends ConsumerWidget {
  const ClientFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeModeProvider);
    final themeMode = themeModeAsync.value ?? ThemeMode.light;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ClientFlow Pro',
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
