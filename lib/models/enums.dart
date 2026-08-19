import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/supabase_constants.dart';

/// Only Admin and Staff accounts are supported.
enum UserRole {
  admin,
  staff;

  String get label => this == UserRole.admin ? 'Admin' : 'Staff';

  static UserRole fromString(String role) =>
      role.toLowerCase() == 'admin' ? UserRole.admin : UserRole.staff;
}

/// The complete order lifecycle: pending, delivered, or return.
enum OrderStatus {
  pending(
    SupabaseConstants.statusPending,
    'Pending',
    AppColors.pending,
    AppColors.pendingBg,
    Icons.schedule,
  ),
  delivered(
    SupabaseConstants.statusDelivered,
    'Delivered',
    AppColors.delivered,
    AppColors.deliveredBg,
    Icons.check_circle,
  ),
  returned(
    SupabaseConstants.statusReturned,
    'Return',
    AppColors.returned,
    AppColors.returnedBg,
    Icons.undo,
  );

  final String value;
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const OrderStatus(this.value, this.label, this.color, this.bgColor, this.icon);

  bool get isLocked => this != OrderStatus.pending;

  static OrderStatus fromString(String status) => OrderStatus.values.firstWhere(
        (item) => item.value == status.toLowerCase(),
        orElse: () => OrderStatus.pending,
      );

  List<OrderStatus> get allowedTransitions => switch (this) {
        OrderStatus.pending => [OrderStatus.delivered, OrderStatus.returned],
        OrderStatus.delivered || OrderStatus.returned => const [],
      };
}

enum CommissionType {
  fixed('fixed', 'Fixed per Order'),
  percentage('percentage', '% of COD');

  final String value;
  final String label;

  const CommissionType(this.value, this.label);

  static CommissionType fromString(String type) => CommissionType.values.firstWhere(
        (item) => item.value == type.toLowerCase(),
        orElse: () => CommissionType.fixed,
      );
}
