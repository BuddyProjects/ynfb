import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../domain/user.dart';
import '../../../services/supabase_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _user;
  String? _errorMessage;

  AuthProvider(this._supabaseService) {
    _init();
  }

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  
  // Demo mode: create a fake user ID for local storage
  String get currentUserId => _user?.id ?? 'demo-user';

  void _init() {
    // In demo mode (Supabase not configured), use a local demo user
    if (!SupabaseService.isInitialized) {
      _user = AppUser(
        id: 'demo-user',
        email: 'demo@ynfb.app',
        createdAt: DateTime.now(),
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }
    
    // Listen to auth state changes
    _supabaseService.authStateChanges.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _loadUserProfile(session.user.id);
      } else {
        _user = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });

    // Check initial auth state
    final currentUser = _supabaseService.currentUser;
    if (currentUser != null) {
      _loadUserProfile(currentUser.id);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      var profile = await _supabaseService.getUserProfile(userId);
      
      // Create profile if it doesn't exist
      if (profile == null) {
        final currentUser = _supabaseService.currentUser;
        profile = AppUser(
          id: userId,
          email: currentUser?.email ?? '',
          createdAt: DateTime.now(),
        );
        await _supabaseService.updateUserProfile(profile);
      }

      _user = profile;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
    }
    notifyListeners();
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabaseService.signUpWithEmail(email, password);
      
      if (response.user != null) {
        // User might need email verification
        if (response.session != null) {
          await _loadUserProfile(response.user!.id);
          return true;
        } else {
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Please check your email to verify your account.';
          notifyListeners();
          return false;
        }
      }
      
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Sign up failed. Please try again.';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabaseService.signInWithEmail(email, password);
      
      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        return true;
      }
      
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Sign in failed. Please check your credentials.';
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      await _supabaseService.signInWithGoogle();
      // Auth state change listener will handle the rest
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Google sign in failed.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Sign out failed.';
      notifyListeners();
    }
  }

  Future<void> updateAffiliatePreference(AffiliatePreference preference) async {
    if (_user == null) return;

    final updatedUser = _user!.copyWith(affiliatePreference: preference);
    await _supabaseService.updateUserProfile(updatedUser);
    _user = updatedUser;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
