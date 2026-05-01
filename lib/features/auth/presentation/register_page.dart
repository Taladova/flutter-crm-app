import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../providers/auth_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage('Merci de remplir tous les champs.');
      return;
    }

    if (password.length < 6) {
      showMessage('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await ref
          .read(authServiceProvider)
          .register(
            name: nameController.text.trim(),
            email: email,
            password: password,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Compte créé avec succès.')));

      context.go('/main');
    } on FirebaseAuthException catch (error) {
      showMessage(getFirebaseErrorMessage(error.code));
    } catch (_) {
      showMessage('Une erreur est survenue.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Mot de passe trop faible.';
      default:
        return 'Impossible de créer le compte.';
    }
  }

  void showMessage(String message) {
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
              _buildHeader(context),
              const SizedBox(height: 42),
              _buildForm(),
              const SizedBox(height: 28),
              _buildRegisterButton(),
              const SizedBox(height: 22),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Créer un compte',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Créez votre espace pour gérer vos clients, projets et tâches.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _InputField(
          controller: nameController,
          label: 'Nom complet',
          hint: 'Votre nom',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 18),
        _InputField(
          controller: emailController,
          label: 'Adresse email',
          hint: 'exemple@email.com',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _InputField(
          controller: passwordController,
          label: 'Mot de passe',
          hint: 'Minimum 6 caractères',
          icon: Icons.lock_rounded,
          obscureText: !isPasswordVisible,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                isPasswordVisible = !isPasswordVisible;
              });
            },
            icon: Icon(
              isPasswordVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppTheme.secondaryTextColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : register,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.cardColor(context),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? CircularProgressIndicator(color: AppTheme.cardColor(context))
            : const Text(
                'Créer mon compte',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text(
            'Vous avez déjà un compte ? ',
            style: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () {
              context.pop();
            },
            child: const Text(
              'Se connecter',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
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
          obscureText: obscureText,
          keyboardType: keyboardType,
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
            hintStyle: TextStyle(
              color: AppTheme.secondaryTextColor(context),
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
