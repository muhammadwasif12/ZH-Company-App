import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/enums.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../providers/salary_provider.dart';

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});
  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _recalculating = false;

  @override
  void initState() {
    super.initState();
    // Keep the salary view current whenever a staff member opens it.
    Future.microtask(_recalculate);
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _recalculate() async {
    if (_recalculating) return;
    setState(() => _recalculating = true);
    try {
      await ref.read(ordersProvider.notifier).loadOrders();
      await ref.read(staffProvider.notifier).loadStaff();
      await ref.read(salaryProvider.notifier).recalculateAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current month salaries recalculated')));
    } finally {
      if (mounted) setState(() => _recalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final allStaff = ref.watch(staffProvider).staff;
    final visibleStaff = auth.role == UserRole.staff && auth.supabaseUser != null
        ? allStaff.where((s) => s.userId == auth.supabaseUser!.id || s.id == auth.supabaseUser!.id).toList()
        : allStaff;
    final staff = visibleStaff.where((s) {
      final q = _query.trim().toLowerCase();
      return q.isEmpty || s.name.toLowerCase().contains(q) || s.staffCode.toLowerCase().contains(q) || (s.email ?? '').toLowerCase().contains(q);
    }).toList();
    final orders = ref.watch(ordersProvider).orders;
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isWide = outerConstraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, isWide ? 4 : 10, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!isWide) ...[
              LayoutBuilder(builder: (context, constraints) {
                final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Salary Management', style: AppTypography.h1.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Current-month staff salary and performance summary', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                ]);
                final button = OutlinedButton.icon(
                  onPressed: _recalculating ? null : _recalculate,
                  icon: _recalculating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate_rounded, size: 20),
                  label: Text(_recalculating ? 'Calculating...' : 'Recalculate'),
                );
                return constraints.maxWidth < 560 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), button]) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: title), button]);
              }),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  onPressed: _recalculating ? null : _recalculate,
                  icon: _recalculating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.calculate_rounded, size: 20),
                  label: Text(_recalculating ? 'Calculating...' : 'Recalculate'),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(width: double.infinity, child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(hintText: 'Search staff by name, code or email...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); setState(() => _query = ''); }), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border))),
            )),
            const SizedBox(height: AppSpacing.md),
            Container(padding: const EdgeInsets.all(AppSpacing.md), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.18))), child: Text('Formula: Final salary = commission earned - return penalty. Fixed commission is per delivered order; percentage commission uses delivered COD.', style: AppTypography.bodySmall.copyWith(color: AppColors.primary))),
            const SizedBox(height: AppSpacing.lg),
            if (staff.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: EmptyState(icon: Icons.payments_outlined, title: 'No staff members', subtitle: 'Add staff to see salary calculations')))
            else LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 600 ? 3 : constraints.maxWidth >= 400 ? 2 : 1;
              final ratio = columns >= 3 ? 1.15 : columns == 2 ? 1.35 : 1.85;
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: ratio), itemCount: staff.length, itemBuilder: (context, index) => _salaryCard(staff[index], orders));
            }),
          ]),
        );
      },
    );
  }

  Widget _salaryCard(dynamic staff, List<dynamic> orders) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final staffOrders = orders.where((o) =>
        (o.staffId == staff.userId || o.staffId == staff.id) &&
        !o.orderDate.isBefore(monthStart) && o.orderDate.isBefore(nextMonth)).toList();
    final delivered = staffOrders.where((o) => o.status.toLowerCase().trim() == 'delivered').toList();
    final returned = staffOrders.where((o) => ['returned', 'return', 'returned_to_sender'].contains(o.status.toLowerCase().trim())).length;
    final commission = staff.commissionType == 'percentage' ? delivered.fold<double>(0, (sum, o) => sum + o.codAmount) * staff.commissionValue / 100 : delivered.length * staff.commissionValue;
    final penalty = returned * staff.returnPenalty;
    final salary = commission - penalty;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 21, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(staff.name.isEmpty ? 'S' : staff.name[0].toUpperCase(), style: AppTypography.h4.copyWith(color: AppColors.primary))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(staff.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)), Text(staff.staffCode, style: AppTypography.caption.copyWith(color: AppColors.textTertiary))])), Icon(Icons.payments_outlined, color: salary >= 0 ? AppColors.success : AppColors.error)]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_metric('Delivered', '${delivered.length}', AppColors.delivered), _metric('Returns', '$returned', AppColors.returned), _metric('Commission', 'Rs. ${commission.toStringAsFixed(0)}', AppColors.success)]),
      const SizedBox(height: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Penalty: Rs. ${penalty.toStringAsFixed(0)}', style: AppTypography.caption.copyWith(color: AppColors.error)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Rs. ${salary.toStringAsFixed(0)}', style: AppTypography.h3.copyWith(color: salary >= 0 ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold)),
        ),
      ]),
    ]));
  }

  Widget _metric(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700)))]);
}
