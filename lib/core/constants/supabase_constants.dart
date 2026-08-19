/// Supabase table and column name constants
class SupabaseConstants {
  SupabaseConstants._();

  // ─── Table Names ──────────────────────────────────────
  static const String profiles = 'profiles';
  static const String staff = 'staff';
  static const String products = 'products';
  static const String orders = 'orders';
  static const String orderItems = 'order_items';
  static const String orderLogs = 'order_logs';
  static const String codLedger = 'cod_ledger';
  static const String salaryRecords = 'salary_records';
  static const String settings = 'settings';
  static const String deliveryCharges = 'delivery_charges';
  static const String couriers = 'couriers';

  // ─── Roles ────────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String roleStaff = 'staff';

  // ─── Order Statuses ───────────────────────────────────
  static const String statusPending = 'pending';
  static const String statusDelivered = 'delivered';
  static const String statusReturned = 'returned';

  static const List<String> allStatuses = [
    statusPending,
    statusDelivered,
    statusReturned,
  ];

  static const List<String> lockedStatuses = [
    statusDelivered,
    statusReturned,
  ];

  // ─── Commission Types ─────────────────────────────────
  static const String commissionFixed = 'fixed';
  static const String commissionPercentage = 'percentage';
}
