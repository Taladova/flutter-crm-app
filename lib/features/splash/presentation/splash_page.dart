import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/onboarding_prefs.dart';
import '../../auth/providers/auth_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  double _opacity = 0;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1);
    });
    _redirect();
  }

  Future<void> _redirect() async {
    final seenOnboarding = await hasSeenOnboarding();
    var role = 'guest';
    try {
      final currentUser = ref.read(firebaseAuthProvider).currentUser;
      if (currentUser != null) {
        role = await ref.read(authServiceProvider).currentUserRole();
      }
    } catch (_) {
      role = 'guest';
    }
    if (!mounted) return;

    _redirectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (role == 'client') {
        context.go('/client/home');
        return;
      }
      if (role == 'professional') {
        context.go('/main');
        return;
      }
      context.go(seenOnboarding ? '/role-choice' : '/onboarding');
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.pageBackground(context),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: MediaQuery.sizeOf(context).height * 0.34,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardColor : AppTheme.midnight,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppTheme.borderColor(context),
                        ),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: AppTheme.midnight.withValues(alpha: 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/splash_logo.png',
                            width: 230,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Gérez. Organisez. Réussissez.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: const [
                              Expanded(
                                child: _SplashFeature(
                                  icon: Icons.group_rounded,
                                  label: 'Clients',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _SplashFeature(
                                  icon: Icons.folder_rounded,
                                  label: 'Projets',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _SplashFeature(
                                  icon: Icons.task_alt_rounded,
                                  label: 'Suivi',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _LoadingStatus(),
                    const Spacer(),
                    Text(
                      'Deskly',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashFeature extends StatelessWidget {
  const _SplashFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStatus extends StatelessWidget {
  const _LoadingStatus();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor,
            ),
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Préparation de votre espace',
          style: TextStyle(
            color: AppTheme.secondaryTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
