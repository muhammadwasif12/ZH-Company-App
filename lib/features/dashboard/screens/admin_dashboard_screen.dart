import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/orders/providers/orders_provider.dart';
import '../../../features/staff/providers/staff_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late int _selectedChartYear;
  late int _selectedPerformerYear;
  late int _selectedPerformerMonth;

  @override
  void initState() {
    super.initState();
    _selectedChartYear = DateTime.now().year;
    _selectedPerformerYear = DateTime.now().year;
    _selectedPerformerMonth = DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final ordersState = ref.watch(ordersProvider);
    final staffState = ref.watch(staffProvider);
    final authState = ref.watch(authProvider);

    final userName = authState.profile?.fullName ?? 'Admin';
    final allOrders = ordersState.orders;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Greeting Section ──────────────────────────────
          _buildGreeting(userName),
          const SizedBox(height: AppSpacing.xl),



          // ─── Live Stats Cards ──────────────────────────────
          _buildLiveStats(stats, allOrders),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Revenue Overview Card ─────────────────────────
          _buildRevenueCard(stats, allOrders),
          const SizedBox(height: AppSpacing.lg),

          // ─── Charts ────────────────────────────────────────
          _buildOrderTrendChart(allOrders),
          const SizedBox(height: AppSpacing.lg),
          _buildStatusRing(
            allOrders.where((order) => order.orderDate.year == _selectedChartYear).toList(),
            year: _selectedChartYear,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Staff Leaderboard ─────────────────────────────
          _buildStaffLeaderboard(staffState.staff, allOrders),
        ],
      ),
    );
  }

  // ─── Greeting ──────────────────────────────────────────
  Widget _buildGreeting(String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetIcon;
    if (hour < 12) {
      greeting = 'Good Morning';
      greetIcon = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetIcon = Icons.wb_cloudy_outlined;
    } else {
      greeting = 'Good Evening';
      greetIcon = Icons.nightlight_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(greetIcon, color: AppColors.warning, size: 18),
            const SizedBox(width: 6),
            Text(
              greeting,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          userName,
          style: AppTypography.h1.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatToday(),
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }



  // ─── Live Stats ──────────────────────────────────────────
  Widget _buildLiveStats(Map<String, dynamic> stats, List<dynamic> allOrders) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Today\'s Pulse',
                style: AppTypography.h4.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _statColumn('Orders', stats['today_orders'].toString(), AppColors.primary),
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(
                child: _statColumn('Delivered', stats['today_delivered'].toString(), AppColors.delivered),
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(
                child: _statColumn('Returns', stats['today_returned'].toString(), AppColors.returned),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: AppTypography.h2.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ─── Revenue Card ──────────────────────────────────────
  Widget _buildRevenueCard(Map<String, dynamic> stats, List<dynamic> allOrders) {
    final totalCod = (stats['total_cod'] as num).toDouble();
    final pendingCod = (stats['pending_cod'] as num).toDouble();
    final returnRatio = (stats['return_ratio'] as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.accentPurple.withValues(alpha: 0.08),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryHover, size: 18),
              const SizedBox(width: 8),
              Text(
                'Revenue Overview',
                style: AppTypography.h4.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Rs. ${totalCod.toStringAsFixed(0)}',
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 32,
              letterSpacing: -1,
            ),
          ),
          Text(
            'Total system COD • ${allOrders.length} orders',
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _revenueMetric(
                  'Pending COD',
                  'Rs. ${pendingCod.toStringAsFixed(0)}',
                  AppColors.warning,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _revenueMetric(
                  'Return Rate',
                  '${returnRatio.toStringAsFixed(1)}%',
                  returnRatio > 15 ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revenueMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h3.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ─── Order Trend Chart ──────────────────────────────────
  Widget _buildOrderTrendChart(List<dynamic> orders) {
    final monthlyOrders = List<int>.generate(12, (monthIndex) {
      final month = monthIndex + 1;
      return orders.where((order) {
        final date = (order as dynamic).orderDate as DateTime;
        return date.year == _selectedChartYear && date.month == month;
      }).length;
    });
    final highestMonth = monthlyOrders.reduce((a, b) => a > b ? a : b);
    // Keep the scale readable at low volume and expand it automatically when a
    // month crosses 50, 100, or any later threshold.
    final maxY = _chartMaxY(highestMonth);
    final interval = _chartInterval(maxY);
    final isCurrentYear = _selectedChartYear == DateTime.now().year;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Volume',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                child: Text('$_selectedChartYear', style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Swipe left or right to view another year',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -150) {
                setState(() => _selectedChartYear--);
              } else if (velocity > 150 && _selectedChartYear < DateTime.now().year) {
                setState(() => _selectedChartYear++);
              }
            },
            child: SizedBox(
              height: 180,
              child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barGroups: List.generate(12, (i) {
                  final monthOrders = monthlyOrders[i];
                  final isCurrentMonth = isCurrentYear && DateTime.now().month == i + 1;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: monthOrders.toDouble(),
                        width: 16,
                        gradient: isCurrentMonth
                            ? const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryHover],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : null,
                        color: isCurrentMonth ? null : AppColors.primary.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                        if (value < 0 || value > 11) return const SizedBox.shrink();
                        final isCurrentMonth = isCurrentYear && DateTime.now().month == value.toInt() + 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            months[value.toInt()],
                            style: AppTypography.caption.copyWith(
                              color: isCurrentMonth ? AppColors.primary : AppColors.textMuted,
                              fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.w400,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value % interval != 0) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.border.withValues(alpha: 0.5),
                      strokeWidth: 0.8,
                      dashArray: [6, 4],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _chartMaxY(int highestMonth) {
    if (highestMonth <= 10) return 10;
    final step = highestMonth <= 50 ? 10 : 20;
    return ((highestMonth + step - 1) ~/ step * step).toDouble();
  }

  double _chartInterval(double maxY) {
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return maxY / 5;
  }

  // ─── Status Distribution Ring ────────────────────────────
  Widget _buildStatusRing(List<dynamic> orders, {required int year}) {
    final pending = orders.where((o) => o.status == 'pending').length;
    final delivered = orders.where((o) => o.status == 'delivered').length;
    final returned = orders.where((o) => o.status == 'returned').length;
    final total = orders.isEmpty ? 1 : orders.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status Breakdown', style: AppTypography.h3.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              Text('$year', style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 32,
                    sections: [
                      PieChartSectionData(
                        value: (pending / total * 100).clamp(0.5, 100.0),
                        title: '',
                        color: AppColors.pending,
                        radius: 22,
                      ),
                      PieChartSectionData(
                        value: (delivered / total * 100).clamp(0.5, 100.0),
                        title: '',
                        color: AppColors.delivered,
                        radius: 22,
                      ),
                      PieChartSectionData(
                        value: (returned / total * 100).clamp(0.5, 100.0),
                        title: '',
                        color: AppColors.returned,
                        radius: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _statusRow('Pending', pending, AppColors.pending),
                    const SizedBox(height: 10),
                    _statusRow('Delivered', delivered, AppColors.delivered),
                    const SizedBox(height: 10),
                    _statusRow('Returned', returned, AppColors.returned),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          '$count',
          style: AppTypography.h4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─── Staff Leaderboard ──────────────────────────────────
  Widget _buildStaffLeaderboard(List<dynamic> staffList, List<dynamic> orders) {
    final ranked = staffList.map((staff) {
      final staffOrders = orders.where((o) =>
          (o.staffId == staff.userId || o.staffId == staff.id) &&
          o.orderDate.year == _selectedPerformerYear &&
          o.orderDate.month == _selectedPerformerMonth).toList();
      final deliveredOrders = staffOrders.where((o) => o.status.toLowerCase() == 'delivered').toList();
      final returns = staffOrders.where((o) => ['returned', 'return', 'returned_to_sender'].contains(o.status.toLowerCase())).length;
      final commission = staff.commissionType == 'percentage'
          ? deliveredOrders.fold<double>(0, (sum, o) => sum + o.codAmount) * staff.commissionValue / 100
          : deliveredOrders.length * staff.commissionValue;
      return <String, dynamic>{
        'staff': staff,
        'orders': staffOrders,
        'delivered': deliveredOrders.length,
        'returns': returns,
        'cod': deliveredOrders.fold<double>(0, (sum, o) => sum + o.codAmount),
        'score': commission - returns * staff.returnPenalty,
      };
    }).where((row) => (row['delivered'] as int) > 0).toList()
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Performers',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_rounded, size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '${ranked.length} active performers',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPerformerPeriodDropdown(),
              Text(
                'Performance for ${_monthName(_selectedPerformerMonth)} $_selectedPerformerYear',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ranked.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: 'No performers for this period',
                  subtitle: 'Select another month or year to view results',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ranked.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = ranked[index];
                    final staff = row['staff'];
                    final staffOrders = row['orders'] as List<dynamic>;
                    final delivered = row['delivered'] as int;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // Rank badge
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? AppColors.warning.withValues(alpha: 0.2)
                                  : AppColors.surfaceBright,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '#${index + 1}',
                                style: AppTypography.caption.copyWith(
                                  color: index == 0 ? AppColors.warning : AppColors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Avatar
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'S',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${staffOrders.length} orders • $delivered delivered',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Rs. ${(row['score'] as double).toStringAsFixed(0)}',
                            style: AppTypography.h4.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildPerformerPeriodDropdown() {
    return OutlinedButton.icon(
      onPressed: _selectPerformerPeriod,
      icon: const Icon(Icons.calendar_month_outlined, size: 16),
      label: Text('${_monthName(_selectedPerformerMonth)} $_selectedPerformerYear'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _selectPerformerPeriod() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedPerformerYear, _selectedPerformerMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year, 12, 31),
      helpText: 'SELECT PERFORMANCE MONTH',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedPerformerYear = selected.year;
      _selectedPerformerMonth = selected.month;
    });
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}
