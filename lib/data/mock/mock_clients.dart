import '../models/client_model.dart';

const List<ClientModel> mockClients = [
  ClientModel(
    id: 'client_001',
    name: 'Stelito',
    company: 'Mobilier & décoration',
    email: 'contact@stelito.fr',
    phone: '+33 6 12 34 56 78',
    projectsCount: 2,
    status: 'Actif',
  ),
  ClientModel(
    id: 'client_002',
    name: 'Maison Design',
    company: 'Architecture intérieure',
    email: 'hello@maisondesign.fr',
    phone: '+33 7 22 45 98 10',
    projectsCount: 1,
    status: 'En attente',
  ),
  ClientModel(
    id: 'client_003',
    name: 'Nova Studio',
    company: 'Agence créative',
    email: 'contact@novastudio.fr',
    phone: '+33 6 88 75 14 32',
    projectsCount: 3,
    status: 'Actif',
  ),
  ClientModel(
    id: 'client_004',
    name: 'Green Habitat',
    company: 'Construction durable',
    email: 'info@greenhabitat.fr',
    phone: '+33 6 41 22 18 90',
    projectsCount: 1,
    status: 'Prospect',
  ),
];