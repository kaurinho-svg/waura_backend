import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../services/auth_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthStorage _storage; // Keep for local flags like 'justRegistered'
  final SupabaseClient _supabase = Supabase.instance.client;

  AppUser? _user;
  bool _isBootstrapped = false;
  bool _justRegistered = false;
  bool _isLoading = false;

  AuthProvider(this._storage);

  AppUser? get user => _user;
  bool get isLoggedIn => _supabase.auth.currentUser != null; // Trust Supabase session
  bool get isBootstrapped => _isBootstrapped;
  bool get justRegistered => _justRegistered;
  bool get isLoading => _isLoading;

  /// Check for existing session
  Future<void> bootstrap() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _loadProfile(session.user.id);
      }
      _justRegistered = await _storage.getJustRegistered();
    } catch (e) {
      debugPrint('Auth bootstrap error: $e');
    } finally {
      _isBootstrapped = true;
      notifyListeners();
    }
  }

  /// Sign Up: Auth + Profile Creation
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required Gender gender,
    UserRole role = UserRole.buyer,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Sign Up with Metadata
      // We pass user data here, and a SQL Trigger (which we will create)
      // will automatically insert it into the 'profiles' table.
      // This avoids "Violates RLS policy" errors.
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'gender': gender.name,
          'role': role.name,
        },
      );

      final user = response.user;
      if (user == null) throw Exception("Registration failed");

      // Note: We do NOT manually insert into 'profiles' anymore.
      // The SQL Trigger handles it securely.

      // Create local user object for immediate UI update
      final appUser = AppUser(
        name: name,
        email: email,
        gender: gender,
        role: role,
      );

      _user = appUser;
      _justRegistered = true;
      await _storage.setJustRegistered(true);
      
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign In
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadProfile(response.user!.id);
        _justRegistered = false;
        await _storage.setJustRegistered(false);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      _user = AppUser.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> updateUser(AppUser newUser) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profiles').update({
        'name': newUser.name,
        // email is managed by auth, not profile updates usually, but we can store it
        // gender/role updates if needed
      }).eq('id', user.id);

      _user = newUser;
    } catch (e) {
      debugPrint('Update user error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy/Mock login (kept for compatibility if needed, else remove)
  Future<void> loginMock(String email) async {
     // Deprecated. Use login()
     throw UnimplementedError("Use real login");
  }

  Future<void> consumeJustRegistered() async {
    if (!_justRegistered) return;
    _justRegistered = false;
    await _storage.setJustRegistered(false);
    notifyListeners();
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _user = null;
    _justRegistered = false;
    // await _storage.clear(); // Don't clear EVERYTHING, maybe just auth flags
    notifyListeners();
  }
}
