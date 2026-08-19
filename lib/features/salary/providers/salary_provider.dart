import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../models/staff_model.dart';
import '../../staff/providers/staff_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/enums.dart';

/// Salary record model
class SalaryRecord {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int deliveredCount;
  final int returnCount;
  final double commissionEarned;
  final double penaltyDeducted;
  final double finalSalary;
  final bool isPaid;
  final DateTime? paidDate;

  const SalaryRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.periodStart,
    required this.periodEnd,
    this.deliveredCount = 0,
    this.returnCount = 0,
    this.commissionEarned = 0,
    this.penaltyDeducted = 0,
    this.finalSalary = 0,
    this.isPaid = false,
    this.paidDate,
  });

  factory SalaryRecord.fromJson(Map<String, dynamic> json) {
    return SalaryRecord(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      staffName: json['staff_name'] as String? ?? '',
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      deliveredCount: json['delivered_count'] as int? ?? 0,
      returnCount: json['return_count'] as int? ?? 0,
      commissionEarned: (json['commission_earned'] as num?)?.toDouble() ?? 0,
      penaltyDeducted: (json['penalty_deducted'] as num?)?.toDouble() ?? 0,
      finalSalary: (json['final_salary'] as num?)?.toDouble() ?? 0,
      isPaid: json['is_paid'] as bool? ?? false,
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'] as String)
          : null,
    );
  }
}

class SalaryState {
  final List<SalaryRecord> records;
  final bool isLoading;
  final String? error;

  const SalaryState({this.records = const [], this.isLoading = false, this.error});

  SalaryState copyWith({
    List<SalaryRecord>? records,
    bool? isLoading,
    String? error,
  }) {
    return SalaryState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SalaryNotifier extends StateNotifier<SalaryState> {
  final Ref ref;

  SalaryNotifier(this.ref) : super(const SalaryState()) {
    loadRecords();
  }

  Future<void> loadRecords() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.salaryRecords)
          .select('*, staff!inner(name)')
          .order('period_end', ascending: false);

      final records = (response as List).map((json) {
        final staffData = json['staff'] as Map<String, dynamic>?;
        json['staff_name'] = staffData?['name'] ?? '';
        return SalaryRecord.fromJson(json as Map<String, dynamic>);
      }).toList();

      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load salary records: $e');
    }
  }

  /// Calculate salary for a staff member for a given period
  /// Formula: Final Salary = (Delivered × Commission) − (Returns × Penalty)
  Future<bool> calculateSalary(
    StaffModel staff,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    try {
      // Count delivered and returned orders for this staff in the period
      final orders = ref.read(ordersProvider).orders;
      final staffOrders = orders.where((o) =>
          o.staffId == staff.userId &&
          o.orderDate.isAfter(periodStart) &&
          o.orderDate.isBefore(periodEnd.add(const Duration(days: 1))));

      final deliveredOrders = staffOrders.where((o) => o.status == 'delivered').toList();
      final returnedOrders = staffOrders.where((o) => o.status == 'returned').toList();

      double commission;
      if (staff.commissionType == 'percentage') {
        // Percentage of COD
        final totalCod = deliveredOrders.fold<double>(0, (s, o) => s + o.codAmount);
        commission = totalCod * (staff.commissionValue / 100);
      } else {
        // Fixed per delivered order
        commission = deliveredOrders.length * staff.commissionValue;
      }

      final penalty = returnedOrders.length * staff.returnPenalty;
      final finalSalary = commission - penalty;

      await SupabaseService.client
          .from(SupabaseConstants.salaryRecords)
          .upsert({
        'staff_id': staff.id,
        'period_start': periodStart.toIso8601String().split('T')[0],
        'period_end': periodEnd.toIso8601String().split('T')[0],
        'delivered_count': deliveredOrders.length,
        'return_count': returnedOrders.length,
        'commission_earned': commission,
        'penalty_deducted': penalty,
        'final_salary': finalSalary < 0 ? 0 : finalSalary,
      }, onConflict: 'staff_id,period_start,period_end');

      await loadRecords();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to calculate salary: $e');
      return false;
    }
  }

  /// Recalculate all staff salaries for current month
  Future<void> recalculateAll() async {
    final auth = ref.read(authProvider);
    final allStaff = ref.read(staffProvider).staff;
    final staffList = auth.role == UserRole.staff && auth.supabaseUser != null
        ? allStaff.where((s) => s.userId == auth.supabaseUser!.id || s.id == auth.supabaseUser!.id).toList()
        : allStaff;
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month, 1);
    final periodEnd = DateTime(now.year, now.month + 1, 0);

    for (final staff in staffList) {
      await calculateSalary(staff, periodStart, periodEnd);
    }
  }
}

final salaryProvider = StateNotifierProvider<SalaryNotifier, SalaryState>((ref) {
  return SalaryNotifier(ref);
});
