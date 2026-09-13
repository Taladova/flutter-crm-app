import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/utils/saved_credentials.dart';
import '../../../core/widgets/deskly_logo.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/client_portal_providers.dart';

class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({super.key});

  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isLoading = false;
  bool rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await loadSavedCredentials(scope: 'client');
    if (saved == null || !mounted) return;

    setState(() {
      emailController.text = saved.email;
      passwordController.text = saved.password;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Merci de saisir votre adresse e-mail et votre mot de passe.',
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ref.read(authServiceProvider).login(email, password);
      final role = await ref.read(authServiceProvider).currentUserRole();

      if (!mounted) return;
      if (role != 'client') {
        await ref.read(authServiceProvider).logout();
        _showMessage(
          'Ce compte n’est pas un compte client. Utilisez l’espace pro.',
        );
        return;
      }

      if (rememberMe) {
        await saveCredentials(email, password, scope: 'client');
      } else {
        await clearSavedCredentials(scope: 'client');
      }

      ref.invalidate(clientAccountProvider);
      ref.invalidate(clientPortalProjectsProvider);
      ref.invalidate(clientPortalActionsProvider);
      ref.invalidate(clientPortalMessagesProvider);
      ref.invalidate(clientPortalDocumentsProvider);

      if (!mounted) return;
      context.go('/client/home');
    } on FirebaseAuthException catch (error) {
      _showMessage(_authMessage(error.code));
    } catch (error) {
      _showMessage('Connexion client impossible : $error');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _authMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Adresse e-mail ou mot de passe incorrect.';
      default:
        return 'Impossible de se connecter.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 34),
              _ClientField(
                controller: emailController,
                label: 'Adresse e-mail',
                hint: 'votre@email.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _ClientField(
                controller: passwordController,
                label: 'Mot de passe',
                hint: 'Votre mot de passe',
                icon: Icons.lock_rounded,
                obscureText: !isPasswordVisible,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => isPasswordVisible = !isPasswordVisible);
                  },
                  icon: Icon(
                    isPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppTheme.secondaryTextColor(context),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  setState(() {
                    rememberMe = !rememberMe;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: (value) {
                          setState(() {
                            rememberMe = value ?? true;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Se souvenir de moi',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text('Me connecter à mon espace client'),
                ),
              ),
              const SizedBox(height: 22),
              _ClientActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go('/role-choice'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.mainTextColor(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const DesklyLogo(size: 58),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Espace client',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour suivre votre projet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClientActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Text(
            'Vous n’avez pas encore d’espace client ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/client/invite'),
              child: const Text('Créer mon espace avec un code'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/track'),
              child: const Text('J’ai seulement un code de suivi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientField extends StatelessWidget {
  const _ClientField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.secondaryTextColor(context)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.cardColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
