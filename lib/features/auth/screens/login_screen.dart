import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─── Ambient Glow Background Accents ─────────────────
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.info.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.info.withValues(alpha: 0.08),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // ─── Main Login Body ─────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusXl,
                          ),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 32,
                              spreadRadius: 0,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ─── Full Unclipped Logo ──────────────────────────
                              Image.asset(
                                'assets/logo/splashscreen.png',
                                width: 220,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // ─── Welcome Header ──────────────────────
                              Text(
                                'Welcome Back',
                                style: AppTypography.h1.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Sign in to access your dashboard',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),

                              // ─── Error Notification ──────────────────
                              if (authState.error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          authState.error!,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],

                              // ─── Email Input ─────────────────────────
                              AppTextField(
                                label: 'Email Address',
                                hint: 'name@beoncosmetic.com',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 20,
                                  color: AppColors.textTertiary,
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!val.contains('@')) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // ─── Password Input ──────────────────────
                              AppTextField(
                                label: 'Password',
                                hint: '••••••••',
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                  color: AppColors.textTertiary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (val.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xxl),

                              // ─── Sign In Action Button ───────────────
                              Container(
                                width: double.infinity,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: authState.isLoading
                                      ? null
                                      : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                    ),
                                  ),
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign In to ZH',
                                              style: AppTypography.button
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxl),

                              // ─── Footer Security Badge ───────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Encrypted & Role-Protected Auth',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
