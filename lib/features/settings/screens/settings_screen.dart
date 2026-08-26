import 'package:flutter/material.dart';
import '../../../app.dart' show isDesktopPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/enums.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../products/providers/products_provider.dart';
import '../../staff/providers/staff_provider.dart';

// ─── Local Providers ───────────────────────────────────────
final deliveryChargesProvider =
    StateNotifierProvider<_DeliveryChargesNotifier, List<Map<String, dynamic>>>(
      (ref) => _DeliveryChargesNotifier(),
    );
final couriersProvider =
    StateNotifierProvider<_CouriersNotifier, List<Map<String, dynamic>>>(
      (ref) => _CouriersNotifier(),
    );
// Retained only for backwards-compatible dead code paths; blacklist UI and
// database integration have been removed.
final blacklistProvider = StateNotifierProvider<_BlacklistNotifier, List<Map<String, dynamic>>>(
  (ref) => _BlacklistNotifier(),
);
final settingsProvider =
    StateNotifierProvider<_SettingsNotifier, Map<String, String>>(
      (ref) => _SettingsNotifier(),
    );

class _DeliveryChargesNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  _DeliveryChargesNotifier() : super([]) {
    load();
  }
  Future<void> load() async {
    try {
      final r = await SupabaseService.client
          .from('delivery_charges')
          .select()
          .order('city');
      state = List<Map<String, dynamic>>.from(r);
    } catch (_) {}
  }

  Future<bool> add(String city, double charge) async {
    try {
      await SupabaseService.client.from('delivery_charges').insert({
        'city': city,
        'charge': charge,
      });
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> update(String id, String city, double charge) async {
    try {
      await SupabaseService.client
          .from('delivery_charges')
          .update({'city': city, 'charge': charge})
          .eq('id', id);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await SupabaseService.client
          .from('delivery_charges')
          .delete()
          .eq('id', id);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _CouriersNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  _CouriersNotifier() : super([]) {
    load();
  }
  Future<void> load() async {
    try {
      final r = await SupabaseService.client
          .from('couriers')
          .select()
          .order('name');
      state = List<Map<String, dynamic>>.from(r);
    } catch (_) {}
  }

  Future<bool> add(String name) async {
    try {
      await SupabaseService.client.from('couriers').insert({'name': name});
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await SupabaseService.client.from('couriers').delete().eq('id', id);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _BlacklistNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  _BlacklistNotifier() : super(const []);
  Future<bool> add(String mobile, String? name, String? reason, {String? entityType, String? entityId, String? accountEmail}) async => false;
  Future<bool> delete(String id) async => false;
}

class _SettingsNotifier extends StateNotifier<Map<String, String>> {
  _SettingsNotifier() : super({}) {
    load();
  }
  Future<void> load() async {
    try {
      final r = await SupabaseService.client.from('settings').select();
      final map = <String, String>{};
      for (final row in r) {
        map[row['key'] as String] = row['value'] as String;
      }
      state = map;
    } catch (_) {}
  }

  Future<bool> save(String key, String value) async {
    try {
      await SupabaseService.client
          .from('settings')
          .update({'value': value})
          .eq('key', key);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Main Settings Screen ───────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedSection = 0;
  final _searchBlacklistController = TextEditingController();
  final _stockSearchController = TextEditingController();
  String _blacklistTypeFilter = 'all';
  bool _isExporting = false;
  String? _exportingTask;
  bool _fingerprintEnabled = false;
  bool _loadingFingerprint = true;

  List<(String, IconData)> get _sections {
    final isAdmin = ref.read(currentRoleProvider) == UserRole.admin;
    return [
      // Security/fingerprint is only available on mobile for admins
      if (isAdmin && !isDesktopPlatform) ('Security', Icons.fingerprint_rounded),
      ('Commission Defaults', Icons.calculate_rounded),
      ('Delivery Charges', Icons.local_shipping_rounded),
      ('Courier Companies', Icons.business_rounded),
      ('Stock Thresholds', Icons.inventory_2_rounded),
      ('Backup & Export', Icons.backup_rounded),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadFingerprintPref();
  }

  @override
  void dispose() {
    _searchBlacklistController.dispose();
    _stockSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFingerprintPref() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      setState(() => _loadingFingerprint = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fingerprintEnabled =
            prefs.getBool('fingerprint_lock_$userId') ?? false;
        _loadingFingerprint = false;
      });
    }
  }

  Future<void> _toggleFingerprint(bool value) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();

    // If Admin is turning OFF the lock, disable it directly and save preference
    if (!value) {
      await prefs.setBool('fingerprint_lock_$userId', false);
      if (mounted) {
        setState(() => _fingerprintEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint lock disabled'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
      return;
    }

    // If Admin is turning ON the lock, prompt native mobile fingerprint scan
    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    if (!canCheck) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a fingerprint in your device settings first'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      final didAuth = await localAuth.authenticate(
        localizedReason: 'Scan fingerprint to enable Admin Fingerprint Lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint verification canceled or failed'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      await prefs.setBool('fingerprint_lock_$userId', true);
      if (mounted) {
        setState(() => _fingerprintEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint lock enabled successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final hideHeader = outerConstraints.maxWidth > 600;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, hideHeader ? 4 : 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hideHeader) ...[
                Text(
                  'Settings',
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Configure system defaults, inventory thresholds, and exports',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 240,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            itemCount: sections.length,
                            itemBuilder: (ctx, i) {
                              final isActive = i == _selectedSection;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _selectedSection = i),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.sidebarItemActive
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sections[i].$2,
                                            size: 18,
                                            color: isActive
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Text(
                                              sections[i].$1,
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color: isActive
                                                        ? AppColors.textPrimary
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: isActive
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _buildContent(),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(sections.length, (i) {
                            final isActive = i == _selectedSection;
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.md,
                              ),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _selectedSection = i),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                    border: Border.all(
                                      color: isActive
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        sections[i].$2,
                                        size: 16,
                                        color: isActive
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        sections[i].$1,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: isActive
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontWeight: isActive
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _buildContent(),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          ],
        ),
      );
      },
    );
  }

  Widget _buildContent() {
    final sections = _sections;
    if (_selectedSection >= sections.length) {
      return const SizedBox();
    }
    final sectionName = sections[_selectedSection].$1;
    switch (sectionName) {
      case 'Security':
        return _buildSecuritySection();
      case 'Commission Defaults':
        return _buildCommission();
      case 'Delivery Charges':
        return _buildDeliveryCharges();
      case 'Courier Companies':
        return _buildCouriers();
      case 'Stock Thresholds':
        return _buildStockThresholdsResponsive();
      case 'Backup & Export':
        return _buildBackup();
      default:
        return const SizedBox();
    }
  }

  // ─── Security / Fingerprint Lock (Admin Only) ────────────
  Widget _buildSecuritySection() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security',
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Admin-only security settings for this device',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Fingerprint Lock',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Use this device\'s enrolled fingerprint to unlock the admin account',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadingFingerprint)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _fingerprintEnabled,
                    onChanged: _toggleFingerprint,
                    activeThumbColor: AppColors.primary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _showChangePasswordDialog,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Change admin password'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your device controls fingerprint enrollment. This app only verifies the enrolled fingerprint; the admin password remains available as a fallback.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var obscureNew = true;
    var obscureConfirm = true;
    var isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change admin password'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'New password',
                    controller: newController,
                    obscureText: obscureNew,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Confirm new password',
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      error!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final next = newController.text;
                      final confirm = confirmController.text;
                      if (next.isEmpty || confirm.isEmpty) {
                        setDialogState(
                          () => error = 'Complete the new password fields',
                        );
                        return;
                      }
                      if (!_isStrongPassword(next)) {
                        setDialogState(
                          () => error =
                              'Use 8+ characters with an uppercase letter, lowercase letter, number, and symbol.',
                        );
                        return;
                      }
                      if (next != confirm) {
                        setDialogState(
                          () => error = 'New passwords do not match',
                        );
                        return;
                      }
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        isSaving = true;
                        error = null;
                      });
                      try {
                        await SupabaseService.changeCurrentUserPassword(
                          newPassword: next,
                        );
                        if (dialogContext.mounted && mounted) {
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Admin password updated successfully',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          isSaving = false;
                          error = _passwordUpdateError(e);
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  String _passwordUpdateError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('weak') || message.contains('leaked')) {
      return 'Choose a stronger password that has not been commonly used.';
    }
    if (message.contains('reauth') || message.contains('nonce')) {
      return 'Password verification is required by Supabase. Please sign out, sign in again, then retry.';
    }
    return 'Password could not be updated. Please try again.';
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  // ─── Commission Defaults ─────────────────────
  Widget _buildCommission() {
    final settings = ref.watch(settingsProvider);
    final commType = settings['default_commission_type'] ?? 'fixed';
    final commVal = settings['default_commission_value'] ?? '100';
    final penalty = settings['default_return_penalty'] ?? '100';

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission Defaults',
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Default commission rules for staff compensation',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final tileWidth = isNarrow ? double.infinity : 200.0;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _settingTile(
                      'Commission Type',
                      commType == 'fixed'
                          ? 'Fixed per Order'
                          : 'Percentage of COD',
                      Icons.monetization_on_outlined,
                      AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _settingTile(
                      'Commission Value',
                      'Rs. $commVal',
                      Icons.paid_outlined,
                      AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _settingTile(
                      'Return Penalty',
                      'Rs. $penalty',
                      Icons.remove_circle_outline,
                      AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _editCommission(commType, commVal, penalty),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Defaults'),
          ),
        ],
      ),
    );
  }

  Widget _settingTile(String title, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      );

  void _editCommission(String type, String val, String pen) {
    final typeCtrl = TextEditingController(text: type);
    final valCtrl = TextEditingController(text: val);
    final penCtrl = TextEditingController(text: pen);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Commission Defaults'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Type (fixed/percentage)',
              controller: typeCtrl,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Value',
              controller: valCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Return Penalty',
              controller: penCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(settingsProvider.notifier)
                  .save('default_commission_type', typeCtrl.text.trim());
              await ref
                  .read(settingsProvider.notifier)
                  .save('default_commission_value', valCtrl.text.trim());
              await ref
                  .read(settingsProvider.notifier)
                  .save('default_return_penalty', penCtrl.text.trim());
              if (ctx.mounted && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings saved!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Delivery Charges ────────────────────────
  Widget _buildDeliveryCharges() {
    final charges = ref.watch(deliveryChargesProvider);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'City Delivery Charges',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Set delivery charges per city',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _addCity,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add City'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: charges.length,
            itemBuilder: (ctx, i) {
              final c = charges[i];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_city,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        c['city'] ?? '',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Rs. ${(c['charge'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    IconButton(
                      onPressed: () => _editCity(c),
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _deleteCity(c),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _addCity() {
    final cityCtrl = TextEditingController();
    final chargeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add City Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'City Name', controller: cityCtrl),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Delivery Charge (Rs.)',
              controller: chargeCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await ref
                  .read(deliveryChargesProvider.notifier)
                  .add(
                    cityCtrl.text.trim(),
                    double.tryParse(chargeCtrl.text) ?? 0,
                  );
              if (ctx.mounted && mounted) {
                Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('City added'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editCity(Map<String, dynamic> c) {
    final cityCtrl = TextEditingController(text: c['city'] ?? '');
    final chargeCtrl = TextEditingController(
      text: (c['charge'] as num?)?.toString() ?? '0',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit City Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'City Name', controller: cityCtrl),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Delivery Charge (Rs.)',
              controller: chargeCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await ref
                  .read(deliveryChargesProvider.notifier)
                  .update(
                    c['id'],
                    cityCtrl.text.trim(),
                    double.tryParse(chargeCtrl.text) ?? 0,
                  );
              if (ctx.mounted && mounted) {
                Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('City updated'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteCity(Map<String, dynamic> c) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete City',
      message: 'Remove "${c['city']}" rate?',
      confirmText: 'Delete',
      confirmColor: AppColors.error,
    );
    if (ok == true && mounted) {
      await ref.read(deliveryChargesProvider.notifier).delete(c['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('City deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // ─── Couriers ────────────────────────────────
  Widget _buildCouriers() {
    final couriers = ref.watch(couriersProvider);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Courier Services',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Manage active courier partners',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _addCourier,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Courier'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: couriers
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          c['name'] ?? '',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: () => _deleteCourier(c),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _addCourier() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        title: const Text('Add Courier Partner'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: AppTextField(label: 'Courier Name', controller: ctrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(couriersProvider.notifier).add(ctrl.text.trim());
              if (ctx.mounted && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Courier added'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCourier(Map<String, dynamic> c) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Remove Courier',
      message: 'Remove "${c['name']}"?',
      confirmText: 'Remove',
      confirmColor: AppColors.error,
    );
    if (ok == true) await ref.read(couriersProvider.notifier).delete(c['id']);
  }

  // ─── Dynamic Blacklist ───────────────────────────────
  // ignore: unused_element
  Widget _buildBlacklistUnused() {
    final list = ref.watch(blacklistProvider);
    final query = _searchBlacklistController.text.trim().toLowerCase();
    final filtered = list.where((b) {
      final m = (b['customer_mobile'] ?? '').toString().toLowerCase();
      final n = (b['customer_name'] ?? '').toString().toLowerCase();
      final r = (b['reason'] ?? '').toString().toLowerCase();
      final t = (b['entity_type'] ?? '').toString().toLowerCase();
      return query.isEmpty ||
          m.contains(query) ||
          n.contains(query) ||
          r.contains(query) ||
          t.contains(query);
    }).toList();
    final typeFiltered = _blacklistTypeFilter == 'all'
        ? filtered
        : filtered.where((b) =>
            (b['entity_type'] ?? '').toString().toLowerCase() ==
            _blacklistTypeFilter.toLowerCase()).toList();

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Blacklist',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Blocked accounts cannot sign in again until removed',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _showAddBlacklistDialog,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Add to Blacklist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: TextField(
                    controller: _searchBlacklistController,
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search blacklist by mobile, name, reason...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      fillColor: AppColors.surfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              DropdownButton<String>(
                value: _blacklistTypeFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (value) => setState(() => _blacklistTypeFilter = value ?? 'all'),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${typeFiltered.length} Blacklisted',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (typeFiltered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: EmptyState(
                  icon: Icons.block_outlined,
                  title: 'No blacklisted customers',
                  subtitle:
                      'Search query yielded 0 results or blacklist is empty',
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: typeFiltered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final b = typeFiltered[i];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    b['customer_name'] ?? b['customer_mobile'] ?? 'Unknown',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Mobile: ${b['customer_mobile'] ?? ''} • Reason: ${b['reason'] ?? 'No reason detailed'}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: 18,
                    ),
                    tooltip: 'Un-blacklist',
                    onPressed: () async {
                      final ok = await ConfirmationDialog.show(
                        context,
                        title: 'Remove Blacklist',
                        message:
                            'Remove "${b['customer_mobile']}" from blacklist?',
                        confirmText: 'Remove',
                        confirmColor: AppColors.error,
                      );
                      if (ok == true) {
                        await ref
                            .read(blacklistProvider.notifier)
                            .delete(b['id']);
                      }
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddBlacklistDialog() {
    final staff = ref.read(staffProvider).staff;
    String selectedType = 'staff';
    String? selectedId;
    final personSearchCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.block, color: AppColors.error),
              SizedBox(width: 8),
              Text('Add to Blacklist'),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 450,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Account type'),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    ],
                    onChanged: (v) => setDialogState(() { selectedType = v ?? 'staff'; selectedId = null; }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: personSearchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search person',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Builder(builder: (_) {
                    final List<(String, String, String?)> allItems =
                        staff.map((s) => (s.userId, s.name, s.email)).toList();
                    final search = personSearchCtrl.text.toLowerCase().trim();
                    final items = allItems.where((item) => search.isEmpty ||
                        item.$2.toLowerCase().contains(search) ||
                        (item.$3 ?? '').toLowerCase().contains(search)).toList();
                    return DropdownButtonFormField<String>(
                      value: selectedId,
                      decoration: const InputDecoration(labelText: 'Select person to blacklist'),
                      isExpanded: true,
                      items: items.map((item) => DropdownMenuItem<String>(
                        value: item.$1,
                        child: Text(item.$3 == null ? item.$2 : '${item.$2} (${item.$3})'),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => selectedId = v),
                    );
                  }),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Reason for Blacklisting',
                    hint: 'Reason (optional)',
                    controller: reasonCtrl,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                if (selectedId == null) return;
                final selected = staff.firstWhere((s) => s.userId == selectedId);
                final name = selected.name;
                final email = selected.email;
                await ref.read(blacklistProvider.notifier).add(
                  'account:$selectedId', name, reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                  entityType: selectedType, entityId: selectedId, accountEmail: email,
                );
                if (ctx.mounted && mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name added to blacklist'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Blacklist'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stock Alert Thresholds UI/UX ────────────────────────
  Widget _buildStockThresholdsResponsive() {
    final products = ref.watch(productsProvider).products;
    final settings = ref.watch(settingsProvider);
    final global = int.tryParse(settings['low_stock_threshold'] ?? '10') ?? 10;
    final query = _stockSearchController.text.trim().toLowerCase();
    final visible = products.where((p) => query.isEmpty ||
        p.name.toLowerCase().contains(query) ||
        (p.sku ?? '').toLowerCase().contains(query) ||
        (p.category ?? '').toLowerCase().contains(query)).toList();
    final low = products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= (p.lowStockThreshold > 0 ? p.lowStockThreshold : global)).length;
    final out = products.where((p) => p.stockQuantity <= 0).length;
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, c) {
        final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stock alerts', style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Text('Manage stock quantities and low-stock thresholds.', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        ]);
        final button = OutlinedButton.icon(onPressed: () => _editGlobalThreshold('$global'), icon: const Icon(Icons.tune_rounded, size: 16), label: Text('Default: $global units'));
        return c.maxWidth < 520 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 10), button]) : Row(children: [Expanded(child: heading), button]);
      }),
      const SizedBox(height: AppSpacing.md),
      TextField(controller: _stockSearchController, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Search products by name, SKU or category...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _stockSearchController.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _stockSearchController.clear(); setState(() {}); }), filled: true, fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      const SizedBox(height: AppSpacing.md),
      Wrap(spacing: 10, runSpacing: 10, children: [_stockSummary('Products', '${products.length}', Icons.inventory_2_outlined, AppColors.primary), _stockSummary('Low stock', '$low', Icons.warning_amber_outlined, AppColors.warning), _stockSummary('Out of stock', '$out', Icons.error_outline, AppColors.error)]),
      const SizedBox(height: AppSpacing.lg),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: EmptyState(icon: Icons.inventory_outlined, title: 'No products found', subtitle: 'Try another search term')))
      else ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: visible.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (context, index) => _stockProductCard(visible[index], global)),
    ]));
  }

  Widget _stockProductCard(dynamic product, int global) {
    final threshold = product.lowStockThreshold > 0 ? product.lowStockThreshold : global;
    final out = product.stockQuantity <= 0;
    final low = !out && product.stockQuantity <= threshold;
    final color = out ? AppColors.error : low ? AppColors.warning : AppColors.success;
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surfaceVariant.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)), child: Text(out ? 'Out of Stock' : low ? 'Low Stock' : 'In Stock', style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 4),
      Text('${product.sku ?? 'No SKU'} • ${product.category ?? 'General'}  |  Rs. ${product.price.toStringAsFixed(0)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) => c.maxWidth < 360 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_stockQuantityControls(product, color), const SizedBox(height: 8), _stockThresholdButton(product, threshold)]) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_stockQuantityControls(product, color), _stockThresholdButton(product, threshold)])),
    ]));
  }

  Widget _stockQuantityControls(dynamic product, Color color) => Row(children: [IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), color: AppColors.error, onPressed: () => _updateStock(product.id, product.stockQuantity - 1)), Container(width: 54, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Text('${product.stockQuantity}', style: AppTypography.h4.copyWith(color: color, fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), color: AppColors.success, onPressed: () => _updateStock(product.id, product.stockQuantity + 1))]);

  Widget _stockThresholdButton(dynamic product, int threshold) => TextButton.icon(onPressed: () => _editProductThreshold(product), icon: const Icon(Icons.edit_outlined, size: 16), label: Text('Threshold: $threshold'));

  // ignore: unused_element
  Widget _buildStockThresholdsUnused() {
    final productsState = ref.watch(productsProvider);
    final products = productsState.products;
    final settings = ref.watch(settingsProvider);
    final globalThresholdStr = settings['low_stock_threshold'] ?? '10';
    final globalThreshold = int.tryParse(globalThresholdStr) ?? 10;

    final lowStockCount = products
        .where(
          (p) =>
              p.stockQuantity <=
                  (p.lowStockThreshold > 0
                      ? p.lowStockThreshold
                      : globalThreshold) &&
              p.stockQuantity > 0,
        )
        .length;
    final outOfStockCount = products.where((p) => p.stockQuantity <= 0).length;

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final editButton = OutlinedButton.icon(
                onPressed: () => _editGlobalThreshold(globalThresholdStr),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text('Default: $globalThresholdStr units'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              );
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock alerts',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Set low-stock limits and adjust quantities quickly.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: AppSpacing.sm),
                    editButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: AppSpacing.md),
                  editButton,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          LayoutBuilder(
            builder: (ctx, constraints) {
              final cards = [
                _stockSummary(
                  'Products',
                  '${products.length}',
                  Icons.inventory_2_outlined,
                  AppColors.primary,
                ),
                _stockSummary(
                  'Low stock',
                  '$lowStockCount',
                  Icons.warning_amber_outlined,
                  AppColors.warning,
                ),
                _stockSummary(
                  'Out of stock',
                  '$outOfStockCount',
                  Icons.error_outline,
                  AppColors.error,
                ),
              ];
              if (constraints.maxWidth < 520) {
                return Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1)
                      const SizedBox(width: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          LayoutBuilder(
            builder: (ctx, tblConstraints) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: Center(
                          child: EmptyState(
                            icon: Icons.inventory_outlined,
                            title: 'No products in catalog',
                            subtitle:
                                'Add products to configure stock thresholds',
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tblConstraints.maxWidth < 650 ? 650 : null,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xl,
                                  vertical: AppSpacing.md,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _th('PRODUCT', 3),
                                    _th('SKU / CAT', 2),
                                    _th('STOCK QTY', 3),
                                    _th('THRESHOLD', 2),
                                    _th('STATUS', 2),
                                  ],
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                                itemBuilder: (ctx, i) {
                                  final p = products[i];
                                  final threshold = p.lowStockThreshold > 0
                                      ? p.lowStockThreshold
                                      : globalThreshold;
                                  final isOut = p.stockQuantity <= 0;
                                  final isLow =
                                      p.stockQuantity <= threshold && !isOut;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              Text(
                                                'Price: Rs. ${p.price.toStringAsFixed(0)}',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color: AppColors
                                                          .textTertiary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${p.sku ?? "N/A"} • ${p.category ?? "General"}',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 18,
                                                  color: AppColors.error,
                                                ),
                                                onPressed: () => _updateStock(
                                                  p.id,
                                                  p.stockQuantity - 1,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSpacing.radiusMd,
                                                      ),
                                                  border: Border.all(
                                                    color: AppColors.border,
                                                  ),
                                                ),
                                                child: Text(
                                                  '${p.stockQuantity}',
                                                  style: AppTypography.h4
                                                      .copyWith(
                                                        color: isOut
                                                            ? AppColors.error
                                                            : (isLow
                                                                  ? AppColors
                                                                        .warning
                                                                  : AppColors
                                                                        .success),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 18,
                                                  color: AppColors.success,
                                                ),
                                                onPressed: () => _updateStock(
                                                  p.id,
                                                  p.stockQuantity + 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: InkWell(
                                            onTap: () =>
                                                _editProductThreshold(p),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '$threshold units',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.edit_outlined,
                                                  size: 14,
                                                  color: AppColors.textTertiary,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isOut
                                                  ? AppColors.error.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : (isLow
                                                        ? AppColors.warning
                                                              .withValues(
                                                                alpha: 0.15,
                                                              )
                                                        : AppColors.success
                                                              .withValues(
                                                                alpha: 0.15,
                                                              )),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppSpacing.radiusFull,
                                                  ),
                                            ),
                                            child: Text(
                                              isOut
                                                  ? 'Out of Stock'
                                                  : (isLow
                                                        ? 'Low Stock'
                                                        : 'In Stock'),
                                              style: AppTypography.caption
                                                  .copyWith(
                                                    color: isOut
                                                        ? AppColors.error
                                                        : (isLow
                                                              ? AppColors
                                                                    .warning
                                                              : AppColors
                                                                    .success),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stockSummary(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text, int flex) => Expanded(
    flex: flex,
    child: Text(
      text,
      style: AppTypography.label.copyWith(
        color: AppColors.textTertiary,
        fontSize: 11,
      ),
    ),
  );

  void _updateStock(String productId, int newQty) {
    if (newQty < 0) return;
    ref.read(productsProvider.notifier).updateProduct(productId, {
      'stock_quantity': newQty,
    });
  }

  void _editGlobalThreshold(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => _compactThresholdDialog(
        ctx,
        title: 'Edit Global Low Stock Threshold',
        label: 'Threshold Units',
        controller: ctrl,
        onSave: () async {
          await ref.read(settingsProvider.notifier).save('low_stock_threshold', ctrl.text.trim());
          if (ctx.mounted && mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Threshold updated'), backgroundColor: AppColors.success));
          }
        },
      ),
    );
  }

  void _editProductThreshold(dynamic product) {
    final ctrl = TextEditingController(text: '${product.lowStockThreshold}');
    showDialog(
      context: context,
      builder: (ctx) => _compactThresholdDialog(
        ctx,
        title: 'Edit Threshold for ${product.name}',
        label: 'Custom Low Stock Threshold',
        controller: ctrl,
        onSave: () async {
          final val = int.tryParse(ctrl.text.trim()) ?? 10;
          await ref.read(productsProvider.notifier).updateProduct(product.id, {'low_stock_threshold': val});
          if (ctx.mounted && mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product threshold updated'), backgroundColor: AppColors.success));
          }
        },
      ),
    );
  }

  Widget _compactThresholdDialog(
    BuildContext dialogContext, {
    required String title,
    required String label,
    required TextEditingController controller,
    required Future<void> Function() onSave,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              AppTextField(label: label, controller: controller, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: onSave, child: const Text('Save')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 100% Working Backup & Export ──────────────────────────
  Widget _buildBackup() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup & Export System',
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Export system datasets to Excel, JSON, and PDF formats',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_isExporting) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    _exportingTask ?? 'Generating export file...',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
                  children: [
                    _backupAction(
                      'Export All Orders',
                      'Download orders sheet (.xlsx)',
                      Icons.table_chart_outlined,
                      AppColors.success,
                      () => _handleExportOrders(),
                      isFullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _backupAction(
                      'Export All Data',
                      'Full database snapshot (.json)',
                      Icons.storage_outlined,
                      AppColors.info,
                      () => _handleExportData(),
                      isFullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _backupAction(
                      'Export Reports',
                      'Printable business report (.pdf)',
                      Icons.picture_as_pdf_outlined,
                      AppColors.error,
                      () => _handleExportReports(),
                      isFullWidth: true,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _backupAction(
                      'Export All Orders',
                      'Download orders sheet (.xlsx)',
                      Icons.table_chart_outlined,
                      AppColors.success,
                      () => _handleExportOrders(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _backupAction(
                      'Export All Data',
                      'Full database snapshot (.json)',
                      Icons.storage_outlined,
                      AppColors.info,
                      () => _handleExportData(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _backupAction(
                      'Export Reports',
                      'Printable business report (.pdf)',
                      Icons.picture_as_pdf_outlined,
                      AppColors.error,
                      () => _handleExportReports(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _backupAction(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isExporting ? null : onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportOrders() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportingTask = 'Creating Excel spreadsheet...';
    });
    try {
      await ref.read(ordersProvider.notifier).loadOrders();
      final orders = ref.read(ordersProvider).orders;
      final path = await ExportService.exportOrdersToExcel(orders);
      if (mounted) _showExportResultDialog('Orders Excel Exported', path);
    } catch (_) {
      if (mounted) _showExportResultDialog('Orders Excel Exported', null);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingTask = null;
        });
      }
    }
  }

  Future<void> _handleExportData() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportingTask = 'Generating JSON database backup...';
    });
    try {
      final path = await ExportService.exportAllDataToJson();
      if (mounted) _showExportResultDialog('Full JSON Backup Saved', path);
    } catch (_) {
      if (mounted) _showExportResultDialog('Full JSON Backup Saved', null);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingTask = null;
        });
      }
    }
  }

  Future<void> _handleExportReports() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _exportingTask = 'Building PDF report document...';
    });
    try {
      await ref.read(ordersProvider.notifier).loadOrders();
      await ref.read(staffProvider.notifier).loadStaff();
      final orders = ref.read(ordersProvider).orders;
      final staff = ref.read(staffProvider).staff;
      final path = await ExportService.exportReportsToPdf(orders, staff);
      if (mounted) _showExportResultDialog('PDF Business Report Created', path);
    } catch (_) {
      if (mounted) _showExportResultDialog('PDF Business Report Created', null);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingTask = null;
        });
      }
    }
  }

  void _showExportResultDialog(String title, String? filePath) {
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export cancelled or failed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Export Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.h4.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'File saved at:',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              filePath,
              style: AppTypography.mono.copyWith(
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

