import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/project_template_model.dart';
import '../../../data/templates/project_templates.dart';
import '../../actions/providers/project_action_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../../documents/providers/document_request_providers.dart';
import '../providers/project_template_providers.dart';
import '../providers/project_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../../timeline/providers/timeline_providers.dart';

class AddProjectPage extends ConsumerStatefulWidget {
  const AddProjectPage({super.key, this.clientName, this.projectId});

  final String? clientName;
  final String? projectId;

  bool get isEditing => projectId != null;

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
  ProjectTemplateModel selectedTemplate = projectTemplates.first;
  double? existingProgress;

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

    if (widget.projectId != null) {
      final project = ref.read(projectByIdProvider(widget.projectId!));

      if (project != null) {
        titleController.text = project.title;
        clientController.text = project.clientName;
        typeController.text = project.type;
        budgetController.text = project.budget;
        deadlineController.text = project.deadline;
        selectedStatus = project.status;
        existingProgress = project.progress;
      }
    } else {
      typeController.text = selectedTemplate.projectType;
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

    final clients = ref.read(clientControllerProvider).value ?? [];
    final clientId = _clientIdFromName(clients, clientController.text.trim());

    final project = ProjectModel(
      id:
          widget.projectId ??
          'project_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      clientName: clientController.text.trim(),
      clientId: clientId,
      type: typeController.text.trim(),
      status: selectedStatus,
      budget: budgetController.text.trim(),
      deadline: deadlineController.text.trim(),
      progress: existingProgress ?? (selectedStatus == 'En cours' ? 0.15 : 0.0),
    );

    if (widget.isEditing) {
      await ref.read(projectControllerProvider.notifier).updateProject(project);
    } else if (!selectedTemplate.isCustom) {
      final confirmed = await _showTemplateSummary(context, selectedTemplate);
      if (confirmed != true) return;

      await ref
          .read(projectTemplateServiceProvider)
          .createProjectFromTemplate(
            project: project,
            template: selectedTemplate,
            clientId: clientId,
          );
      ref.invalidate(projectControllerProvider);
      ref.invalidate(taskControllerProvider);
      ref.invalidate(projectActionControllerProvider);
      ref.invalidate(documentRequestControllerProvider);
      ref.invalidate(timelineControllerProvider);
    } else {
      await ref.read(projectControllerProvider.notifier).addProject(project);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Projet mis à jour avec succès.'
              : 'Projet ajouté avec succès.',
        ),
      ),
    );

    if (widget.isEditing) {
      context.pop();
    } else {
      context.go('/main?tab=2');
    }
  }

  String _clientIdFromName(List<ClientModel> clients, String clientName) {
    for (final client in clients) {
      if (client.name == clientName) return client.id;
    }
    return clientName;
  }

  Future<bool?> _showTemplateSummary(
    BuildContext context,
    ProjectTemplateModel template,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deskly va préparer votre projet',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  template.name,
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor(sheetContext),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _TemplateSummaryRow(
                  icon: Icons.timeline_rounded,
                  label: 'étapes',
                  value: template.timeline.length,
                ),
                _TemplateSummaryRow(
                  icon: Icons.folder_rounded,
                  label: 'documents à fournir',
                  value: template.documentRequests.length,
                ),
                _TemplateSummaryRow(
                  icon: Icons.person_pin_circle_rounded,
                  label: 'actions client',
                  value: template.clientActions.length,
                ),
                _TemplateSummaryRow(
                  icon: Icons.task_alt_rounded,
                  label: 'tâches',
                  value: template.tasks.length,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showTemplateDetails(sheetContext, template),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Voir le détail'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('Créer le projet'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTemplateDetails(
    BuildContext context,
    ProjectTemplateModel template,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final hasDetails =
            template.timeline.isNotEmpty ||
            template.documentRequests.isNotEmpty ||
            template.clientActions.isNotEmpty ||
            template.tasks.isNotEmpty;

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor(sheetContext),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Détail du template',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.name,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(sheetContext),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!hasDetails)
                      _TemplateEmptyDetails(templateName: template.name)
                    else ...[
                      _TemplateDetailSection(
                        title: 'Étapes',
                        items: template.timeline
                            .map((step) => step.title)
                            .toList(),
                      ),
                      _TemplateDetailSection(
                        title: 'Documents à fournir',
                        items: template.documentRequests
                            .map((request) => request.title)
                            .toList(),
                      ),
                      _TemplateDetailSection(
                        title: 'Actions client',
                        items: template.clientActions
                            .map((action) => action.title)
                            .toList(),
                      ),
                      _TemplateDetailSection(
                        title: 'Tâches',
                        items: template.tasks
                            .map((task) => task.title)
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddProjectHeader(
                  onBack: () => context.pop(),
                  title: widget.isEditing
                      ? 'Modifier le projet'
                      : 'Nouveau projet',
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormCardHeader(
                        icon: Icons.work_rounded,
                        title: 'Informations projet',
                        subtitle: 'Client, budget et échéance',
                      ),
                      const SizedBox(height: 16),
                      if (!widget.isEditing) ...[
                        _TemplateSelector(
                          selectedTemplate: selectedTemplate,
                          onChanged: (template) {
                            setState(() {
                              selectedTemplate = template;
                              typeController.text = template.projectType;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
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
                      const SizedBox(height: 14),
                      clientsAsync.maybeWhen(
                        data: (clients) => clients.isEmpty
                            ? _ClientTextField(controller: clientController)
                            : _ClientSelectField(
                                clients: clients,
                                selectedClientName: clientController.text,
                                onChanged: (value) {
                                  setState(() {
                                    clientController.text = value;
                                  });
                                },
                              ),
                        orElse: () =>
                            _ClientTextField(controller: clientController),
                      ),
                      const SizedBox(height: 14),
                      _AppTextField(
                        controller: typeController,
                        label: 'Type de projet',
                        hint: 'Ex : WordPress / WooCommerce',
                        icon: Icons.category_rounded,
                        enabled: selectedTemplate.isCustom || widget.isEditing,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le type est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _AppTextField(
                        controller: budgetController,
                        label: 'Budget',
                        hint: 'Ex : 1500 €',
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le budget est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _AppTextField(
                        controller: deadlineController,
                        label: 'Échéance',
                        hint: 'Ex : 30 mai 2026',
                        icon: Icons.event_rounded,
                        readOnly: true,
                        onTap: () => _pickDeadlineDate(context),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L’échéance est obligatoire';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _StatusSelector(
                  statuses: statuses,
                  selectedStatus: selectedStatus,
                  onChanged: (status) {
                    setState(() {
                      selectedStatus = status;
                    });
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
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
                      widget.isEditing ? 'Enregistrer' : 'Ajouter le projet',
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

  Future<void> _pickDeadlineDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseFrenchDate(deadlineController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;
    setState(() {
      deadlineController.text = _formatFrenchDate(selected);
    });
  }
}

DateTime? _parseFrenchDate(String value) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _formatFrenchDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class _AddProjectHeader extends StatelessWidget {
  const _AddProjectHeader({required this.onBack, required this.title});

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
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.mainTextColor(context),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }
}

class _ClientTextField extends StatelessWidget {
  const _ClientTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _AppTextField(
      controller: controller,
      label: 'Client',
      hint: 'Ex : Stelito',
      icon: Icons.person_rounded,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le client est obligatoire';
        }
        return null;
      },
    );
  }
}

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({
    required this.selectedTemplate,
    required this.onChanged,
  });

  final ProjectTemplateModel selectedTemplate;
  final ValueChanged<ProjectTemplateModel> onChanged;

  @override
  Widget build(BuildContext context) {
    const visibleTemplateIds = {
      'website',
      'visual_identity',
      'mobile_app',
      'custom',
    };
    final visibleTemplates = projectTemplates
        .where((template) => visibleTemplateIds.contains(template.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quel type de projet créez-vous ?',
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visibleTemplates.map((template) {
            final isSelected = selectedTemplate.id == template.id;
            return GestureDetector(
              onTap: () => onChanged(template),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.secondarySurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor(context),
                  ),
                ),
                child: Text(
                  template.name,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.secondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TemplateSummaryRow extends StatelessWidget {
  const _TemplateSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.mainTextColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateDetailSection extends StatelessWidget {
  const _TemplateDetailSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.mainTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateEmptyDetails extends StatelessWidget {
  const _TemplateEmptyDetails({required this.templateName});

  final String templateName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondarySurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Text(
        '$templateName ne prépare aucun élément automatique. '
        'Vous pourrez créer vos étapes, documents, actions et tâches ensuite.',
        style: TextStyle(
          color: AppTheme.secondaryTextColor(context),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ClientSelectField extends StatelessWidget {
  const _ClientSelectField({
    required this.clients,
    required this.selectedClientName,
    required this.onChanged,
  });

  final List<ClientModel> clients;
  final String selectedClientName;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppTheme.secondarySurface(context);
    final clientNames = clients.map((client) => client.name).toSet().toList();
    final value = clientNames.contains(selectedClientName)
        ? selectedClientName
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client',
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: clientNames
              .map(
                (clientName) => DropdownMenuItem(
                  value: clientName,
                  child: Text(clientName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le client est obligatoire';
            }
            return null;
          },
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontWeight: FontWeight.w700,
          ),
          dropdownColor: AppTheme.cardColor(context),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Sélectionner un client',
            prefixIcon: Icon(
              Icons.person_rounded,
              color: AppTheme.secondaryTextColor(context),
            ),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            hintStyle: TextStyle(
              color: AppTheme.secondaryTextColor(
                context,
              ).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
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

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fieldColor = AppTheme.secondarySurface(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: AppTheme.mainTextColor(context),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            prefixIcon: onTap == null
                ? Icon(icon, color: AppTheme.secondaryTextColor(context))
                : IconButton(
                    onPressed: onTap,
                    icon: Icon(
                      icon,
                      color: AppTheme.secondaryTextColor(context),
                    ),
                  ),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            hintStyle: TextStyle(
              color: AppTheme.secondaryTextColor(
                context,
              ).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            errorStyle: const TextStyle(fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FormCardHeader(
            icon: Icons.timeline_rounded,
            title: 'Statut du projet',
            subtitle: 'Indiquez l’étape actuelle',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((status) {
              final isSelected = selectedStatus == status;

              return GestureDetector(
                onTap: () => onChanged(status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.secondarySurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor(context),
                    ),
                  ),
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
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FormCardHeader extends StatelessWidget {
  const _FormCardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.mainTextColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.secondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
