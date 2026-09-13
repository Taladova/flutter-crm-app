import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../providers/client_portal_providers.dart';

class ClientInvitePage extends ConsumerStatefulWidget {
  const ClientInvitePage({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<ClientInvitePage> createState() => _ClientInvitePageState();
}

class _ClientInvitePageState extends ConsumerState<ClientInvitePage> {
  final tokenController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? error;

  void _goBackToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/role-choice');
    }
  }

  @override
  void initState() {
    super.initState();
    tokenController.text = widget.initialToken ?? '';
  }

  @override
  void dispose() {
    tokenController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccess() async {
    final token = tokenController.text.trim().toUpperCase();
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if ([token, name, email, password].any((value) => value.isEmpty)) {
      setState(() => error = 'Merci de remplir tous les champs.');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      await ref
          .read(clientPortalServiceProvider)
          .registerFromInvitation(
            token: token,
            name: name,
            email: email,
            password: password,
          );
      if (!mounted) return;
      ref.invalidate(clientAccountProvider);
      ref.invalidate(clientPortalProjectsProvider);
      ref.invalidate(clientPortalActionsProvider);
      ref.invalidate(clientPortalMessagesProvider);
      ref.invalidate(clientPortalDocumentsProvider);
      context.go('/client/home');
    } on FirebaseAuthException catch (exception) {
      setState(() => error = _authMessage(exception.code));
    } catch (exception) {
      final message = exception.toString().replaceFirst('Bad state: ', '');
      setState(() {
        if (message.contains('Invitation invalide')) {
          error =
              'Code d’invitation introuvable ou expiré. Vérifiez le code reçu par votre prestataire, ou demandez-lui de générer une nouvelle invitation.';
        } else if (message.contains('permission-denied')) {
          error =
              'Impossible de créer votre espace avec ce code. Demandez à votre prestataire de générer une nouvelle invitation.';
        } else {
          error = message;
        }
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _authMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cette adresse e-mail.';
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      default:
        return 'Impossible de créer l’accès client.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _goBackToLogin,
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
              const SizedBox(height: 22),
              Text(
                'Créer votre compte client',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Vous avez reçu un code d’invitation. Créez un compte client avec votre adresse e-mail et un mot de passe pour accéder directement à votre espace Deskly.',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _InviteField(
                controller: tokenController,
                label: 'Code d’invitation',
                hint: 'Code reçu par votre prestataire',
                icon: Icons.vpn_key_rounded,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              _InviteField(
                controller: nameController,
                label: 'Nom',
                hint: 'Votre nom',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),
              _InviteField(
                controller: emailController,
                label: 'Adresse e-mail du compte',
                hint: 'Votre adresse e-mail',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _InviteField(
                controller: passwordController,
                label: 'Créer un mot de passe',
                hint: 'Choisissez un mot de passe',
                icon: Icons.lock_rounded,
                obscureText: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createAccess,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text('Créer mon accès client'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/track'),
                  child: const Text('Utiliser seulement le suivi par code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteField extends StatelessWidget {
  const _InviteField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: AppTheme.mainTextColor(context),
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.secondaryTextColor(context)),
        filled: true,
        fillColor: AppTheme.cardColor(context),
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
    );
  }
}
