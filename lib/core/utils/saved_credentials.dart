import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

const _emailKey = 'saved_login_email';
const _passwordKey = 'saved_login_password';
const _clientEmailKey = 'saved_client_login_email';
const _clientPasswordKey = 'saved_client_login_password';

class SavedCredentials {
  const SavedCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

String _emailKeyForScope(String scope) {
  return scope == 'client' ? _clientEmailKey : _emailKey;
}

String _passwordKeyForScope(String scope) {
  return scope == 'client' ? _clientPasswordKey : _passwordKey;
}

Future<SavedCredentials?> loadSavedCredentials({String scope = 'pro'}) async {
  final email = await _storage.read(key: _emailKeyForScope(scope));
  final password = await _storage.read(key: _passwordKeyForScope(scope));

  if (email == null || password == null) return null;

  return SavedCredentials(email: email, password: password);
}

Future<void> saveCredentials(
  String email,
  String password, {
  String scope = 'pro',
}) async {
  await _storage.write(key: _emailKeyForScope(scope), value: email);
  await _storage.write(key: _passwordKeyForScope(scope), value: password);
}

Future<void> clearSavedCredentials({String scope = 'pro'}) async {
  await _storage.delete(key: _emailKeyForScope(scope));
  await _storage.delete(key: _passwordKeyForScope(scope));
}
