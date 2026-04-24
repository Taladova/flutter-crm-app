import '../models/task_model.dart';

const List<TaskModel> mockTasks = [
  TaskModel(
    id: 'task_001',
    title: 'Envoyer la maquette homepage',
    projectName: 'Site e-commerce Stelito',
    projectId: 'project_001',
    status: 'En cours',
    priority: 'Haute',
    deadline: 'Aujourd’hui',
  ),
  TaskModel(
    id: 'task_002',
    title: 'Configurer WooCommerce',
    projectName: 'Site e-commerce Stelito',
    projectId: 'project_001',
    status: 'À faire',
    priority: 'Haute',
    deadline: 'Demain',
  ),
  TaskModel(
    id: 'task_003',
    title: 'Préparer contenu page services',
    projectName: 'Refonte site vitrine',
    projectId: 'project_002',
    status: 'À faire',
    priority: 'Moyenne',
    deadline: '30 avril',
  ),
  TaskModel(
    id: 'task_004',
    title: 'Valider les couleurs avec le client',
    projectName: 'Landing page premium',
    projectId: 'project_003',
    status: 'Terminé',
    priority: 'Basse',
    deadline: 'Hier',
  ),
];