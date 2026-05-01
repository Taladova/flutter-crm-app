import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/project_model.dart';
import '../providers/project_providers.dart';

class AddProjectPage extends ConsumerStatefulWidget {
  const AddProjectPage({
    super.key,
    this.clientName,
  });

  final String? clientName;

  @override
  ConsumerState<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends ConsumerState<AddProjectPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final clientController = TextEditingController();
  final typeController = TextEditingController();
  final budgetController = TextEditingController();
  final deadlineController = TextEditingController();

  String selectedStatus = 'Planifié';

  final List<String> statuses = const [
    'Planifié',
    'En cours',
    'Maquette',
    'Validation',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.clientName != null) {
      clientController.text = widget.clientName!;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    clientController.dispose();
    typeController.dispose();
    budgetController.dispose();
    deadlineController.dispose();
    super.dispose();
  }

  Future<void> submitForm() async {
    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    final newProject = ProjectModel(
      id: 'project_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      clientName: clientController.text.trim(),
      type: typeController.text.trim(),
      status: selectedStatus,
      budget: budgetController.text.trim(),
      deadline: deadlineController.text.trim(),
      progress: selectedStatus == 'En cours' ? 0.15 : 0.0,
    );

    await ref.read(projectControllerProvider.notifier).addProject(newProject);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Projet ajouté avec succès.'),
      ),
    );

    context.go('/projects');
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
                _AddProjectHeader(
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Informations projet'),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _AppTextField(
                        controller: titleController,
                        label: 'Nom du projet',
                        hint: 'Ex : Site e-commerce Stelito',
                        icon: Icons.work_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom du projet est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: clientController,
                        label: 'Client',
                        hint: 'Ex : Stelito',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le client est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: typeController,
                        label: 'Type de projet',
                        hint: 'Ex : WordPress / WooCommerce',
                        icon: Icons.category_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le type est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: budgetController,
                        label: 'Budget',
                        hint: 'Ex : 1500€',
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le budget est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _AppTextField(
                        controller: deadlineController,
                        label: 'Deadline',
                        hint: 'Ex : 30 mai 2026',
                        icon: Icons.event_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La deadline est obligatoire';
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
                    child: const Text(
                      'Ajouter le projet',
                      style: TextStyle(
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

class _AddProjectHeader extends StatelessWidget {
  const _AddProjectHeader({
    required this.onBack,
  });

  final VoidCallback onBack;

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
            'Nouveau projet',
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
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
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
              color: AppTheme.secondaryTextColor(context).withOpacity(0.7),
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
      child: Column(
        children: statuses.asMap().entries.map((entry) {
          final index = entry.key;
          final status = entry.value;
          final isSelected = selectedStatus == status;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == statuses.length - 1 ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: () => onChanged(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
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
                      fontSize: 13,
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