import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clientflow_pro/features/splash/presentation/splash_page.dart';

void main() {
  testWidgets('SplashPage affiche le nom et le slogan de l\'application', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.text('ClientFlow Pro'), findsOneWidget);
    expect(
      find.textContaining('Gérez vos clients'),
      findsOneWidget,
    );
  });
}
