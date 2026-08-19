import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthChangeEvent;
import '../../../core/services/supabase_service.dart';
import '../../../models/user_model.dart';
import '../../../models/enums.dart';

/// App auth state holding the current user session and profile
class AppAuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? supabaseUser;
  final UserModel? profile;
  final UserRole? role;
  final String? error;

  const AppAuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.supabaseUser,
    this.profile,
    this.role,
    this.error,
  });

  AppAuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    User? supabaseUser,
    UserModel? profile,
    UserRole? role,
    String? error,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      supabaseUser: supabaseUser ?? this.supabaseUser,
      profile: profile ?? this.profile,
      role: role ?? this.role,
      error: error,
    );
  }
}

/// Auth notifier — manages authentication state
class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier() : super(const AppAuthState(isLoading: true)) {
    _init();
  }

  StreamSubscription<supabase.AuthState>? _authSubscription;

  void _init() {
    // Check existing persisted session first
    final currentSession = SupabaseService.client.auth.currentSession;
    final currentUser = currentSession?.user;

    if (currentUser != null) {
      _loadProfile(currentUser);
    } else {
      // No persisted session — done loading, show login
      state = const AppAuthState(isLoading: false);
    }

    // Listen to auth changes (sign-in, sign-out, token refresh)
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session?.user != null) {
        _loadProfile(session!.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AppAuthState();
      } else if (event == AuthChangeEvent.tokenRefreshed && session?.user != null) {
        // Session was auto-refreshed — keep user logged in
        if (!state.isAuthenticated) {
          _loadProfile(session!.user);
        }
      }
    });
  }

  Future<void> _loadProfile(User user) async {
    state = state.copyWith(isLoading: true);
    try {
      final profileData = await SupabaseService.getUserProfile(user.id);
      if (profileData != null) {
        final profile = UserModel.fromJson(profileData);
        if (!profile.isActive) {
          await SupabaseService.signOut();
          state = const AppAuthState(
            isLoading: false,
            error: 'This account is inactive. Please contact the administrator.',
          );
          return;
        }
        final role = UserRole.fromString(profile.role);
        state = AppAuthState(
          isLoading: false,
          isAuthenticated: true,
          supabaseUser: user,
          profile: profile,
          role: role,
        );
      } else {
        // Profile doesn't exist yet — create default
        final newProfile = {
          'id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? '',
          'role': 'staff',
          'is_active': true,
        };
        await SupabaseService.client.from('profiles').upsert(newProfile);
        final profile = UserModel.fromJson({
          ...newProfile,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        state = AppAuthState(
          isLoading: false,
          isAuthenticated: true,
          supabaseUser: user,
          profile: profile,
          role: UserRole.staff,
        );
      }
    } catch (e) {
      state = AppAuthState(
        isLoading: false,
        isAuthenticated: true,
        supabaseUser: user,
        error: 'Failed to load profile: $e',
      );
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.signIn(email: email, password: password);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseAuthError(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = const AppAuthState();
  }

  Future<void> refreshProfile() async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await _loadProfile(user);
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  String _parseAuthError(dynamic error) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'Invalid email or password';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in';
    }
    if (message.contains('too many requests')) {
      return 'Too many attempts. Please try again later';
    }
    return 'Sign in failed. Please try again.';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Providers
final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).profile;
});

final currentRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).role;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentRoleProvider) == UserRole.admin;
});
