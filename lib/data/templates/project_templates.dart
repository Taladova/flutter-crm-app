import '../models/project_template_model.dart';

const projectTemplates = <ProjectTemplateModel>[
  ProjectTemplateModel(
    id: 'website',
    name: 'Site internet',
    projectType: 'Site internet',
    timeline: [
      TemplateTimelineStep(title: 'Brief', status: 'current'),
      TemplateTimelineStep(title: 'Contenus', daysOffset: 7),
      TemplateTimelineStep(title: 'Maquette', daysOffset: 14),
      TemplateTimelineStep(title: 'Validation', daysOffset: 18),
      TemplateTimelineStep(title: 'Développement', daysOffset: 28),
      TemplateTimelineStep(title: 'Recette', daysOffset: 35),
      TemplateTimelineStep(title: 'Livraison', daysOffset: 42),
    ],
    tasks: [
      TemplateTask(title: 'Préparer le brief projet'),
      TemplateTask(title: 'Créer l’arborescence du site'),
      TemplateTask(title: 'Préparer la maquette homepage'),
      TemplateTask(title: 'Intégrer les pages principales'),
      TemplateTask(title: 'Tester responsive et formulaires'),
    ],
    clientActions: [
      TemplateClientAction(
        title: 'Compléter le brief',
        description: 'Ajoutez les informations indispensables au lancement.',
        priority: 'high',
        daysOffset: 3,
      ),
      TemplateClientAction(
        title: 'Envoyer les documents',
        description: 'Logo, photos, textes et éléments légaux.',
        type: 'document',
        priority: 'high',
        daysOffset: 5,
      ),
      TemplateClientAction(
        title: 'Valider la maquette',
        description: 'Confirmez la direction visuelle avant développement.',
        type: 'validation',
        priority: 'high',
        daysOffset: 18,
      ),
    ],
    documentRequests: [
      TemplateDocumentRequest(title: 'Logo'),
      TemplateDocumentRequest(title: 'Charte graphique'),
      TemplateDocumentRequest(title: 'Photos'),
      TemplateDocumentRequest(title: 'Textes'),
      TemplateDocumentRequest(title: 'Mentions légales'),
    ],
    startChecklist: [
      'Confirmer le périmètre',
      'Récupérer les accès utiles',
      'Planifier le premier point client',
    ],
  ),
  ProjectTemplateModel(
    id: 'visual_identity',
    name: 'Identité visuelle',
    projectType: 'Identité visuelle',
    timeline: [
      TemplateTimelineStep(title: 'Brief', status: 'current'),
      TemplateTimelineStep(title: 'Moodboard'),
      TemplateTimelineStep(title: 'Pistes créatives'),
      TemplateTimelineStep(title: 'Validation'),
      TemplateTimelineStep(title: 'Livraison des fichiers'),
    ],
    tasks: [
      TemplateTask(title: 'Analyser le brief de marque'),
      TemplateTask(title: 'Préparer les pistes visuelles'),
      TemplateTask(title: 'Exporter les fichiers finaux'),
    ],
    clientActions: [
      TemplateClientAction(title: 'Compléter le brief de marque'),
      TemplateClientAction(
        title: 'Valider la piste retenue',
        type: 'validation',
      ),
    ],
    documentRequests: [
      TemplateDocumentRequest(title: 'Inspirations visuelles'),
      TemplateDocumentRequest(title: 'Logo existant'),
    ],
    startChecklist: [
      'Clarifier positionnement',
      'Lister les supports à livrer',
    ],
  ),
  ProjectTemplateModel(
    id: 'mobile_app',
    name: 'Application mobile',
    projectType: 'Application mobile',
    timeline: [
      TemplateTimelineStep(title: 'Cadrage', status: 'current'),
      TemplateTimelineStep(title: 'UX/UI'),
      TemplateTimelineStep(title: 'Développement'),
      TemplateTimelineStep(title: 'Tests'),
      TemplateTimelineStep(title: 'Publication'),
    ],
    tasks: [
      TemplateTask(title: 'Définir les écrans clés'),
      TemplateTask(title: 'Préparer le prototype'),
      TemplateTask(title: 'Planifier les tests'),
    ],
    clientActions: [
      TemplateClientAction(title: 'Valider le périmètre fonctionnel'),
      TemplateClientAction(title: 'Tester la version bêta', type: 'validation'),
    ],
    documentRequests: [
      TemplateDocumentRequest(title: 'Logo app'),
      TemplateDocumentRequest(title: 'Textes stores'),
    ],
    startChecklist: [
      'Choisir plateformes cibles',
      'Identifier les rôles utilisateurs',
    ],
  ),
  ProjectTemplateModel(
    id: 'photo_shoot',
    name: 'Shooting photo',
    projectType: 'Shooting photo',
    timeline: [
      TemplateTimelineStep(title: 'Brief', status: 'current'),
      TemplateTimelineStep(title: 'Préparation'),
      TemplateTimelineStep(title: 'Shooting'),
      TemplateTimelineStep(title: 'Sélection'),
      TemplateTimelineStep(title: 'Retouches'),
      TemplateTimelineStep(title: 'Livraison'),
    ],
    tasks: [
      TemplateTask(title: 'Préparer la shot list'),
      TemplateTask(title: 'Organiser le planning'),
      TemplateTask(title: 'Exporter la galerie finale'),
    ],
    clientActions: [
      TemplateClientAction(title: 'Valider la shot list'),
      TemplateClientAction(title: 'Choisir les photos à retoucher'),
    ],
    documentRequests: [
      TemplateDocumentRequest(title: 'Moodboard'),
      TemplateDocumentRequest(title: 'Liste produits ou lieux'),
    ],
    startChecklist: ['Confirmer lieu et date', 'Valider style attendu'],
  ),
  ProjectTemplateModel(
    id: 'architecture',
    name: 'Projet architecture',
    projectType: 'Projet architecture',
    timeline: [
      TemplateTimelineStep(title: 'Brief', status: 'current'),
      TemplateTimelineStep(title: 'Relevés'),
      TemplateTimelineStep(title: 'Avant-projet'),
      TemplateTimelineStep(title: 'Validation'),
      TemplateTimelineStep(title: 'Dossier final'),
    ],
    tasks: [
      TemplateTask(title: 'Collecter les contraintes'),
      TemplateTask(title: 'Préparer les plans initiaux'),
      TemplateTask(title: 'Assembler le dossier final'),
    ],
    clientActions: [
      TemplateClientAction(
        title: 'Envoyer les plans existants',
        type: 'document',
      ),
      TemplateClientAction(title: 'Valider l’avant-projet', type: 'validation'),
    ],
    documentRequests: [
      TemplateDocumentRequest(title: 'Plans existants'),
      TemplateDocumentRequest(title: 'Photos du lieu'),
      TemplateDocumentRequest(title: 'Contraintes techniques'),
    ],
    startChecklist: ['Identifier contraintes', 'Planifier le relevé'],
  ),
  ProjectTemplateModel(
    id: 'marketing',
    name: 'Campagne marketing',
    projectType: 'Campagne marketing',
    timeline: [
      TemplateTimelineStep(title: 'Objectifs', status: 'current'),
      TemplateTimelineStep(title: 'Stratégie'),
      TemplateTimelineStep(title: 'Création'),
      TemplateTimelineStep(title: 'Lancement'),
      TemplateTimelineStep(title: 'Analyse'),
    ],
    tasks: [
      TemplateTask(title: 'Définir les personas'),
      TemplateTask(title: 'Préparer les contenus'),
      TemplateTask(title: 'Configurer le suivi'),
    ],
    clientActions: [
      TemplateClientAction(title: 'Valider les objectifs'),
      TemplateClientAction(title: 'Valider les contenus', type: 'validation'),
    ],
    documentRequests: [
      TemplateDocumentRequest(title: 'Brand assets'),
      TemplateDocumentRequest(title: 'Offres à promouvoir'),
    ],
    startChecklist: ['Clarifier KPI', 'Lister les canaux'],
  ),
  ProjectTemplateModel(
    id: 'custom',
    name: 'Personnalisé',
    projectType: '',
    timeline: [],
    tasks: [],
    clientActions: [],
    documentRequests: [],
    startChecklist: [],
  ),
];
