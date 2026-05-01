import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/providers/firestore_providers.dart';

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth.currentUser;

    if (user == null) {
      return ThemeMode.light;
    }

    final doc = await ref
        .watch(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('preferences')
        .get();

    final data = doc.data();
    final theme = data?['themeMode'];

    if (theme == 'dark') {
      return ThemeMode.dark;
    }

    return ThemeMode.light;
  }

  Future<void> toggleTheme(bool isDark) async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;

    final newTheme = isDark ? ThemeMode.dark : ThemeMode.light;

    state = AsyncValue.data(newTheme);

    if (user == null) return;

    await ref
        .read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('preferences')
        .set({
      'themeMode': isDark ? 'dark' : 'light',
    }, SetOptions(merge: true));
  }
}