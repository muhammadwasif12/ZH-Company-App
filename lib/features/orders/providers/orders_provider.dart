import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../models/order_model.dart';
import '../../auth/providers/auth_provider.dart';

/// State for orders list
class OrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  OrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? error,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Orders notifier — handles CRUD operations against Supabase
class OrdersNotifier extends StateNotifier<OrdersState> {
  final Ref ref;

  OrdersNotifier(this.ref) : super(const OrdersState()) {
    loadOrders();
  }

  /// Fetch all orders (admin sees all, staff sees own)
  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.orders)
          .select()
          .order('created_at', ascending: false);

      final orders = (response as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load orders: $e',
      );
    }
  }

  /// Create a new order
  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    try {
      // Do not send optional null fields. This keeps order creation compatible
      // with Supabase projects that have not yet added optional columns.
      final data = Map<String, dynamic>.from(orderData)
        ..removeWhere((_, value) => value == null);

      // Auto-fill staff info from logged in user
      final user = SupabaseService.currentUser;
      if (user != null) {
        data['staff_id'] = user.id;
      }
      final profile = ref.read(currentUserProvider);
      if (profile != null) {
        data['staff_name'] = profile.fullName;
      } else if (user != null) {
        data['staff_name'] = user.email?.split('@').first ?? 'Staff';
      }

      if (!data.containsKey('order_date') || data['order_date'] == null) {
        data['order_date'] = DateTime.now().toIso8601String();
      }
      if (!data.containsKey('status') || data['status'] == null) {
        data['status'] = SupabaseConstants.statusPending;
      }

      await SupabaseService.client
          .from(SupabaseConstants.orders)
          .insert(data)
          .select('id')
          .single();

      await loadOrders();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create order: $e');
      return false;
    }
  }

  /// Update an existing order
  Future<bool> updateOrder(String orderId, Map<String, dynamic> updates) async {
    try {
      final data = Map<String, dynamic>.from(updates)
        ..removeWhere((_, value) => value == null);

      await SupabaseService.client
          .from(SupabaseConstants.orders)
          .update(data)
          .eq('id', orderId);

      await loadOrders();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update order: $e');
      return false;
    }
  }

  /// Update order status (with lock enforcement via DB trigger)
  Future<bool> updateStatus(
    String orderId,
    String newStatus, {
    String? proofImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
      };
      if (proofImageUrl != null) {
        updates['proof_image_url'] = proofImageUrl;
      }

      await SupabaseService.client
          .from(SupabaseConstants.orders)
          .update(updates)
          .eq('id', orderId);

      await loadOrders();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update status: $e');
      return false;
    }
  }

  /// Delete an order (admin only)
  Future<bool> deleteOrder(String orderId) async {
    try {
      final row = await SupabaseService.client
          .from(SupabaseConstants.orders)
          .select('proof_image_url')
          .eq('id', orderId)
          .maybeSingle();
      final proofUrl = row?['proof_image_url'] as String?;
      final deleted = await SupabaseService.client
          .from(SupabaseConstants.orders)
          .delete()
          .eq('id', orderId)
          .select('id');
      if ((deleted as List).isEmpty) {
        throw StateError('Order was not deleted from Supabase.');
      }

      if (proofUrl != null && proofUrl.isNotEmpty) {
        final deletedFromCloud = await CloudinaryService.deleteImageByUrl(proofUrl);
        if (!deletedFromCloud) {
          state = state.copyWith(
            error: 'Order deleted, but its proof image could not be removed from Cloudinary.',
          );
        }
      }

      await loadOrders();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete order: $e');
      return false;
    }
  }

  /// Check for duplicate mobile number
  Future<bool> isDuplicateMobile(String mobile) async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConstants.orders)
          .select('id')
          .eq('customer_mobile', mobile)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Providers
final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref);
});

/// Filtered orders by status
final filteredOrdersProvider = Provider.family<List<OrderModel>, String?>((ref, status) {
  final orders = ref.watch(ordersProvider).orders;
  if (status == null || status.isEmpty) return orders;
  return orders.where((o) => o.status == status).toList();
});

/// Today's orders
final todayOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider).orders;
  final now = DateTime.now();
  return orders.where((o) =>
    o.orderDate.year == now.year &&
    o.orderDate.month == now.month &&
    o.orderDate.day == now.day
  ).toList();
});

/// Dashboard stats
final dashboardStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final now = DateTime.now();
  final todayOrders = ref.watch(todayOrdersProvider);
  final allOrders = ref.watch(ordersProvider).orders;
  bool isUpdatedToday(OrderModel order) =>
      order.updatedAt.year == now.year &&
      order.updatedAt.month == now.month &&
      order.updatedAt.day == now.day;

  final todayDelivered = allOrders
      .where((o) =>
          o.status.trim().toLowerCase() == SupabaseConstants.statusDelivered &&
          isUpdatedToday(o))
      .length;
  final todayReturned = allOrders
      .where((o) =>
          o.status.trim().toLowerCase() == SupabaseConstants.statusReturned &&
          isUpdatedToday(o))
      .length;

  final totalCod = allOrders.fold<double>(0, (sum, o) => sum + o.codAmount);
  final deliveredCod = allOrders
      .where((o) => o.status == 'delivered')
      .fold<double>(0, (sum, o) => sum + o.codAmount);
  final pendingCod = totalCod - deliveredCod;

  final totalDelivered = allOrders.where((o) => o.status == 'delivered').length;
  final totalReturned = allOrders.where((o) => o.status == 'returned').length;
  final returnRatio = (totalDelivered + totalReturned) > 0
      ? (totalReturned / (totalDelivered + totalReturned) * 100)
      : 0.0;

  return {
    'today_orders': todayOrders.length,
    'today_delivered': todayDelivered,
    'today_returned': todayReturned,
    'total_cod': totalCod,
    'delivered_cod': deliveredCod,
    'pending_cod': pendingCod,
    'return_ratio': returnRatio,
  };
});
