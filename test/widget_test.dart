import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clientflow_pro/features/splash/presentation/splash_page.dart';

void main() {
  testWidgets('SplashPage affiche le logo de l\'application', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashPage()),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/main', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
}
