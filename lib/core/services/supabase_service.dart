import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton wrapper for Supabase client access
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  /// Current authenticated user
  static User? get currentUser => auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null;

  /// Auth state stream
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
  }

  /// Verifies credentials without replacing the active Supabase session.
  /// Used by the local admin lock password fallback.
  static Future<bool> verifyPassword({
    required String email,
    required String password,
  }) async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || key.isEmpty) return false;

    final response = await http.post(
      Uri.parse('$url/auth/v1/token?grant_type=password'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Updates the active signed-in user's password in Supabase Auth. The
  /// current authenticated session identifies the account being updated.
  static Future<void> changeCurrentUserPassword({required String newPassword}) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Your admin session has expired. Please sign in again.');
    }

    await auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Create user by Admin via direct HTTP request to Supabase Auth endpoint
  /// This avoids PKCE assertion errors and does NOT touch active Admin session
  static Future<String> createUserByAdmin({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    final uri = Uri.parse('$url/auth/v1/signup');
    final response = await http.post(
      uri,
      headers: {
        'apikey': key,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'data': {
          'full_name': fullName,
          'role': role,
        },
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final userId = data['id'] as String? ??
          (data['user'] as Map<String, dynamic>?)?['id'] as String?;
      if (userId == null || userId.isEmpty) {
        throw 'User created but failed to get user ID';
      }
      return userId;
    } else {
      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = errorData['msg'] ??
          errorData['error_description'] ??
          errorData['message'] ??
          'Failed to create account';
      throw msg.toString();
    }
  }

  /// Get user profile from profiles table
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  /// Get current user's role
  static Future<String?> getCurrentUserRole() async {
    if (currentUserId == null) return null;
    final profile = await getUserProfile(currentUserId!);
    return profile?['role'] as String?;
  }
}
