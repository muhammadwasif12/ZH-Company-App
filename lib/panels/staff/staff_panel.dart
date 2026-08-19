import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/common_widgets.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/orders/providers/orders_provider.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/salary/screens/salary_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../models/enums.dart';

class StaffPanel extends ConsumerStatefulWidget {
  const StaffPanel({super.key});

  @override
  ConsumerState<StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends ConsumerState<StaffPanel> {
  int _bottomNavIndex = 0;
  String? _drawerScreen;

  @override
  void initState() {
    super.initState();
    // A fresh session must never reuse orders from the previous user/session.
    Future.microtask(() => ref.read(ordersProvider.notifier).loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.profile?.fullName ?? 'Staff Member';

    return PopScope(
      canPop: _drawerScreen == null && _bottomNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_drawerScreen != null) {
          setState(() {
            _drawerScreen = null;
            _bottomNavIndex = 0;
          });
        } else if (_bottomNavIndex != 0) {
          setState(() => _bottomNavIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        appBar: _buildAppBar(userName),
        drawer: _buildModernDrawer(userName, 'Staff Account'),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          child: _buildCurrentBody(userName),
        ),
        bottomNavigationBar: _drawerScreen == null ? _buildFloatingNav() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String userName) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 20),
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        _drawerScreen != null ? _getDrawerItemTitle(_drawerScreen!) : _getTabTitle(_bottomNavIndex),
        style: AppTypography.h2.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildModernDrawer(String userName, String userRole) {
    final email = ref.read(authProvider).profile?.email ?? ref.read(authProvider).supabaseUser?.email ?? '';
    final drawerWidth = (MediaQuery.of(context).size.width * 0.82).clamp(280.0, 330.0);

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: AppColors.background,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dark Header with Big Clean Logo Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
              ),
              child: Column(
                children: [
                  // Clean Large Hero Logo (Slightly smaller proportion)
                  SizedBox(
                    width: double.infinity,
                    height: 125,
                    child: Center(
                      child: Image.asset(
                        'assets/logo/splashscreen.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 72),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: AppTypography.h2.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: AppTypography.caption.copyWith(color: AppColors.textTertiary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          userRole.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Drawer Section Title & Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'ACCOUNT & PREFERENCES',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _drawerItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
                  _drawerItem('profile', 'My Profile', Icons.person_outline_rounded, Icons.person_rounded),
                ],
              ),
            ),
            
            // Modern Footer Sign Out
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authProvider.notifier).signOut();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: AppTypography.button.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(String key, String title, IconData icon, IconData activeIcon) {
    final isActive = (_drawerScreen == key) || (key == 'dashboard' && _drawerScreen == null);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (key == 'dashboard') {
                _drawerScreen = null;
                _bottomNavIndex = 0;
              } else {
                _drawerScreen = key;
              }
            });
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.22),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                    )
                  : null,
              color: isActive ? null : AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.border.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                if (isActive)
                  Container(
                    width: 4,
                    height: 18,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 4),
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isActive)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNav() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            0,
            Icons.space_dashboard_outlined,
            Icons.space_dashboard_rounded,
            'Home',
          ),
          _navItem(
            1,
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            'Orders',
          ),
          _navItem(
            2,
            Icons.payments_outlined,
            Icons.payments_rounded,
            'Salary',
          ),
          _navItem(
            3,
            Icons.bar_chart_outlined,
            Icons.bar_chart_rounded,
            'Reports',
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _bottomNavIndex = index;
          _drawerScreen = null;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? AppColors.primaryHover : AppColors.textTertiary,
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryHover,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBody(String userName) {
    // If we had staff drawer modules, handle here. e.g. if (_drawerScreen == 'settings') return SettingsScreen();
    switch (_bottomNavIndex) {
      case 0:
        return _buildStaffDashboard(userName);
      case 1:
        return const OrdersScreen(
          key: ValueKey('staff_orders'),
          staffOnly: true,
        );
      case 2:
        return const SalaryScreen(key: ValueKey('staff_salary'));
      case 3:
        return const ReportsScreen(key: ValueKey('staff_reports'));
      default:
        return _buildStaffDashboard(userName);
    }
  }

  Widget _buildStaffDashboard(String userName) {
    final ordersState = ref.watch(ordersProvider);
    final currentUserId = ref.watch(authProvider).supabaseUser?.id;

    final myOrders = ordersState.orders
        .where((o) => currentUserId == null || o.staffId == currentUserId)
        .toList();

    final now = DateTime.now();
    final todayOrders = myOrders
        .where(
          (o) =>
              o.orderDate.year == now.year &&
              o.orderDate.month == now.month &&
              o.orderDate.day == now.day,
        )
        .toList();

    final deliveredCount = myOrders
        .where((o) => o.status == 'delivered')
        .length;
    final returnedCount = myOrders.where((o) => o.status == 'returned').length;
    final pendingCount = myOrders
        .where((o) => o.status == 'pending')
        .length;

    return SingleChildScrollView(
      key: const ValueKey('staff_dashboard'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Hey, $userName 👋',
            style: AppTypography.h1.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          Text(
            'Here\'s your performance overview',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Today',
                  '${todayOrders.length}',
                  Icons.shopping_bag_outlined,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  'Delivered',
                  '$deliveredCount',
                  Icons.check_circle_outline,
                  AppColors.delivered,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Pending',
                  '$pendingCount',
                  Icons.hourglass_empty_rounded,
                  AppColors.pending,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  'Returns',
                  '$returnedCount',
                  Icons.undo_rounded,
                  AppColors.returned,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Recent Orders
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _bottomNavIndex = 1),
                child: Text(
                  'See all',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryHover,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (myOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'No orders yet',
                subtitle: 'Tap + to create your first order',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myOrders.length > 5 ? 5 : myOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = myOrders[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.displayId,
                                  style: AppTypography.mono.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  status: OrderStatus.fromString(item.status),
                                  fontSize: 10,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.customerName,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item.productName} • ${item.city}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rs. ${item.codAmount.toStringAsFixed(0)}',
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

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'My Orders';
      case 2:
        return 'My Salary';
      case 3:
        return 'Reports';
      default:
        return 'Dashboard';
    }
  }

  String _getDrawerItemTitle(String key) {
    switch (key) {
      case 'profile':
        return 'My Profile';
      default:
        return 'Module';
    }
  }
}
