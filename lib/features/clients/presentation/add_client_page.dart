import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/client_model.dart';
import '../providers/client_providers.dart';

class AddClientPage extends ConsumerStatefulWidget {
  const AddClientPage({super.key, this.clientId});

  final String? clientId;

  bool get isEditing => clientId != null;

  @override
  ConsumerState<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends ConsumerState<AddClientPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final companyController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String selectedStatus = 'Prospect';
  int existingProjectsCount = 0;

  final List<String> statuses = const [
    'Prospect',
    'Actif',
    'En attente',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.clientId != null) {
      final client = ref.read(clientByIdProvider(widget.clientId!));

      if (client != null) {
        nameController.text = client.name;
        companyController.text = client.company;
        emailController.text = client.email;
        phoneController.text = client.phone;
        selectedStatus = client.status;
        existingProjectsCount = client.projectsCount;
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    companyController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submitForm() async {
    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    final client = ClientModel(
      id: widget.clientId ?? 'client_${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text.trim(),
      company: companyController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim(),
      projectsCount: existingProjectsCount,
      status: selectedStatus,
    );

    if (widget.isEditing) {
      await ref.read(clientControllerProvider.notifier).updateClient(client);
    } else {
      await ref.read(clientControllerProvider.notifier).addClient(client);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Client mis à jour avec succès.'
              : 'Client ajouté avec succès.',
        ),
      ),
    );

    if (widget.isEditing) {
      context.pop();
    } else {
      context.go('/clients');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddClientHeader(
                  onBack: () => context.pop(),
                  title: widget.isEditing ? 'Modifier le client' : 'Nouveau client',
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Informations client'),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _AppTextField(
                        controller: nameController,
                        label: 'Nom du client',
                        hint: 'Ex : Stelito',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: companyController,
                        label: 'Entreprise',
                        hint: 'Ex : Mobilier & décoration',
                        icon: Icons.business_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L’entreprise est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: emailController,
                        label: 'Email',
                        hint: 'contact@email.fr',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L’email est obligatoire';
                          }

                          if (!value.contains('@')) {
                            return 'Email invalide';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: phoneController,
                        label: 'Téléphone',
                        hint: '+33 6 12 34 56 78',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le téléphone est obligatoire';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Statut'),
                const SizedBox(height: 14),
                _StatusSelector(
                  statuses: statuses,
                  selectedStatus: selectedStatus,
                  onChanged: (status) {
                    setState(() {
                      selectedStatus = status;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      widget.isEditing ? 'Enregistrer' : 'Ajouter le client',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddClientHeader extends StatelessWidget {
  const _AddClientHeader({
    required this.onBack,
    required this.title,
  });

  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppTheme.borderColor(context),
              ),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppTheme.isDark(context)
        ? const Color(0xFF000B27)
        : const Color(0xFFF8FAFC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          validator: validator,
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              color: AppTheme.secondaryTextColor(context),
            ),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            hintStyle: TextStyle(
              color: AppTheme.secondaryTextColor(context).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            errorStyle: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppTheme.borderColor(context),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppTheme.borderColor(context),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.statuses,
    required this.selectedStatus,
    required this.onChanged,
  });

  final List<String> statuses;
  final String selectedStatus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: statuses.map((status) {
          final isSelected = selectedStatus == status;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.isDark(context)
                          ? const Color(0xFF000B27)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor(context),
                  ),
                ),
                child: Center(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}