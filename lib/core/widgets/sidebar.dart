import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

/// Navigation item model
class SidebarItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String? badge;

  const SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    this.activeIcon,
    this.badge,
  });
}

/// Fixed left sidebar navigation
class AppSidebar extends StatefulWidget {
  final String activeItemId;
  final List<SidebarItem> items;
  final String userName;
  final String userRole;
  final ValueChanged<String> onItemSelected;
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.activeItemId,
    required this.items,
    required this.userName,
    required this.userRole,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  String? _hoveredItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ─── Logo / Brand ─────────────────────────────
          _buildHeader(),
          const Divider(),

          // ─── Navigation Items ─────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isActive = item.id == widget.activeItemId;
                final isHovered = item.id == _hoveredItem;
                return _buildNavItem(item, isActive, isHovered);
              },
            ),
          ),

          // ─── User Section ─────────────────────────────
          const Divider(),
          _buildUserSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/logo/splashscreen.png',
            width: 44,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ZH',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        'PRO',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryHover,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Order System',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(SidebarItem item, bool isActive, bool isHovered) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredItem = item.id),
        onExit: (_) => setState(() => _hoveredItem = null),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.onItemSelected(item.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.sidebarItemActive
                  : isHovered
                      ? AppColors.sidebarItemHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: isActive
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? (item.activeIcon ?? item.icon) : item.icon,
                  size: 20,
                  color: isActive
                      ? AppColors.primary
                      : isHovered
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.bodySmall.copyWith(
                      color: isActive
                          ? AppColors.textPrimary
                          : isHovered
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      item.badge!,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              widget.userName.isNotEmpty
                  ? widget.userName[0].toUpperCase()
                  : '?',
              style: AppTypography.h4.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.userRole,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onLogout,
              child: Tooltip(
                message: 'Sign out',
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
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
