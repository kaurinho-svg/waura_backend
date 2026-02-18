import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class AuthStorage {
  static const _kUser = 'auth_user_v1';
  static const _kJustRegistered = 'auth_just_registered_v1';

  Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<AppUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Флаг: "пользователь только что зарегистрировался" (показать Welcome один раз)
  Future<void> setJustRegistered(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kJustRegistered, value);
  }

  Future<bool> getJustRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kJustRegistered) ?? false;
  }

  /// Прочитать и сразу сбросить (одноразовое потребление)
  Future<bool> consumeJustRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_kJustRegistered) ?? false;
    if (value) {
      await prefs.setBool(_kJustRegistered, false);
    }
    return value;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUser);
    await prefs.remove(_kJustRegistered);
  }
}
