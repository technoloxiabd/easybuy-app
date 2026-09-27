import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The two secrets the app keeps: the bearer token (signed in) and the guest
/// cart token (shopping before signing in). Both live in the platform
/// keystore / keychain, never in plain preferences.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _cartKey = 'cart_token';

  String? _token;
  String? _cartToken;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _token = await _storage.read(key: _tokenKey);
    _cartToken = await _storage.read(key: _cartKey);
    _loaded = true;
  }

  String? get token => _token;
  String? get cartToken => _cartToken;

  Future<void> setToken(String? value) async {
    _token = value;
    value == null
        ? await _storage.delete(key: _tokenKey)
        : await _storage.write(key: _tokenKey, value: value);
  }

  Future<void> setCartToken(String? value) async {
    _cartToken = value;
    value == null
        ? await _storage.delete(key: _cartKey)
        : await _storage.write(key: _cartKey, value: value);
  }
}
