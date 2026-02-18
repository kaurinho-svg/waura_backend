import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthStorage _storage;

  AppUser? _user;
  bool _isBootstrapped = false;

  // Одноразовый флаг "только что зарегистрировался"
  bool _justRegistered = false;

  AuthProvider(this._storage);

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isBootstrapped => _isBootstrapped;

  /// true => показать "Добро пожаловать" один раз
  bool get justRegistered => _justRegistered;

  Future<void> bootstrap() async {
    try {
      _user = await _storage.loadUser().timeout(const Duration(seconds: 2));
      _justRegistered = await _storage.getJustRegistered();
    } catch (e) {
      debugPrint('Auth bootstrap error: $e');
    } finally {
      _isBootstrapped = true;
      notifyListeners();
    }
  }

  Future<void> register(AppUser user) async {
    _user = user;

    // ВАЖНО: ставим одноразовый флаг в storage
    _justRegistered = true;
    await _storage.saveUser(user);
    await _storage.setJustRegistered(true);

    notifyListeners();
  }

  Future<void> updateUser(AppUser newUser) async {
    _user = newUser;
    await _storage.saveUser(newUser);
    notifyListeners();
  }

  /// Временный логин для теста:
  /// - если в storage уже есть юзер с таким email -> используем его (с правильным name)
  /// - иначе создаём мок (как раньше)
  Future<void> loginMock(String email) async {
    final stored = await _storage.loadUser();
    if (stored != null &&
        stored.email.toLowerCase() == email.toLowerCase()) {
      _user = stored;
      _justRegistered = false;
      await _storage.setJustRegistered(false);
      notifyListeners();
      return;
    }

    final guessedName = email.split("@").first;
    final mock = AppUser(
      name: guessedName.isEmpty ? "User" : guessedName,
      email: email,
      gender: Gender.male,
      role: UserRole.buyer,
    );

    _user = mock;
    _justRegistered = false;
    await _storage.saveUser(mock);
    await _storage.setJustRegistered(false);
    notifyListeners();
  }

  /// Вызывается на Home после первого показа "Добро пожаловать"
  Future<void> consumeJustRegistered() async {
    if (!_justRegistered) return;
    _justRegistered = false;
    await _storage.setJustRegistered(false);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _justRegistered = false;
    await _storage.clear();
    notifyListeners();
  }
}
