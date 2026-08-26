import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'core/constants/app_spacing.dart';
import 'core/widgets/common_widgets.dart';
import 'core/services/supabase_service.dart';
import 'core/services/external_activity_guard.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'models/enums.dart';
import 'panels/admin/admin_panel.dart';
import 'panels/staff/staff_panel.dart';

/// Whether the app is running on a desktop operating system.
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

class BeonCosmeticApp extends ConsumerWidget {
  const BeonCosmeticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ZH',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _SplashGate(),
    );
  }
}

// ─── Splash Gate ─────────────────────────────────────────────
// Shows splash logo briefly while auth session is being checked.
class _SplashGate extends ConsumerStatefulWidget {
  const _SplashGate();

  @override
  ConsumerState<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<_SplashGate> {
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    // Fast display time to load app quickly
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show splash while auth is loading OR minimum time hasn't elapsed
    if (authState.isLoading || !_minTimeElapsed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Image.asset(
            'assets/logo/splashscreen.png',
            width: 250,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // Auth resolved — route to login or panel
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // Authenticated — check if admin needs biometric lock (mobile only)
    if (authState.role == UserRole.admin) {
      // Desktop has no fingerprint hardware — skip lock gate entirely
      if (isDesktopPlatform) return const AdminPanel();
      return _AdminLockGate(authState: authState);
    }

    // Staff goes directly to its panel.
    return _buildPanelForRole(authState.role);
  }

  Widget _buildPanelForRole(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return const AdminPanel();
      case UserRole.staff:
        return const StaffPanel();
      default:
        return const StaffPanel();
    }
  }
}

// ─── Admin Biometric Lock Gate ───────────────────────────────
// Checks if fingerprint lock is enabled for the admin, shows lock screen if so.
class _AdminLockGate extends StatefulWidget {
  final AppAuthState authState;
  const _AdminLockGate({required this.authState});

  @override
  State<_AdminLockGate> createState() => _AdminLockGateState();
}

class _AdminLockGateState extends State<_AdminLockGate> with WidgetsBindingObserver {
  bool _isLocked = true; // Start locked, check preference
  bool _isCheckingLock = true;
  DateTime? _backgroundedAt;
  static const _lockThresholdSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockPreference();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    if (ExternalActivityGuard.isActive) {
      _backgroundedAt = null;
      return;
    }
    if (_backgroundedAt == null) return;
    final elapsed = DateTime.now().difference(_backgroundedAt!).inSeconds;
    _backgroundedAt = null;

    if (elapsed >= _lockThresholdSeconds) {
      final enabled = await _isFingerprintEnabled();
      if (enabled && mounted) {
        setState(() => _isLocked = true);
      }
    }
  }

  Future<bool> _isFingerprintEnabled() async {
    final userId = widget.authState.supabaseUser?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('fingerprint_lock_$userId') ?? false;
  }

  Future<void> _checkLockPreference() async {
    final enabled = await _isFingerprintEnabled();
    if (mounted) {
      setState(() {
        _isLocked = enabled;
        _isCheckingLock = false;
      });
    }
  }

  void _onUnlocked() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLock) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Image.asset(
            'assets/logo/splashscreen.png',
            width: 250,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (_isLocked) {
      return _BiometricLockScreen(
        email: widget.authState.profile?.email ?? '',
        onUnlocked: _onUnlocked,
      );
    }

    return const AdminPanel();
  }
}

// ─── Biometric Lock Screen ───────────────────────────────────
class _BiometricLockScreen extends StatefulWidget {
  final String email;
  final VoidCallback onUnlocked;
  const _BiometricLockScreen({required this.email, required this.onUnlocked});

  @override
  State<_BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<_BiometricLockScreen> {
  final _localAuth = LocalAuthentication();
  bool _showPasswordFallback = false;
  bool _isAuthenticating = false;
  bool _obscurePassword = true;
  String? _error;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Open device native fingerprint scanner cleanly when screen loads
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !_showPasswordFallback) {
        _tryBiometric();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    setState(() { _isAuthenticating = true; _error = null; });
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _showPasswordFallback = true;
            _error = 'No device fingerprint is enrolled. Use your admin password.';
          });
        }
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to unlock app',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (didAuthenticate) {
        widget.onUnlocked();
      } else {
        if (mounted) setState(() { _isAuthenticating = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _isAuthenticating = false; });
    }
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() { _isAuthenticating = true; _error = null; });

    try {
      final email = widget.email.trim().isNotEmpty
          ? widget.email.trim()
          : (SupabaseService.currentUser?.email ?? 'admin@beoncosmetic.com');

      final isPasswordValid = await SupabaseService.verifyPassword(
        email: email,
        password: password,
      );
      if (!isPasswordValid) {
        throw StateError('Incorrect password');
      }
      widget.onUnlocked();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Incorrect password';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset(
                  'assets/logo/splashscreen.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('App Locked', style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _showPasswordFallback
                      ? 'Enter your admin password to continue'
                      : 'Scan your fingerprint on the sensor to unlock',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error))),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (!_showPasswordFallback) ...[
                  Text(
                    _isAuthenticating
                        ? 'Waiting for the device fingerprint prompt...'
                        : 'Fingerprint verification was cancelled.',
                    style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: _isAuthenticating ? null : _tryBiometric,
                    child: const Text('Try device fingerprint again'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  TextButton(
                    onPressed: () => setState(() => _showPasswordFallback = true),
                    child: Text('Use Password Instead', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ] else ...[
                  // Password fallback with Eye Icon Toggle
                  AppTextField(
                    label: 'Admin Password',
                    hint: 'Enter password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textTertiary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isAuthenticating ? null : _verifyPassword,
                      child: _isAuthenticating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : Text('Verify Password', style: AppTypography.button.copyWith(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () {
                      setState(() => _showPasswordFallback = false);
                      _tryBiometric();
                    },
                    child: Text('Use Fingerprint Instead', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
