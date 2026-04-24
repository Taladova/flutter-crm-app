import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../mock/mock_clients.dart';
import '../models/client_model.dart';

class ClientRepository {
  const ClientRepository();

  static const String _clientsKey = 'clients';

  Future<List<ClientModel>> getClients() async {
    await Future.delayed(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    final clientsString = prefs.getString(_clientsKey);

    if (clientsString == null) {
      await saveClients(mockClients);
      return mockClients;
    }

    final List<dynamic> decoded = jsonDecode(clientsString);

    return decoded
        .map((item) => ClientModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveClients(List<ClientModel> clients) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      clients.map((client) => client.toJson()).toList(),
    );

    await prefs.setString(_clientsKey, encoded);
  }

  Future<ClientModel?> getClientById(String id) async {
    final clients = await getClients();

    try {
      return clients.firstWhere((client) => client.id == id);
    } catch (_) {
      return null;
    }
  }
}