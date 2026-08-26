import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/providers/orders_provider.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/cod_ledger/screens/cod_ledger_screen.dart';
import '../../features/salary/screens/salary_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class AdminPanel extends ConsumerStatefulWidget {
  const AdminPanel({super.key});

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel> {
  int _bottomNavIndex = 0;
  String? _drawerScreen;
  bool _isSidebarCollapsed = false;

  /// Unified key for the sidebar — maps both bottom-nav indices and drawer keys.
  String get _activeKey {
    if (_drawerScreen != null) return _drawerScreen!;
    switch (_bottomNavIndex) {
      case 1: return 'orders';
      case 2: return 'products';
      case 3: return 'reports';
      default: return 'dashboard';
    }
  }

  void _selectSidebarItem(String key) {
    setState(() {
      switch (key) {
        case 'dashboard':
          _drawerScreen = null;
          _bottomNavIndex = 0;
          break;
        case 'orders':
          _drawerScreen = null;
          _bottomNavIndex = 1;
          break;
        case 'products':
          _drawerScreen = null;
          _bottomNavIndex = 2;
          break;
        case 'reports':
          _drawerScreen = null;
          _bottomNavIndex = 3;
          break;
        default:
          _drawerScreen = key;
          break;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ordersProvider.notifier).loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userName = authState.profile?.fullName ?? 'Admin';
    final userRole = authState.role?.label ?? 'Admin';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return _buildDesktopLayout(userName, userRole);
        }
        return _buildMobileLayout(userName, userRole);
      },
    );
  }

  // ─── Desktop Layout ───────────────────────────────────────
  Widget _buildDesktopLayout(String userName, String userRole) {
    final email = ref.read(authProvider).profile?.email ??
        ref.read(authProvider).supabaseUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Permanent / Collapsible sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _isSidebarCollapsed ? 72 : 260,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Sidebar header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _isSidebarCollapsed ? 8 : 20,
                    24,
                    _isSidebarCollapsed ? 8 : 20,
                    8,
                  ),
                  child: _isSidebarCollapsed
                      ? Column(
                          children: [
                            Image.asset(
                              'assets/logo/splashscreen.png',
                              height: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Image.asset(
                              'assets/logo/splashscreen.png',
                              height: 54,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              userName,
                              style: AppTypography.h4.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                userRole.toUpperCase(),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                Divider(
                  color: AppColors.border.withValues(alpha: 0.5),
                  height: 24,
                ),
                // Nav items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isSidebarCollapsed ? 8 : 12,
                    ),
                    children: [
                      if (!_isSidebarCollapsed) _sidebarLabel('MAIN'),
                      _sidebarItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
                      _sidebarItem('orders', 'Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
                      _sidebarItem('products', 'Products', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
                      _sidebarItem('reports', 'Reports', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
                      SizedBox(height: _isSidebarCollapsed ? 8 : 16),
                      if (!_isSidebarCollapsed) _sidebarLabel('MANAGEMENT'),
                      _sidebarItem('staff', 'Staff Management', Icons.people_alt_outlined, Icons.people_alt_rounded),
                      _sidebarItem('cod_ledger', 'COD Ledger', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
                      _sidebarItem('salary', 'Salary & Payouts', Icons.payments_outlined, Icons.payments_rounded),
                      _sidebarItem('settings', 'System Settings', Icons.tune_outlined, Icons.tune_rounded),
                    ],
                  ),
                ),
                // Sign out
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _isSidebarCollapsed ? 8 : 16,
                    8,
                    _isSidebarCollapsed ? 8 : 16,
                    20,
                  ),
                  child: ClipRect(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async => await ref.read(authProvider.notifier).signOut(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: _isSidebarCollapsed ? 0 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: _isSidebarCollapsed
                              ? const Tooltip(
                                  message: 'Sign Out',
                                  child: Center(
                                    child: Icon(
                                      Icons.logout_rounded,
                                      color: AppColors.error,
                                      size: 18,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.logout_rounded,
                                      color: AppColors.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Sign Out',
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.button.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Desktop top bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                        icon: Icon(
                          _isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getFullTitle(_activeKey),
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showProfileMenu(context, userName, userRole),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.accentPurple],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                              style: AppTypography.h4.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_activeKey),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _buildCurrentBody(),
                      ),
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

  Widget _sidebarLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
    child: Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.bold,
        fontSize: 10,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _sidebarItem(String key, String title, IconData icon, IconData activeIcon) {
    final isActive = _activeKey == key;
    if (_isSidebarCollapsed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: title,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectSidebarItem(key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ClipRect(
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectSidebarItem(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTypography.bodySmall.copyWith(
                        color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 3,
                      height: 16,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getFullTitle(String key) {
    switch (key) {
      case 'dashboard': return 'Dashboard';
      case 'orders': return 'Orders';
      case 'products': return 'Products';
      case 'reports': return 'Reports';
      case 'staff': return 'Staff Management';
      case 'cod_ledger': return 'COD Ledger';
      case 'salary': return 'Salary & Payouts';
      case 'settings': return 'Settings';
      default: return 'Dashboard';
    }
  }

  // ─── Mobile Layout (unchanged) ────────────────────────────
  Widget _buildMobileLayout(String userName, String userRole) {
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
        appBar: _buildAppBar(userName, userRole),
        drawer: _buildModernDrawer(userName, userRole),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Align(
            alignment: Alignment.topCenter,
            child: _buildCurrentBody(),
          ),
        ),
        bottomNavigationBar: _drawerScreen == null ? _buildFloatingNav() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String userName, String userRole) {
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
            child: const Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: _drawerScreen != null
          ? Text(
              _getDrawerItemTitle(_drawerScreen!),
              style: AppTypography.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            )
          : Row(
              children: [
                Text(
                  _getTabTitle(_bottomNavIndex),
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.accentPurple.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    userRole,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryHover,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        // Profile avatar button
        GestureDetector(
          onTap: () => _showProfileMenu(context, userName, userRole),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                style: AppTypography.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileMenu(
    BuildContext context,
    String userName,
    String userRole,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accentPurple],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                  style: AppTypography.h1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              userName,
              style: AppTypography.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              userRole,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).signOut();
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
                label: Text(
                  'Sign Out',
                  style: AppTypography.button.copyWith(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
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
        border: Border.all(color: AppColors.border, width: 1),
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
            Icons.inventory_2_outlined,
            Icons.inventory_2_rounded,
            'Products',
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

  Widget _buildModernDrawer(String userName, String userRole) {
    final email =
        ref.read(authProvider).profile?.email ??
        ref.read(authProvider).supabaseUser?.email ??
        '';
    final drawerWidth = (MediaQuery.of(context).size.width * 0.82).clamp(
      280.0,
      330.0,
    );

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
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                20,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
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
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 72,
                        ),
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
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'MODULES MANAGEMENT',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _drawerItem(
                    'dashboard',
                    'Dashboard',
                    Icons.space_dashboard_outlined,
                    Icons.space_dashboard_rounded,
                  ),
                  _drawerItem(
                    'staff',
                    'Staff Management',
                    Icons.people_alt_outlined,
                    Icons.people_alt_rounded,
                  ),
                  _drawerItem(
                    'cod_ledger',
                    'COD Ledger',
                    Icons.account_balance_wallet_outlined,
                    Icons.account_balance_wallet_rounded,
                  ),
                  _drawerItem(
                    'salary',
                    'Salary & Payouts',
                    Icons.payments_outlined,
                    Icons.payments_rounded,
                  ),
                  _drawerItem(
                    'settings',
                    'System Settings',
                    Icons.tune_outlined,
                    Icons.tune_rounded,
                  ),
                ],
              ),
            ),

            // Modern Footer Sign Out
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
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
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
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

  Widget _drawerItem(
    String key,
    String title,
    IconData icon,
    IconData activeIcon,
  ) {
    final isActive =
        (_drawerScreen == key) || (key == 'dashboard' && _drawerScreen == null);
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
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
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

  Widget _buildCurrentBody() {
    if (_drawerScreen != null) {
      return _buildDrawerScreen(_drawerScreen!);
    }

    switch (_bottomNavIndex) {
      case 0:
        return const AdminDashboardScreen(key: ValueKey('admin_dashboard'));
      case 1:
        return const OrdersScreen(key: ValueKey('admin_orders'));
      case 2:
        return const ProductsScreen(key: ValueKey('admin_products'));
      case 3:
        return const ReportsScreen(key: ValueKey('admin_reports'));
      default:
        return const AdminDashboardScreen(key: ValueKey('admin_dashboard'));
    }
  }

  Widget _buildDrawerScreen(String key) {
    switch (key) {
      case 'staff':
        return const StaffScreen(key: ValueKey('admin_staff'));
      case 'cod_ledger':
        return const CodLedgerScreen(key: ValueKey('admin_cod_ledger'));
      case 'salary':
        return const SalaryScreen(key: ValueKey('admin_salary'));
      case 'settings':
        return const SettingsScreen(key: ValueKey('admin_settings'));
      default:
        return const AdminDashboardScreen();
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Orders';
      case 2:
        return 'Products';
      case 3:
        return 'Reports';
      default:
        return 'Dashboard';
    }
  }

  String _getDrawerItemTitle(String key) {
    switch (key) {
      case 'staff':
        return 'Staff Management';
      case 'cod_ledger':
        return 'COD Ledger';
      case 'salary':
        return 'Salary & Payouts';
      case 'settings':
        return 'Settings';
      default:
        return 'Module';
    }
  }
}
