import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/order_model.dart';
import '../../../models/staff_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../services/report_export_service.dart';

/// Mobile-first reports. Labelled cards prevent desktop-table fields from
/// overlapping on small phones, while the page naturally scrolls for long data.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _tabs = ['Daily', 'Staff-wise', 'Product-wise', 'City-wise', 'Delivered', 'Return', 'COD', 'Salary'];
  int _selectedTab = 0;
  bool _isExporting = false;

  Future<void> _handleExport(String type, List<OrderModel> orders, List<StaffModel> staff) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final data = ReportExportService.prepareReportData(tabIndex: _selectedTab, orders: orders, staffList: staff);
      switch (type) {
        case 'Excel':
          await ReportExportService.exportToExcel(data);
          break;
        case 'PDF':
          await ReportExportService.generateAndPrintPdf(data: data, isPrintMode: false);
          break;
        case 'Print':
          await ReportExportService.generateAndPrintPdf(data: data, isPrintMode: true);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(type == 'Print' ? 'Print dialog opened for the ${_tabs[_selectedTab]} report.' : '${_tabs[_selectedTab]} report is ready to share.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate the $type report: $error'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).orders;
    final staff = ref.watch(staffProvider).staff;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 116),
      children: [
        Text('Reports', style: AppTypography.h1.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('Generate, share and print business reports', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: AppSpacing.lg),
        _exportActions(orders, staff),
        const SizedBox(height: AppSpacing.lg),
        _reportTabs(),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(_selectedTab), child: _selectedReport(orders, staff)),
        ),
      ],
    );
  }

  Widget _exportActions(List<OrderModel> orders, List<StaffModel> staff) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = [
        _exportButton('Excel', Icons.table_chart_rounded, orders, staff),
        _exportButton('PDF', Icons.picture_as_pdf_rounded, orders, staff),
        _exportButton('Print', Icons.print_rounded, orders, staff),
      ];
      if (constraints.maxWidth < 340) return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions);
      return Row(children: [
        Expanded(child: actions[0]), const SizedBox(width: AppSpacing.sm),
        Expanded(child: actions[1]), const SizedBox(width: AppSpacing.sm),
        Expanded(child: actions[2]),
      ]);
    },
  );

  Widget _exportButton(String label, IconData icon, List<OrderModel> orders, List<StaffModel> staff) => OutlinedButton.icon(
    onPressed: _isExporting ? null : () => _handleExport(label, orders, staff),
    icon: _isExporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18),
    label: Text(label, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
  );

  Widget _reportTabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: List.generate(_tabs.length, (index) {
        final selected = _selectedTab == index;
        return Padding(
          padding: EdgeInsets.only(right: index == _tabs.length - 1 ? 0 : 4),
          child: Semantics(
            selected: selected,
            button: true,
            label: '${_tabs[index]} report',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.42) : Colors.transparent),
                ),
                child: Text(_tabs[index], style: AppTypography.bodySmall.copyWith(color: selected ? AppColors.textPrimary : AppColors.textTertiary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              ),
            ),
          ),
        );
      })),
    ),
  );

  Widget _selectedReport(List<OrderModel> orders, List<StaffModel> staff) {
    switch (_selectedTab) {
      case 0:
        final now = DateTime.now();
        return _orderReport(orders.where((o) => _isSameDay(o.orderDate, now)).toList(), title: 'Today\'s orders', emptyTitle: 'No orders today', emptySubtitle: 'Orders created today will appear here.');
      case 1: return _staffReport(orders);
      case 2: return _groupReport(orders, 'Product', (o) => o.productName);
      case 3: return _groupReport(orders, 'City', (o) => o.city);
      case 4: return _orderReport(orders.where((o) => o.status == 'delivered').toList(), title: 'Delivered orders', emptyTitle: 'No delivered orders', emptySubtitle: 'Delivered orders will appear here.');
      case 5: return _orderReport(orders.where((o) => o.status == 'returned').toList(), title: 'Returned orders', emptyTitle: 'No returned orders', emptySubtitle: 'Returned orders will appear here.');
      case 6: return _codReport(orders);
      default: return _salaryReport(orders, staff);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _orderReport(List<OrderModel> orders, {required String title, required String emptyTitle, required String emptySubtitle}) {
    if (orders.isEmpty) return _empty(emptyTitle, emptySubtitle, Icons.receipt_long_outlined);
    return _section(title: title, subtitle: '${orders.length} ${orders.length == 1 ? 'record' : 'records'}', child: Column(children: orders.map(_orderCard).toList()));
  }

  Widget _staffReport(List<OrderModel> orders) {
    final groups = <String, List<OrderModel>>{};
    for (final order in orders) {
      final name = (order.staffName?.trim().isNotEmpty ?? false) ? order.staffName!.trim() : 'Unassigned';
      groups.putIfAbsent(name, () => []).add(order);
    }
    if (groups.isEmpty) return _empty('No staff data', 'Staff results will appear as orders are processed.', Icons.people_outline);
    return _section(title: 'Staff performance', subtitle: '${groups.length} team members', child: Column(children: groups.entries.map((entry) {
      final memberOrders = entry.value;
      return _dataCard(title: entry.key, icon: Icons.person_outline_rounded, values: {
        'Orders': '${memberOrders.length}',
        'Delivered': '${memberOrders.where((o) => o.status == 'delivered').length}',
        'Returns': '${memberOrders.where((o) => o.status == 'returned').length}',
        'COD': _money(memberOrders.fold<double>(0, (sum, o) => sum + o.codAmount)),
      });
    }).toList()));
  }

  Widget _groupReport(List<OrderModel> orders, String label, String Function(OrderModel) key) {
    final groups = <String, List<OrderModel>>{};
    for (final order in orders) {
      final group = key(order).trim().isEmpty ? 'Not specified' : key(order).trim();
      groups.putIfAbsent(group, () => []).add(order);
    }
    if (groups.isEmpty) return _empty('No $label data', '$label results will appear as orders are processed.', Icons.assessment_outlined);
    return _section(title: '$label summary', subtitle: '${groups.length} ${label.toLowerCase()} groups', child: Column(children: groups.entries.map((entry) {
      final groupOrders = entry.value;
      return _dataCard(title: entry.key, icon: label == 'City' ? Icons.location_city_outlined : Icons.inventory_2_outlined, values: {
        'Orders': '${groupOrders.length}',
        'Delivered': '${groupOrders.where((o) => o.status == 'delivered').length}',
        'Total COD': _money(groupOrders.fold<double>(0, (sum, o) => sum + o.codAmount)),
      });
    }).toList()));
  }

  Widget _codReport(List<OrderModel> orders) {
    final total = orders.fold<double>(0, (sum, o) => sum + o.codAmount);
    final delivered = orders.where((o) => o.status == 'delivered').fold<double>(0, (sum, o) => sum + o.codAmount);
    return Column(children: [
      _metricGrid([
        _Metric('Total COD', _money(total), Icons.account_balance_wallet_outlined, AppColors.info),
        _Metric('Collected COD', _money(delivered), Icons.check_circle_outline, AppColors.delivered),
        _Metric('Pending COD', _money(total - delivered), Icons.hourglass_bottom_rounded, AppColors.pending),
      ]),
      const SizedBox(height: AppSpacing.lg),
      _orderReport(orders, title: 'COD orders', emptyTitle: 'No COD data', emptySubtitle: 'COD records will appear as orders are created.'),
    ]);
  }

  Widget _salaryReport(List<OrderModel> orders, List<StaffModel> staff) {
    if (staff.isEmpty) return _empty('No staff found', 'Add a staff member to generate salary results.', Icons.payments_outlined);
    return _section(title: 'Salary & commission', subtitle: '${staff.length} team members', child: Column(children: staff.map((member) {
      final memberOrders = orders.where((o) => o.staffId == member.userId).toList();
      final delivered = memberOrders.where((o) => o.status == 'delivered').toList();
      final returns = memberOrders.where((o) => o.status == 'returned').length;
      final commission = member.commissionType == 'percentage' ? delivered.fold<double>(0, (sum, o) => sum + o.codAmount) * member.commissionValue / 100 : delivered.length * member.commissionValue;
      final penalty = returns * member.returnPenalty;
      return _dataCard(title: member.name, icon: Icons.account_circle_outlined, values: {
        'Delivered': '${delivered.length}', 'Returns': '$returns', 'Commission': _money(commission), 'Penalty': _money(penalty), 'Net salary': _money(commission - penalty),
      });
    }).toList()));
  }


  Widget _section({required String title, required String subtitle, required Widget child}) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppTypography.h3.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(subtitle, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
      const SizedBox(height: AppSpacing.md), child,
    ]),
  );

  Widget _orderCard(OrderModel order) => _dataCard(
    title: order.customerName.trim().isEmpty ? 'Unnamed customer' : order.customerName,
    icon: Icons.receipt_long_outlined,
    trailing: _statusBadge(order.status),
    values: {
      'Order ID': order.displayId,
      'City': order.city.trim().isEmpty ? 'Not specified' : order.city,
      'Product': order.productName.trim().isEmpty ? 'Not specified' : order.productName,
      'Quantity': '${order.quantity}',
      'COD': _money(order.codAmount),
      'Order date': '${order.orderDate.day.toString().padLeft(2, '0')}/${order.orderDate.month.toString().padLeft(2, '0')}/${order.orderDate.year}',
    },
  );

  Widget _dataCard({required String title, required IconData icon, required Map<String, String> values, Widget? trailing}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(color: AppColors.surfaceVariant.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(AppSpacing.radiusLg), border: Border.all(color: AppColors.border.withValues(alpha: 0.8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.primary, size: 19), const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing],
      ]),
      const SizedBox(height: AppSpacing.md),
      LayoutBuilder(builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 360;
        final width = twoColumns ? (constraints.maxWidth - AppSpacing.sm) / 2 : constraints.maxWidth;
        return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: values.entries.map((entry) => SizedBox(width: width, child: _detail(entry.key, entry.value))).toList());
      }),
    ]),
  );

  Widget _detail(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontSize: 10, letterSpacing: 0.4)),
    const SizedBox(height: 1),
    Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
  ]);

  Widget _metricGrid(List<_Metric> metrics) => LayoutBuilder(builder: (context, constraints) {
    final twoColumns = constraints.maxWidth >= 350;
    final width = twoColumns ? (constraints.maxWidth - AppSpacing.sm) / 2 : constraints.maxWidth;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: metrics
          .map((metric) => SizedBox(
                width: width,
                child: _compactMetricCard(metric),
              ))
          .toList(),
    );
  });

  /// Smaller than the dashboard KPI card, so three report summaries do not
  /// overpower the report data below them on mobile.
  Widget _compactMetricCard(_Metric metric) => Container(
        height: 96,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: metric.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 15),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                metric.value,
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    final color = normalized == 'delivered' ? AppColors.delivered : normalized == 'returned' ? AppColors.returned : normalized == 'pending' ? AppColors.pending : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
      child: Text(normalized.isEmpty ? 'UNKNOWN' : normalized.toUpperCase(), style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10)),
    );
  }

  Widget _empty(String title, String subtitle, IconData icon) => Container(
    constraints: const BoxConstraints(minHeight: 220),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusXl), border: Border.all(color: AppColors.border)),
    child: Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: EmptyState(icon: icon, title: title, subtitle: subtitle)),
  );

  String _money(double value) => 'Rs. ${value.toStringAsFixed(0)}';
}

class _Metric {
  const _Metric(this.title, this.value, this.icon, this.color);
  final String title;
  final String value;
  final IconData icon;
  final Color color;
}
