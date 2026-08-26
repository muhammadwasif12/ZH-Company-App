import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/staff_model.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/staff_provider.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffState = ref.watch(staffProvider);
    final query = _searchQuery.toLowerCase();
    final visibleStaff = staffState.staff.where((staff) {
      if (query.isEmpty) return true;
      return staff.name.toLowerCase().contains(query) ||
          staff.staffCode.toLowerCase().contains(query) ||
          (staff.email?.toLowerCase().contains(query) ?? false) ||
          (staff.phone?.toLowerCase().contains(query) ?? false);
    }).toList();

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isWide = outerConstraints.maxWidth > 700;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, isWide ? 4 : 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isWide) ...[
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Management',
                            style: AppTypography.h1.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Manage staff accounts, edit details, and commission settings',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () => _showAddStaffDialog(context, ref),
                      icon: const Icon(Icons.person_add_rounded, size: 20),
                      label: const Text('Add Staff'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAddStaffDialog(context, ref),
                      icon: const Icon(Icons.person_add_rounded, size: 20),
                      label: const Text('Add Staff'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _searchField(),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildStaffBody(context, ref, staffState.copyWith(staff: visibleStaff)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchField() => TextField(
    controller: _searchController,
    onChanged: (value) => setState(() => _searchQuery = value.trim()),
    decoration: InputDecoration(
      hintText: 'Search staff by name, code, email or phone...',
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.textTertiary,
      ),
      suffixIcon: _searchQuery.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
    ),
  );

  Widget _buildStaffBody(
    BuildContext context,
    WidgetRef ref,
    StaffState staffState,
  ) {
    if (staffState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (staffState.staff.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: const Center(
          child: EmptyState(
            icon: Icons.people_outline,
            title: 'No staff members yet',
            subtitle: 'Add your first staff member to get started',
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: staffState.staff.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _staffCard(context, ref, staffState.staff[index]),
          );
        }
        final minWidth = constraints.maxWidth > 920
            ? constraints.maxWidth
            : 920.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: SizedBox(
              width: minWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: staffState.staff.length + 1,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Table Header
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: 14,
                        ),
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: _headerText('STAFF CODE')),
                            Expanded(flex: 3, child: _headerText('NAME')),
                            Expanded(flex: 3, child: _headerText('EMAIL')),
                            Expanded(flex: 2, child: _headerText('PHONE')),
                            Expanded(flex: 2, child: _headerText('COMMISSION')),
                            Expanded(flex: 2, child: _headerText('PENALTY')),
                            Expanded(flex: 2, child: _headerText('STATUS')),
                            Expanded(flex: 2, child: _headerText('ACTIONS')),
                          ],
                        ),
                      );
                    }

                    final item = staffState.staff[index - 1];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.staffCode,
                              style: AppTypography.mono.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.name,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.email ?? '-',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.phone ?? '-',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.commissionType == 'fixed'
                                  ? 'Rs. ${item.commissionValue}'
                                  : '${item.commissionValue}%',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Rs. ${item.returnPenalty}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isActive
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  item.isActive ? 'Active' : 'Inactive',
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: AppTypography.caption.copyWith(
                                    color: item.isActive
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    size: 20,
                                    color: AppColors.info,
                                  ),
                                  tooltip: 'Edit Staff Account',
                                  onPressed: () =>
                                      _showEditStaffDialog(context, ref, item),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    size: 20,
                                    color: AppColors.error,
                                  ),
                                  tooltip: 'Delete Staff Account',
                                  onPressed: () =>
                                      _confirmDeleteStaff(context, ref, item),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _staffCard(BuildContext context, WidgetRef ref, StaffModel staff) {
    final statusColor = staff.isActive ? AppColors.success : AppColors.error;
    final commission = staff.commissionType == 'fixed'
        ? 'Rs. ${staff.commissionValue.toStringAsFixed(0)} / order'
        : '${staff.commissionValue.toStringAsFixed(0)}% commission';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                child: Text(
                  staff.name.isEmpty ? 'S' : staff.name[0].toUpperCase(),
                  style: AppTypography.h4.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name.isEmpty ? 'Unnamed staff' : staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      staff.staffCode.isEmpty
                          ? 'No staff code'
                          : staff.staffCode,
                      style: AppTypography.monoSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  staff.isActive ? 'Active' : 'Inactive',
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, cardConstraints) {
              final cellWidth = cardConstraints.maxWidth >= 360
                  ? (cardConstraints.maxWidth - AppSpacing.sm) / 2
                  : cardConstraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: cellWidth,
                    child: _staffDetail('Email', staff.email ?? 'Not added'),
                  ),
                  SizedBox(
                    width: cellWidth,
                    child: _staffDetail('Phone', staff.phone ?? 'Not added'),
                  ),
                  SizedBox(
                    width: cellWidth,
                    child: _staffDetail(
                      'Commission',
                      commission,
                      valueColor: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cellWidth,
                    child: _staffDetail(
                      'Return penalty',
                      'Rs. ${staff.returnPenalty.toStringAsFixed(0)}',
                      valueColor: AppColors.error,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showEditStaffDialog(context, ref, staff),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: () => _confirmDeleteStaff(context, ref, staff),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                tooltip: 'Delete staff',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffDetail(String label, String value, {Color? valueColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  Widget _headerText(String text) {
    return Text(
      text,
      style: AppTypography.label.copyWith(
        color: AppColors.textTertiary,
        fontSize: 11,
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StaffFormScreen()),
    );
  }

  void _showEditStaffDialog(
    BuildContext context,
    WidgetRef ref,
    StaffModel staff,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StaffFormScreen(staff: staff)),
    );
  }

  void _confirmDeleteStaff(
    BuildContext context,
    WidgetRef ref,
    StaffModel staff,
  ) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Staff Account',
      message:
          'Delete "${staff.name}" permanently? Its login, profile, staff record and salary records will be deleted. Orders and performance history remain available to Admin.',
      confirmText: 'Delete Staff',
      confirmColor: AppColors.error,
    );

    if (confirm == true) {
      final success = await ref
          .read(staffProvider.notifier)
          .deleteStaff(staff.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Staff account deleted; order history preserved'
                  : 'Failed to delete staff account',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }
}

class StaffFormScreen extends StatelessWidget {
  final StaffModel? staff;
  const StaffFormScreen({super.key, this.staff});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          staff != null ? 'Edit Staff Account' : 'Add New Staff',
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: staff != null
            ? _EditStaffDialog(staff: staff!)
            : const _AddStaffDialog(),
      ),
    );
  }
}

// ─── Add Staff Dialog ──────────────────────────────
class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog();

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commissionController = TextEditingController(text: '100');
  final _penaltyController = TextEditingController(text: '100');
  String _commissionType = 'fixed';
  bool _isLoading = false;
  bool _isPasswordHidden = true;
  bool _defaultsApplied = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _commissionController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await SupabaseService.createUserByAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
        role: 'staff',
      );

      final success = await ref.read(staffProvider.notifier).createStaff({
        'user_id': userId,
        'staff_code': _codeController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'commission_type': _commissionType,
        'commission_value':
            double.tryParse(_commissionController.text) ??
            double.tryParse(
              ref.read(settingsProvider)['default_commission_value'] ?? '',
            ) ??
            100,
        'return_penalty':
            double.tryParse(_penaltyController.text) ??
            double.tryParse(
              ref.read(settingsProvider)['default_return_penalty'] ?? '',
            ) ??
            100,
        'is_active': true,
      });

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff account created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _error = 'Failed to save staff record in database';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaults = ref.watch(settingsProvider);
    if (!_defaultsApplied && defaults.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _defaultsApplied) return;
        final commission = defaults['default_commission_value'];
        final penalty = defaults['default_return_penalty'];
        final commType = defaults['default_commission_type'];
        if (commission != null && commission.isNotEmpty) {
          _commissionController.text = commission;
        }
        if (penalty != null && penalty.isNotEmpty) {
          _penaltyController.text = penalty;
        }
        if (commType != null && commType.isNotEmpty) {
          setState(() => _commissionType = commType);
        }
        _defaultsApplied = true;
      });
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
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
                              _error!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppTextField(
                    label: 'Full Name *',
                    controller: _nameController,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isNarrow = constraints.maxWidth < 400;
                      if (isNarrow) {
                        return Column(
                          children: [
                            AppTextField(
                              label: 'Email *',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Invalid email'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: 'Login Password *',
                              controller: _passwordController,
                              obscureText: _isPasswordHidden,
                              suffixIcon: IconButton(
                                tooltip: _isPasswordHidden
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _isPasswordHidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _isPasswordHidden = !_isPasswordHidden,
                                ),
                              ),
                              validator: (v) => v == null || v.length < 6
                                  ? 'Min 6 chars'
                                  : null,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Email *',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Invalid email'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: AppTextField(
                              label: 'Login Password *',
                              controller: _passwordController,
                              obscureText: _isPasswordHidden,
                              suffixIcon: IconButton(
                                tooltip: _isPasswordHidden
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _isPasswordHidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _isPasswordHidden = !_isPasswordHidden,
                                ),
                              ),
                              validator: (v) => v == null || v.length < 6
                                  ? 'Min 6 chars'
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isNarrow = constraints.maxWidth < 400;
                      if (isNarrow) {
                        return Column(
                          children: [
                            AppTextField(
                              label: 'Staff Code *',
                              controller: _codeController,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Staff Code *',
                              controller: _codeController,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: AppTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isNarrow = constraints.maxWidth < 400;

                      final typeDropdown = DropdownButtonFormField<String>(
                        value: _commissionType,
                        decoration: InputDecoration(
                          labelText: 'Commission Type',
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed per Order'),
                          ),
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage (%)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _commissionType = val);
                          }
                        },
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            typeDropdown,
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: _commissionType == 'fixed'
                                  ? 'Commission (Rs.)'
                                  : 'Commission (%)',
                              controller: _commissionController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: 'Return Penalty',
                              controller: _penaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: typeDropdown),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: AppTextField(
                                  label: _commissionType == 'fixed'
                                      ? 'Commission (Rs.)'
                                      : 'Commission (%)',
                                  controller: _commissionController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Return Penalty (Rs.)',
                                  controller: _penaltyController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              const Spacer(),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(_isLoading ? 'Saving...' : 'Create Account'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Edit Staff Dialog ──────────────────────────────
class _EditStaffDialog extends ConsumerStatefulWidget {
  final StaffModel staff;
  const _EditStaffDialog({required this.staff});

  @override
  ConsumerState<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends ConsumerState<_EditStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _commissionController;
  late TextEditingController _penaltyController;
  late String _commissionType;
  late bool _isActive;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff.name);
    _phoneController = TextEditingController(text: widget.staff.phone ?? '');
    _commissionController = TextEditingController(
      text: widget.staff.commissionValue.toString(),
    );
    _penaltyController = TextEditingController(
      text: widget.staff.returnPenalty.toString(),
    );
    _commissionType = widget.staff.commissionType.isEmpty
        ? 'fixed'
        : widget.staff.commissionType;
    _isActive = widget.staff.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commissionController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final updates = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'commission_value':
          double.tryParse(_commissionController.text) ??
          widget.staff.commissionValue,
      'commission_type': _commissionType,
      'return_penalty':
          double.tryParse(_penaltyController.text) ??
          widget.staff.returnPenalty,
      'is_active': _isActive,
    };

    final success = await ref
        .read(staffProvider.notifier)
        .updateStaff(widget.staff.id, updates);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff details updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to update staff record';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppTextField(
                    label: 'Full Name *',
                    controller: _nameController,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isNarrow = constraints.maxWidth < 400;

                      final typeDropdown = DropdownButtonFormField<String>(
                        value: _commissionType,
                        decoration: InputDecoration(
                          labelText: 'Commission Type',
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed per Order'),
                          ),
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage (%)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _commissionType = val);
                          }
                        },
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            typeDropdown,
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: _commissionType == 'fixed'
                                  ? 'Commission (Rs.)'
                                  : 'Commission (%)',
                              controller: _commissionController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              label: 'Return Penalty',
                              controller: _penaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: typeDropdown),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: AppTextField(
                                  label: _commissionType == 'fixed'
                                      ? 'Commission (Rs.)'
                                      : 'Commission (%)',
                                  controller: _commissionController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Return Penalty (Rs.)',
                                  controller: _penaltyController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              const Spacer(),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Account Active Status',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Deactivated staff cannot login to system',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    value: _isActive,
                    activeThumbColor: AppColors.success,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
