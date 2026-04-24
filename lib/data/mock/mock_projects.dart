import '../models/project_model.dart';

const List<ProjectModel> mockProjects = [
  ProjectModel(
    id: 'project_001',
    title: 'Site e-commerce Stelito',
    clientName: 'Stelito',
    type: 'WooCommerce',
    status: 'En cours',
    budget: '2 500€',
    deadline: '28 avril 2026',
    progress: 0.72,
  ),
  ProjectModel(
    id: 'project_002',
    title: 'Refonte site vitrine',
    clientName: 'Maison Design',
    type: 'WordPress',
    status: 'Maquette',
    budget: '1 200€',
    deadline: '10 mai 2026',
    progress: 0.45,
  ),
  ProjectModel(
    id: 'project_003',
    title: 'Landing page premium',
    clientName: 'Nova Studio',
    type: 'Design + intégration',
    status: 'Validation',
    budget: '850€',
    deadline: '2 mai 2026',
    progress: 0.88,
  ),
  ProjectModel(
    id: 'project_004',
    title: 'Site portfolio architecte',
    clientName: 'Green Habitat',
    type: 'WordPress',
    status: 'Planifié',
    budget: '1 600€',
    deadline: '18 mai 2026',
    progress: 0.15,
  ),
];